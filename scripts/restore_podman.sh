#!/bin/bash
# ==========================================================
# 🔹 Proyecto Final Infraestructura - Fase 5 (Podman)
# 🔹 Autor: Esteban Galeano
# 🔹 Script: start_podman.sh
# 🔹 Descripción:
#   - Detiene y limpia contenedores Docker
#   - Monta LVM/RAID con persistencia
#   - Asigna permisos correctos
#   - Crea red y levanta contenedores Podman:
#     Apache, MySQL, Nginx y phpMyAdmin
# ==========================================================

set -e

echo "=========================================================="
echo "🧹 1) Deteniendo contenedores Docker y liberando recursos..."
echo "=========================================================="

# Verifica si Docker está activo
if systemctl is-active --quiet docker; then
  echo "→ Docker está activo, deteniendo contenedores..."
  sudo docker stop $(sudo docker ps -q) 2>/dev/null || true
  sudo docker rm -f $(sudo docker ps -aq) 2>/dev/null || true
  sudo systemctl stop docker
  echo "✅ Docker detenido correctamente."
else
  echo "→ Docker no está en ejecución. Continuando..."
fi

echo ""
echo "=========================================================="
echo "🔧 2) Activando volúmenes LVM (vg_apache, vg_mysql, vg_nginx)..."
echo "=========================================================="
sudo vgscan >/dev/null 2>&1 || true
sudo lvscan >/dev/null 2>&1 || true
sudo vgchange -ay >/dev/null 2>&1 || true

sudo mkdir -p /mnt/apache_vol /mnt/mysql_vol /mnt/nginx_vol

# Montaje de volúmenes
sudo mountpoint -q /mnt/apache_vol || sudo mount /dev/vg_apache/lv_apache /mnt/apache_vol
sudo mountpoint -q /mnt/mysql_vol  || sudo mount /dev/vg_mysql/lv_mysql /mnt/mysql_vol
sudo mountpoint -q /mnt/nginx_vol  || sudo mount /dev/vg_nginx/lv_nginx /mnt/nginx_vol

echo "✅ Volúmenes activos:"
lsblk | grep "vg_"

echo ""
echo "=========================================================="
echo "🔐 3) Corrigiendo permisos sobre los volúmenes..."
echo "=========================================================="
sudo chown -R 33:33 /mnt/apache_vol    # Apache -> www-data
sudo chown -R 999:999 /mnt/mysql_vol   # MySQL -> mysql
sudo chown -R 101:101 /mnt/nginx_vol   # Nginx -> nginx
sudo chmod -R 777 /mnt/apache_vol /mnt/mysql_vol /mnt/nginx_vol

echo ""
echo "=========================================================="
echo "🌐 4) Creando red interna 'red_app' para Podman..."
echo "=========================================================="
if ! sudo podman network inspect red_app >/dev/null 2>&1; then
  sudo podman network create red_app >/dev/null
  echo "✅ red_app creada"
else
  echo "→ red_app ya existe"
fi

echo ""
echo "=========================================================="
echo "🧹 5) Eliminando contenedores Podman antiguos..."
echo "=========================================================="
sudo podman rm -f cont_apache cont_mysql cont_nginx phpmyadmin 2>/dev/null || true

echo ""
echo "=========================================================="
echo "🚀 6) Iniciando contenedores en Podman..."
echo "=========================================================="

# MySQL
sudo podman run -d --name cont_mysql --network red_app \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_DATABASE=clientes \
  -v /mnt/mysql_vol:/var/lib/mysql:Z \
  docker.io/library/mysql_custom:latest

# Apache
sudo podman run -d --name cont_apache --network red_app \
  -p 8080:80 \
  -v /mnt/apache_vol:/var/www/html:Z \
  docker.io/library/apache_custom:latest

# Nginx
sudo podman run -d --name cont_nginx --network red_app \
  -p 8081:80 \
  -v /mnt/nginx_vol:/usr/share/nginx/html:Z \
  docker.io/library/nginx_custom:latest

# phpMyAdmin
sudo podman run -d --name phpmyadmin --network red_app \
  -e PMA_HOST=cont_mysql \
  -e PMA_USER=root \
  -e PMA_PASSWORD=root \
  -p 8082:80 \
  docker.io/phpmyadmin/phpmyadmin:latest

echo ""
echo "=========================================================="
echo "🧩 7) Contenedores activos en Podman:"
echo "=========================================================="
sudo podman ps

echo ""
echo "=========================================================="
echo "✅ Entorno Podman desplegado con éxito"
echo "----------------------------------------------------------"
echo "Apache:     http://localhost:8080"
echo "Nginx:      http://localhost:8081"
echo "phpMyAdmin: http://localhost:8082  (root / root)"
echo "MySQL:      cont_mysql (interno)"
echo "----------------------------------------------------------"
