# 🚀 Proyecto Final - Infraestructura Virtual

**Autores:**
- Juan Esteban Galeano Bolaños - CC: 1005087822
- Mariana Pineda Muñoz - CC: 1095550335
- Santiago Rodas Echeverry - CC: 1092851226

**Universidad del Quindío – 2025**
**Asignatura:** Infraestructura Virtual
**Docente:** Maycol Cárdenas Acevedo

---

## 📘 Descripción General

Este proyecto implementa una infraestructura virtual completa basada en tecnologías de almacenamiento, virtualización y contenedores.

El objetivo fue diseñar un entorno **modular, persistente y automatizado** que integre:

- ✅ **RAID 1** con mdadm para redundancia de almacenamiento
- ✅ **Administración de volúmenes** con LVM
- ✅ **Contenedores** con Docker y Podman
- ✅ **Servicios** de Apache, MySQL, Nginx y phpMyAdmin
- ✅ **Monitorización en tiempo real** con Netdata
- ✅ **Automatización** con scripts Bash
- ✅ **Documentación y bitácora** en GitHub

---

## 🧩 Componentes del Proyecto

| Componente | Descripción | Puerto |
|-------------|-------------|--------|
| **RAID 1 (mdadm)** | Implementa redundancia de datos en discos virtuales | N/A |
| **LVM** | Crea volúmenes dinámicos para Apache, MySQL y Nginx | N/A |
| **Docker** | Orquesta contenedores persistentes para cada servicio | N/A |
| **Podman** | Alternativa sin daemon para pruebas equivalentes | N/A |
| **Apache** | Servidor web principal | 8080 |
| **Nginx** | Servidor web adicional para balanceo y pruebas | 8081 |
| **MySQL** | Base de datos con persistencia en LVM | 3306 |
| **phpMyAdmin** | Interfaz web para gestionar la base de datos | 8082 |
| **Netdata** | Monitoreo en tiempo real del sistema y contenedores | 19999 |

---

## 🧠 Objetivos del Proyecto

### 🎯 Objetivo General

Implementar una infraestructura virtual **segura, escalable y funcional** que combine:
- Almacenamiento redundante (RAID 1)
- Gestión flexible de volúmenes (LVM)
- Despliegue de servicios en contenedores (Docker/Podman)
- Monitorización en tiempo real (Netdata)

### 🎯 Objetivos Específicos

1. ✅ Configurar **RAID 1** con múltiples discos virtuales para garantizar redundancia
2. ✅ Implementar **volúmenes lógicos LVM** para separar datos de cada servicio
3. ✅ Crear **imágenes personalizadas** para Apache, Nginx y MySQL mediante Dockerfile
4. ✅ **Migrar** de Docker a Podman demostrando compatibilidad
5. ✅ **Implementar Netdata** para monitorización completa de contenedores y sistema
6. ✅ Automatizar la **restauración de la infraestructura** con Bash
7. ✅ Documentar el **proceso completo** en GitHub con bitácora detallada

---

## 🧱 Creación de Imágenes con Dockerfile y Containerfile

Para la personalización de los servicios del proyecto (Apache, Nginx y MySQL), se construyeron imágenes personalizadas utilizando archivos **Dockerfile**, que contienen las instrucciones necesarias para definir el entorno, instalar dependencias y copiar los archivos del proyecto dentro del contenedor.

Con el fin de asegurar compatibilidad tanto con **Docker** como con **Podman**, se duplicaron estos archivos bajo el nombre **Containerfile**, dado que ambos gestores de contenedores interpretan el mismo formato.

### 📦 Archivos de Construcción

```
docker_builds/
├── apache/
│   ├── Dockerfile
│   ├── Containerfile
│   └── index.html
├── nginx/
│   ├── Dockerfile
│   ├── Containerfile
│   └── index.html
└── mysql/
    ├── Dockerfile
    └── Containerfile
```

### 🔧 Construcción de Imágenes

**Con Docker:**
```bash
sudo docker build -t apache_custom ./docker_builds/apache
sudo docker build -t nginx_custom ./docker_builds/nginx
sudo docker build -t mysql_custom ./docker_builds/mysql
```

**Con Podman:**
```bash
sudo podman build -t apache_custom ./docker_builds/apache
sudo podman build -t nginx_custom ./docker_builds/nginx
sudo podman build -t mysql_custom ./docker_builds/mysql
```

---

## 📊 Monitoreo en Tiempo Real con Netdata

