#!/bin/bash

# =================================================================
# SCRIPT DE INSTALACIÓN CLOUDFLARE TUNNEL (GATEWAY)
# =================================================================
# Este script debe ejecutarse en una VM DEDICADA o un 
# servidor que servirá de puente hacia Internet.

# Cargar configuración global si existe
if [ -f "config.env" ]; then
    source config.env
else
    echo "ERROR: config.env no encontrado. Se usaran valores por defecto para red."
    NET_IFACE="ens18"
    IP_DNS="192.168.0.71"
fi

set -e

# 1. Configurar Red para el Gateway
echo "Configurando Red ($IP_TUNNEL)..."
CURRENT_IP=$(ip -o -4 addr list $NET_IFACE | head -n1 | awk '{print $4}')
TARGET_IP="$IP_TUNNEL/$NETMASK"

if [ "$CURRENT_IP" != "$TARGET_IP" ]; then
    nmcli con mod "$NET_IFACE" ipv4.addresses "$TARGET_IP" ipv4.gateway "$GATEWAY" ipv4.method manual ipv4.dns "$IP_DNS"
    echo "Reiniciando red..."
    nmcli con up "$NET_IFACE"
fi

hostnamectl set-hostname $HOSTNAME_TUNNEL

# 2. Instalar Cloudflared (Repositorio Oficial)
echo "Instalando repositorio y cloudflared..."
curl -L --output /etc/yum.repos.d/cloudflare-tunnel.repo https://pkg.cloudflare.com/cloudflared-ascii.repo
dnf install -y cloudflared

# 3. Instrucciones Finales
echo "------------------------------------------------------------"
echo "✅ Cloudflared se ha instalado correctamente."
echo "------------------------------------------------------------"
echo "IMPORTANTE: Si ya tenías el túnel configurado, DEBES ACTUALIZAR "
echo "los IPs de destino en el Dashboard de Cloudflare Zero Trust:"
echo ""
echo "Dashboard Cloudflare -> Networks -> Tunnels -> [tu-tunel]"
echo "Modifica los 'Public Hostnames' para apuntar a las nuevas IPs:"
echo "   - portal.$DOMAIN_MAIN -> http://$IP_WEB"
echo "   - campus.$DOMAIN_MAIN -> http://$IP_LMS"
echo "   - sis.$DOMAIN_MAIN    -> http://$IP_SIS"
echo "   - legado.$DOMAIN_MAIN -> http://$IP_SIS_LEGACY"
echo "------------------------------------------------------------"

