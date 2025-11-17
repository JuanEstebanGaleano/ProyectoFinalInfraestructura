#!/bin/bash
################################################################################
# Script: infrastructure_setup.sh
# Autor: Juan Esteban Galeano, Mariana Pineda, Santiago Rodas
# Proyecto Final - Infraestructura Virtual
# Objetivo: Levantar toda la infraestructura (Podman + Netdata + LVM)
################################################################################

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variables
BASE_NETDATA="${HOME}/ProyectoFinalInfra/ProyectoFinalInfra/netdata"
PODMAN_SOCKET="/run/podman/podman.sock"
CONTAINERS=("cont_mysql" "cont_apache" "cont_nginx" "phpmyadmin")

################################################################################
# Función: Log con colores
################################################################################
log_info() {
    echo -e "${GREEN}✅${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠️ ${NC} $1"
}

log_error() {
    echo -e "${RED}❌${NC} $1"
}

log_header() {
    echo ""
    echo "=========================================================="
    echo "🔧 $1"
    echo "=========================================================="
}

################################################################################
# 1) LIMPIEZA INICIAL
################################################################################
log_header "1) Limpiando infraestructura anterior"

# Detener Docker si está activo
if systemctl is-active --quiet docker; then
    log_warn "Docker activo. Deteniendo..."
    sudo docker stop $(sudo docker ps -q) 2>/dev/null || true
    sudo docker rm -f $(sudo docker ps -aq) 2>/dev/null || true
    sudo systemctl stop docker
    log_info "Docker detenido"
else
    log_info "Docker no está activo"
fi

# Limpiar Podman anterior
log_warn "Eliminando contenedores y volúmenes previos de Podman..."
sudo podman ps -a --format "{{.Names}}" | xargs -r sudo podman rm -f 2>/dev/null || true
sudo podman volume rm netdataconfig netdatalib netdatacache 2>/dev/null || true
log_info "Limpieza completada"

################################################################################
# 2) VOLÚMENES LVM
################################################################################
log_header "2) Activando volúmenes LVM"

sudo vgscan >/dev/null 2>&1 || true
sudo lvscan >/dev/null 2>&1 || true
sudo vgchange -ay >/dev/null 2>&1 || true

# Crear directorios
sudo mkdir -p /mnt/apache_vol /mnt/mysql_vol /mnt/nginx_vol

# Montar volúmenes
for vol in apache mysql nginx; do
    dev="/dev/vg_${vol}/lv_${vol}"
    mnt="/mnt/${vol}_vol"
    
    if ! sudo mountpoint -q "$mnt"; then
        sudo mount "$dev" "$mnt" 2>/dev/null || log_warn "No se pudo montar $mnt (puede estar ya montado)"
    fi
done

log_info "Volúmenes montados:"
lsblk | grep "vg_" || log_warn "No se encontraron volúmenes LVM"

################################################################################
# 3) PERMISOS
################################################################################
log_header "3) Configurando permisos de volúmenes"

sudo chown -R 33:33   /mnt/apache_vol   # Apache
sudo chown -R 999:999 /mnt/mysql_vol    # MySQL
sudo chown -R 101:101 /mnt/nginx_vol    # Nginx
sudo chmod -R 755 /mnt/apache_vol /mnt/mysql_vol /mnt/nginx_vol

log_info "Permisos aplicados"

################################################################################
# 4) RED INTERNA PODMAN
################################################################################
log_header "4) Creando red 'red_app' para Podman"

if ! sudo podman network inspect red_app >/dev/null 2>&1; then
    sudo podman network create red_app
    log_info "Red 'red_app' creada"
else
    log_info "Red 'red_app' ya existe"
fi

################################################################################
# 5) LIBERAR PUERTOS
################################################################################
log_header "5) Liberando puertos"

for port in 8080 8081 8082 3306 19999; do
    sudo fuser -k ${port}/tcp 2>/dev/null || true
done

log_info "Puertos liberados"

################################################################################
# 6) CONFIGURAR PODMAN SOCKET
################################################################################
log_header "6) Habilitando y configurando podman.socket"

sudo systemctl enable --now podman.socket 2>/dev/null || true

# Esperar a que el socket esté disponible
for i in {1..10}; do
    if [ -S "$PODMAN_SOCKET" ]; then
        log_info "Socket de Podman disponible"
        break
    fi
    sleep 1
done

if [ ! -S "$PODMAN_SOCKET" ]; then
    log_error "Socket de Podman no disponible después de 10 segundos"
    exit 1
fi

# Usar grupo podman en lugar de permisos 666
sudo usermod -aG podman $USER 2>/dev/null || true
sudo chmod 666 "$PODMAN_SOCKET"
log_info "Permisos de socket configurados"

################################################################################
# 7) CREAR CONTENEDORES
################################################################################
log_header "7) Creando contenedores Podman"

# MySQL
log_warn "Iniciando MySQL..."
sudo podman run -d --name cont_mysql \
    --network red_app \
    --restart unless-stopped \
    -e MYSQL_ROOT_PASSWORD=root \
    -e MYSQL_DATABASE=clientes \
    -v /mnt/mysql_vol:/var/lib/mysql:Z \
    docker.io/library/mysql_custom:latest

# Apache
log_warn "Iniciando Apache..."
sudo podman run -d --name cont_apache \
    --network red_app \
    --restart unless-stopped \
    -p 8080:80 \
    -v /mnt/apache_vol:/var/www/html:Z \
    docker.io/library/apache_custom:latest

