# 📋 BITÁCORA DEL PROYECTO - Infraestructura Virtual

**Proyecto:** Implementación de Infraestructura Computacional con RAID, LVM, Docker, Podman y Netdata

**Autores:**
- Juan Esteban Galeano Bolaños - CC: 1005087822
- Mariana Pineda Muñoz - CC: 1095550335
- Santiago Rodas Echeverry - CC: 1092851226

**Universidad del Quindío – 2025**  
**Asignatura:** Infraestructura Virtual  
**Docente:** Maycol Cárdenas Acevedo

---

## 📖 Introducción

El presente proyecto tiene como propósito la implementación de una infraestructura computacional basada en tecnologías de virtualización y contenedorización, con el fin de integrar servicios distribuidos de manera eficiente y segura.

A través de la creación de arreglos RAID 1, la configuración de volúmenes lógicos LVM y la ejecución de contenedores Docker y Podman, se busca garantizar la persistencia, tolerancia a fallos y portabilidad de los servicios.

Los servicios desplegados (Apache, MySQL, Nginx y phpMyAdmin) representan una arquitectura típica de servidores web y de base de datos en entornos empresariales.

El desarrollo de este proyecto permite afianzar conocimientos en almacenamiento redundante, administración de volúmenes, virtualización, gestión de contenedores, monitorización con Netdata y automatización de despliegues, pilares fundamentales de la infraestructura moderna en la nube.

---

## 🎓 Marco Teórico

### RAID (Redundant Array of Independent Disks)

RAID combina múltiples discos duros en un solo sistema lógico para mejorar el rendimiento y la tolerancia a fallos. En este proyecto se utilizó **RAID 1 (espejo)**, que duplica los datos en dos discos para garantizar la integridad ante fallos de hardware.

**Características de RAID 1:**
- Duplicación completa de datos en discos espejo
- Alta disponibilidad y redundancia
- Recuperación automática ante fallo de un disco
- Capacidad total equivalente al disco más pequeño

### LVM (Logical Volume Manager)

LVM permite administrar el almacenamiento de forma flexible mediante:

- **Volúmenes físicos (PV):** Discos o particiones base que forman parte del sistema LVM
- **Grupos de volúmenes (VG):** Agrupación de uno o más PVs que forman un pool de almacenamiento
- **Volúmenes lógicos (LV):** Particiones lógicas redimensionables creadas a partir de un VG

**Ventajas:**
- Ampliación y reducción de volúmenes en caliente
- Snapshots para respaldos consistentes
- Migración de datos entre discos sin interrupciones

### Virtualización vs Contenedorización

**Virtualización:**
- Crea máquinas virtuales independientes con sistema operativo completo
- Mayor aislamiento pero mayor consumo de recursos
- Cada VM incluye kernel completo del sistema operativo

**Contenedorización:**
- Aísla aplicaciones en entornos ligeros compartiendo el kernel del host
- Menor consumo de recursos y arranque más rápido
- Portabilidad total entre diferentes entornos

**Docker** utiliza un demonio central (`dockerd`) que gestiona todos los contenedores, mientras que **Podman** opera sin daemon, ejecutando contenedores como procesos de usuario, ofreciendo mayor seguridad y compatibilidad con imágenes Docker.

### Servicios Implementados

Los servicios implementados fueron:

- **Apache HTTP Server:** Servidor web estándar de la industria para alojar sitios web y aplicaciones
- **MySQL:** Sistema de gestión de bases de datos relacionales para almacenar y consultar información estructurada
- **Nginx:** Servidor web, proxy inverso y balanceador de carga de alto rendimiento
- **phpMyAdmin:** Interfaz web para administración visual de bases de datos MySQL
- **Netdata:** Sistema de monitorización en tiempo real de infraestructura y aplicaciones

La persistencia se logró montando volúmenes LVM sobre los contenedores, asegurando la conservación de datos incluso tras reinicios o recreación de contenedores.

---

## 📚 Definiciones Clave

- **Contenedor:** Entorno aislado que ejecuta una aplicación junto con sus dependencias, compartiendo el kernel del sistema operativo host
- **Imagen:** Plantilla inmutable de solo lectura que contiene el sistema base, aplicaciones y archivos necesarios para crear un contenedor
- **Volumen:** Directorio persistente montado dentro del contenedor para conservar datos más allá del ciclo de vida del contenedor
- **Dockerfile/Containerfile:** Archivo de texto con instrucciones para construir una imagen personalizada de forma reproducible
- **Pod:** Conjunto de contenedores que comparten red y almacenamiento, concepto adoptado por Podman inspirado en Kubernetes
- **Socket:** Canal de comunicación entre procesos, utilizado por Docker y Podman para gestionar contenedores