Se integró **Netdata**, una herramienta profesional para visualizar métricas en tiempo real:

- 📈 **CPU, RAM, discos y red** del sistema completo
- 🔴 **Estado de RAID y LVM** en tiempo real
- 🐳 **Actividad de contenedores** Docker/Podman
- 🔍 **Métricas por servicio** (Apache, MySQL, Nginx)
- ⚠️ **Alertas y notificaciones** automáticas
- 📉 **Gráficos instantáneos** sin configuración

### Configuración de Netdata

```
netdata/
├── go.d/
│   ├── podman.conf      # Collector para Podman
│   └── cgroups.conf     # Collector para cgroups
└── etc/
    └── netdata.conf     # Configuración principal
```

### Ejecución del Contenedor Netdata con Podman

```bash
sudo podman run -d --name netdata \
  -p 19999:19999 \
  --network host \
  --pid host \
  --privileged \
  -v netdata_config:/etc/netdata \
  -v netdata_lib:/var/lib/netdata \
  -v netdata_cache:/var/cache/netdata \
  -v /etc/passwd:/host/etc/passwd:ro \
  -v /etc/group:/host/etc/group:ro \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  -v /run/podman/podman.sock:/host/run/podman/podman.sock:ro \
  docker.io/netdata/netdata:latest
```

### 🌍 Acceso al Dashboard Web

**URL:** `http://localhost:19999`

### 📌 Beneficios dentro del Proyecto

- ✅ Monitoreo profesional en tiempo real
- ✅ Validación del rendimiento de RAID/LVM bajo carga
- ✅ Seguimiento de contenedores Docker y Podman
- ✅ Supervisión de MySQL, Apache y Nginx en tiempo real
- ✅ Alertas y gráficos instantáneos
- ✅ Detección automática de recursos y servicios

---

## 🏗️ Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────┐
│       VirtualBox - Ubuntu Server 22.04 LTS              │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │         RAID 1 (Arreglos Redundantes)           │   │
│  │  /dev/md0  /dev/md1  /dev/md2 (espejo)         │   │
│  └─────────────────┬───────────────────────────────┘   │
│                    │                                    │
│  ┌─────────────────▼───────────────────────────────┐   │
│  │     LVM (Logical Volume Manager)                │   │
│  │  vg_apache  →  /mnt/apache_vol                  │   │
│  │  vg_mysql   →  /mnt/mysql_vol                   │   │
│  │  vg_nginx   →  /mnt/nginx_vol                   │   │
│  └─────────────────┬───────────────────────────────┘   │
│                    │                                    │
│  ┌─────────────────▼───────────────────────────────┐   │
│  │    Contenedores Docker/Podman (red interna)     │   │
│  │                                                 │   │
│  │  cont_apache   cont_mysql   cont_nginx          │   │
│  │  (:8080)       (:3306)      (:8081)             │   │
│  │                                                 │   │
│  │  phpmyadmin    netdata                          │   │
│  │  (:8082)       (:19999) ← MONITOREO             │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

---

## 📁 Estructura del Proyecto

```bash
ProyectoFinalInfraestructura/
│
├── README.md                    # Este archivo
├── BITACORA.md                  # Bitácora detallada del proyecto
├── Comandos.md                  # Referencia de comandos útiles
├── Proyecto-Final.pdf           # Documento del proyecto completo
│
├── ProyectoFinalInfra/
│   │
│   ├── docker_builds/
│   │   ├── apache/
│   │   │   ├── Dockerfile
│   │   │   ├── Containerfile
│   │   │   └── index.html
│   │   ├── nginx/
│   │   │   ├── Dockerfile
│   │   │   ├── Containerfile
│   │   │   └── index.html
│   │   └── mysql/
│   │       ├── Dockerfile
│   │       └── Containerfile
│   │
│   ├── netdata/
│   │   ├── go.d/
│   │   │   ├── podman.conf      # Collector de Podman
│   │   │   └── cgroups.conf     # Collector de cgroups
│   │   ├── etc/
│   │   │   └── netdata.conf     # Configuración principal
│   │   └── systemd/
│   │       └── podman.socket.override.conf
│   │
│   └── scripts/
│       ├── infrastructure_setup.sh        # Script principal (Podman)
│       ├── restore_docker_socket.sh       # Script alternativo (Docker)
│       ├── cleanup.sh                     # Script de limpieza
│       └── verificacion.sh                # Script de verificación
│
└── docs/
    ├── manual-instalacion.md
    └── capturas/
        └── (screenshots del proyecto)
```

