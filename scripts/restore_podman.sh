#!/bin/bash
################################################################################
# Script: restore_podman.sh
# Autor: Juan Esteban Galeano
# Proyecto Final - Infraestructura Virtual
# Objetivo: Levantar toda la infraestructura (Podman + Netdata + LVM)
# Versión: 3.0 (DEFINITIVA - Corregida)
################################################################################

set -e

################################################################################
# CONFIGURACIÓN INICIAL
################################################################################

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables de rutas y configuración
BASE_NETDATA="${HOME}/ProyectoFinalInfra/ProyectoFinalInfra/netdata"
PODMAN_SOCKET="/run/podman/podman.sock"
CONTAINERS=("cont_mysql" "cont_apache" "cont_nginx" "phpmyadmin")
PORTS=(8080 8081 8082 3306 19999)

################################################################################
# FUNCIONES DE UTILIDAD
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
    echo -e "${BLUE}=========================================================="
    echo "🔧 $1"
    echo "==========================================================${NC}"
}

log_step() {
    echo -e "${BLUE}→${NC} $1"
}

################################################################################
# FASE 1: LIMPIEZA INICIAL
################################################################################

log_header "FASE 1: Limpiando infraestructura anterior"

# Detener Docker si está activo
log_step "Verificando Docker..."
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
log_step "Limpiando Podman..."
sudo podman ps -a --format "{{.Names}}" | xargs -r sudo podman rm -f 2>/dev/null || true
sudo podman volume rm netdata_config netdata_lib netdata_cache 2>/dev/null || true
log_info "Limpieza completada"

################################################################################
# FASE 2: CONFIGURACIÓN DE VOLÚMENES LVM
################################################################################

log_header "FASE 2: Configurando volúmenes LVM"

log_step "Escaneando volúmenes..."
sudo vgscan >/dev/null 2>&1 || true
sudo lvscan >/dev/null 2>&1 || true
sudo vgchange -ay >/dev/null 2>&1 || true

log_step "Creando directorios..."
sudo mkdir -p /mnt/apache_vol /mnt/mysql_vol /mnt/nginx_vol

log_step "Montando volúmenes..."
for vol in apache mysql nginx; do
    dev="/dev/vg_${vol}/lv_${vol}"
    mnt="/mnt/${vol}_vol"
    
    if ! sudo mountpoint -q "$mnt"; then
        sudo mount "$dev" "$mnt" 2>/dev/null || log_warn "No se pudo montar $mnt (puede estar ya montado)"
    fi
done

log_info "Volúmenes LVM activos:"
lsblk | grep "vg_" || log_warn "No se encontraron volúmenes LVM"

################################################################################
# FASE 3: CONFIGURACIÓN DE PERMISOS
################################################################################

log_header "FASE 3: Configurando permisos de volúmenes"

log_step "Asignando propietarios..."
sudo chown -R 33:33   /mnt/apache_vol   # Apache
sudo chown -R 999:999 /mnt/mysql_vol    # MySQL
sudo chown -R 101:101 /mnt/nginx_vol    # Nginx

log_step "Asignando permisos..."
sudo chmod -R 755 /mnt/apache_vol /mnt/mysql_vol /mnt/nginx_vol

log_info "Permisos aplicados correctamente"

################################################################################
# FASE 4: CONFIGURACIÓN DE RED
################################################################################

log_header "FASE 4: Configurando red interna"

log_step "Creando red 'red_app'..."
if ! sudo podman network inspect red_app >/dev/null 2>&1; then
    sudo podman network create red_app
    log_info "Red 'red_app' creada"
else
    log_info "Red 'red_app' ya existe"
fi

################################################################################
# FASE 5: LIBERACIÓN DE PUERTOS
################################################################################

log_header "FASE 5: Liberando puertos"

log_step "Limpiando puertos: ${PORTS[@]}"
for port in "${PORTS[@]}"; do
    sudo fuser -k ${port}/tcp 2>/dev/null || true
done

log_info "Puertos liberados"

################################################################################
# FASE 6: CONFIGURACIÓN DE PODMAN SOCKET
################################################################################

log_header "FASE 6: Configurando podman.socket"

log_step "Habilitando podman.socket..."
sudo systemctl enable --now podman.socket 2>/dev/null || true

log_step "Esperando disponibilidad del socket..."
for i in {1..10}; do
    if [ -S "$PODMAN_SOCKET" ]; then
        log_info "Socket de Podman disponible (intento $i/10)"
        break
    fi
    log_warn "Intento $i/10..."
    sleep 1
done

if [ ! -S "$PODMAN_SOCKET" ]; then
    log_error "Socket de Podman no disponible después de 10 segundos"
    exit 1
fi

