# 🧰 Guía de Comandos - Proyecto Final Infraestructura Virtual

Autores:
Juan Esteban Galeano
Mariana Pienda
Santiago Rodas

Universidad del Quindío — 2025

------------------------------------------------------------

## 📘 Descripción

Este documento reúne todos los comandos utilizados durante el desarrollo del proyecto de Infraestructura Virtual.

------------------------------------------------------------

## ⚙️ Fase 1: Configuración de RAID

sudo fdisk -l
sudo mdadm --create --verbose /dev/md0 --level=1 --raid-devices=2 /dev/sdb /dev/sdc
cat /proc/mdstat
sudo mdadm --detail /dev/md0
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf

------------------------------------------------------------

## 💽 Fase 2: Creación de volúmenes LVM

sudo pvcreate /dev/md0 /dev/md1 /dev/md2
sudo vgcreate vg_apache /dev/md0
sudo vgcreate vg_mysql /dev/md1
sudo vgcreate vg_nginx /dev/md2
sudo lvcreate -L 1.5G -n lv_apache vg_apache
sudo lvcreate -L 1.7G -n lv_mysql vg_mysql
sudo lvcreate -L 1.4G -n lv_nginx vg_nginx
sudo mkfs.ext4 /dev/vg_apache/lv_apache
sudo mkfs.ext4 /dev/vg_mysql/lv_mysql
sudo mkfs.ext4 /dev/vg_nginx/lv_nginx
sudo mkdir -p /mnt/apache_vol /mnt/mysql_vol /mnt/nginx_vol
sudo mount /dev/vg_apache/lv_apache /mnt/apache_vol
sudo mount /dev/vg_mysql/lv_mysql /mnt/mysql_vol
sudo mount /dev/vg_nginx/lv_nginx /mnt/nginx_vol

------------------------------------------------------------

## 🐋 Fase 3: Creación de Imágenes Docker

# Apache
cd ~/docker_builds/apache
sudo docker build -t apache_custom .

# MySQL
cd ~/docker_builds/mysql
sudo docker build -t mysql_custom .

# Nginx
cd ~/docker_builds/nginx
sudo docker build -t nginx_custom .

------------------------------------------------------------

## 🚀 Fase 4: Ejecución de Contenedores Docker

sudo docker run -d --name cont_apache -p 8080:80 -v /mnt/apache_vol:/var/www/html:Z apache_custom
sudo docker run -d --name cont_mysql -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=clientes -v /mnt/mysql_vol:/var/lib/mysql:Z mysql_custom
sudo docker run -d --name cont_nginx -p 8081:80 -v /mnt/nginx_vol:/usr/share/nginx/html:Z nginx_custom
sudo docker run -d --name phpmyadmin -e PMA_HOST=cont_mysql -e PMA_USER=root -e PMA_PASSWORD=root -p 8082:80 --link cont_mysql:db phpmyadmin/phpmyadmin

------------------------------------------------------------

## 🧩 Fase 5: Administración de Contenedores

sudo docker ps
sudo docker ps -a
sudo docker stop cont_apache cont_mysql cont_nginx phpmyadmin
sudo docker rm -f cont_apache cont_mysql cont_nginx phpmyadmin
sudo docker logs cont_apache
sudo docker exec -it cont_mysql bash

------------------------------------------------------------

## 🐳 Fase 6: Podman (Alternativa a Docker)

sudo podman pull docker-daemon:apache_custom:latest
sudo podman pull docker-daemon:mysql_custom:latest
sudo podman pull docker-daemon:nginx_custom:latest
sudo podman run -d --name cont_apache -p 8080:80 -v /mnt/apache_vol:/var/www/html:Z apache_custom
sudo podman run -d --name cont_mysql -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=clientes -v /mnt/mysql_vol:/var/lib/mysql:Z mysql_custom
sudo podman run -d --name cont_nginx -p 8081:80 -v /mnt/nginx_vol:/usr/share/nginx/html:Z nginx_custom
sudo podman ps

------------------------------------------------------------
📊 Fase 7: Monitoreo con Netdata
🟦 Netdata con Docker
sudo docker run -d --name netdata \
  -p 19999:19999 \
  --cap-add SYS_PTRACE \
  -v netdata_lib:/var/lib/netdata \
  -v netdata_cache:/var/cache/netdata \
  -v /etc/passwd:/host/etc/passwd:ro \
  -v /etc/group:/host/etc/group:ro \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  netdata/netdata

🟩 Netdata con Podman
sudo podman run -d --name netdata \
  -p 19999:19999 \
  --network red_app \
  --cap-add=SYS_PTRACE \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  -v /etc/passwd:/host/etc/passwd:ro \
  -v /etc/group:/host/etc/group:ro \
  netdata/netdata


📍Acceso al panel:
👉 http://localhost:19999
------------------------------------------------------------
## 🧠 Fase 8: Automatización con Script

sudo bash scripts/restore_docker.sh
sudo bash scripts/restore_podman.sh

------------------------------------------------------------

## 🧹 Fase 9: Limpieza y Mantenimiento

sudo systemctl stop docker
sudo systemctl stop podman
sudo docker system prune -a
sudo podman system prune -a

------------------------------------------------------------

## 🔍 Verificación del Entorno

sudo lvs
cat /proc/mdstat
sudo systemctl status docker
sudo systemctl status podman
