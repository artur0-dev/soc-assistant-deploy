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

## Acceso desde un segundo equipo (opcional)

Si la aplicación va a estar en el PC del cliente y quieres entrar también desde
otro equipo tuyo, **no hace falta abrir el 443 a toda la red**. La forma
recomendada es un túnel SSH: el segundo equipo se conecta por SSH al PC donde
está la app y reenvía el puerto local de la aplicación.

```text
PC del cliente (app)                       Segundo equipo
127.0.0.1:443  <── túnel SSH ──  localhost:8443
```

Así la app sigue cerrada a la red. Solo puede entrar quien tenga acceso SSH al
PC del cliente y sepa crear el túnel. Si quieres limitarlo a esos dos equipos,
permite el puerto SSH (22) solo desde la IP del segundo equipo.

### 1. Prepara el servidor SSH en el PC del cliente

**Windows 10/11:**

1. Abre **Configuración → Aplicaciones → Características opcionales**.
2. Pulsa **Agregar una característica**.
3. Busca **Servidor OpenSSH** y instálalo.
4. Abre **Servicios**, busca **OpenSSH SSH Server**, ponlo en **Automático** y
   pulsa **Iniciar**.

**Linux:**

```bash
sudo apt install openssh-server
sudo systemctl enable --now ssh
```

Si el firewall del PC del cliente bloquea el puerto 22, permite TCP 22 solo
desde la IP del segundo equipo. En Windows puedes hacerlo desde **Firewall de
Windows Defender → Configuración avanzada → Reglas de entrada → Nueva regla →
Puerto → TCP 22 → Permitir → Ámbito: estas direcciones IP**.

### 2. Crea el túnel desde el segundo equipo

En el segundo equipo, abre una terminal y ejecuta:

```bash
ssh -L 8443:127.0.0.1:443 USUARIO@IP_DEL_PC_CLIENTE
```

Sustituye:

- `USUARIO` por el usuario de Windows o Linux del PC del cliente.
- `IP_DEL_PC_CLIENTE` por la IP de ese PC en la red.

La primera vez te pedirá aceptar la huella del servidor y la contraseña de ese
usuario. Deja esa terminal abierta mientras uses la aplicación.

### 3. Abre la aplicación desde el segundo equipo

```text
https://localhost:8443
```

El segundo equipo no necesita Docker ni tener SOC Assistant instalado. Solo
necesita un cliente SSH y un navegador.

Si quieres que no aparezca el aviso de certificado, copia la CA desde el PC del
cliente y instálala en el segundo equipo:

```bash
docker cp soc-assistant:/certs/ca.crt .
```

La CA se copia en el PC del cliente y luego se instala en el segundo equipo.

### Importante

- No uses `-p 443:443` para esto. Eso abriría la app a cualquier equipo de la
  red. El túnel funciona precisamente porque la app sigue en `127.0.0.1`.
- Si cierras la sesión SSH, el acceso desde el segundo equipo se corta.
- Para que solo entren esos dos equipos, limita el SSH a la IP del segundo
  equipo y usa preferiblemente autenticación con clave SSH.
- Si no quieres instalar SSH, Tailscale o WireGuard son alternativas similares:
  crean una red privada entre tus equipos y no exponen la app a toda la red.


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

Por defecto, el compose también publica la aplicación solo en `127.0.0.1`. Si
quieres entrar desde un segundo equipo, usa el túnel SSH de la sección
**Acceso desde un segundo equipo**; no necesitas abrir el compose a la red.

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
