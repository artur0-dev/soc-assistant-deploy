param(
    [string]$Image = "ghcr.io/artur0-dev/soc-assistant-allinone:latest",
    [string]$ContainerName = "soc-assistant",
    [string]$BindIp = "0.0.0.0",
    [int]$HttpPort = 80,
    [int]$HttpsPort = 443,
    [string]$WazuhHost = "",
    [string]$SplunkHost = "",
    [switch]$Cpu,
    [switch]$Gpu,
    [switch]$Force,
    [switch]$NoPull,
    [switch]$RegenerateCerts
)

$ErrorActionPreference = "Stop"

function Get-LanIp {
    try {
        $socket = [System.Net.Sockets.Socket]::new(
            [System.Net.Sockets.AddressFamily]::InterNetwork,
            [System.Net.Sockets.SocketType]::Dgram,
            [System.Net.Sockets.ProtocolType]::Udp
        )
        $socket.Connect("8.8.8.8", 65530)
        $ip = ([System.Net.IPEndPoint]$socket.LocalEndPoint).Address.ToString()
        $socket.Close()
        if ($ip -and $ip -ne "127.0.0.1") { return $ip }
    } catch {
        # Sin salida a Internet: se busca una IP privada local.
    }
    try {
        $candidate = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object {
                $_.IPAddress -notlike "127.*" -and
                $_.IPAddress -notlike "169.254.*" -and
                $_.PrefixOrigin -ne "WellKnown"
            } |
            Select-Object -First 1
        if ($candidate) { return $candidate.IPAddress }
    } catch {
        # Se usa localhost como ultimo recurso.
    }
    return "127.0.0.1"
}

function Test-Container {
    $names = & docker ps -a --format "{{.Names}}"
    return ($names -contains $ContainerName)
}

function Get-AdminPassword {
    try {
        $value = & docker exec $ContainerName sh -c '. /certs/.soc.env; printf %s "$ADMIN_PASSWORD"'
        return (($value | Out-String).Trim())
    } catch {
        return "(no disponible; consulta /certs/.soc.env dentro del contenedor)"
    }
}

function Show-Access {
    param([string]$Ip, [int]$Port)
    $url = if ($Port -eq 443) { "https://$Ip" } else { "https://${Ip}:$Port" }
    Write-Host ""
    Write-Host "============================================================"
    Write-Host " SOC Assistant esta listo"
    Write-Host " URL:              $url"
    Write-Host " Usuario:          admin"
    Write-Host " Contrasena admin: $(Get-AdminPassword)"
    Write-Host ""
    Write-Host " CA para clientes:"
    Write-Host "   docker cp ${ContainerName}:/certs/ca.crt .\ca.crt"
    Write-Host "============================================================"
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker no esta instalado o no esta en el PATH."
}
& docker info *> $null
if ($LASTEXITCODE -ne 0) {
    throw "Docker no esta arrancado."
}
if ($Cpu -and $Gpu) {
    throw "Usa -Cpu o -Gpu, no ambos."
}

# La imagen contiene PostgreSQL, backend, nginx y Ollama con los modelos.
# La base de datos arranca vacia: vive en el volumen soc_assistant_pgdata.
if (-not $NoPull) {
    Write-Host "[1/5] Descargando/actualizando la imagen $Image ..."
    & docker pull $Image
    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo descargar la imagen. Si el paquete es privado, ejecuta antes: docker login ghcr.io"
    }
} else {
    Write-Host "[1/5] Usando la imagen local $Image (sin pull)."
    & docker image inspect $Image *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "No existe la imagen local $Image."
    }
}

if (Test-Container) {
    if ($Force) {
        Write-Host "[2/5] Eliminando contenedor anterior ..."
        & docker rm -f $ContainerName | Out-Null
    } else {
        Write-Host "[2/5] El contenedor ya existe. Arrancandolo ..."
        & docker start $ContainerName | Out-Null
        Start-Sleep -Seconds 3
        $ip = Get-LanIp
        Show-Access -Ip $ip -Port $HttpsPort
        Write-Host "Para recrearlo con otra imagen, puertos o GPU: .\Iniciar-AllInOne.ps1 -Force"
        exit 0
    }
}

$ip = Get-LanIp
$publicUrl = if ($HttpsPort -eq 443) { "https://$ip" } else { "https://${ip}:${HttpsPort}" }

$useGpu = $false
if ($Gpu) {
    $useGpu = $true
} elseif (-not $Cpu) {
    $runtimes = & docker info --format "{{json .Runtimes}}" 2>$null
    if ($runtimes -match "nvidia") { $useGpu = $true }
}

Write-Host "[3/5] Creando volumenes persistentes ..."
& docker volume create soc_assistant_pgdata | Out-Null
& docker volume create soc_assistant_certs | Out-Null

Write-Host "[4/5] Arrancando contenedor (GPU: $useGpu) ..."
# PUBLIC_URL es la URL DE LA PROPIA APP, no la de Wazuh ni Splunk.
# Wazuh/Splunk se configuran despues desde la interfaz de Integraciones.
$dockerArgs = @(
    "run", "-d",
    "--name", $ContainerName,
    "--restart", "unless-stopped",
    "-p", "${BindIp}:${HttpPort}:80",
    "-p", "${BindIp}:${HttpsPort}:443",
    "-e", "CERT_HOST_IPS=127.0.0.1,$ip",
    "-e", "CERT_HOST_DNS=soc-assistant.local,localhost",
    "-e", "PUBLIC_URL=$publicUrl",
    "-v", "soc_assistant_pgdata:/var/lib/postgresql/data",
    "-v", "soc_assistant_certs:/certs"
)
if ($WazuhHost) { $dockerArgs += @("-e", "WAZUH_HOST=$WazuhHost") }
if ($SplunkHost) { $dockerArgs += @("-e", "SPLUNK_HOST=$SplunkHost") }
if ($RegenerateCerts) { $dockerArgs += @("-e", "FORCE_CERTS=true") }
if ($useGpu) { $dockerArgs += @("--gpus", "all") }
$dockerArgs += $Image

& docker @dockerArgs
if ($LASTEXITCODE -ne 0) { throw "No se pudo arrancar el contenedor." }

Write-Host "[5/5] Esperando a que este sano ..."
$healthy = $false
for ($i = 0; $i -lt 120; $i++) {
    $status = (& docker inspect --format "{{.State.Status}}" $ContainerName 2>$null)
    if ($status -eq "exited") {
        Write-Host "El contenedor ha terminado. Ultimos logs:"
        & docker logs --tail 100 $ContainerName
        throw "SOC Assistant no ha arrancado correctamente."
    }
    $health = (& docker inspect --format "{{if .State.Health}}{{.State.Health.Status}}{{end}}" $ContainerName 2>$null)
    if ($health -eq "healthy") {
        $healthy = $true
        break
    }
    Start-Sleep -Seconds 2
}
if (-not $healthy) {
    Write-Host "Aviso: el contenedor sigue arrancando. Ultimos logs:"
    & docker logs --tail 100 $ContainerName
}

Show-Access -Ip $ip -Port $HttpsPort

