# SOC Assistant - despliegue todo en uno

Este repositorio sirve para **descargar y arrancar SOC Assistant** en otro PC
sin copiar el codigo fuente, sin base de datos y sin ficheros `.env`.

La aplicacion va dentro de una unica imagen Docker:

- PostgreSQL
- Backend FastAPI
- Frontend nginx
- Ollama con los modelos de IA y embeddings

La base de datos se crea vacia en el primer arranque. Los secretos
(`JWT_SECRET`, `SECRET_KEY`, contrasena de PostgreSQL y de `admin`) se generan
automaticamente dentro del contenedor y se guardan en el volumen
`soc_assistant_certs`.

> Importante: este repositorio **no contiene la imagen Docker**. La imagen ya
> esta publicada en GitHub Container Registry (GHCR) y es publica: no hace falta
> cuenta de GitHub para descargarla. El repo solo contiene los scripts de
> instalacion.

> Si solo quieres instalar SOC Assistant, salta directamente a la seccion 3.

## 1. Publicar o actualizar la imagen (solo el propietario)

En el PC donde ya existe `soc-assistant-allinone:latest`:

```powershell
docker tag soc-assistant-allinone:latest ghcr.io/artur0-dev/soc-assistant-allinone:latest

$env:GH_TOKEN | docker login ghcr.io -u artur0-dev --password-stdin

docker push ghcr.io/artur0-dev/soc-assistant-allinone:latest
```

El usuario ya esta configurado como `artur0-dev`.

Despues, en GitHub:

1. Entra en **Packages**.
2. Abre `soc-assistant-allinone`.
3. En **Settings**, pon la visibilidad en **Public** si quieres que cualquiera
   pueda descargarla sin autenticarse.

Si prefieres dejarla privada, en el PC destino tendran que ejecutar antes:

```powershell
docker login ghcr.io
```

## 2. Repositorio ya configurado

Este repositorio ya apunta a `artur0-dev`. No hay que cambiar ningun nombre
antes de usarlo.

## 3. Arrancar en el PC destino

### Windows

Requisitos:

- Docker Desktop instalado y arrancado.
- 30-40 GB libres.
- Opcional: GPU NVIDIA con NVIDIA Container Toolkit.

```powershell
git clone https://github.com/artur0-dev/soc-assistant-deploy.git
cd soc-assistant-deploy

.\Iniciar-AllInOne.ps1
```

Si Windows bloquea el script:

```powershell
powershell -ExecutionPolicy Bypass -File .\Iniciar-AllInOne.ps1
```

El script:

1. descarga la imagen,
2. detecta la IP de red,
3. crea los volumenes persistentes,
4. arranca el contenedor,
5. espera a que este sano,
6. muestra la URL, el usuario `admin` y la contrasena generada.

Si no quieres usar un registry y prefieres mover el `.tar` por USB:

```powershell
docker load -i .\soc-assistant-allinone.tar
.\Iniciar-AllInOne.ps1 -Image soc-assistant-allinone:latest -NoPull
```

### Linux o macOS

```bash
chmod +x iniciar-allinone.sh
./iniciar-allinone.sh
```

O con Docker Compose:

```bash
CERT_HOST_IPS="127.0.0.1,192.168.1.50" \
PUBLIC_URL="https://192.168.1.50" \
docker compose up -d
```

## 4. Que es `PUBLIC_URL`

`PUBLIC_URL` es la URL de **SOC Assistant**, no la de Wazuh ni la de Splunk.

Ejemplo:

```text
PUBLIC_URL=https://192.168.1.50
```

Si la empresa tiene otra IP, el script detecta automaticamente la IP del PC y
genera el certificado para esa IP en el primer arranque. Tambien se puede
indicar manualmente:

```powershell
.\Iniciar-AllInOne.ps1 -Force
```

Si la IP del servidor cambia despues del primer arranque, hay que regenerar el
certificado para que incluya la nueva IP:

```powershell
.\Iniciar-AllInOne.ps1 -Force -RegenerateCerts
```

Eso genera una CA nueva; los equipos cliente tendran que volver a instalar
`ca.crt`. Si no se regenera, la app sigue funcionando pero el navegador avisara
de que el certificado no coincide con la IP.

o, con Compose:

```powershell
$env:CERT_HOST_IPS="127.0.0.1,192.168.1.77"
$env:PUBLIC_URL="https://192.168.1.77"
docker compose up -d
```

Para regenerar certificados con Compose:

```powershell
$env:FORCE_CERTS="true"
docker compose up -d
```

### Wazuh y Splunk

Son conectores independientes y opcionales. No van en `PUBLIC_URL`.

- Wazuh: se configura desde **Integraciones** con la URL, usuario y contrasena
  del Wazuh de la empresa.
- Splunk: igual, desde **Integraciones**.
- Si no se configura ninguno, la app arranca y funciona con el resto de
  funciones.

Los parametros `-WazuhHost` y `-SplunkHost` del script solo anaden nombres de
host al `/etc/hosts` del contenedor. Las credenciales reales se ponen en la
interfaz.

## 5. Puertos y acceso

Por defecto:

- `80/tcp` redirige a HTTPS.
- `443/tcp` sirve la aplicacion.

Si estan ocupados:

```powershell
.\Iniciar-AllInOne.ps1 -HttpPort 8080 -HttpsPort 8443
```

La URL sera `https://IP:8443`.

Para instalar la CA en los equipos cliente:

```powershell
docker cp soc-assistant:/certs/ca.crt .\ca.crt
```

## 6. Ver la contrasena de admin

```powershell
docker exec soc-assistant sh -c ". /certs/.soc.env; echo \$ADMIN_PASSWORD"
```

## 7. Datos y actualizaciones

Los datos viven en los volumenes:

- `soc_assistant_pgdata`: base de datos.
- `soc_assistant_certs`: certificados y secretos.

Para actualizar la imagen sin perder datos:

```powershell
.\Iniciar-AllInOne.ps1 -Force
```

Eso descarga la ultima imagen, recrea el contenedor y conserva los volumenes.

Para empezar de cero, borrando todos los datos:

```powershell
docker rm -f soc-assistant
docker volume rm soc_assistant_pgdata soc_assistant_certs
.\Iniciar-AllInOne.ps1
```

## 8. Que NO se sube a GitHub

El `.gitignore` ya lo bloquea:

```text
.env
.env.*
certs/
*.pem
*.key
*.crt
*.tar
*.tar.gz
backups/
pgdata/
volumes/
*.log
ca.crt
```

El repositorio no contiene datos de alertas, informes, casos, usuarios ni
secretos. La app arranca con la base vacia.

## 9. Instrucciones para subir este repositorio a GitHub

Estan en [`SUBIR_A_GITHUB.md`](SUBIR_A_GITHUB.md).

Las instrucciones detalladas para publicar la imagen en GHCR estan en
[`PUBLICAR_GHCR.md`](PUBLICAR_GHCR.md).

