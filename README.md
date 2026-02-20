# Infraestructura Académica Automatizada (CentOS 9 Stream)

Scripts para desplegar la infraestructura de servidores de Cumbre.edu.bo sobre VMs clonadas en Proxmox.

## 📋 Requisitos Previos
1.  **Cluster Proxmox:** Nodos 1 y 2 con plantilla de **CentOS Stream 9** (Minimal).
2.  **Usuario root:** Todos los scripts deben ejecutarse como `root`.
3.  **Git:** Instalado en la plantilla base (`dnf install git -y`).

## Instrucciones de Uso

### Paso 1: Clonar Repositorio
En CADA nueva VM que crees (DNS, Web, Moodle...), ejecuta:
```bash
git clone https://github.com/lsiles/scripts.git /root/scripts
cd /root/scripts
chmod +x *.sh
```

### Paso 2: Configuración (¡Importante!)
Edita el archivo `config.env` **SOLAMENTE SI** estás desplegando en una red diferente a la `192.168.0.x`.
```bash
nano config.env
# Cambia GATEWAY, IP_DNS, etc. si es necesario.
```
*Si estás en la red por defecto, no necesitas tocar nada.*

### Paso 3: Ejecutar Script según el ROL
Dependiendo de qué servidor sea, ejecuta el script correspondiente:

| Rol de Servidor | Hostname | IP (Defecto) | Script a Ejecutar |
| :--- | :--- | :--- | :--- |
| **DNS Principal**  | `dns02` | `192.168.0.71` | `./dns-setup.sh` |
| **Portal Web**     | `web01` | `192.168.0.72` | `./web-setup.sh` |
| **SIS Académico**  | `sis01` | `192.168.0.73` | `./sis-setup.sh` |
| **Moodle LMS**     | `lms01` | `192.168.0.74` | `./lms-setup.sh` |
| **NAS (Backups)**  | `nas01` | `192.168.0.75` | `./nas-setup.sh` |

---
> **Nota de Seguridad:** Las contraseñas de base de datos están en `config.env`. Cámbialas antes de desplegar en producción real.

## 🧪 Pruebas y Verificación (Manual de Test)

Después de ejecutar cada script, usa estos comandos para confirmar que todo está OK:

### 1. Servidor DNS (Probar desde cualquier VM)
Verifica que los nombres resuelven a las IPs correctas:
```bash
dig @192.168.0.71 portal.cumbre.edu.bo +short
dig @192.168.0.71 sis.cumbre.edu.bo +short
dig @192.168.0.71 campus.cumbre.edu.bo +short
```

### 2. Servidor WEB (.72) y SIS (.73)
Verifica que Apache y PHP 8.3 están respondiendo:
```bash
# Debería devolver HTTP 200 OK
curl -I http://192.168.0.72
curl -I http://192.168.0.73
```

### 3. Servidor LMS Moodle (.74)
Verifica que Moodle y su carpeta de datos están listos:
```bash
# Debería devolver HTTP 200 o 303
curl -I http://192.168.0.74/moodle/

# Verificar permisos de moodledata
ls -ld /var/www/moodledata
```

### 4. Servidor NAS (.75)
Verifica que la carpeta compartida sea visible desde la red:
```bash
# (Necesitas nfs-utils instalado para probar)
showmount -e 192.168.0.75
```

### 5. Base de Datos (SIS/LMS)
Entra a MySQL para asegurar que las bases de datos existen:
```bash
mysql -u root -p -e "SHOW DATABASES;"
```

