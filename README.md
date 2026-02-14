# Infraestructura Académica Automatizada (CentOS 9 Stream)

Scripts para desplegar la infraestructura de servidores de Cumbre.edu.bo sobre VMs clonadas en Proxmox.

## 📋 Requisitos Previos
1.  **Cluster Proxmox:** Nodos 1 y 2 con plantilla de **CentOS Stream 9** (Minimal).
2.  **Usuario root:** Todos los scripts deben ejecutarse como `root`.
3.  **Git:** Instalado en la plantilla base (`dnf install git -y`).

## 🚀 Instrucciones de Uso

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
| **DNS Principal** | `dns02` | `192.168.0.71` | `./dns-setup.sh` |
| **Portal Web** | `web01` | `192.168.0.72` | `./web-setup.sh` |
| **SIS Académico** | `sis01` | `192.168.0.73` | `./sis-setup.sh` |
| **Moodle LMS** | `lms01` | `192.168.0.74` | `./lms-setup.sh` |
| **NAS (Backups)** | `nas01` | `192.168.0.75` | `./nas-setup.sh` |

---
> **Nota de Seguridad:** Las contraseñas de base de datos están en `config.env`. Cámbialas antes de desplegar en producción real.
