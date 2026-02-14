#!/bin/bash

# Script de instalación y configuración de DNS en CentOS Stream 9
# Versión: 1.0
# Nota: Parametrizable, sin pruebas al final.

set -e

# =========================
# Variables de configuración
# =========================
NET_IFACE="ens18"                # Interfaz de red
HOSTNAME="dns02.local"           # Nombre de host
IP_ADDR="192.168.0.71/24"        # IP de la VM
GATEWAY="192.168.0.1"            # Puerta de enlace
DNS_FORWARDER="8.8.8.8"          # DNS externo
ZONE1="cumbre.edu.bo"
ZONE2="institutocumbre.edu.bo"
ZONE1_RECORDS=( "dns01 A 192.168.0.61" "portal A 192.168.0.62" "sis A 192.168.0.64" "campus A 192.168.0.66" )
ZONE2_RECORDS=( "dns01 A 192.168.0.61" "institutocumbre A 192.168.0.65" )

# =========================
# Actualizar sistema e instalar paquetes
# =========================
echo "Actualizando sistema..."
dnf update -y

echo "Instalando BIND y utilidades..."
dnf install -y bind bind-utils

# =========================
# Configuración de red
# =========================
echo "Configurando interfaz de red $NET_IFACE..."
# Renombrar si no coincide
nmcli con show | grep -q "$HOSTNAME" || nmcli con add type ethernet con-name "$HOSTNAME" ifname "$NET_IFACE" autoconnect yes
nmcli con mod "$HOSTNAME" ipv4.addresses "$IP_ADDR" ipv4.gateway "$GATEWAY" ipv4.method manual
nmcli con up "$HOSTNAME"

# =========================
# Configuración BIND
# =========================
echo "Configurando named.conf..."
cat > /etc/named.conf <<EOF
options {
    listen-on port 53 { 127.0.0.1; $IP_ADDR; };
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

zone "$ZONE1" IN {
    type master;
    file "/var/named/$ZONE1.zone";
    allow-update { none; };
};

zone "$ZONE2" IN {
    type master;
    file "/var/named/$ZONE2.zone";
    allow-update { none; };
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
EOF

# =========================
# Crear archivos de zona
# =========================
echo "Creando archivos de zona..."

# Zona 1
cat > /var/named/$ZONE1.zone <<EOF
\$TTL 86400
@ IN SOA dns01.$ZONE1. root.$ZONE1. (
    2026020501 ; Serial
    3600       ; Refresh
    1800       ; Retry
    604800     ; Expire
    86400 )    ; Minimum TTL

@       IN NS dns01.$ZONE1.
EOF

for record in "${ZONE1_RECORDS[@]}"; do
    echo "$record" >> /var/named/$ZONE1.zone
done

# Zona 2
cat > /var/named/$ZONE2.zone <<EOF
\$TTL 86400
@ IN SOA dns01.$ZONE2. root.$ZONE2. (
    2026020501 ; Serial
    3600       ; Refresh
    1800       ; Retry
    604800     ; Expire
    86400 )    ; Minimum TTL

@       IN NS dns01.$ZONE2.
EOF

for record in "${ZONE2_RECORDS[@]}"; do
    echo "$record" >> /var/named/$ZONE2.zone
done

# =========================
# Permisos y SELinux
# =========================
echo "Configurando permisos..."
chown root:named /var/named/*.zone
chmod 640 /var/named/*.zone

# =========================
# Verificación de zonas
# =========================
echo "Verificando configuración de BIND..."
named-checkconf
named-checkzone $ZONE1 /var/named/$ZONE1.zone
named-checkzone $ZONE2 /var/named/$ZONE2.zone

# =========================
# Habilitar y arrancar servicio
# =========================
echo "Habilitando y arrancando named..."
systemctl enable named
systemctl restart named

echo "DNS instalado y configurado sin pruebas de resolución"
