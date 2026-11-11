# Publicar la imagen en GHCR

GHCR significa **GitHub Container Registry**. Es el registro de imagenes Docker
de GitHub. No se sube una carpeta: se sube la imagen ya construida con
`docker push`.

## Requisitos

- Docker funcionando en el PC de origen.
- La imagen `soc-assistant-allinone:latest` ya construida.
- Una cuenta de GitHub.
- Un token personal con permiso `write:packages`.

## 1. Crear el token de GitHub

1. Entra en GitHub.
2. **Settings** â†’ **Developer settings** â†’ **Personal access tokens**.
3. Crea un token con estos permisos:
   - `write:packages`
   - `read:packages`
   - `delete:packages` si quieres poder borrar versiones antiguas
   - `repo` si el repositorio es privado
4. Copia el token. No lo guardes en el repositorio.

## 2. Iniciar sesion en GHCR

En PowerShell:

```powershell
$env:GH_TOKEN = "ghp_TU_TOKEN_AQUI"

$env:GH_TOKEN | docker login ghcr.io -u artur0-dev --password-stdin
```

El usuario ya esta configurado como `artur0-dev`. Sustituye solo
`ghp_TU_TOKEN_AQUI` por tu token.

Si no quieres dejar el token en una variable de entorno, puedes ejecutar
`docker login ghcr.io` y pegarlo cuando lo pida.

## 3. Etiquetar la imagen

```powershell
docker tag soc-assistant-allinone:latest ghcr.io/artur0-dev/soc-assistant-allinone:latest
```

Si quieres una version concreta:

```powershell
docker tag soc-assistant-allinone:latest ghcr.io/artur0-dev/soc-assistant-allinone:2026.11
```

## 4. Subir la imagen

```powershell
docker push ghcr.io/artur0-dev/soc-assistant-allinone:latest
```

Si subes tambien una version:

```powershell
docker push ghcr.io/artur0-dev/soc-assistant-allinone:2026.11
```

La primera subida puede tardar bastante: la imagen pesa unos 23 GB sin
comprimir. Usa una conexion estable y no interrumpas el proceso.

## 5. Hacer publico el paquete

Si quieres que las empresas descarguen la imagen sin cuenta de GitHub:

1. Entra en tu perfil de GitHub.
2. **Packages**.
3. Abre `soc-assistant-allinone`.
4. **Package settings**.
5. **Change visibility** â†’ **Public**.

Si lo dejas privado, en el PC destino tendran que hacer:

```powershell
docker login ghcr.io
docker pull ghcr.io/artur0-dev/soc-assistant-allinone:latest
```

## 6. Probar la descarga en otro PC

```powershell
docker pull ghcr.io/artur0-dev/soc-assistant-allinone:latest
docker tag ghcr.io/artur0-dev/soc-assistant-allinone:latest soc-assistant-allinone:latest
.\Iniciar-AllInOne.ps1
```

O directamente:

```powershell
.\Iniciar-AllInOne.ps1 -Image ghcr.io/artur0-dev/soc-assistant-allinone:latest
```

## 7. Actualizar la imagen

Cuando cambies el codigo:

```powershell
docker build -f docker/all-in-one/Dockerfile -t soc-assistant-allinone:latest .
docker tag soc-assistant-allinone:latest ghcr.io/artur0-dev/soc-assistant-allinone:latest
docker push ghcr.io/artur0-dev/soc-assistant-allinone:latest
```

En el PC destino:

```powershell
.\Iniciar-AllInOne.ps1 -Force
```

Los volumenes `soc_assistant_pgdata` y `soc_assistant_certs` se conservan.

## 8. Errores frecuentes

### `denied: permission_denied`

El token no tiene `write:packages`, o no has hecho login con el usuario
correcto. Crea otro token y vuelve a ejecutar `docker login`.

### `unauthorized`

El token es incorrecto o ha caducado. Genera uno nuevo.

### `manifest unknown` en el PC destino

La imagen no existe con ese tag, o el paquete es privado y no has hecho
`docker login ghcr.io`.

### El push se corta

Vuelve a ejecutar `docker push`. Docker reutiliza las capas ya subidas.

## 9. Que no se sube a GHCR

- La carpeta del proyecto.
- El fichero `.env`.
- La base de datos.
- Los certificados reales.
- El `.tar` de 9,72 GB.

GHCR solo recibe la imagen Docker.

