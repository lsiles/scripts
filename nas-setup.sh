#!/bin/bash

# =================================================================
# SCRIPT DE INSTALACIÓN NAS (NFS Server para Backups)
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
echo "🌐 Configurando Red ($IP_NAS)..."

# Auto-detección de interfaz si ens18 no existe
if ! ip link show "$NET_IFACE" >/dev/null 2>&1; then
    echo "⚠️ Interfaz $NET_IFACE no encontrada. Detectando automáticamente..."
    NET_IFACE=$(ip -o link show | awk -F': ' '$2 != "lo" {print $2}' | head -n1)
    echo "✅ Interfaz detectada: $NET_IFACE"
fi

CURRENT_IP=$(ip -o -4 addr list $NET_IFACE | head -n1 | awk '{print $4}')
TARGET_IP="$IP_NAS/$NETMASK"

if [ "$CURRENT_IP" != "$TARGET_IP" ]; then
    # Limpiar conexiones previas para evitar conflictos
    nmcli con delete "$HOSTNAME_NAS" >/dev/null 2>&1 || true
    nmcli con add type ethernet con-name "$HOSTNAME_NAS" ifname "$NET_IFACE" autoconnect yes
    nmcli con mod "$HOSTNAME_NAS" ipv4.addresses "$TARGET_IP" ipv4.gateway "$GATEWAY" ipv4.method manual ipv4.dns "$IP_DNS"
    echo "⚠️  Reiniciando red..."
    nmcli con up "$HOSTNAME_NAS"
fi

hostnamectl set-hostname $HOSTNAME_NAS
echo "$IP_NAS $HOSTNAME_NAS" >> /etc/hosts

# 2. Instalar NFS Utilities
echo "📦 Instalando NFS..."
dnf install -y nfs-utils

# 3. Crear directorio de Backups
echo "📂 Creando carpeta compartida /backups..."
mkdir -p /backups
chmod 777 /backups

# 4. Configurar Exports
echo "/backups *(rw,sync,no_root_squash,no_all_squash)" > /etc/exports

# 5. Iniciar Servicio
echo "🚀 Iniciando NFS Server..."
systemctl enable --now nfs-server
exportfs -r

# 6. Firewall
echo "🔥 Abriendo puertos NFS..."
firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service=mountd
firewall-cmd --permanent --add-service=rpc-bind
firewall-cmd --reload

echo "✅ Servidor NAS listo en $IP_NAS:/backups"
