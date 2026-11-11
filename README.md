# SOC Assistant

SOC Assistant es una aplicación web pensada para el trabajo diario de un equipo
SOC. Reúne en un mismo sitio las alertas, los casos y los informes, y añade un
asistente de IA que puede responder preguntas usando el contexto de esos datos.

La idea es que puedas tener todo funcionando en una sola máquina, sin montar
varios servicios a mano y sin depender de una nube externa para la IA. Los
modelos de lenguaje se ejecutan dentro del propio contenedor.

Wazuh y Splunk son **opcionales**. Si tu empresa ya los tiene, puedes conectarlos
desde la pantalla de **Integraciones**. Si no los tienes, la aplicación arranca
igual y funciona con sus alertas, casos, informes y asistente.

## Qué incluye

La imagen Docker es todo-en-uno:

- La interfaz web de SOC Assistant.
- El backend y la base de datos PostgreSQL.
- El asistente de IA local con Ollama y sus modelos.
- Un certificado HTTPS autofirmado para acceder por la red interna.

La base de datos se crea vacía en el primer arranque. No se incluyen alertas,
casos, informes, usuarios ni secretos de ninguna instalación anterior. Las
contraseñas y claves se generan automáticamente la primera vez.

## Antes de empezar

Necesitas:

- Un PC con Docker instalado y funcionando.
  - En Windows y macOS: Docker Desktop.
  - En Linux: Docker Engine.
- Unos **30–40 GB de espacio libre**. La imagen ocupa unos 23 GB y Docker
  necesita espacio adicional para capas y volúmenes.
- **16 GB de RAM recomendados**. Con menos memoria puede funcionar, pero el
  asistente irá más lento.
- Los puertos **80** y **443** libres. Si están ocupados, se pueden cambiar.
- Opcionalmente, una GPU NVIDIA con NVIDIA Container Toolkit para que la IA
  responda más rápido.

La primera vez hay que descargar la imagen desde GitHub Container Registry. No
hace falta tener cuenta de GitHub ni ejecutar `docker login`.

## Instalación en Windows

### 1. Instala Docker Desktop

Descárgalo desde <https://www.docker.com/products/docker-desktop/> e instálalo.
Si te ofrece usar WSL 2, acepta esa opción. Después de instalarlo, ábrelo y
espera a que el motor de Docker esté en marcha.

### 2. Descarga este repositorio

Con Git instalado:

```powershell
git clone https://github.com/artur0-dev/soc-assistant-deploy.git
cd soc-assistant-deploy
```

Si no tienes Git, entra en la página del repositorio, pulsa **Code** →
**Download ZIP**, descomprime el archivo y abre una terminal dentro de la
carpeta.

### 3. Arranca SOC Assistant

```powershell
.\Iniciar-AllInOne.ps1
```

Si Windows bloquea el script por la política de ejecución:

```powershell
powershell -ExecutionPolicy Bypass -File .\Iniciar-AllInOne.ps1
```

La primera vez puede tardar bastante, porque descarga la imagen completa. El
script se encarga de:

1. Descargar la imagen.
2. Detectar la IP del equipo en la red local.
3. Crear los volúmenes donde se guardan los datos.
4. Arrancar el contenedor.
5. Esperar a que la aplicación esté sana.
6. Mostrar la URL, el usuario `admin` y la contraseña generada.

Al terminar verás algo parecido a esto:

```text
============================================================
 SOC Assistant está listo
 URL:              https://192.168.1.50
 Usuario:          admin
 Contraseña admin: xxxxxxxxxxxxxxxxxxxxxxxx

 CA para clientes:
   docker cp soc-assistant:/certs/ca.crt .\ca.crt
============================================================
```

Abre esa URL en el navegador. Si el navegador avisa de que el certificado no es
de confianza, es normal: la app usa un certificado propio para la red interna.
Más abajo se explica cómo instalar la CA en los equipos cliente.

Para comprobar que el contenedor está sano:

```powershell
docker ps --filter name=soc-assistant
```

En la columna `STATUS` debe aparecer `healthy`. Si aparece `starting`, espera
unos minutos: la primera vez tarda más porque arranca la base de datos y los
modelos de IA.

## Instalación en Linux

Con Docker Engine instalado y tu usuario con permiso para usar `docker`:

```bash
git clone https://github.com/artur0-dev/soc-assistant-deploy.git
cd soc-assistant-deploy
chmod +x iniciar-allinone.sh
./iniciar-allinone.sh
```

El script hace lo mismo que el de Windows. Si tu usuario no está en el grupo
`docker`, tendrás que añadirlo o ejecutar Docker con los permisos adecuados.

En macOS puedes usar Docker Desktop y el mismo script. Si la IP que detecta no
es la correcta, arranca con Docker Compose indicando la IP manualmente:

```bash
CERT_HOST_IPS="127.0.0.1,192.168.1.50" \
PUBLIC_URL="https://192.168.1.50" \
docker compose up -d
```

## Cómo entrar desde otro equipo

