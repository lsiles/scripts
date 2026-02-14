#!/bin/bash

# =================================================================
# SCRIPT DE INSTALACIÓN DNS (AUTORITATIVO)
# =================================================================
# Lee la configuración global desde config.env

# Cargar configuración
if [ -f "config.env" ]; then
    source config.env
else
    echo "❌ ERROR: No se encuentra el archivo 'config.env'. Ejecuta este script en la misma carpeta."
    exit 1
fi

set -e

# =========================
# Actualizar sistema e instalar paquetes
# =========================
echo "🔄 Actualizando sistema..."
dnf update -y

echo "📦 Instalando BIND y utilidades..."
dnf install -y bind bind-utils

# =========================
# Configuración de red
# =========================
# Obtener IP actual
CURRENT_IP=$(ip -o -4 addr list $NET_IFACE | head -n1 | awk '{print $4}')
TARGET_IP="$IP_DNS/$NETMASK"

if [ "$CURRENT_IP" == "$TARGET_IP" ]; then
    echo "✅ La IP ya está configurada a $TARGET_IP. Saltando reinicio de red."
else
    echo "Configurando interfaz de red $NET_IFACE..."
    # Renombrar si no coincide
    nmcli con show | grep -q "$HOSTNAME_DNS" || nmcli con add type ethernet con-name "$HOSTNAME_DNS" ifname "$NET_IFACE" autoconnect yes
    nmcli con mod "$HOSTNAME_DNS" ipv4.addresses "$TARGET_IP" ipv4.gateway "$GATEWAY" ipv4.method manual ipv4.dns "$DNS_FORWARDER"
    
    echo "⚠️  ATENCIÓN: Se reiniciará la interfaz de red. Si estás por SSH, la conexión podría cerrarse."
    nmcli con up "$HOSTNAME_DNS"
fi

# Configurar Hostname
hostnamectl set-hostname $HOSTNAME_DNS
echo "$IP_DNS $HOSTNAME_DNS" >> /etc/hosts

# =========================
# Configuración BIND
# =========================
echo "Configurando named.conf..."
cat > /etc/named.conf <<EOF
options {
    listen-on port 53 { 127.0.0.1; $IP_DNS; };
    listen-on-v6 port 53 { ::1; };
    directory       "/var/named";
    dump-file       "/var/named/data/cache_dump.db";
    statistics-file "/var/named/data/named_stats.txt";
    memstatistics-file "/var/named/data/named_mem_stats.txt";
    secroots-file   "/var/named/data/named.secroots";
    recursing-file  "/var/named/data/named.recursing";
    allow-query     { any; };
    recursion yes;
    dnssec-validation yes;
    managed-keys-directory "/var/named/dynamic";
    pid-file "/run/named/named.pid";
    session-keyfile "/run/named/session.key";
    include "/etc/crypto-policies/back-ends/bind.config";
};

logging {
    channel default_debug {
        file "data/named.run";
        severity dynamic;
    };
};

zone "." IN {
    type hint;
    file "named.ca";
};

zone "$DOMAIN_MAIN" IN {
    type master;
    file "/var/named/$DOMAIN_MAIN.zone";
    allow-update { none; };
};

zone "$DOMAIN_SEC" IN {
    type master;
    file "/var/named/$DOMAIN_SEC.zone";
    allow-update { none; };
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
EOF

# =========================
# Crear archivos de zona
# =========================
echo "Creando archivos de zona..."

SERIAL=$(date +%Y%m%d01)

# Zona 1: DOMAIN_MAIN
cat > /var/named/$DOMAIN_MAIN.zone <<EOF
\$TTL 86400
@ IN SOA $HOSTNAME_DNS. root.$DOMAIN_MAIN. (
    $SERIAL ; Serial
    3600       ; Refresh
    1800       ; Retry
    604800     ; Expire
    86400 )    ; Minimum TTL

@       IN NS $HOSTNAME_DNS.

; Registros A (Infraestructura)
dns01   IN A $IP_DNS
portal  IN A $IP_WEB
sis     IN A $IP_SIS
campus  IN A $IP_LMS
nas     IN A $IP_NAS

; Alias / CNAME (Opcionales)
www     IN CNAME portal
EOF

# Zona 2: DOMAIN_SEC
cat > /var/named/$DOMAIN_SEC.zone <<EOF
\$TTL 86400
@ IN SOA $HOSTNAME_DNS. root.$DOMAIN_SEC. (
    $SERIAL ; Serial
    3600       ; Refresh
    1800       ; Retry
    604800     ; Expire
    86400 )    ; Minimum TTL

@       IN NS $HOSTNAME_DNS.

; Registros A
dns01           IN A $IP_DNS
institutocumbre IN A $IP_WEB
EOF

# =========================
# Permisos y SELinux
# =========================
echo "Configurando permisos..."
chown root:named /var/named/*.zone
chmod 640 /var/named/*.zone

# =========================
# Configuración Firewall
# =========================
echo "🔥 Configurando Firewall..."
firewall-cmd --permanent --add-service=dns
firewall-cmd --reload

# =========================
# Verificación de zonas
# =========================
echo "Verificando configuración de BIND..."
named-checkconf
named-checkzone $DOMAIN_MAIN /var/named/$DOMAIN_MAIN.zone
named-checkzone $DOMAIN_SEC /var/named/$DOMAIN_SEC.zone

# =========================
# Habilitar y arrancar servicio
# =========================
echo "Habilitando y arrancando named..."
systemctl enable named
systemctl restart named

echo "✅ DNS instalado y configurado correctamente (IP: $IP_DNS)"