---

## 🚀 Instalación Rápida

### Requisitos Previos

- Ubuntu Server 22.04 LTS
- VirtualBox 7.0+
- 4 GB RAM mínimo
- 3 discos virtuales (5GB c/u) para RAID
- Conexión a internet

### Instalación Paso a Paso

```bash
# 1. Clonar el repositorio
git clone https://github.com/JuanEstebanGaleano/ProyectoFinalInfraestructura.git
cd ProyectoFinalInfraestructura

# 2. Ejecutar con Podman (RECOMENDADO)
chmod +x ProyectoFinalInfra/scripts/infrastructure_setup.sh
./ProyectoFinalInfra/scripts/infrastructure_setup.sh

# O ejecutar con Docker (ALTERNATIVO)
chmod +x ProyectoFinalInfra/scripts/restore_docker_socket.sh
./ProyectoFinalInfra/scripts/restore_docker_socket.sh
```

---

## 📊 Servicios Disponibles

Una vez ejecutada la infraestructura:

| Servicio | URL | Usuario | Contraseña |
|----------|-----|---------|------------|
| Apache | http://localhost:8080 | N/A | N/A |
| Nginx | http://localhost:8081 | N/A | N/A |
| phpMyAdmin | http://localhost:8082 | root | root |
| MySQL | localhost:3306 | root | root |
| Netdata | http://localhost:19999 | N/A | N/A |

---

## 💡 Comandos Útiles

### Gestión de Contenedores Podman

```bash
# Ver contenedores activos
sudo podman ps

# Ver logs de un servicio
sudo podman logs netdata

# Entrar a un contenedor
sudo podman exec -it cont_mysql bash

# Reiniciar un contenedor
sudo podman restart cont_apache
```

### Verificación de RAID y LVM

```bash
# Estado de RAID
cat /proc/mdstat
sudo mdadm --detail /dev/md0

# Volúmenes LVM
sudo lvs
df -h | grep mnt
```

### Monitorización con Netdata

```bash
# Ver logs de Netdata
sudo podman logs netdata | tail -50

# Verificar detección de contenedores
sudo podman logs netdata | grep -i "podman"

# Reiniciar Netdata
sudo podman restart netdata
```

---

## 🐛 Solución de Problemas

### Netdata no muestra contenedores

```bash
# Verificar socket de Podman
ls -la /run/podman/podman.sock

# Ver logs
sudo podman logs netdata | grep -i error

# Reiniciar
sudo podman restart netdata
```

### Contenedor no inicia

```bash
# Ver logs detallados
sudo podman logs <nombre-contenedor>

# Verificar puertos
sudo ss -tlnp | grep <puerto>

# Recrear contenedor
sudo podman rm -f <nombre-contenedor>
```

### Volumen LVM sin espacio

```bash
# Ver espacio
df -h | grep mnt

# Extender volumen (+2GB)
sudo lvextend -L +2G /dev/vg_mysql/lv_mysql
sudo resize2fs /dev/vg_mysql/lv_mysql
```

---

## 📚 Documentación Adicional

- 📄 [Documento del proyecto completo](Proyecto-Final.pdf)
- 📋 [Bitácora del proyecto](BITACORA.md)
- 🔧 [Referencia de comandos](Comandos.md)
- 📘 [Documentación de Podman](https://docs.podman.io/)
- 📊 [Documentación de Netdata](https://learn.netdata.cloud/)

---

## 🤝 Equipo del Proyecto

| Integrante | Cédula | Rol |
|-----------|--------|-----|
| Juan Esteban Galeano | 1005087822 | Infraestructura, Podman, Netdata |
| Mariana Pineda | 1095550335 | Diseño, Documentación |
| Santiago Rodas | 1092851226 | Testing, Validación |

---

## 📄 Licencia

Este proyecto es de carácter académico para la asignatura de Infraestructura Virtual de la Universidad del Quindío.

---

## 📞 Contacto

- **Repositorio:** [github.com/JuanEstebanGaleano/ProyectoFinalInfraestructura](https://github.com/JuanEstebanGaleano/ProyectoFinalInfraestructura)
- **Universidad:** Universidad del Quindío
- **Año:** 2025

---

⭐ **Si este proyecto te fue útil, dale una estrella en GitHub**

**Desarrollado con 💙 para Infraestructura Virtual 2025**

│   └── restore_docker.sh
|   └── restore_podman.sh
