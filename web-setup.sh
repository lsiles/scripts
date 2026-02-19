#!/bin/bash

# =================================================================
# SCRIPT DE INSTALACIÓN WEB PORTAL (Apache + PHP)
# =================================================================
# Lee la configuración global desde config.env

if [ -f "config.env" ]; then
    source config.env
else
    echo "ERROR: config.env no encontrado."
    exit 1
fi

set -e

# 1. Configurar Red y Hostname
echo "Configurando Red ($IP_WEB)..."
CURRENT_IP=$(ip -o -4 addr list $NET_IFACE | head -n1 | awk '{print $4}')
TARGET_IP="$IP_WEB/$NETMASK"

if [ "$CURRENT_IP" != "$TARGET_IP" ]; then
    nmcli con show | grep -q "$HOSTNAME_WEB" || nmcli con add type ethernet con-name "$HOSTNAME_WEB" ifname "$NET_IFACE" autoconnect yes
    nmcli con mod "$HOSTNAME_WEB" ipv4.addresses "$TARGET_IP" ipv4.gateway "$GATEWAY" ipv4.method manual ipv4.dns "$IP_DNS"
    echo "Reiniciando red..."
    nmcli con up "$HOSTNAME_WEB"
fi

hostnamectl set-hostname $HOSTNAME_WEB
echo "$IP_WEB $HOSTNAME_WEB" >> /etc/hosts

# 2. Instalar Apache y PHP 8.3
echo "Instalando Apache y PHP 8.3..."
dnf module reset php -y
dnf module enable php:8.3 -y
dnf install -y httpd php php-cli php-mysqlnd php-gd php-xml php-mbstring unzip

# 3. Configurar Apache
echo "Configurando Apache..."
systemctl enable httpd
systemctl start httpd

# Pagina de prueba
echo "<h1>Bienvenido a Portal Cumbre ($HOSTNAME_WEB)</h1><p>IP: $IP_WEB</p>" > /var/www/html/index.php

# 4. Firewall
echo "Abriendo puertos web..."
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

echo "Servidor WEB instalado en http://$IP_WEB"
