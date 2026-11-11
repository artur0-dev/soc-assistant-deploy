# Subir este paquete a GitHub

Este paquete esta pensado para un repositorio de **despliegue**, separado del
codigo fuente. La empresa descarga este repo, descarga la imagen Docker y
arranca la app. No ve el codigo ni recibe datos.

## 1. Crear el repositorio en GitHub

Crea un repositorio vacio llamado, por ejemplo:

```text
soc-assistant-deploy
```

Puede ser publico. No marques la opcion de crear README ni licencia para
evitar conflictos.

## 2. Copiar la carpeta fuera del proyecto principal

Es importante no crear un repositorio Git dentro de otro repositorio Git.

```powershell
Copy-Item -Recurse C:\soc_ia\mvp_reducido\publicar-github C:\soc_ia\soc-assistant-deploy
cd C:\soc_ia\soc-assistant-deploy
```

## 3. Repositorio ya configurado

Este repositorio ya apunta a `artur0-dev`. No hay que cambiar ningun nombre
antes de usarlo.

## 4. Revisar que no hay secretos

```powershell
Get-ChildItem -Recurse -File
```

No debe aparecer:

```text
.env
certs/
*.pem
*.key
*.crt
*.tar
backups/
```

El `.gitignore` de esta carpeta ya los bloquea.

## 5. Crear el commit y subirlo

```powershell
git init
git add .
git status
```

Revisa que solo aparezcan:

```text
.gitignore
README.md
SUBIR_A_GITHUB.md
Iniciar-AllInOne.ps1
iniciar-allinone.sh
docker-compose.yml
```

Si todo esta bien:

```powershell
git commit -m "deploy: SOC Assistant all-in-one"
git branch -M main
git remote add origin https://github.com/artur0-dev/soc-assistant-deploy.git
git push -u origin main
```

Si Git pide identidad:

```powershell
git config --global user.name "Tu Nombre"
git config --global user.email "tu-correo@example.com"
```

## 6. Publicar la imagen en GHCR

Los detalles completos estan en [`PUBLICAR_GHCR.md`](PUBLICAR_GHCR.md).
Resumen desde el PC donde esta la imagen:

```powershell
docker tag soc-assistant-allinone:latest ghcr.io/artur0-dev/soc-assistant-allinone:latest

$env:GH_TOKEN | docker login ghcr.io -u artur0-dev --password-stdin

docker push ghcr.io/artur0-dev/soc-assistant-allinone:latest
```

Despues, en GitHub:

1. **Packages**.
2. `soc-assistant-allinone`.
3. **Settings**.
4. Visibilidad **Public** si quieres que se descargue sin login.

Si la dejas privada, el PC destino tendra que ejecutar `docker login ghcr.io`
con un token de solo lectura.

## 7. Probar el despliegue como si fueras la empresa

En otro PC, o en una carpeta limpia:

```powershell
git clone https://github.com/artur0-dev/soc-assistant-deploy.git
cd soc-assistant-deploy
.\Iniciar-AllInOne.ps1
```

Debe:

- descargar la imagen,
- arrancar la app con la base vacia,
- generar los secretos,
- mostrar la URL y la contrasena de `admin`.

## 8. Actualizar la imagen

Cuando cambies la app:

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

## 9. Que no hay que subir nunca

- El `.tar` de 9,72 GB.
- La carpeta `portable-allinone/`.
- El fichero `.env`.
- Certificados o claves.
- Volcados de base de datos.
- Logs con datos reales.

GitHub no esta pensado para el `.tar` de la imagen. Para mover la imagen sin
registry, usa USB, disco externo o nube.

