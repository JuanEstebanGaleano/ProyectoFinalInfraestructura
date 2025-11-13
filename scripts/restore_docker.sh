#!/bin/bash
# ------------------------------------------------------------
# Script: restore_docker.sh
# Autor: Juan Esteban Galeano, Mariana Pienda, Santiago Rodas
# Proyecto Final - Infraestructura Virtual
# Objetivo: Restaurar contenedores Docker y montajes LVM/RAID
# ------------------------------------------------------------

echo "🧠 [1/10] Activando volúmenes LVM..."
sudo vgscan > /dev/null
sudo lvscan > /dev/null
sudo vgchange -ay

echo "📂 [2/10] Montando volúmenes en /mnt..."
sudo mount /dev/vg_apache/lv_apache /mnt/apache_vol 2>/dev/null
sudo mount /dev/vg_mysql/lv_mysql /mnt/mysql_vol 2>/dev/null
sudo mount /dev/vg_nginx/lv_nginx /mnt/nginx_vol 2>/dev/null

echo "🔐 [3/10] Asignando permisos completos a los volúmenes..."
# Permisos de propietario según servicio:
sudo chown -R 33:33 /mnt/apache_vol   # Apache (www-data)
sudo chown -R 999:999 /mnt/mysql_vol  # MySQL
sudo chown -R 101:101 /mnt/nginx_vol  # Nginx
# Permisos totales para evitar bloqueos
sudo chmod -R 777 /mnt/apache_vol /mnt/mysql_vol /mnt/nginx_vol

echo "🧹 [4/10] Verificando si Podman está activo..."
if systemctl is-active --quiet podman; then
  echo "⚠️  Podman está ejecutándose. Deteniendo servicios para evitar conflicto con Docker..."
  sudo systemctl stop podman
  sudo pkill -9 podman 2>/dev/null
  echo "✅ Podman detenido correctamente."
else
  echo "✔️  Podman no está activo. Continuando..."
fi

echo "🧹 [5/10] Deteniendo Docker y limpiando bloqueos previos..."
sudo systemctl stop docker docker.socket 2>/dev/null
sudo pkill -9 dockerd containerd runc 2>/dev/null
sudo rm -rf /var/run/docker/runtime-runc/moby/* 2>/dev/null

echo "🚀 [6/10] Iniciando servicio Docker..."
sudo systemctl start docker
sleep 10

if ! systemctl is-active --quiet docker; then
  echo "❌ Error: Docker no pudo iniciarse. Revisa el servicio manualmente con 'sudo systemctl status docker'"
  exit 1
fi
echo "✅ Docker iniciado correctamente."

echo "🧩 [7/10] Eliminando contenedores anteriores (si existen)..."
sudo docker rm -f cont_apache cont_mysql cont_nginx phpmyadmin 2>/dev/null

echo "🐋 [8/10] Creando contenedores con volúmenes persistentes..."

# --- Apache ---
sudo docker run -d --name cont_apache \
  --restart=always \
  -p 8080:80 \
  -v /mnt/apache_vol:/var/www/html:Z \
  apache_custom || { echo "❌ Error al crear contenedor Apache"; exit 1; }

# --- MySQL ---
sudo docker run -d --name cont_mysql \
  --restart=always \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_DATABASE=clientes \
  -v /mnt/mysql_vol:/var/lib/mysql:Z \
  mysql_custom || { echo "❌ Error al crear contenedor MySQL"; exit 1; }

# --- Nginx ---
sudo docker run -d --name cont_nginx \
  --restart=always \
  -p 8081:80 \
  -v /mnt/nginx_vol:/usr/share/nginx/html:Z \
  nginx_custom || { echo "❌ Error al crear contenedor Nginx"; exit 1; }

# --- PhpMyAdmin ---
sudo docker run -d --name phpmyadmin \
  --restart=always \
  -e PMA_HOST=cont_mysql \
  -e PMA_USER=root \
  -e PMA_PASSWORD=root \
  -p 8082:80 \
  --link cont_mysql:db \
  phpmyadmin/phpmyadmin || { echo "❌ Error al crear contenedor PhpMyAdmin"; exit 1; }

echo "🔍 [9/10] Verificando estado de los contenedores..."
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo "✅ [10/10] Restauración completa. Accede desde:"
echo "  🌐 Apache:     http://localhost:8080"
echo "  🌐 Nginx:      http://localhost:8081"
echo "  💾 PhpMyAdmin: http://localhost:8082"
echo "------------------------------------------------------------"