# Nginx
log_warn "Iniciando Nginx..."
sudo podman run -d --name cont_nginx \
    --network red_app \
    --restart unless-stopped \
    -p 8081:80 \
    -v /mnt/nginx_vol:/usr/share/nginx/html:Z \
    docker.io/library/nginx_custom:latest

# phpMyAdmin
log_warn "Iniciando phpMyAdmin..."
sudo podman run -d --name phpmyadmin \
    --network red_app \
    --restart unless-stopped \
    -e PMA_HOST=cont_mysql \
    -e PMA_USER=root \
    -e PMA_PASSWORD=root \
    -p 8082:80 \
    docker.io/phpmyadmin/phpmyadmin:latest

# Esperar a que los contenedores estén listos
sleep 5
log_info "Contenedores creados"

################################################################################
# 8) CONFIGURAR PLUGINS NETDATA
################################################################################
log_header "8) Configurando plugins de Netdata"

# Crear directorios
sudo mkdir -p "$BASE_NETDATA/go.d"
sudo mkdir -p "$BASE_NETDATA/systemd"

# Configurar cgroups para Podman
sudo tee "$BASE_NETDATA/go.d/cgroups.conf" >/dev/null <<'EOF'
jobs:
  - name: podman-cgroups
    update_every: 1
    enable_cgroups: true
    autodetect: true
    cgroup_base: "/host/sys/fs/cgroup"
EOF

# Configurar plugin Podman
sudo tee "$BASE_NETDATA/go.d/podman.conf" >/dev/null <<'EOF'
update_every: 1
socket: /host/run/podman/podman.sock
containers:
  include:
    - ".*"
EOF

# Copiar configuraciones a Netdata
sudo mkdir -p /etc/netdata/go.d/
sudo cp "$BASE_NETDATA/go.d"/*.conf /etc/netdata/go.d/ 2>/dev/null || log_warn "No se copiaron configs de go.d"

log_info "Plugins configurados"

################################################################################
# 9) SERVICIO PARA PERMISOS DEL SOCKET
################################################################################
log_header "9) Creando servicio para permisos persistentes"

sudo tee /etc/systemd/system/podman-sock-perms.service >/dev/null <<'EOF'
[Unit]
Description=Fix Podman socket permissions at boot
After=podman.socket
Wants=podman.socket

[Service]
Type=oneshot
ExecStart=/bin/chmod 666 /run/podman/podman.sock
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now podman-sock-perms.service 2>/dev/null || true
log_info "Servicio de permisos creado"

################################################################################
# 10) INICIAR NETDATA
################################################################################
log_header "10) Iniciando Netdata"

# Eliminar si existe
sudo podman ps -a --format "{{.Names}}" | grep -q "^netdata$" && \
    sudo podman rm -f netdata >/dev/null 2>&1 || true

sudo podman run -d --name netdata \
    --network host \
    --cap-add SYS_PTRACE \
    --cap-add SYS_ADMIN \
    --security-opt apparmor=unconfined \
    -e DOCKER_HOST="/host/run/podman/podman.sock" \
    -v netdataconfig:/etc/netdata \
    -v netdatalib:/var/lib/netdata \
    -v netdatacache:/var/cache/netdata \
    -v /etc/passwd:/host/etc/passwd:ro \
    -v /etc/group:/host/etc/group:ro \
    -v /proc:/host/proc:ro \
    -v /sys:/host/sys:ro \
    -v /run/podman/podman.sock:/host/run/podman/podman.sock:ro \
    docker.io/netdata/netdata:latest

sleep 5
log_info "Netdata iniciado"

################################################################################
# 11) VERIFICACIONES FINALES
################################################################################
log_header "11) Verificaciones finales"

echo ""
echo "📦 Estado de contenedores:"
sudo podman ps

echo ""
echo "🔌 Verificando conectividad de red:"
sudo podman network inspect red_app | grep -A 50 '"Containers"' || log_warn "No se pudo verificar red"

echo ""
echo "📊 Verificando Netdata:"
if sudo podman ps | grep -q netdata; then
    log_info "Netdata está corriendo"
else
    log_error "Netdata no está corriendo"
fi

echo ""
echo "🔍 Logs de Netdata (últimas 20 líneas):"
sudo podman logs netdata 2>&1 | tail -20 || log_warn "No hay logs disponibles"

################################################################################
# 12) RESUMEN FINAL
################################################################################
log_header "¡ENTORNO COMPLETO LEVANTADO!"

cat <<EOF

📱 SERVICIOS DISPONIBLES:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🌐 Apache      → http://localhost:8080
  🌐 Nginx       → http://localhost:8081
  📊 phpMyAdmin  → http://localhost:8082
  🗄️  MySQL      → cont_mysql:3306 (en red: red_app)
  📈 Netdata     → http://localhost:19999
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 COMANDOS ÚTILES:
  Ver logs:           sudo podman logs <nombre-contenedor>
  Entrar al contenedor: sudo podman exec -it <nombre> bash
  Ver red:            sudo podman network inspect red_app
  Ver volúmenes:      sudo podman volume ls

🐛 SOLUCIÓN DE PROBLEMAS:
  Si Netdata no ve contenedores:
    sudo podman logs netdata | grep -i "docker\|podman\|cgroup"

  Si falla conectividad:
    sudo podman network inspect red_app
    sudo podman exec <contenedor> ping otro_contenedor

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Script completado exitosamente
EOF

