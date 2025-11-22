#!/bin/bash
# ============================================================
# Script: restore_docker.sh
# Autor: Juan Esteban Galeano, Mariana Pineda, Santiago Rodas
# Proyecto Final - Infraestructura Virtual
# Objetivo: Limpiar y restaurar contenedores Docker + Netdata
# ============================================================

set -e

echo "🧠 [1/12] Activando volúmenes LVM..."
sudo vgscan > /dev/null
sudo lvscan > /dev/null
sudo vgchange -ay > /dev/null
echo "✅ Volúmenes LVM activados."

echo "📂 [2/12] Montando volúmenes en /mnt..."
sudo mkdir -p /mnt/apache_vol /mnt/mysql_vol /mnt/nginx_vol
sudo mountpoint -q /mnt/apache_vol || sudo mount /dev/vg_apache/lv_apache /mnt/apache_vol
sudo mountpoint -q /mnt/mysql_vol || sudo mount /dev/vg_mysql/lv_mysql /mnt/mysql_vol
sudo mountpoint -q /mnt/nginx_vol || sudo mount /dev/vg_nginx/lv_nginx /mnt/nginx_vol
echo "✅ Volúmenes montados."

echo "🧹 [2.5/12] Limpiando datos antiguos de MySQL..."
# IMPORTANTE: Limpiar el volumen de MySQL si tiene datos corruptos
if [ "$(ls -A /mnt/mysql_vol)" ]; then
    echo "  ⚠  Eliminando datos antiguos de MySQL para empezar limpio..."
    sudo rm -rf /mnt/mysql_vol/*
    echo "  ✅ Volumen MySQL limpio."
else
    echo "  ✔  Volumen MySQL ya está vacío."
fi

echo "🔐 [3/12] Asignando permisos a los volúmenes..."
sudo chown -R 33:33 /mnt/apache_vol   # Apache
sudo chown -R 999:999 /mnt/mysql_vol  # MySQL
sudo chown -R 101:101 /mnt/nginx_vol  # Nginx
sudo chmod -R 777 /mnt/apache_vol /mnt/mysql_vol /mnt/nginx_vol
echo "✅ Permisos configurados."

echo "🧹 [4/12] Verificando conflictos con Podman..."
if systemctl is-active --quiet podman 2>/dev/null; then
    echo "⚠  Deteniendo Podman para evitar conflictos..."
    sudo systemctl stop podman
    sudo pkill -9 podman 2>/dev/null || true
    echo "✅ Podman detenido."
else
    echo "✔  Podman no activo. Continuando..."
fi

echo "🚀 [5/12] Iniciando servicio Docker..."
sudo systemctl enable --now docker
sleep 5
if ! systemctl is-active --quiet docker; then
    echo "❌ Docker no pudo iniciarse. Revisa con 'sudo systemctl status docker'"
    exit 1
fi
echo "✅ Docker activo."

echo "🗑  [6/12] LIMPIEZA COMPLETA: Eliminando contenedores antiguos..."

# Método 1: Eliminar por nombre exacto
echo "  → Deteniendo y eliminando cont_apache..."
sudo docker stop cont_apache 2>/dev/null || true
sudo docker rm -f cont_apache 2>/dev/null || true

echo "  → Deteniendo y eliminando cont_mysql..."
sudo docker stop cont_mysql 2>/dev/null || true
sudo docker rm -f cont_mysql 2>/dev/null || true

echo "  → Deteniendo y eliminando cont_nginx..."
sudo docker stop cont_nginx 2>/dev/null || true
sudo docker rm -f cont_nginx 2>/dev/null || true

echo "  → Deteniendo y eliminando phpmyadmin..."
sudo docker stop phpmyadmin 2>/dev/null || true
sudo docker rm -f phpmyadmin 2>/dev/null || true

echo "  → Deteniendo y eliminando netdata..."
sudo docker stop netdata 2>/dev/null || true
sudo docker rm -f netdata 2>/dev/null || true

# Método 2: Limpieza adicional de cualquier resto
echo "  → Limpieza final de contenedores huérfanos..."
sudo docker ps -aq --filter "name=cont_" --filter "name=phpmyadmin" --filter "name=netdata" | xargs -r sudo docker rm -f 2>/dev/null || true

# Esperar a que se completen las eliminaciones
sleep 3
echo "🗑  [6/12] LIMPIEZA COMPLETA: Eliminando contenedores antiguos..."

# MÉTODO AGRESIVO: Eliminar TODOS los contenedores primero
echo "  ⚠  Eliminación forzada de TODOS los contenedores..."
sudo docker ps -aq | xargs -r sudo docker stop 2>/dev/null || true
sudo docker ps -aq | xargs -r sudo docker rm -f 2>/dev/null || true

# Limpiar volúmenes anónimos huérfanos también
sudo docker volume prune -f 2>/dev/null || true

# Verificar que no quede ningún contenedor
CONTENEDORES_RESTANTES=$(sudo docker ps -aq | wc -l)
if [ "$CONTENEDORES_RESTANTES" -gt 0 ]; then
    echo "  ⚠  Aún quedan $CONTENEDORES_RESTANTES contenedores. Forzando limpieza..."
    sudo systemctl restart docker
    sleep 5
    sudo docker ps -aq | xargs -r sudo docker rm -f 2>/dev/null || true
fi

echo "✅ Todos los contenedores eliminados."

echo "✅ Todos los contenedores antiguos eliminados."

echo "🌐 [7/12] Limpiando red anterior..."
# Desconectar contenedores de la red y eliminarla
if [ "$(sudo docker network ls -q -f name=^proyecto_network$)" ]; then
    echo "  ⚠  Desconectando contenedores de la red..."
    # Obtener contenedores conectados y desconectarlos
    sudo docker network inspect proyecto_network --format='{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null | xargs -n1 | while read contenedor; do
        [ -n "$contenedor" ] && sudo docker network disconnect -f proyecto_network "$contenedor" 2>/dev/null || true
    done
    echo "  ⚠  Eliminando red: proyecto_network"
    sudo docker network rm proyecto_network 2>/dev/null || true
fi
echo "✅ Red anterior eliminada."

echo "🔓 [8/12] Liberando puertos en uso..."
sudo fuser -k 8080/tcp 2>/dev/null || true
sudo fuser -k 8081/tcp 2>/dev/null || true
sudo fuser -k 8082/tcp 2>/dev/null || true
sudo fuser -k 3306/tcp 2>/dev/null || true
sudo fuser -k 19999/tcp 2>/dev/null || true
sleep 2
echo "✅ Puertos liberados."

echo "🌐 [9/12] Creando red personalizada limpia..."
sudo docker network create proyecto_network 2>/dev/null || echo "✔  Red ya existe y lista para usar."
echo "✅ Red 'proyecto_network' disponible."

echo "🐋 [10/12] Creando contenedores NUEVOS con volúmenes persistentes..."

# Apache
echo "  → Contenedor Apache..."
sudo docker run -d --name cont_apache \
  --restart=always \
  -p 8080:80 \
  --network proyecto_network \
  -v /mnt/apache_vol:/var/www/html:Z \
  apache_custom

# MySQL - IMPORTANTE: Darle tiempo para inicializarse
echo "  → Contenedor MySQL..."
sudo docker run -d --name cont_mysql \
  --restart=always \
  --network proyecto_network \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_DATABASE=clientes \
  -v /mnt/mysql_vol:/var/lib/mysql:Z \
  mysql_custom

# Esperar a que MySQL esté completamente listo
echo "  ⏳ Esperando a que MySQL inicie completamente..."
sleep 15

# Verificar que MySQL está escuchando
until sudo docker exec cont_mysql mysqladmin ping --silent 2>/dev/null; do
    echo "  ⏳ MySQL aún no está listo, esperando..."
    sleep 3
done
echo "  ✅ MySQL está listo y respondiendo."

# Nginx
echo "  → Contenedor Nginx..."
sudo docker run -d --name cont_nginx \
  --restart=always \
  -p 8081:80 \
  --network proyecto_network \
  -v /mnt/nginx_vol:/usr/share/nginx/html:Z \
  nginx_custom

# PhpMyAdmin - Ahora que MySQL está listo
echo "  → Contenedor phpMyAdmin..."
sudo docker run -d --name phpmyadmin \
  --restart=always \
  --network proyecto_network \
  -e PMA_HOST=cont_mysql \
  -e PMA_USER=root \
  -e PMA_PASSWORD=root \
  -e PMA_ARBITRARY=1 \
  -p 8082:80 \
  phpmyadmin/phpmyadmin

# Esperar a que phpMyAdmin se conecte
echo "  ⏳ Esperando a que phpMyAdmin se conecte a MySQL..."
sleep 5

echo "✅ Contenedores creados exitosamente."



echo "📊 [11/12] Iniciando Netdata con monitoreo de contenedores..."
sudo docker run -d --name netdata \
  --restart=always \
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
  --group-add $(getent group docker | cut -d: -f3) \
  netdata/netdata:latest

echo "✅ Netdata iniciado correctamente."

echo ""
echo "📌 [12/12] Verificación final - Estado de todos los contenedores:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Networks}}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🎉 INFRAESTRUCTURA COMPLETAMENTE REINICIADA"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Apache:       http://localhost:8080"
echo "Nginx:        http://localhost:8081"
echo "phpMyAdmin:   http://localhost:8082"
echo "MySQL:        cont_mysql (red: proyecto_network)"
echo "Netdata:      http://localhost:19999"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 TIPS:"
echo "   - Todo fue eliminado y recreado desde cero"
echo "   - Contenedores en red limpia: proyecto_network"
echo "   - Monitoreo en: Netdata > Containers & VMs"
echo "   - Datos persistentes en /mnt/apache_vol, /mnt/mysql_vol, /mnt/nginx_vol"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
