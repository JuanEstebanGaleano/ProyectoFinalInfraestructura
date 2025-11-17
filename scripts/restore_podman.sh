#!/bin/bash
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
sudo chown -R 33:33  /mnt/apache_vol
sudo chown -R 999:999 /mnt/mysql_vol
sudo chown -R 101:101 /mnt/nginx_vol
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

for c in cont_apache cont_mysql cont_nginx phpmyadmin netdata; do
  if sudo podman ps -a --format "{{.Names}}" | grep -q "^$c$"; then
    echo "→ Eliminando contenedor existente: $c"
    sudo podman rm -f $c >/dev/null 2>&1 || true
  fi
done

sudo podman rm -f $(sudo podman ps -aq) >/dev/null 2>&1 || true

echo ""
echo "=========================================================="
echo "🚀 6) Iniciando contenedores en Podman..."
echo "=========================================================="

# MySQL
sudo podman run -d --name cont_mysql --network red_app \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_DATABASE=clientes \
  -v /mnt/mysql_vol:/var/lib/mysql:Z \
  mysql_custom:latest

# Apache
sudo podman run -d --name cont_apache --network red_app \
  -p 8080:80 \
  -v /mnt/apache_vol:/var/www/html:Z \
  apache_custom:latest

# Nginx
sudo podman run -d --name cont_nginx --network red_app \
  -p 8081:80 \
  -v /mnt/nginx_vol:/usr/share/nginx/html:Z \
  nginx_custom:latest

# phpMyAdmin
sudo podman run -d --name phpmyadmin --network red_app \
  -e PMA_HOST=cont_mysql \
  -e PMA_USER=root \
  -e PMA_PASSWORD=root \
  -p 8082:80 \
  docker.io/phpmyadmin/phpmyadmin:latest

# NETDATA
echo ""
echo "=========================================================="
echo "📊 6.1) Iniciando Netdata (monitoring)..."
echo "=========================================================="

sudo podman run -d --name netdata --network host \
  --cap-add SYS_PTRACE \
  --security-opt=apparmor=unconfined \
  -v netdataconfig:/etc/netdata \
  -v netdatalib:/var/lib/netdata \
  -v netdatacache:/var/cache/netdata \
  -v /etc/passwd:/host/etc/passwd:ro \
  -v /etc/group:/host/etc/group:ro \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  -p 19999:19999 \
  docker.io/netdata/netdata:latest

echo "✅ Netdata está corriendo en: http://localhost:19999"

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
echo "Netdata:    http://localhost:19999"
echo "----------------------------------------------------------"
echo ""
echo "=========================================================="
echo "🩺 8) Health-Check del entorno"
echo "=========================================================="

LOG_FILE="/var/log/infra_health.log"
sudo touch $LOG_FILE
sudo chmod 777 $LOG_FILE

health_log () {
  echo "$(date '+%Y-%m-%d %H:%M:%S')  $1" | tee -a $LOG_FILE
}

check_container () {
  local name=$1
  if sudo podman ps --format "{{.Names}}" | grep -q "^$name$"; then
    echo -e "🟢 $name está ejecutándose"
    health_log "OK: $name ejecutándose"
  else
    echo -e "🔴 $name NO está ejecutándose"
    health_log "FAIL: $name no está ejecutándose"
  fi
}

check_port () {
  local port=$1
  local service=$2

  if sudo ss -tuln | grep -q ":$port"; then
    echo -e "🟢 Puerto $port ($service) está activo"
    health_log "OK: Puerto $port ($service) activo"
  else
    echo -e "🔴 Puerto $port ($service) NO está activo"
    health_log "FAIL: Puerto $port ($service) no está activo"
  fi
}

echo "📦 Verificando contenedores..."

check_container cont_apache
check_container cont_nginx
check_container cont_mysql
check_container phpmyadmin
check_container netdata

echo ""
echo "🌐 Verificando puertos expuestos..."

check_port 8080 "Apache"
check_port 8081 "Nginx"
check_port 8082 "phpMyAdmin"
check_port 3306 "MySQL"
check_port 19999 "Netdata"

echo ""
echo "=========================================================="
echo "📋 Resumen del estado del sistema"
echo "=========================================================="

OK_COUNT=$(grep -c "OK:" $LOG_FILE)
FAIL_COUNT=$(grep -c "FAIL:" $LOG_FILE)

echo "   🟢 Servicios correctos: $OK_COUNT"
echo "   🔴 Servicios con error: $FAIL_COUNT"
echo ""
echo "📄 Log completo en: $LOG_FILE"
echo "=========================================================="
