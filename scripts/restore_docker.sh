#!/bin/bash
# ============================================================
# Script: restore_docker_socket.sh
# Autor: Juan Esteban Galeano, Mariana Pineda, Santiago Rodas
# Proyecto Final - Infraestructura Virtual
# Objetivo: Restaurar contenedores Docker y levantar Netdata
# ============================================================

set -e

echo "🧠 [1/11] Activando volúmenes LVM..."
sudo vgscan > /dev/null
sudo lvscan > /dev/null
sudo vgchange -ay > /dev/null

echo "📂 [2/11] Montando volúmenes en /mnt..."
sudo mkdir -p /mnt/apache_vol /mnt/mysql_vol /mnt/nginx_vol
sudo mountpoint -q /mnt/apache_vol || sudo mount /dev/vg_apache/lv_apache /mnt/apache_vol
sudo mountpoint -q /mnt/mysql_vol || sudo mount /dev/vg_mysql/lv_mysql /mnt/mysql_vol
sudo mountpoint -q /mnt/nginx_vol || sudo mount /dev/vg_nginx/lv_nginx /mnt/nginx_vol

echo "🔐 [3/11] Asignando permisos completos a los volúmenes..."
sudo chown -R 33:33 /mnt/apache_vol   # Apache
sudo chown -R 999:999 /mnt/mysql_vol  # MySQL
sudo chown -R 101:101 /mnt/nginx_vol  # Nginx
sudo chmod -R 777 /mnt/apache_vol /mnt/mysql_vol /mnt/nginx_vol

echo "🧹 [4/11] Verificando conflictos con Podman..."
if systemctl is-active --quiet podman; then
    echo "⚠  Deteniendo Podman para evitar conflictos..."
    sudo systemctl stop podman
    sudo pkill -9 podman 2>/dev/null || true
    echo "✅ Podman detenido."
else
    echo "✔  Podman no activo. Continuando..."
fi

echo "🧹 [5/11] Deteniendo Docker y limpiando contenedores previos..."
sudo docker rm -f cont_apache cont_mysql cont_nginx phpmyadmin netdata 2>/dev/null || true
sudo fuser -k 8080/tcp 2>/dev/null || true
sudo fuser -k 8081/tcp 2>/dev/null || true
sudo fuser -k 8082/tcp 2>/dev/null || true
sudo fuser -k 3306/tcp 2>/dev/null || true
sudo fuser -k 19999/tcp 2>/dev/null || true

echo "🚀 [6/11] Iniciando servicio Docker..."
sudo systemctl enable --now docker
sleep 5
if ! systemctl is-active --quiet docker; then
    echo "❌ Docker no pudo iniciarse. Revisa con 'sudo systemctl status docker'"
    exit 1
fi
echo "✅ Docker activo."

echo "🌐 [7/11] Creando red personalizada para los contenedores..."
# ✅ NUEVO: Crear red Docker compartida
sudo docker network create proyecto_network 2>/dev/null || true

echo "🐋 [8/11] Creando contenedores con volúmenes persistentes en la red..."

# Apache
sudo docker run -d --name cont_apache \
  --restart=always \
  -p 8080:80 \
  --network proyecto_network \
  -v /mnt/apache_vol:/var/www/html:Z \
  apache_custom

# MySQL
sudo docker run -d --name cont_mysql \
  --restart=always \
  --network proyecto_network \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_DATABASE=clientes \
  -v /mnt/mysql_vol:/var/lib/mysql:Z \
  mysql_custom

# Nginx
sudo docker run -d --name cont_nginx \
  --restart=always \
  -p 8081:80 \
  --network proyecto_network \
  -v /mnt/nginx_vol:/usr/share/nginx/html:Z \
  nginx_custom

# PhpMyAdmin
sudo docker run -d --name phpmyadmin \
  --restart=always \
  --network proyecto_network \
  -e PMA_HOST=cont_mysql \
  -e PMA_USER=root \
  -e PMA_PASSWORD=root \
  -p 8082:80 \
  phpmyadmin/phpmyadmin

echo "📡 [9/11] Verificando contenedores activos..."
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo "📊 [10/11] Iniciando Netdata en la red Docker..."
# Elimina si existe contenedor previo
sudo docker rm -f netdata 2>/dev/null || true

# ✅ CORRECCIÓN: Netdata también en la red + acceso a docker.sock
sudo docker run -d --name netdata \
  -p 19999:19999 \
  --network proyecto_network \
  --cap-add SYS_PTRACE \
  --cap-add SYS_ADMIN \
  --security-opt apparmor=unconfined \
  -v netdata_lib:/var/lib/netdata \
  -v netdata_cache:/var/cache/netdata \
  -v /etc/passwd:/host/etc/passwd:ro \
  -v /etc/group:/host/etc/group:ro \
  -v /etc/os-release:/host/etc/os-release:ro \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /run/dbus:/run/dbus:ro \
  --group-add 999 \
  netdata/netdata:latest

echo "✅ Netdata iniciado correctamente."

echo "📌 [11/11] Estado final de todos los contenedores:"
sudo docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Networks}}"

echo ""
echo "🎉 ENTORNO COMPLETO LEVANTADO"
echo "----------------------------------------------------------"
echo "Apache:     http://localhost:8080"
echo "Nginx:      http://localhost:8081"
echo "phpMyAdmin: http://localhost:8082"
echo "MySQL:      cont_mysql (desde red: proyecto_network)"
echo "Netdata:    http://localhost:19999"
echo "----------------------------------------------------------"
echo ""
echo "💡 TIPS:"
echo "   - Dentro de Netdata, ve a 'Containers & VMs' para ver tus contenedores"
echo "   - Los contenedores se comunican por nombre (ej: 'cont_mysql')"
echo "   - Si aún no ves los contenedores, ejecuta:"
echo "     sudo docker logs netdata | grep -i docker"
echo "----------------------------------------------------------"
