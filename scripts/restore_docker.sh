#!/bin/bash
# ------------------------------------------------------------
# Script: restore_docker.sh
# Autor: Esteban - Proyecto Final Infraestructura
# Objetivo: Restaurar contenedores Docker y montajes LVM/RAID
# ------------------------------------------------------------

echo "🧠 [1/8] Activando volúmenes LVM..."
sudo vgscan > /dev/null
sudo lvscan > /dev/null
sudo vgchange -ay

echo "📂 [2/8] Montando volúmenes en /mnt..."
sudo mount /dev/vg_apache/lv_apache /mnt/apache_vol
sudo mount /dev/vg_mysql/lv_mysql /mnt/mysql_vol
sudo mount /dev/vg_nginx/lv_nginx /mnt/nginx_vol

echo "🧹 [3/8] Deteniendo Docker y limpiando bloqueos..."
sudo systemctl stop docker
sudo systemctl stop docker.socket
sudo pkill -9 dockerd 2>/dev/null
sudo pkill -9 containerd 2>/dev/null
sudo pkill -9 runc 2>/dev/null
sudo rm -rf /var/run/docker/runtime-runc/moby/*

echo "🚀 [4/8] Reiniciando servicio Docker..."
sudo systemctl start docker

echo "🔍 [5/8] Eliminando contenedores anteriores (si existen)..."
sudo docker rm -f cont_apache cont_mysql cont_nginx phpmyadmin 2>/dev/null

echo "🐋 [6/8] Creando contenedores con volúmenes persistentes..."

# Apache
sudo docker run -d --name cont_apache \
  --restart=always \
  -p 8080:80 \
  -v /mnt/apache_vol:/var/www/html:Z \
  apache_custom

# MySQL
sudo docker run -d --name cont_mysql \
  --restart=always \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_DATABASE=clientes \
  -v /mnt/mysql_vol:/var/lib/mysql:Z \
  mysql_custom

# Nginx
sudo docker run -d --name cont_nginx \
  --restart=always \
  -p 8081:80 \
  -v /mnt/nginx_vol:/usr/share/nginx/html:Z \
  nginx_custom

# PhpMyAdmin
sudo docker run -d --name phpmyadmin \
  --restart=always \
  -e PMA_HOST=cont_mysql \
  -e PMA_USER=root \
  -e PMA_PASSWORD=root \
  -p 8082:80 \
  --link cont_mysql:db \
  phpmyadmin/phpmyadmin

echo "🧩 [7/8] Verificando estado de los contenedores..."
sudo docker ps

echo "✅ [8/8] Restauración completa. Accede desde:"
echo "  - Apache:     http://localhost:8080"
echo "  - Nginx:      http://localhost:8081"
echo "  - PhpMyAdmin: http://localhost:8082"
echo "------------------------------------------------------------"
