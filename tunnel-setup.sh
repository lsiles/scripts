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

echo "Configurando VM Gateway para Cloudflare Tunnel..."

# 1. Configurar Red (Usar una IP libre, ej: .80)
# Puedes cambiar esta IP segun tu necesidad
IP_GW="192.168.0.80"
HOSTNAME_GW="gateway01.local"

echo "Configurando red estática en $IP_GW..."
nmcli con mod "$NET_IFACE" ipv4.addresses "$IP_GW/24" ipv4.gateway "192.168.0.1" ipv4.method manual ipv4.dns "$IP_DNS"
nmcli con up "$NET_IFACE"
hostnamectl set-hostname $HOSTNAME_GW

# 2. Instalar Cloudflared (Repositorio Oficial)
echo "Instalando repositorio de Cloudflare..."
curl -L --output /etc/yum.repos.d/cloudflare-tunnel.repo https://pkg.cloudflare.com/cloudflared-ascii.repo

echo "Instalando cloudflared..."
dnf install -y cloudflared

# 3. Instrucciones Finales
echo "------------------------------------------------------------"
echo "✅ Cloudflared se ha instalado correctamente."
echo "------------------------------------------------------------"
echo "PASOS PARA ACTIVAR EL TUNEL:"
echo "1. Ejecuta: cloudflared tunnel login"
echo "2. Sigue el link para autorizar tu dominio en Cloudflare."
echo "3. Crea el tunel: cloudflared tunnel create universidad"
echo "4. Mapea tus servicios en el Dashboard de Cloudflare Zero Trust:"
echo "   - portal.midominio.com -> http://192.168.0.72"
echo "   - campus.midominio.com -> http://192.168.0.74"
echo "------------------------------------------------------------"
