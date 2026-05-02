# =============================================================
# Genera par de llaves WireGuard en la Asus (Windows)
# Requiere: WireGuard instalado (https://www.wireguard.com/install/)
# El ejecutable wg.exe queda en C:\Program Files\WireGuard\
# =============================================================

$wg = "C:\Program Files\WireGuard\wg.exe"

if (-not (Test-Path $wg)) {
    Write-Error "WireGuard no está instalado. Descárgalo en https://www.wireguard.com/install/"
    exit 1
}

# Genera llave privada y deriva la pública
$privateKey = & $wg genkey
$publicKey  = $privateKey | & $wg pubkey

# Guarda la privada solo localmente (NO subir al repo)
$outDir = "$env:USERPROFILE\wireguard_keys"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
Set-Content  -Path "$outDir\private.key" -Value $privateKey -NoNewline
icacls "$outDir\private.key" /inheritance:r /grant "$env:USERNAME:F" | Out-Null

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗"
Write-Host "║  LLAVE PÚBLICA DEL CLIENTE (copiar al servidor)      ║"
Write-Host "╠══════════════════════════════════════════════════════╣"
Write-Host "║  $publicKey"
Write-Host "╚══════════════════════════════════════════════════════╝"
Write-Host ""
Write-Host "Llave privada guardada en: $outDir\private.key"
Write-Host "(NO compartas ni subas ese archivo)"
