# 🚀 Proyecto Final - Infraestructura Virtual

**Autores:**  
- Juan Esteban Galeano  
- Mariana Pienda  
- Santiago Rodas  

**Universidad del Quindío – 2025**  
**Asignatura:** Infraestructura Virtual  

---

## 📘 Descripción General

Este proyecto implementa una **infraestructura virtual completa** basada en tecnologías de almacenamiento, virtualización y contenedores.  
El objetivo fue diseñar un entorno modular, persistente y automatizado que integre:

- RAID 1 con `mdadm`  
- Administración de volúmenes con `LVM`  
- Contenedores con `Docker` y `Podman`  
- Servicios de **Apache**, **MySQL**, **Nginx** y **phpMyAdmin**  
- Automatización con **scripts Bash**  
- Documentación y bitácora en **GitHub**

---

## 🧩 Componentes del Proyecto

| Componente | Descripción |
|-------------|-------------|
| **RAID 1 (mdadm)** | Implementa redundancia de datos en discos virtuales. |
| **LVM (Logical Volume Manager)** | Crea volúmenes dinámicos para Apache, MySQL y Nginx. |
| **Docker** | Orquesta contenedores persistentes para cada servicio. |
| **Podman** | Alternativa sin daemon para pruebas equivalentes. |
| **Apache** | Servidor web principal con página informativa del proyecto. |
| **Nginx** | Servidor web adicional para balanceo y pruebas. |
| **MySQL** | Base de datos con persistencia en LVM. |
| **phpMyAdmin** | Interfaz web para gestionar la base de datos. |
| **NetData** | Monitoreo en tiempo real del sistema y contenedores. |
| **Bash Script (`restore_docker.sh`)** | Automatiza el montaje LVM y restauración de contenedores. |

---

## 🧠 Objetivos del Proyecto

### 🎯 Objetivo General
Implementar una infraestructura virtual segura y funcional que combine almacenamiento redundante (RAID), gestión flexible (LVM) y despliegue de servicios en contenedores (Docker y Podman).

### 🎯 Objetivos Específicos
- Configurar RAID 1 con múltiples discos virtuales.  
- Implementar volúmenes lógicos para separar datos de cada servicio.  
- Crear imágenes personalizadas para Apache, Nginx y MySQL mediante `Dockerfile`.  
- Automatizar la restauración de la infraestructura con Bash.  
- Documentar el proceso completo en GitHub.

---
## 🧱 Creación de Imágenes con Dockerfile y Containerfile

Para la personalización de los servicios del proyecto (Apache, Nginx y MySQL), se construyeron imágenes personalizadas utilizando archivos **Dockerfile**, que contienen las instrucciones necesarias para definir el entorno, instalar dependencias y copiar los archivos del proyecto dentro del contenedor.

Con el fin de asegurar compatibilidad tanto con **Docker** como con **Podman**, se duplicaron estos archivos bajo el nombre **Containerfile**, dado que ambos gestores de contenedores interpretan el mismo formato.
---
## 📊Monitoreo en Tiempo Real con Netdata

Se integró Netdata, una herramienta profesional para visualizar métricas en tiempo real:

-CPU, RAM, discos y red

-Estado de RAID y LVM

-Actividad de contenedores Docker/Podman

-Métricas por servicio (Apache, MySQL, Nginx)

---
## ▶️ Ejecución del contenedor Netdata con Podman
sudo podman run -d --name netdata \
  -p 19999:19999 \
  -v netdataconfig:/etc/netdata:Z \
  -v netdatalib:/var/lib/netdata:Z \
  -v netdatacache:/var/cache/netdata:Z \
  --cap-add SYS_PTRACE \
  --security-opt label=disable \
  docker.io/netdata/netdata:latest
---
## 🌍 Acceso al Dashboard Web
http://localhost:19999
---
## 📌 Beneficios dentro del proyecto

-Monitoreo profesional en tiempo real.

-Validación del rendimiento de RAID/LVM bajo carga.

-Seguimiento de contenedores Docker y Podman.

-Supervisión de MySQL, Apache y Nginx en tiempo real.

-Alertas y gráficos instantáneos

---

### 📦 Archivos utilizados
- `/docker_builds/apache/Dockerfile`  
- `/docker_builds/nginx/Dockerfile`  
- `/docker_builds/mysql/Dockerfile`  

Y sus equivalentes:
- `/docker_builds/apache/Containerfile`  
- `/docker_builds/nginx/Containerfile`  
- `/docker_builds/mysql/Containerfile`  

### 🔧 Ejemplo de construcción
Con Docker:
sudo docker build -t apache_custom ./docker_builds/apache
sudo docker build -t nginx_custom ./docker_builds/nginx
sudo docker build -t mysql_custom ./docker_builds/mysql
```bash


## ⚙️ Estructura del Proyecto

```bash
ProyectoFinalInfraestructura/
│
├── BITACORA.md
├── README.md
├── Comandos.txt
├── Proyecto Final Infraestructura.pdf
├── ProyectoFinalInfra
│   ├── apache/
│   │   ├── Dockerfile
│   │   └── Containerfile
|   |   └── index.html
│   ├── mysql/
│   │   ├── Dockerfile
│   │   └── Containerfile
│   └── nginx/
│   |    ├── Dockerfile
│   |    └── Containerfile
│   |     └── index.html
│   └── netdata/
│       ├── go.d
|          └── cgroups.conf
|          └── podman.conf
│       └── system
│          └── podman.socket.override.conf
├── scripts/
│   └── restore_docker.sh
|   └── restore_podman.sh
