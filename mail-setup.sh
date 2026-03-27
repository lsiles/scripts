#!/bin/bash

# =================================================================
# SCRIPT DE INSTALACIÓN SERVIDOR DE CORREO (Postfix + Dovecot)
# PARA CENTOS STREAM 10 / RHEL 10
# =================================================================

if [ -f "config.env" ]; then
    source config.env
else
    echo "❌ ERROR: config.env no encontrado."
    exit 1
fi

set -e

# 1. Configurar Red y Hostname para Mail
echo "🌐 Configurando Red ($IP_MAIL)..."
# Auto-detección de interfaz
NET_IFACE=$(ip -o link show | awk -F': ' '$2 != "lo" {print $2}' | head -n1)

CURRENT_IP=$(ip -o -4 addr list $NET_IFACE | head -n1 | awk '{print $4}')
TARGET_IP="$IP_MAIL/$NETMASK"

if [ "$CURRENT_IP" != "$TARGET_IP" ]; then
    nmcli con delete "$HOSTNAME_MAIL" >/dev/null 2>&1 || true
    nmcli con add type ethernet con-name "$HOSTNAME_MAIL" ifname "$NET_IFACE" autoconnect yes
    nmcli con mod "$HOSTNAME_MAIL" ipv4.addresses "$TARGET_IP" ipv4.gateway "$GATEWAY" ipv4.method manual ipv4.dns "$IP_DNS"
    echo "⚠️  Reiniciando red..."
    nmcli con up "$HOSTNAME_MAIL"
fi

hostnamectl set-hostname $HOSTNAME_MAIL
echo "$IP_MAIL $HOSTNAME_MAIL" >> /etc/hosts

# 2. Instalar Postfix (MTA) y Dovecot (IMAP/POP3)
echo "📦 Instalando Postfix y Dovecot en CentOS 10..."
dnf install -y postfix dovecot smail-utils-cyrus-sasl

# 3. Configurar Postfix (SMTP)
echo "🏗️ Configurando Postfix..."
postconf -e "myhostname = mail.$DOMAIN_MAIN"
postconf -e "mydomain = $DOMAIN_MAIN"
postconf -e "myorigin = \$mydomain"
postconf -e "inet_interfaces = all"
postconf -e "inet_protocols = ipv4"
postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain"
postconf -e "mynetworks = 127.0.0.0/8, $IP_MAIL/24"
postconf -e "home_mailbox = Maildir/"

# 4. Configurar Dovecot (IMAP)
echo "🏗️ Configurando Dovecot..."
sed -i 's/#protocols = imap pop3 lmtp/protocols = imap pop3/' /etc/dovecot/dovecot.conf
sed -i 's/#mail_location =/mail_location = maildir:~\/Maildir/' /etc/dovecot/conf.d/10-mail.conf
sed -i 's/disable_plaintext_auth = yes/disable_plaintext_auth = no/' /etc/dovecot/conf.d/10-auth.conf

# 5. Iniciar Servicios
echo "🚀 Iniciando servicios de correo..."
systemctl enable --now postfix
systemctl enable --now dovecot

# 6. Firewall
echo "🔥 Abriendo puertos de correo (SMTP, IMAP, submission)..."
firewall-cmd --permanent --add-service=smtp
firewall-cmd --permanent --add-service=smtps
firewall-cmd --permanent --add-service=submission
firewall-cmd --permanent --add-service=imap
firewall-cmd --permanent --add-service=imaps
firewall-cmd --reload

echo "================================================================"
echo "✅ SERVIDOR DE CORREO LISTO ($IP_MAIL)"
echo "Host Público Sugerido: mail.$DOMAIN_MAIN"
echo "================================================================"
echo "⚠️ NOTA: Para producción recuerda configurar MX, SPF y PTR."
