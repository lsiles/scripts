#!/bin/bash

# =================================================================
# SCRIPT DE ACTUALIZACIÓN DE RED - VERSION FINAL PRODUCTION
# =================================================================

if [ -f "config.env" ]; then
    source config.env
else
    echo "ERROR: No se encuentra config.env"
    exit 1
fi

# Detectar el ROL de esta VM
# Se basa en el hostname actual de la maquina
CURRENT_HOSTNAME=$(hostname | tr '[:upper:]' '[:lower:]')
echo "Detectando rol de la maquina... Hostname actual: $CURRENT_HOSTNAME"

if [[ "$CURRENT_HOSTNAME" == *"dns"* ]]; then
    TARGET_IP=$IP_DNS
    TARGET_HOSTNAME=$HOSTNAME_DNS
elif [[ "$CURRENT_HOSTNAME" == *"web"* ]]; then
    TARGET_IP=$IP_WEB
    TARGET_HOSTNAME=$HOSTNAME_WEB
elif [[ "$CURRENT_HOSTNAME" == *"sis"* ]]; then
    TARGET_IP=$IP_SIS
    TARGET_HOSTNAME=$HOSTNAME_SIS
elif [[ "$CURRENT_HOSTNAME" == *"lms"* ]]; then
    TARGET_IP=$IP_LMS
    TARGET_HOSTNAME=$HOSTNAME_LMS
elif [[ "$CURRENT_HOSTNAME" == *"nas"* ]]; then
    TARGET_IP=$IP_NAS
    TARGET_HOSTNAME=$HOSTNAME_NAS
else
    echo "ERROR: No se puede detectar el rol (dns, web, sis, lms o nas no encontrados en hostname)"
    exit 1
fi

echo "Rol detectado: $TARGET_HOSTNAME"
echo "Nueva IP configurada: $TARGET_IP"
echo "Gateway: $GATEWAY"
echo "Mascara: $NETMASK"

# Auto-detección de interfaz de red real
# Buscamos la interfaz que no sea 'lo' y que este activa
NET_IFACE=$(ip -o link show | awk -F': ' '$2 != "lo" {print $2}' | head -n1)
echo "Interfaz de red detectada: $NET_IFACE"

# Aplicar cambios con nmcli
# 1. Borramos la conexion anterior para que no haya conflictos
nmcli con delete "$TARGET_HOSTNAME" >/dev/null 2>&1 || true

# 2. Creamos la nueva conexion estatica
nmcli con add type ethernet con-name "$TARGET_HOSTNAME" ifname "$NET_IFACE" autoconnect yes
nmcli con mod "$TARGET_HOSTNAME" ipv4.addresses "$TARGET_IP/$NETMASK" ipv4.gateway "$GATEWAY" ipv4.method manual ipv4.dns "$IP_DNS"

# 3. Actualizar hostname del sistema
hostnamectl set-hostname $TARGET_HOSTNAME

# 4. Levantar la conexion
echo "Aplicando cambios de red..."
nmcli con up "$TARGET_HOSTNAME"

echo "Configuracion completada para $TARGET_HOSTNAME"
echo "IP actual: $(ip addr show $NET_IFACE | grep 'inet ' | awk '{print $2}')"