---

## 🏗️ Estructura del Proyecto

```
ProyectoFinalInfraestructura/
│
├── README.md
├── BITACORA.md
├── Comandos.md
├── Proyecto-Final.pdf
│
├── ProyectoFinalInfra/
│   ├── docker_builds/
│   │   ├── apache/
│   │   │   ├── Dockerfile
│   │   │   ├── Containerfile
│   │   │   └── index.html
│   │   ├── mysql/
│   │   │   ├── Dockerfile
│   │   │   └── Containerfile
│   │   └── nginx/
│   │       ├── Dockerfile
│   │       ├── Containerfile
│   │       └── index.html
│   │
│   ├── netdata/
│   │   ├── go.d/
│   │   │   ├── podman.conf
│   │   │   └── cgroups.conf
│   │   ├── etc/
│   │   │   └── netdata.conf
│   │   └── systemd/
│   │       └── podman.socket.override.conf
│   │
│   └── scripts/
│       ├── infrastructure_setup.sh
│       ├── restore_docker_socket.sh
│       ├── cleanup.sh
│       └── verificacion.sh
│
└── docs/
    ├── manual-instalacion.md
    └── capturas/
```

---

## 🔨 ACTIVIDADES REALIZADAS

---

## FASE 1: Configuración de RAID 1

### Objetivo

Crear 3 arreglos RAID 1 (espejo) con los discos virtuales disponibles. Cada RAID servirá como base para un volumen LVM que usará un contenedor diferente.

### 1.1 Verificación de Discos Disponibles

**Comando utilizado:**
```bash
sudo fdisk -l
```

**Observación:** Se listan los discos conectados al sistema y se identifican los discos destinados a la configuración RAID.

### 1.2 Asignación de Discos por Servicio

| Propósito | Disco 1 | Disco 2 | Resultado |
|-----------|---------|---------|-----------|
| **Apache** | /dev/sdb (APACHE.vdi) | /dev/sdc (PRUEBA1.vdi) | /dev/md0 |
| **MySQL** | /dev/sdd (MySQL.vdi) | /dev/sde (PRUEBA2.vdi) | /dev/md1 |
| **Nginx** | /dev/sdf (Nginx1vdi.vdi) | /dev/sdg (PRUEBA3.vdi) | /dev/md2 |

### 1.3 Creación de los Arreglos RAID

**Comandos ejecutados:**

```bash
# RAID 1 para Apache
sudo mdadm --create --verbose /dev/md0 --level=1 --raid-devices=2 /dev/sdb /dev/sdc

# RAID 1 para MySQL
sudo mdadm --create --verbose /dev/md1 --level=1 --raid-devices=2 /dev/sdd /dev/sde

# RAID 1 para Nginx
sudo mdadm --create --verbose /dev/md2 --level=1 --raid-devices=2 /dev/sdf /dev/sdg
```

**Explicación de parámetros:**
- `--create` → Crea un nuevo arreglo RAID
- `--verbose` → Muestra información detallada del proceso
- `--level=1` → Indica RAID 1 (modo espejo/mirror)
- `--raid-devices=2` → Usa dos discos por arreglo

### 1.4 Verificación del Estado de los RAID

**Comando:**
```bash
cat /proc/mdstat
```

### 1.5 Guardar Configuración de RAID

**Comandos utilizados:**

```bash
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf
sudo update-initramfs -u
```

### 1.6 Verificación Detallada

**Comandos:**
```bash
sudo mdadm --detail /dev/md0
sudo mdadm --detail /dev/md1
sudo mdadm --detail /dev/md2
```

**Conclusión FASE 1:** ✅ Los 3 arreglos RAID están operativos y sincronizados.

---

## FASE 2: Configuración de LVM sobre RAID

### 2.1 Creación de Physical Volumes (PV)

```bash
sudo pvcreate /dev/md0
sudo pvcreate /dev/md1
sudo pvcreate /dev/md2
```

### 2.2 Creación de Volume Groups (VG)

```bash
sudo vgcreate vg_apache /dev/md0
sudo vgcreate vg_mysql /dev/md1
sudo vgcreate vg_nginx /dev/md2
```

### 2.3 Creación de Logical Volumes (LV)

```bash
sudo lvcreate -l 100%FREE -n lv_apache vg_apache
sudo lvcreate -l 100%FREE -n lv_mysql vg_mysql
sudo lvcreate -l 100%FREE -n lv_nginx vg_nginx
```

### 2.4 Formateo con ext4

```bash
sudo mkfs.ext4 /dev/vg_apache/lv_apache
sudo mkfs.ext4 /dev/vg_mysql/lv_mysql
sudo mkfs.ext4 /dev/vg_nginx/lv_nginx
```

