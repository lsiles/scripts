#!/bin/bash

# =================================================================
# SCRIPT DE INSTALACIÓN MOODLE (LMS)
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
echo "Configurando Red ($IP_LMS)..."
CURRENT_IP=$(ip -o -4 addr list $NET_IFACE | head -n1 | awk '{print $4}')
TARGET_IP="$IP_LMS/$NETMASK"

if [ "$CURRENT_IP" != "$TARGET_IP" ]; then
    nmcli con show | grep -q "$HOSTNAME_LMS" || nmcli con add type ethernet con-name "$HOSTNAME_LMS" ifname "$NET_IFACE" autoconnect yes
    nmcli con mod "$HOSTNAME_LMS" ipv4.addresses "$TARGET_IP" ipv4.gateway "$GATEWAY" ipv4.method manual ipv4.dns "$IP_DNS"
    echo "Reiniciando red..."
    nmcli con up "$HOSTNAME_LMS"
fi

hostnamectl set-hostname $HOSTNAME_LMS
echo "$IP_LMS $HOSTNAME_LMS" >> /etc/hosts

# 2. Instalar Requisitos Moodle (PHP 8.3 + Apache + MariaDB)
echo "Instalando Stack Moodle (PHP 8.3)..."
dnf module reset php -y
dnf module enable php:8.3 -y
dnf install -y httpd mariadb-server \
    php php-cli php-mysqlnd php-gd php-xml php-mbstring php-intl \
    php-soap php-zip php-opcache php-json unzip wget tar

# 3. Configurar Base de Datos para Moodle
echo "Configurando MariaDB para Moodle..."
systemctl enable --now mariadb

mysql -e "CREATE DATABASE IF NOT EXISTS moodle DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS 'moodleuser'@'localhost' IDENTIFIED BY '$MOODLE_DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON moodle.* TO 'moodleuser'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# 4. Configurar Apache
echo "Iniciando Apache..."
systemctl enable --now httpd

# 5. Descargar e Instalar Moodle
echo "Descargando e instalando Moodle (Ultima version estable)..."
cd /var/www/html
if [ ! -d "moodle" ]; then
    wget https://download.moodle.org/download.php/direct/stable405/moodle-latest-405.tgz -O moodle-latest.tgz
    tar -zxvf moodle-latest.tgz
    rm -f moodle-latest.tgz
    chown -R apache:apache /var/www/html/moodle
    chmod -R 755 /var/www/html/moodle
else
    echo "La carpeta /var/www/html/moodle ya existe. Saltando descarga."
fi

# 6. Crear carpeta de datos (Moodledata)
echo "Creando moodledata..."
if [ ! -d "/var/www/moodledata" ]; then
    mkdir -p /var/www/moodledata
    chown -R apache:apache /var/www/moodledata
    chmod -R 777 /var/www/moodledata
else
    echo "Moodledata ya existe."
fi

# 7. Firewall
echo "Abriendo puertos..."
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

echo "Servidor Moodle Instalado Rapidamente."
echo "URL: http://$IP_LMS/moodle"
echo "Datos de DB: DB=moodle, User=moodleuser, Pass=$MOODLE_DB_PASS"

