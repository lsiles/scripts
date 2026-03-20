#!/bin/bash

# =================================================================
# SCRIPT DE INSTALACIÓN SIS LEGADO (CentOS 7 + PHP 5.4)
# =================================================================
# Lee la configuración global desde config.env

if [ -f "config.env" ]; then
    source config.env
else
    echo "ERROR: config.env no encontrado."
    exit 1
fi

set -e

# 1. Configurar Red y Hostname para CentOS 7
echo "Configurando Red ($IP_SIS_LEGACY)..."
CURRENT_IP=$(ip -o -4 addr list $NET_IFACE | head -n1 | awk '{print $4}')
TARGET_IP="$IP_SIS_LEGACY/$NETMASK"

if [ "$CURRENT_IP" != "$TARGET_IP" ]; then
    # Limpiar conexiones previas si existen
    nmcli con delete "$HOSTNAME_SIS_LEGACY" 2>/dev/null || true
    nmcli con add type ethernet con-name "$HOSTNAME_SIS_LEGACY" ifname "$NET_IFACE" autoconnect yes
    nmcli con mod "$HOSTNAME_SIS_LEGACY" ipv4.addresses "$TARGET_IP" ipv4.gateway "$GATEWAY" ipv4.method manual ipv4.dns "$IP_DNS"
    echo "Reiniciando red..."
    nmcli con up "$HOSTNAME_SIS_LEGACY"
fi

hostnamectl set-hostname $HOSTNAME_SIS_LEGACY
echo "$IP_SIS_LEGACY $HOSTNAME_SIS_LEGACY" >> /etc/hosts

# 2. Arreglar Repositorios para CentOS 7 (EOL - Vault)
# Los repos oficiales de CentOS 7 ya no funcionan, hay que apuntar a vault.centos.org
echo "Configurando repositorios EOL (Vault)..."
sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
sed -i 's|#baseurl=http://mirror.centos.org/centos/$releasever|baseurl=http://vault.centos.org/7.9.2009|g' /etc/yum.repos.d/CentOS-*

yum clean all
yum makecache

# 3. Instalar Stack SIS (PHP 5.4 + Apache + MariaDB)
echo "Instalando Stack SIS Legado (PHP 5)..."
yum install -y httpd mariadb-server \
    php php-cli php-mysql php-gd php-xml php-mbstring \
    unzip wget tar

# 4. Configurar MariaDB
echo "Configurando MariaDB..."
systemctl enable --now mariadb

# 5. Configurar Apache
echo "Iniciando Apache..."
systemctl enable --now httpd

# 6. Firewall (CentOS 7 usa firewalld por defecto)
echo "Abriendo puertos en el firewall..."
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

echo "================================================================="
echo "Servidor SIS Legado (CentOS 7) Instalado."
echo "URL: http://$IP_SIS_LEGACY"
echo "Versión PHP: $(php -v | head -n1)"
echo "Base de Datos: MariaDB lista."
echo "================================================================="