log_step "Configurando permisos del socket..."
sudo usermod -aG podman $USER 2>/dev/null || true
sudo chmod 666 "$PODMAN_SOCKET"

log_info "Socket de Podman configurado"

################################################################################
# FASE 7: PREPARACIÓN DE CONFIGURACIÓN NETDATA
################################################################################

log_header "FASE 7: Preparando configuración de Netdata"

log_step "Creando estructura de directorios..."
sudo mkdir -p "$BASE_NETDATA/go.d"
sudo mkdir -p "$BASE_NETDATA/etc"
sudo mkdir -p "$BASE_NETDATA/systemd"

log_info "Directorios creados en: $BASE_NETDATA"

################################################################################
# FASE 8: CONFIGURACIÓN DE COLLECTORS
################################################################################

log_header "FASE 8: Configurando collectors de Netdata"

# Collector Podman
log_step "Creando podman.conf..."
sudo tee "$BASE_NETDATA/go.d/podman.conf" > /dev/null <<'EOF'
jobs:
  - name: local
    url: unix:///host/run/podman/podman.sock
    collect_container_size: yes
    timeout: 5
EOF
log_info "podman.conf creado"

# Collector cgroups
log_step "Creando cgroups.conf..."
sudo tee "$BASE_NETDATA/go.d/cgroups.conf" > /dev/null <<'EOF'
jobs:
  - name: podman-cgroups
    update_every: 1
    enable_cgroups: true
    autodetect: true
    cgroup_base: "/host/sys/fs/cgroup"
EOF
log_info "cgroups.conf creado"

# Configuración global de Netdata
log_step "Creando netdata.conf..."
sudo tee "$BASE_NETDATA/etc/netdata.conf" > /dev/null <<'EOF'
[global]
    hostname = ubuntu-clase
    update_every = 1
    port = 19999
    dbengine disk space = 256
    memory deduplication (ksm) = yes

[plugins]
    go.d = yes
    python = yes

[go.d plugin]
    update_every = 1

[health]
    enabled = yes
EOF
log_info "netdata.conf creado"

################################################################################
# FASE 9: CREACIÓN DE CONTENEDORES
################################################################################

log_header "FASE 9: Creando contenedores Podman"

log_step "Iniciando MySQL..."
sudo podman run -d --name cont_mysql \
    --network red_app \
    --restart unless-stopped \
    -e MYSQL_ROOT_PASSWORD=root \
    -e MYSQL_DATABASE=clientes \
    -v /mnt/mysql_vol:/var/lib/mysql:Z \
    docker.io/library/mysql_custom:latest
log_info "MySQL iniciado"

log_step "Iniciando Apache..."
sudo podman run -d --name cont_apache \
    --network red_app \
    --restart unless-stopped \
    -p 8080:80 \
    -v /mnt/apache_vol:/var/www/html:Z \
    docker.io/library/apache_custom:latest
log_info "Apache iniciado"

log_step "Iniciando Nginx..."
sudo podman run -d --name cont_nginx \
    --network red_app \
    --restart unless-stopped \
    -p 8081:80 \
    -v /mnt/nginx_vol:/usr/share/nginx/html:Z \
    docker.io/library/nginx_custom:latest
log_info "Nginx iniciado"

log_step "Iniciando phpMyAdmin..."
sudo podman run -d --name phpmyadmin \
    --network red_app \
    --restart unless-stopped \
    -e PMA_HOST=cont_mysql \
    -e PMA_USER=root \
    -e PMA_PASSWORD=root \
    -p 8082:80 \
    docker.io/phpmyadmin/phpmyadmin:latest
log_info "phpMyAdmin iniciado"

log_step "Esperando a que los contenedores estén listos..."
sleep 5
log_info "Contenedores creados y en ejecución"

################################################################################
# FASE 10: SERVICIO DE PERMISOS PERSISTENTES
################################################################################

log_header "FASE 10: Configurando servicio de permisos persistentes"

log_step "Creando servicio systemd..."
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

log_step "Activando servicio..."
sudo systemctl daemon-reload
sudo systemctl enable --now podman-sock-perms.service 2>/dev/null || true

log_info "Servicio de permisos creado"

################################################################################
# FASE 11: VOLÚMENES DE NETDATA
################################################################################

log_header "FASE 11: Creando volúmenes de Netdata"

log_step "Creando volúmenes..."
sudo podman volume create netdata_config 2>/dev/null || log_warn "netdata_config ya existe"
sudo podman volume create netdata_lib 2>/dev/null || log_warn "netdata_lib ya existe"
sudo podman volume create netdata_cache 2>/dev/null || log_warn "netdata_cache ya existe"

log_info "Volúmenes de Netdata listos"

################################################################################
# FASE 12: SINCRONIZACIÓN DE CONFIGURACIÓN
################################################################################