La URL que muestra el instalador es la que deben usar los demás equipos de la
red. No uses `127.0.0.1` desde otro PC: esa dirección siempre apunta al propio
equipo.

Si Windows Defender o el firewall del servidor preguntan si permitir Docker,
acepta la regla para redes privadas.

### Instalar el certificado en los clientes

Para que el navegador no muestre el aviso de certificado, copia la CA desde el
contenedor:

```powershell
docker cp soc-assistant:/certs/ca.crt .\ca.crt
```

En Windows, haz doble clic en `ca.crt` → **Instalar certificado** → **Equipo
local** → **Siguiente** → colócalo en **Entidades de certificación raíz de
confianza** → **Finalizar**.

En Linux, copia el archivo a `/usr/local/share/ca-certificates/` y ejecuta:

```bash
sudo update-ca-certificates
```

Si cambias la IP del servidor más adelante, el certificado dejará de coincidir.
En ese caso vuelve a arrancar con:

```powershell
.\Iniciar-AllInOne.ps1 -Force -RegenerateCerts
```

Eso genera una CA nueva y tendrás que volver a instalarla en los clientes.

## Wazuh y Splunk

Son conectores independientes y opcionales. Se configuran desde la pantalla
**Integraciones** de SOC Assistant:

- **Wazuh**: URL, usuario y contraseña del Wazuh de tu empresa.
- **Splunk**: URL y credenciales de Splunk.

La variable `PUBLIC_URL` es la URL de SOC Assistant, no la de Wazuh ni la de
Splunk. No las mezcles.

Si no configuras ninguno de los dos, la aplicación funciona igual: puedes usar
el asistente, las alertas, los casos y los informes con los datos que vayas
creando.

## Cambiar los puertos

Por defecto se usan el 80 (redirige a HTTPS) y el 443. Si están ocupados:

```powershell
.\Iniciar-AllInOne.ps1 -HttpPort 8080 -HttpsPort 8443
```

La URL pasará a ser `https://IP:8443`.

Con Docker Compose:

```powershell
$env:HTTP_PORT="8080"
$env:HTTPS_PORT="8443"
docker compose up -d
```

## Ver la contraseña de admin

Si cierras la terminal y no apuntaste la contraseña:

```powershell
docker exec soc-assistant sh -c ". /certs/.soc.env; echo \$ADMIN_PASSWORD"
```

## Datos, actualizaciones y parada

Los datos se guardan en dos volúmenes de Docker:

- `soc_assistant_pgdata`: base de datos.
- `soc_assistant_certs`: certificados y secretos generados.

Para actualizar a la última imagen sin perder los datos:

```powershell
.\Iniciar-AllInOne.ps1 -Force
```

Para parar y volver a arrancar:

```powershell
docker stop soc-assistant
docker start soc-assistant
```

Para ver los logs en directo:

```powershell
docker logs -f soc-assistant
```

Si necesitas una copia de seguridad, detén el contenedor y copia esos dos
volúmenes. No borres `soc_assistant_pgdata` ni `soc_assistant_certs` si quieres
conservar la base de datos, los usuarios y los certificados.

Para empezar de cero, borrando todos los datos:

```powershell
docker rm -f soc-assistant
docker volume rm soc_assistant_pgdata soc_assistant_certs
.\Iniciar-AllInOne.ps1
```

**Aviso:** eso elimina la base de datos, los casos, los informes, los usuarios y
los certificados. No se puede deshacer.

## Problemas frecuentes

### Docker no está arrancado

Abre Docker Desktop y espera a que termine de iniciarse. Luego vuelve a ejecutar
el instalador.

### El puerto 80 o 443 está ocupado

Puede pasar si hay otro servidor web en el equipo. Usa otros puertos:

```powershell
.\Iniciar-AllInOne.ps1 -HttpPort 8080 -HttpsPort 8443
```

### El contenedor no llega a estar sano

Mira los últimos logs:

```powershell
docker logs --tail 200 soc-assistant
```

La primera vez puede tardar varios minutos mientras arrancan PostgreSQL, la IA y
el resto de servicios.

### El navegador avisa del certificado

Es normal si todavía no has instalado `ca.crt`. Instálalo como se explica más
arriba. Si la IP del servidor ha cambiado, regenera los certificados.

### La IA va lenta

Los modelos se ejecutan en local. Ayuda tener más RAM y una GPU NVIDIA. Sin GPU
funciona, pero las respuestas pueden tardar más.

### La descarga de la imagen falla

Comprueba la conexión a Internet y vuelve a intentarlo. También puedes descargar
la imagen a mano:

```powershell
docker pull ghcr.io/artur0-dev/soc-assistant-allinone:latest
```

## Estructura del repositorio

```text
Iniciar-AllInOne.ps1   Instalador para Windows
iniciar-allinone.sh    Instalador para Linux/macOS
docker-compose.yml     Alternativa para arrancar con Docker Compose
```

Este repositorio solo contiene los scripts de instalación. La aplicación y los
modelos están en la imagen Docker publicada en GHCR.
