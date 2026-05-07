#!/usr/bin/env bash
# =============================================================
# WireGuard — Configuración del SERVIDOR (Ubuntu, Núremberg)
# IP pública   : 178.104.226.136
# IP túnel VPN : 10.10.0.1/24
# Puerto UDP   : 51820
# =============================================================
# Ejecutar como root en el servidor:
#   sudo bash 01_setup_servidor_wireguard.sh
# =============================================================
set -euo pipefail

WG_DIR="/etc/wireguard"
IFACE="wg0"
SERVER_VPN_IP="10.10.0.1/24"
SERVER_PORT="51820"

echo "==> [1/6] Instalando WireGuard..."
apt-get update -qq
apt-get install -y wireguard

echo "==> [2/6] Generando par de llaves del servidor..."
cd "$WG_DIR"
# Permisos estrictos antes de crear llaves
umask 077
wg genkey | tee server_private.key | wg pubkey > server_public.key

SERVER_PRIVATE=$(cat server_private.key)
SERVER_PUBLIC=$(cat server_public.key)

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  LLAVE PÚBLICA DEL SERVIDOR (copiar al cliente)      ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  $SERVER_PUBLIC"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

echo "==> [3/6] Detectando interfaz de red principal..."
NET_IFACE=$(ip route | awk '/^default/ { print $5; exit }')
echo "    Interfaz detectada: $NET_IFACE"

echo "==> [4/6] Escribiendo /etc/wireguard/wg0.conf..."
cat > "$WG_DIR/$IFACE.conf" <<EOF
[Interface]
Address    = $SERVER_VPN_IP
ListenPort = $SERVER_PORT
PrivateKey = $SERVER_PRIVATE

# Habilitar reenvío de paquetes (NAT)
PostUp   = iptables -A FORWARD -i $IFACE -j ACCEPT; \
           iptables -t nat -A POSTROUTING -o $NET_IFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i $IFACE -j ACCEPT; \
           iptables -t nat -D POSTROUTING -o $NET_IFACE -j MASQUERADE

# ── Cliente: Asus / Windows ──────────────────────────────────
# Reemplaza CLIENT_PUBLIC_KEY con la llave pública que genera
# el script 02_setup_cliente_windows.ps1 en la Asus.
[Peer]
PublicKey  = CLIENT_PUBLIC_KEY_AQUI
AllowedIPs = 10.10.0.2/32
EOF

chmod 600 "$WG_DIR/$IFACE.conf"

echo "==> [5/6] Habilitando reenvío IPv4 permanente..."
if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi
sysctl -p > /dev/null

echo "==> [6/6] Habilitando e iniciando wg0..."
systemctl enable wg-quick@$IFACE
systemctl start  wg-quick@$IFACE

echo ""
echo "✓ Servidor WireGuard activo en 10.10.0.1 (puerto UDP $SERVER_PORT)"
echo ""
echo "PRÓXIMO PASO:"
echo "  1. Ejecuta 02_setup_cliente_windows.ps1 en la Asus."
echo "  2. Copia la LLAVE PÚBLICA DEL CLIENTE que muestra ese script."
echo "  3. Edita /etc/wireguard/wg0.conf y reemplaza CLIENT_PUBLIC_KEY_AQUI."
echo "  4. Recarga: sudo wg syncconf wg0 <(wg-quick strip wg0)"
echo ""
echo "Verificar túnel:  sudo wg show"
