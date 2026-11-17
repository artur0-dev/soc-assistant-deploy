# SOC Assistant

SOC Assistant es una aplicación web para el trabajo diario de un equipo SOC.
Reúne alertas, casos e informes, y añade un asistente de IA que responde
preguntas usando el contexto de esos datos.

Todo funciona en una sola máquina. La imagen Docker es **todo-en-uno**: incluye
la interfaz web, el backend, PostgreSQL, Ollama con sus modelos y un certificado
HTTPS para la red interna.

Wazuh y Splunk son **opcionales**. Si tu empresa ya los tiene, se conectan desde
la pantalla de **Integraciones**. Si no los tienes, la aplicación arranca igual
y funciona con sus alertas, casos, informes y asistente.

La base de datos se crea vacía en el primer arranque. No se incluyen alertas,
casos, informes, usuarios ni secretos de ninguna instalación anterior. Las
contraseñas y claves se generan automáticamente la primera vez.

## Instalación rápida: solo Docker

No necesitas Git ni scripts. Solo Docker.

### 1. Instala Docker

- **Windows y macOS:** instala [Docker Desktop](https://www.docker.com/products/docker-desktop/).
  Si te ofrece usar WSL 2, acepta esa opción. Después ábrelo y espera a que el
  motor de Docker esté en marcha.
- **Linux:** instala Docker Engine y asegúrate de que tu usuario puede ejecutar
  `docker` (o usa `sudo`).

Necesitas unos **30-40 GB de espacio libre** y, recomendablemente, **16 GB de
RAM**. La imagen ocupa unos 23 GB.

### 2. Abre una terminal

Puede ser la terminal de Docker Desktop, CMD, Terminal de macOS o la terminal
de Linux. Los comandos son los mismos.

### 3. Ejecuta este comando

Copia y pega esta línea completa:

```bash
docker run -d --name soc-assistant --restart unless-stopped -p 127.0.0.1:80:80 -p 127.0.0.1:443:443 -v soc_assistant_pgdata:/var/lib/postgresql/data -v soc_assistant_certs:/certs ghcr.io/artur0-dev/soc-assistant-allinone:latest
```

Este comando publica la aplicación **solo en `127.0.0.1`**: se puede usar desde
este mismo PC, pero no queda abierta al resto de la red. Si necesitas entrar
desde otro equipo, mira la sección **Acceso desde otros equipos**.

Docker descarga la imagen desde GitHub Container Registry y arranca todo
automáticamente. No hace falta cuenta de GitHub ni `docker login`.

La primera vez puede tardar bastante porque la imagen es grande. Puedes ver el
progreso con:

```bash
docker logs -f soc-assistant
```

### 4. Espera a que esté listo

```bash
docker ps --filter name=soc-assistant
```

En la columna `STATUS` debe aparecer `healthy`. Si aparece `starting`, espera
unos minutos: la primera vez tarda más porque arranca PostgreSQL, la IA y el
resto de servicios.

### 5. Abre la aplicación

En el mismo PC:

```text
https://localhost
```

Si el navegador avisa de que el certificado no es de confianza, es normal: la
aplicación usa un certificado propio para la red interna. Puedes continuar.

### 6. Usuario y contraseña

El usuario es `admin`. La contraseña se genera automáticamente y se muestra en
los logs la primera vez:

```bash
docker logs soc-assistant
```

Busca la línea `Contrasena admin:`. Si ya no aparece, puedes consultarla así:

```bash
docker exec soc-assistant sh -c "grep ADMIN_PASSWORD /certs/.soc.env"
```

## Acceso desde otros equipos

Si solo vas a usar SOC Assistant desde el mismo PC, no tienes que cambiar nada.

Si necesitas que otros equipos de la red entren, tendrás que abrir la
aplicación a la red. Es opcional y solo recomendable en una red de confianza:
cualquier equipo que llegue al puerto verá la pantalla de login.

Para entrar desde otro equipo de la red, abre:

```text
https://IP-DEL-SERVIDOR
```

Puedes ver la IP con `ipconfig` en Windows o `hostname -I` en Linux. El
certificado está pensado para `localhost`, así que el navegador mostrará un
aviso. Puedes continuar y la aplicación funcionará igual.

Si quieres que el certificado incluya también la IP del servidor, recrea el
contenedor indicando tu IP. Sustituye `192.168.1.50` por la IP real:

```bash
docker rm -f soc-assistant
docker run -d --name soc-assistant --restart unless-stopped -p 80:80 -p 443:443 -e PUBLIC_URL=https://192.168.1.50 -e CERT_HOST_IPS=127.0.0.1,192.168.1.50 -v soc_assistant_pgdata:/var/lib/postgresql/data -v soc_assistant_certs:/certs ghcr.io/artur0-dev/soc-assistant-allinone:latest
```

Si cambias la IP más adelante, tendrás que repetir ese paso y volver a instalar
la CA en los equipos cliente.

## Instalar el certificado en los clientes

Para que el navegador no muestre el aviso, copia la CA desde el contenedor:

```bash
docker cp soc-assistant:/certs/ca.crt .
```

- **Windows:** doble clic en `ca.crt` → **Instalar certificado** → **Equipo
  local** → **Siguiente** → **Entidades de certificación raíz de confianza** →
  **Finalizar**.
- **Linux:** copia el archivo a `/usr/local/share/ca-certificates/` y ejecuta
  `sudo update-ca-certificates`.
- **macOS:** abre el archivo con **Acceso a Llaveros** y marca la CA como
  confiable.

## Alternativa con Docker Compose

Si prefieres usar un archivo, el repositorio incluye `docker-compose.yml`.
Descarga el repositorio y ejecuta:

```bash
git clone https://github.com/artur0-dev/soc-assistant-deploy.git
cd soc-assistant-deploy
docker compose up -d
```

También puedes usar el botón **Code → Download ZIP** de GitHub y ejecutar
`docker compose up -d` dentro de la carpeta descomprimida.

Por defecto, el compose también publica la aplicación solo en `127.0.0.1`.
Para abrirla al resto de la red:

```bash
BIND_IP=0.0.0.0 docker compose up -d
```

En Windows CMD sería:

```cmd
set BIND_IP=0.0.0.0 && docker compose up -d
```

## Cambiar los puertos

Si el 80 o el 443 están ocupados, usa otros puertos. Por ejemplo:

```bash
docker run -d --name soc-assistant --restart unless-stopped -p 127.0.0.1:8080:80 -p 127.0.0.1:8443:443 -e PUBLIC_URL=https://localhost:8443 -v soc_assistant_pgdata:/var/lib/postgresql/data -v soc_assistant_certs:/certs ghcr.io/artur0-dev/soc-assistant-allinone:latest
```

La URL pasará a ser `https://localhost:8443`.

## Actualizar sin perder datos

Los datos se guardan en dos volúmenes de Docker:

- `soc_assistant_pgdata`: base de datos.
- `soc_assistant_certs`: certificados y secretos generados.

Para actualizar:

```bash
docker pull ghcr.io/artur0-dev/soc-assistant-allinone:latest
docker rm -f soc-assistant
```

Después vuelve a ejecutar el comando de instalación. Los volúmenes se conservan.

Con Docker Compose:

```bash
docker compose pull
docker compose up -d
```

## Parar, arrancar y ver logs

```bash
docker stop soc-assistant
docker start soc-assistant
docker logs -f soc-assistant
```

## Wazuh y Splunk

Son conectores independientes y opcionales. Se configuran desde la pantalla
**Integraciones** de SOC Assistant:

- **Wazuh:** URL, usuario y contraseña del Wazuh de tu empresa.
- **Splunk:** URL y credenciales de Splunk.

La variable `PUBLIC_URL` es la URL de SOC Assistant, no la de Wazuh ni la de
Splunk. No las mezcles.

Si no configuras ninguno de los dos, la aplicación funciona igual: puedes usar
el asistente, las alertas, los casos y los informes con los datos que vayas
creando.

## Copias de seguridad y borrado

Para conservar los datos, no borres los volúmenes `soc_assistant_pgdata` ni
`soc_assistant_certs`.

Para empezar de cero, borrando todo:

```bash
docker rm -f soc-assistant
docker volume rm soc_assistant_pgdata soc_assistant_certs
```

Después vuelve a ejecutar el comando de instalación.

**Aviso:** eso elimina la base de datos, los casos, los informes, los usuarios y
los certificados. No se puede deshacer.

## Problemas frecuentes

### Docker no está arrancado

Abre Docker Desktop y espera a que termine de iniciarse. En Linux comprueba que
el servicio de Docker está activo.

### El puerto 80 o 443 está ocupado

Usa otros puertos, por ejemplo `-p 127.0.0.1:8080:80 -p 127.0.0.1:8443:443`, y abre
`https://localhost:8443`.

### El contenedor no llega a estar sano

Mira los últimos logs:

```bash
docker logs --tail 200 soc-assistant
```

La primera vez puede tardar varios minutos mientras arrancan PostgreSQL, la IA
y el resto de servicios.

### El navegador avisa del certificado

Es normal si todavía no has instalado `ca.crt`. Instálalo como se explica más
arriba. Si accedes desde otro PC, también es normal que el certificado no
coincida con la IP; puedes continuar o regenerarlo indicando tu IP.

### La IA va lenta

Los modelos se ejecutan en local. Ayuda tener más RAM y una GPU NVIDIA. Sin GPU
funciona, pero las respuestas pueden tardar más.

### La descarga de la imagen falla

Comprueba la conexión a Internet y vuelve a intentarlo:

```bash
docker pull ghcr.io/artur0-dev/soc-assistant-allinone:latest
```

## Estructura del repositorio

```text
docker-compose.yml   Alternativa para arrancar con Docker Compose
README.md            Esta guía
```

Este repositorio solo contiene la forma de arrancar la imagen publicada en
GHCR. La aplicación y los modelos están dentro de la imagen Docker.