log_header "FASE 12: Sincronizando configuración de Netdata"

log_step "Copiando archivos a /etc/netdata..."
sudo mkdir -p /etc/netdata/go.d
sudo cp "$BASE_NETDATA/go.d"/*.conf /etc/netdata/go.d/ 2>/dev/null || log_warn "go.d configs"

if [ -f "$BASE_NETDATA/etc/netdata.conf" ]; then
    sudo cp "$BASE_NETDATA/etc/netdata.conf" /etc/netdata/netdata.conf 2>/dev/null || log_warn "netdata.conf"
fi

log_info "Configuración sincronizada"

################################################################################
# FASE 13: INICIALIZACIÓN DE NETDATA (VERSIÓN DEFINITIVA)
################################################################################

log_header "FASE 13: Iniciando Netdata"

# Limpiar contenedores previos
log_step "Limpiando instalación previa..."
sudo podman ps -a --format "{{.Names}}" | grep -q "^netdata$" && \
    sudo podman rm -f netdata >/dev/null 2>&1 || true
sudo fuser -k 19999/tcp 2>/dev/null || true

# Iniciar Netdata SIN montar configuración personalizada
log_step "Iniciando contenedor base..."
sudo podman run -d --name netdata \
    --hostname="ubuntu-clase" \
    --network host \
    --pid host \
    --privileged \
    -e DOCKER_HOST="/host/run/podman/podman.sock" \
    -e NETDATA_LISTENER_PORT=19999 \
    -v netdata_config:/etc/netdata \
    -v netdata_lib:/var/lib/netdata \
    -v netdata_cache:/var/cache/netdata \
    -v /etc/passwd:/host/etc/passwd:ro \
    -v /etc/group:/host/etc/group:ro \
    -v /proc:/host/proc:ro \
    -v /sys:/host/sys:ro \
    -v /run/podman/podman.sock:/host/run/podman/podman.sock:ro \
    --restart unless-stopped \
    docker.io/netdata/netdata:latest

# Esperar inicialización
log_step "Esperando inicialización (15 segundos)..."
sleep 15

# Verificar que está corriendo
if ! sudo podman ps | grep -q netdata; then
    log_error "Netdata no pudo iniciar"
    sudo podman logs netdata 2>&1 | tail -30
    exit 1
fi
log_info "Netdata iniciado correctamente"

# Copiar configuraciones personalizadas
log_step "Aplicando configuración personalizada..."
sudo podman exec netdata mkdir -p /etc/netdata/go.d 2>/dev/null || true

for config_file in podman.conf cgroups.conf; do
    if [ -f "$BASE_NETDATA/go.d/$config_file" ]; then
        sudo podman cp "$BASE_NETDATA/go.d/$config_file" netdata:/etc/netdata/go.d/
        log_info "$config_file → copiado"
    fi
done

# Reiniciar para aplicar configuración
log_step "Reiniciando Netdata..."
sudo podman restart netdata
sleep 10

# Validación final
log_step "Validando acceso HTTP..."
if curl -s -f http://localhost:19999 >/dev/null 2>&1; then
    log_info "✓ Netdata responde en http://localhost:19999"
else
    log_warn "Netdata aún no responde HTTP (puede tomar unos segundos más)"
fi

log_info "Configuración de Netdata completada"

################################################################################
# FASE 14: VERIFICACIONES FINALES
################################################################################

log_header "FASE 14: Realizando verificaciones finales"

echo ""
log_step "Estado de contenedores:"
sudo podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
log_step "Redes disponibles:"
sudo podman network ls

echo ""
log_step "Puertos escuchando:"
sudo ss -tlnp 2>/dev/null | grep -E ":(8080|8081|8082|3306|19999)" || echo "  No se encontraron puertos"

echo ""
log_step "Logs de Netdata (últimas 15 líneas):"
sudo podman logs netdata 2>&1 | tail -15

log_info "Verificaciones completadas"

################################################################################
# FASE 15: RESUMEN FINAL Y PRÓXIMOS PASOS
################################################################################

log_header "¡INFRAESTRUCTURA COMPLETAMENTE LEVANTADA!"

cat <<EOF

${BLUE}📱 SERVICIOS DISPONIBLES:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
  🌐 Apache      → ${GREEN}http://localhost:8080${NC}
  🌐 Nginx       → ${GREEN}http://localhost:8081${NC}
  📊 phpMyAdmin  → ${GREEN}http://localhost:8082${NC}
  🗄️  MySQL      → ${GREEN}cont_mysql:3306${NC} (red: red_app)
  📈 Netdata     → ${GREEN}http://localhost:19999${NC}

${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${GREEN}✅ Script completado exitosamente${NC}
⏰ $(date)
${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

EOF
