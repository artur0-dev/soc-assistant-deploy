#!/usr/bin/env bash
# Arranque del SOC Assistant todo-en-uno en Linux/macOS.
# La base de datos empieza vacia y los secretos se generan solos.
set -Eeuo pipefail

IMAGE="${SOC_IMAGE:-ghcr.io/artur0-dev/soc-assistant-allinone:latest}"
CONTAINER="${SOC_CONTAINER:-soc-assistant}"
HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_PORT="${HTTPS_PORT:-443}"
BIND_IP="${BIND_IP:-0.0.0.0}"
WAZUH_HOST="${WAZUH_HOST:-}"
SPLUNK_HOST="${SPLUNK_HOST:-}"
FORCE=0
USE_GPU=0
NO_PULL=0
REGEN_CERTS=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --force) FORCE=1 ;;
        --gpu) USE_GPU=1 ;;
        --no-pull) NO_PULL=1 ;;
        --regenerate-certs) REGEN_CERTS=1 ;;
        --image) IMAGE="$2"; shift ;;
        --http-port) HTTP_PORT="$2"; shift ;;
        --https-port) HTTPS_PORT="$2"; shift ;;
        --bind-ip) BIND_IP="$2"; shift ;;
        --wazuh-host) WAZUH_HOST="$2"; shift ;;
        --splunk-host) SPLUNK_HOST="$2"; shift ;;
        -h|--help)
            echo "Uso: $0 [--force] [--gpu] [--no-pull] [--regenerate-certs] [--image IMAGEN] [--http-port 80] [--https-port 443]"
            exit 0
            ;;
        *) echo "Opcion desconocida: $1" >&2; exit 1 ;;
    esac
    shift
done

command -v docker >/dev/null 2>&1 || { echo "Docker no esta instalado." >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "Docker no esta arrancado." >&2; exit 1; }

get_ip() {
    local ip=""
    ip="$(ip route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}')" || true
    if [ -z "$ip" ]; then
        ip="$(hostname -I 2>/dev/null | awk '{print $1}')" || true
    fi
    if [ -z "$ip" ]; then ip="127.0.0.1"; fi
    printf '%s' "$ip"
}

show_access() {
    local ip="$1" port="$2" url=""
    if [ "$port" = "443" ]; then url="https://$ip"; else url="https://$ip:$port"; fi
    local admin=""
    admin="$(docker exec "$CONTAINER" sh -c '. /certs/.soc.env; printf %s "$ADMIN_PASSWORD"' 2>/dev/null || true)"
    echo ""
    echo "============================================================"
    echo " SOC Assistant esta listo"
    echo " URL:              $url"
    echo " Usuario:          admin"
    echo " Contrasena admin: ${admin:-(no disponible; consulta /certs/.soc.env)}"
    echo ""
    echo " CA para clientes:"
    echo "   docker cp $CONTAINER:/certs/ca.crt ./ca.crt"
    echo "============================================================"
}

if [ "$NO_PULL" = "0" ]; then
    echo "[1/5] Descargando/actualizando $IMAGE ..."
    docker pull "$IMAGE"
else
    echo "[1/5] Usando imagen local $IMAGE ..."
    docker image inspect "$IMAGE" >/dev/null
fi

if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    if [ "$FORCE" = "1" ]; then
        echo "[2/5] Eliminando contenedor anterior ..."
        docker rm -f "$CONTAINER" >/dev/null
    else
        echo "[2/5] El contenedor ya existe. Arrancandolo ..."
        docker start "$CONTAINER" >/dev/null
        sleep 3
        show_access "$(get_ip)" "$HTTPS_PORT"
        echo "Para recrearlo: $0 --force"
        exit 0
    fi
fi

IP="$(get_ip)"
if [ "$HTTPS_PORT" = "443" ]; then
    PUBLIC_URL="https://$IP"
else
    PUBLIC_URL="https://$IP:$HTTPS_PORT"
fi

if [ "$USE_GPU" = "0" ]; then
    if docker info --format '{{json .Runtimes}}' 2>/dev/null | grep -q nvidia; then
        USE_GPU=1
    fi
fi

echo "[3/5] Creando volumenes persistentes ..."
docker volume create soc_assistant_pgdata >/dev/null
docker volume create soc_assistant_certs >/dev/null

echo "[4/5] Arrancando contenedor (GPU: $USE_GPU) ..."
ARGS=(
    run -d
    --name "$CONTAINER"
    --restart unless-stopped
    -p "${BIND_IP}:${HTTP_PORT}:80"
    -p "${BIND_IP}:${HTTPS_PORT}:443"
    -e "CERT_HOST_IPS=127.0.0.1,$IP"
    -e "CERT_HOST_DNS=soc-assistant.local,localhost"
    -e "PUBLIC_URL=$PUBLIC_URL"
    -v "soc_assistant_pgdata:/var/lib/postgresql/data"
    -v "soc_assistant_certs:/certs"
)
# PUBLIC_URL es la URL de la app, no la de Wazuh ni Splunk.
[ -n "$WAZUH_HOST" ] && ARGS+=(-e "WAZUH_HOST=$WAZUH_HOST")
[ -n "$SPLUNK_HOST" ] && ARGS+=(-e "SPLUNK_HOST=$SPLUNK_HOST")
[ "$REGEN_CERTS" = "1" ] && ARGS+=(-e "FORCE_CERTS=true")
[ "$USE_GPU" = "1" ] && ARGS+=(--gpus all)
ARGS+=("$IMAGE")

docker "${ARGS[@]}"

echo "[5/5] Esperando a que este sano ..."
for _ in $(seq 1 120); do
    status="$(docker inspect --format '{{.State.Status}}' "$CONTAINER" 2>/dev/null || true)"
    if [ "$status" = "exited" ]; then
        echo "El contenedor ha terminado. Ultimos logs:"
        docker logs --tail 100 "$CONTAINER"
        exit 1
    fi
    health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$CONTAINER" 2>/dev/null || true)"
    if [ "$health" = "healthy" ]; then
        break
    fi
    sleep 2
done

show_access "$IP" "$HTTPS_PORT"

