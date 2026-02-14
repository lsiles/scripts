#!/bin/bash

# =================================================================
# SCRIPT DE INSTALACIÓN SIS ACADÉMICO (Apache + PHP + MariaDB)
# =================================================================
# Lee la configuración global desde config.env

if [ -f "config.env" ]; then
    source config.env
else
    echo "❌ ERROR: config.env no encontrado."
    exit 1
fi

set -e

# 1. Configurar Red y Hostname
echo "🌐 Configurando Red ($IP_SIS)..."
CURRENT_IP=$(ip -o -4 addr list $NET_IFACE | head -n1 | awk '{print $4}')
TARGET_IP="$IP_SIS/$NETMASK"

if [ "$CURRENT_IP" != "$TARGET_IP" ]; then
    nmcli con show | grep -q "$HOSTNAME_SIS" || nmcli con add type ethernet con-name "$HOSTNAME_SIS" ifname "$NET_IFACE" autoconnect yes
    nmcli con mod "$HOSTNAME_SIS" ipv4.addresses "$TARGET_IP" ipv4.gateway "$GATEWAY" ipv4.method manual ipv4.dns "$IP_DNS"
    echo "⚠️  Reiniciando red..."
    nmcli con up "$HOSTNAME_SIS"
fi

hostnamectl set-hostname $HOSTNAME_SIS
echo "$IP_SIS $HOSTNAME_SIS" >> /etc/hosts

# 2. Instalar Apache, PHP y MariaDB
echo "📦 Instalando Stack LAMP..."
dnf install -y httpd mariadb-server php php-cli php-mysqlnd php-gd php-xml php-mbstring unzip

# 3. Configurar Servicios
echo "⚙️ Iniciando servicios..."
systemctl enable --now httpd
systemctl enable --now mariadb

# 4. Configurar Base de Datos (Seguridad Básica)
echo "🔒 Configurando MariaDB..."
mysql -e "UPDATE mysql.global_priv SET priv=json_set(priv, '$.plugin', 'mysql_native_password', '$.authentication_string', PASSWORD('$DB_ROOT_PASS')) WHERE User='root';"
mysql -e "DELETE FROM mysql.global_priv WHERE User='';"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "FLUSH PRIVILEGES;"

# 5. Pagina de prueba
echo "<h1>Sistema SIS Académico ($HOSTNAME_SIS)</h1><p>Base de datos lista.</p>" > /var/www/html/index.php

# 6. Firewall
echo "🔥 Abriendo puertos..."
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

echo "✅ Servidor SIS instalado en http://$IP_SIS"