### 2.5 Creación de Puntos de Montaje

```bash
sudo mkdir -p /mnt/apache_vol
sudo mkdir -p /mnt/mysql_vol
sudo mkdir -p /mnt/nginx_vol
```

### 2.6 Montaje de Volúmenes

```bash
sudo mount /dev/vg_apache/lv_apache /mnt/apache_vol
sudo mount /dev/vg_mysql/lv_mysql /mnt/mysql_vol
sudo mount /dev/vg_nginx/lv_nginx /mnt/nginx_vol
```

### 2.7 Verificación

```bash
lsblk
mount | grep /mnt
df -h | grep /mnt
```

**Conclusión FASE 2:** ✅ LVM configurado correctamente sobre RAID.

---

## FASE 3: Creación de Contenedores con Docker

### 3.1 Verificación de Docker

```bash
sudo systemctl status docker
sudo systemctl start docker
sudo systemctl enable docker
```

### 3.2 Creación de Dockerfiles

#### Apache Dockerfile

**Ubicación:** `~/docker_builds/apache/Dockerfile`

```dockerfile
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y apache2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

EXPOSE 80

CMD ["apachectl", "-D", "FOREGROUND"]
```

**Construcción:**
```bash
cd ~/docker_builds/apache
sudo docker build -t apache_custom .
```

#### MySQL Dockerfile

**Ubicación:** `~/docker_builds/mysql/Dockerfile`

```dockerfile
FROM mysql:8.0

ENV MYSQL_ROOT_PASSWORD=root
ENV MYSQL_DATABASE=clientes

EXPOSE 3306
```

**Construcción:**
```bash
cd ~/docker_builds/mysql
sudo docker build -t mysql_custom .
```

#### Nginx Dockerfile

**Ubicación:** `~/docker_builds/nginx/Dockerfile`

```dockerfile
FROM nginx:latest

COPY ./index.html /usr/share/nginx/html/index.html

EXPOSE 80
```

**Archivo index.html:**
```bash
echo "<h1>Servidor Nginx funcionando correctamente</h1>" > index.html
```

**Construcción:**
```bash
cd ~/docker_builds/nginx
sudo docker build -t nginx_custom .
```

### 3.3 Ejecución de Contenedores

**Apache:**
```bash
sudo docker run -d --name cont_apache \
  -p 8080:80 \
  -v /mnt/apache_vol:/var/www/html \
  apache_custom
```

**MySQL:**
```bash
sudo docker run -d --name cont_mysql \
  -e MYSQL_ROOT_PASSWORD=root \
  -v /mnt/mysql_vol:/var/lib/mysql \
  mysql_custom
```

**Nginx:**
```bash
sudo docker run -d --name cont_nginx \
  -p 8081:80 \
  -v /mnt/nginx_vol:/usr/share/nginx/html \
  nginx_custom
```

**phpMyAdmin:**
```bash
sudo docker run -d --name phpmyadmin \
  -e PMA_HOST=cont_mysql \
  -e PMA_USER=root \
  -e PMA_PASSWORD=root \
  -p 8082:80 \
  --link cont_mysql:db \
  phpmyadmin/phpmyadmin
```

### 3.4 Pruebas de Funcionamiento

- **Apache:** http://localhost:8080
- **Nginx:** http://localhost:8081
- **phpMyAdmin:** http://localhost:8082
- **MySQL:** Acceso con `sudo docker exec -it cont_mysql mysql -u root -p`

---

## PRUEBAS DE PERSISTENCIA

### Prueba 1: Apache

```bash
echo "<h1>Prueba de persistencia Apache</h1>" | sudo tee /mnt/apache_vol/index.html
sudo docker restart cont_apache
```

**Resultado:** ✅ Datos persistentes

### Prueba 2: MySQL

```sql
USE clientes;
CREATE TABLE persistencia2 (
  id INT PRIMARY KEY,
  descripcion VARCHAR(100)
);
INSERT INTO persistencia2 VALUES (1, 'Segunda prueba de persistencia con RAID y LVM');
```

```bash
sudo docker restart cont_mysql
```

**Resultado:** ✅ Datos persistentes

### Prueba 3: Nginx

```bash
echo "<h1>Prueba de persistencia Nginx</h1>" | sudo tee /mnt/nginx_vol/index.html
sudo docker restart cont_nginx
```

**Resultado:** ✅ Datos persistentes

---

## FASE 4: Implementación con Podman

### 4.1 Instalación

```bash
sudo apt update
sudo apt install -y podman
podman --version
```

### 4.2 Creación de Contenedores Podman

```bash
sudo podman run -d --name cont_apache \
  -p 8080:80 \
  -v /mnt/apache_vol:/var/www/html:Z \
  apache_custom

sudo podman run -d --name cont_nginx \
  -p 8081:80 \
  -v /mnt/nginx_vol:/usr/share/nginx/html:Z \
  nginx_custom

sudo podman run -d --name cont_mysql \
  -e MYSQL_ROOT_PASSWORD=root \
  -v /mnt/mysql_vol:/var/lib/mysql:Z \
  mysql_custom
```

**Conclusión FASE 4:** ✅ Podman compatible con Docker, mismos volúmenes LVM.

---

## FASE 5: Integración de Netdata

### 5.1 Configuración de Collectors

**podman.conf:**
```yaml
jobs:
  - name: local
    url: unix:///host/run/podman/podman.sock
    collect_container_size: yes
    timeout: 5
```

**cgroups.conf:**
```yaml
jobs:
  - name: podman-cgroups
    update_every: 1
    enable_cgroups: true
    autodetect: true
    cgroup_base: "/host/sys/fs/cgroup"
```

### 5.2 Habilitar Socket de Podman

```bash
sudo systemctl enable --now podman.socket
sudo chmod 666 /run/podman/podman.sock
```

### 5.3 Ejecutar Netdata

```bash
sudo podman run -d --name netdata \
  -p 19999:19999 \
  --network host \
  --pid host \
  --privileged \
  -e DOCKER_HOST="/host/run/podman/podman.sock" \
  -v netdata_config:/etc/netdata \
  -v netdata_lib:/var/lib/netdata \
  -v netdata_cache:/var/cache/netdata \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  -v /run/podman/podman.sock:/host/run/podman/podman.sock:ro \
  --restart unless-stopped \
  docker.io/netdata/netdata:latest
```

### 5.4 Acceso al Dashboard

**URL:** http://localhost:19999

**Métricas monitoreadas:**
- CPU, RAM, disco, red del sistema
- Estado de RAID (md0, md1, md2)
- Uso de volúmenes LVM
- Contenedores Podman individuales
- Servicios Apache, MySQL, Nginx

**Conclusión FASE 5:** ✅ Netdata operativo monitoreando toda la infraestructura.

---

## 📊 CONCLUSIONES

El desarrollo del proyecto permitió implementar una infraestructura modular, segura y persistente aplicando principios de redundancia y virtualización.

**RAID y LVM** garantizaron la integridad de los datos mediante espejado y gestión flexible de volúmenes.

**Docker y Podman** demostraron portabilidad total, con contenedores ejecutándose en ambas plataformas usando los mismos volúmenes persistentes.

Las **pruebas de persistencia** confirmaron la conservación de datos tras reinicios, validando el diseño.

**Netdata** proporcionó observabilidad profesional en tiempo real de todos los componentes.

Este proyecto demuestra cómo las tecnologías de contenedores, almacenamiento redundante y monitorización constituyen la base de infraestructuras DevOps modernas.

---

## 📚 REFERENCIAS BIBLIOGRÁFICAS

### Tecnologías de Contenedorización

- Docker Inc. (2024). *Docker Documentation*. https://docs.docker.com/
- Podman. (2024). *What is Podman? — Podman documentation*. https://docs.podman.io/
- Red Hat. (2024). *Podman: Managing containers and pods*. https://podman.io/

### Monitorización

- Netdata Inc. (2024). *Netdata Documentation: Learn Netdata*. https://learn.netdata.cloud/
- Netdata Inc. (2024). *Netdata GitHub Repository*. https://github.com/netdata/netdata

### Almacenamiento

- The Linux Foundation. (2024). *Logical Volume Manager (LVM) HOWTO*. https://tldp.org/HOWTO/LVM-HOWTO/
- Red Hat. (2024). *Configuring and managing logical volumes*. Red Hat Enterprise Linux 9 Documentation.
- The Linux Documentation Project. (2024). *Linux RAID Wiki*. https://raid.wiki.kernel.org/

### Servicios

- The Apache Software Foundation. (2024). *Apache HTTP Server Documentation Version 2.4*. https://httpd.apache.org/docs/2.4/
- NGINX Inc. (2024). *NGINX Documentation*. https://nginx.org/en/docs/
- Oracle Corporation. (2024). *MySQL 8.0 Reference Manual*. https://dev.mysql.com/doc/refman/8.0/en/
- phpMyAdmin Contributors. (2024). *phpMyAdmin Documentation*. https://docs.phpmyadmin.net/

### Virtualización

- Canonical Ltd. (2024). *Ubuntu Server Documentation*. https://ubuntu.com/server/docs
- Oracle Corporation. (2024). *Oracle VM VirtualBox User Manual*. https://www.virtualbox.org/manual/

---

**Fecha de finalización:** Noviembre 17, 2025  
**Versión:** 1.0
