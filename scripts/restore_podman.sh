#!/bin/bash
################################################################################
# Script: restore_podman.sh
# Autor: Juan Esteban Galeano, Mariana Pineda, Santiago Rodas
# Proyecto Final - Infraestructura Virtual
# Objetivo: Cambiar de Docker a Podman + Netdata
# Versión: 3.1 (CORREGIDA)
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
NC='\033[0m'

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
    echo -e "${YELLOW}⚠ ${NC} $1"
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
# FASE 1: LIMPIEZA Y TRANSICIÓN DOCKER → PODMAN
################################################################################

log_header "FASE 1: Transición de Docker a Podman"

# Detener Docker COMPLETAMENTE
log_step "Deteniendo Docker..."
if systemctl is-active --quiet docker 2>/dev/null; then
    log_warn "Docker activo. Deteniendo todos los contenedores..."
    sudo docker ps -q | xargs -r sudo docker stop 2>/dev/null || true
    sudo docker ps -aq | xargs -r sudo docker rm -f 2>/dev/null || true
    sudo systemctl stop docker
    sudo systemctl stop docker.socket 2>/dev/null || true
    log_info "Docker completamente detenido"
else
    log_info "Docker ya está detenido"
fi

# Limpiar Podman anterior
log_step "Limpiando instalación previa de Podman..."
sudo podman stop ${CONTAINERS[@]} netdata 2>/dev/null || true
sudo podman rm -f ${CONTAINERS[@]} netdata 2>/dev/null || true
sudo podman volume rm netdata_config netdata_lib netdata_cache 2>/dev/null || true

log_info "Transición completada"

################################################################################
# FASE 2: VERIFICAR/IMPORTAR IMÁGENES CUSTOM
################################################################################

log_header "FASE 2: Verificando imágenes custom en Podman"

CUSTOM_IMAGES=("mysql_custom" "apache_custom" "nginx_custom")

for img in "${CUSTOM_IMAGES[@]}"; do
    log_step "Verificando imagen: $img"
    
    if ! sudo podman image exists localhost/$img:latest 2>/dev/null; then
        log_warn "$img no encontrada en Podman. Intentando importar desde Docker..."
        
        if sudo docker image inspect $img:latest >/dev/null 2>&1; then
            log_step "Exportando $img desde Docker..."
            sudo docker save -o /tmp/${img}.tar $img:latest
            
            log_step "Importando $img a Podman..."
            sudo podman load -i /tmp/${img}.tar
            sudo podman tag $img:latest localhost/$img:latest
            rm /tmp/${img}.tar
            
            log_info "$img importada exitosamente"
        else
            log_error "$img no encontrada. Construye la imagen primero."
            exit 1
        fi
    else
        log_info "$img ya existe en Podman"
    fi
done

log_info "Todas las imágenes disponibles"

################################################################################
# FASE 3: CONFIGURACIÓN DE VOLÚMENES LVM
################################################################################

log_header "FASE 3: Configurando volúmenes LVM"

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
        sudo mount "$dev" "$mnt" 2>/dev/null || log_warn "Ya montado: $mnt"
    fi
done

# Limpiar volumen MySQL
log_step "Verificando volumen MySQL..."
if [ "$(ls -A /mnt/mysql_vol 2>/dev/null)" ]; then
    log_warn "Limpiando datos antiguos de MySQL..."
    sudo rm -rf /mnt/mysql_vol/* 2>/dev/null || true
    log_info "Volumen MySQL limpio"
fi

log_info "Volúmenes LVM listos"

################################################################################
# FASE 4: CONFIGURACIÓN DE PERMISOS
################################################################################

log_header "FASE 4: Configurando permisos"

log_step "Asignando propietarios..."
sudo chown -R 33:33   /mnt/apache_vol
sudo chown -R 999:999 /mnt/mysql_vol
sudo chown -R 101:101 /mnt/nginx_vol

log_step "Asignando permisos..."
sudo chmod -R 755 /mnt/apache_vol /mnt/mysql_vol /mnt/nginx_vol

log_info "Permisos aplicados"

################################################################################
# FASE 5: CONFIGURACIÓN DE RED
################################################################################

log_header "FASE 5: Configurando red interna"

log_step "Eliminando red anterior..."
sudo podman network rm red_app 2>/dev/null || true

log_step "Creando red 'red_app'..."
sudo podman network create red_app
log_info "Red 'red_app' creada"

################################################################################
# FASE 6: LIBERACIÓN DE PUERTOS
################################################################################

log_header "FASE 6: Liberando puertos"

log_step "Limpiando puertos: ${PORTS[@]}"
for port in "${PORTS[@]}"; do
    sudo fuser -k ${port}/tcp 2>/dev/null || true
done
sleep 2

log_info "Puertos liberados"
################################################################################
# FASE 7: CONFIGURACIÓN DE PODMAN SOCKET (SOLUCIÓN DEFINITIVA)
################################################################################

log_header "FASE 7: Configurando podman.socket"

# Limpiar completamente
log_step "Limpiando servicios y sockets previos..."
sudo systemctl stop podman.socket podman.service podman-api.service 2>/dev/null || true
sudo systemctl disable podman-api.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/podman-api.service 2>/dev/null || true
sudo systemctl daemon-reload
sleep 2

# Limpiar directorio y socket
sudo rm -rf /run/podman 2>/dev/null || true
sudo killall -9 podman 2>/dev/null || true
sleep 1

# CREAR EL DIRECTORIO PRIMERO CON PERMISOS CORRECTOS
log_step "Creando directorio /run/podman con permisos..."
sudo mkdir -p /run/podman
sudo chmod 755 /run/podman
sudo chown root:root /run/podman

# Verificar que el directorio existe
if [ ! -d /run/podman ]; then
    log_error "No se pudo crear /run/podman"
    exit 1
fi
log_info "Directorio /run/podman creado correctamente"

# OPCIÓN 1: Intentar con systemd (método preferido)
log_step "Método 1: Intentando con systemd..."
sudo systemctl reset-failed podman.socket 2>/dev/null || true

if sudo systemctl start podman.socket 2>&1; then
    sleep 3
    
    if systemctl is-active --quiet podman.socket && [ -S "$PODMAN_SOCKET" ]; then
        log_info "✓ Socket iniciado con systemd"
        sudo chmod 666 "$PODMAN_SOCKET"
        log_info "Socket configurado: $PODMAN_SOCKET"
    else
        log_warn "systemd no creó el socket correctamente"
        sudo systemctl stop podman.socket 2>/dev/null || true
    fi
fi

# OPCIÓN 2: Si systemd falló, usar servicio manual
if [ ! -S "$PODMAN_SOCKET" ]; then
    log_warn "Método 2: Creando socket manualmente..."
    
    # Iniciar servicio Podman en background
    log_step "Iniciando servicio Podman API..."
    nohup sudo podman system service --time=0 unix:///run/podman/podman.sock >/tmp/podman-service.log 2>&1 &
    PODMAN_PID=$!
    
    log_step "Esperando creación del socket..."
    for i in {1..20}; do
        if [ -S "$PODMAN_SOCKET" ]; then
            log_info "✓ Socket creado en intento $i/20"
            sudo chmod 666 "$PODMAN_SOCKET"
            break
        fi
        
        if [ $i -eq 20 ]; then
            log_error "Socket no se creó después de 40 segundos"
            log_error "Logs de Podman:"
            cat /tmp/podman-service.log 2>/dev/null || echo "Sin logs"
            kill $PODMAN_PID 2>/dev/null || true
            exit 1
        fi
        
        sleep 2
    done
    
    # Crear servicio systemd permanente
    log_step "Creando servicio systemd permanente..."
    sudo tee /etc/systemd/system/podman-api.service >/dev/null <<'EOF'
[Unit]
Description=Podman API Socket Service
After=network.target

[Service]
Type=simple
ExecStartPre=/bin/mkdir -p /run/podman
ExecStartPre=/bin/chmod 755 /run/podman
ExecStart=/usr/bin/podman system service --time=0 unix:///run/podman/podman.sock
ExecStartPost=/bin/sleep 2
ExecStartPost=/bin/chmod 666 /run/podman/podman.sock
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable podman-api.service 2>/dev/null || true
    
    log_info "Servicio Podman API creado y habilitado"
fi

# Verificación final del socket
log_step "Verificación final..."
if [ ! -S "$PODMAN_SOCKET" ]; then
    log_error "FALLO: Socket no disponible"
    log_error "Contenido de /run/podman/:"
    ls -la /run/podman/ 2>&1 || echo "Directorio no existe"
    log_error "Estado de servicios:"
    sudo systemctl status podman.socket --no-pager 2>&1 || true
    sudo systemctl status podman-api.service --no-pager 2>&1 || true
    exit 1
fi

log_info "✓ Socket disponible: $PODMAN_SOCKET"

# Verificar permisos
log_step "Verificando permisos..."
ls -lh "$PODMAN_SOCKET"

# Probar funcionalidad
log_step "Probando funcionalidad del socket..."
if sudo podman --remote version >/dev/null 2>&1; then
    log_info "✓ Socket funcional (test con podman)"
else
    log_warn "Socket existe pero podman --remote falló (puede funcionar con Netdata)"
fi

log_info "Configuración de socket completada"

################################################################################
# FASE 8: CONFIGURACIÓN DE NETDATA
################################################################################

log_header "FASE 8: Preparando configuración de Netdata"

log_step "Creando estructura..."
mkdir -p "$BASE_NETDATA/go.d"
mkdir -p "$BASE_NETDATA/etc"

# Collector Podman
log_step "Creando podman.conf..."
cat > "$BASE_NETDATA/go.d/podman.conf" <<'EOF'
jobs:
  - name: local
    url: unix:///host/run/podman/podman.sock
    collect_container_size: yes
    timeout: 5
EOF

# Collector cgroups
log_step "Creando cgroups.conf..."
cat > "$BASE_NETDATA/go.d/cgroups.conf" <<'EOF'
jobs:
  - name: podman-cgroups
    update_every: 1
    enable_cgroups: true
    autodetect: true
    cgroup_base: "/host/sys/fs/cgroup"
EOF

# Configuración global
log_step "Creando netdata.conf..."
cat > "$BASE_NETDATA/etc/netdata.conf" <<'EOF'
[global]
    hostname = ubuntu-clase
    update_every = 1
    port = 19999

[plugins]
    go.d = yes

[go.d plugin]
    update_every = 1
EOF

log_info "Configuración de Netdata creada"

################################################################################
# FASE 9: CREACIÓN DE CONTENEDORES
################################################################################

log_header "FASE 9: Creando contenedores Podman"

# MySQL
log_step "Iniciando MySQL..."
sudo podman run -d --name cont_mysql \
    --network red_app \
    --restart unless-stopped \
    -e MYSQL_ROOT_PASSWORD=root \
    -e MYSQL_DATABASE=clientes \
    -v /mnt/mysql_vol:/var/lib/mysql:Z \
    localhost/mysql_custom:latest
log_info "MySQL iniciado"

# Esperar MySQL
log_step "Esperando a que MySQL esté listo..."
sleep 10
for i in {1..20}; do
    if sudo podman exec cont_mysql mysqladmin ping --silent 2>/dev/null; then
        log_info "MySQL listo (intento $i/20)"
        break
    fi
    log_warn "Esperando MySQL... $i/20"
    sleep 2
done

# Apache
log_step "Iniciando Apache..."
sudo podman run -d --name cont_apache \
    --network red_app \
    --restart unless-stopped \
    -p 8080:80 \
    -v /mnt/apache_vol:/var/www/html:Z \
    localhost/apache_custom:latest
log_info "Apache iniciado"

# Nginx
log_step "Iniciando Nginx..."
sudo podman run -d --name cont_nginx \
    --network red_app \
    --restart unless-stopped \
    -p 8081:80 \
    -v /mnt/nginx_vol:/usr/share/nginx/html:Z \
    localhost/nginx_custom:latest
log_info "Nginx iniciado"

# phpMyAdmin
log_step "Iniciando phpMyAdmin..."
sudo podman run -d --name phpmyadmin \
    --network red_app \
    --restart unless-stopped \
    -e PMA_HOST=cont_mysql \
    -e PMA_USER=root \
    -e PMA_PASSWORD=root \
    -e PMA_ARBITRARY=1 \
    -p 8082:80 \
    docker.io/phpmyadmin/phpmyadmin:latest
log_info "phpMyAdmin iniciado"

sleep 5
log_info "Contenedores en ejecución"

################################################################################
# FASE 10: SERVICIO DE PERMISOS PERSISTENTES
################################################################################

log_header "FASE 10: Configurando servicio de permisos"

log_step "Creando servicio systemd..."
sudo tee /etc/systemd/system/podman-sock-perms.service >/dev/null <<'EOF'
[Unit]
Description=Fix Podman socket permissions
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

log_info "Servicio creado"

################################################################################
# FASE 11: VOLÚMENES DE NETDATA
################################################################################

log_header "FASE 11: Creando volúmenes de Netdata"

log_step "Creando volúmenes..."
sudo podman volume create netdata_config 2>/dev/null || true
sudo podman volume create netdata_lib 2>/dev/null || true
sudo podman volume create netdata_cache 2>/dev/null || true

log_info "Volúmenes listos"

################################################################################
# FASE 12: INICIALIZACIÓN DE NETDATA
################################################################################

log_header "FASE 12: Iniciando Netdata"

log_step "Limpiando instalación previa..."
sudo podman rm -f netdata >/dev/null 2>&1 || true
sudo fuser -k 19999/tcp 2>/dev/null || true
sleep 2

log_step "Iniciando contenedor..."
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

log_step "Esperando inicialización (15s)..."
sleep 15

if ! sudo podman ps | grep -q netdata; then
    log_error "Netdata no pudo iniciar"
    sudo podman logs netdata 2>&1 | tail -30
    exit 1
fi

log_info "Netdata iniciado"

# Aplicar configuración personalizada
log_step "Aplicando configuración personalizada..."
sudo podman exec netdata mkdir -p /etc/netdata/go.d 2>/dev/null || true

for config in podman.conf cgroups.conf; do
    if [ -f "$BASE_NETDATA/go.d/$config" ]; then
        sudo podman cp "$BASE_NETDATA/go.d/$config" netdata:/etc/netdata/go.d/
        log_info "$config copiado"
    fi
done

log_step "Reiniciando Netdata..."
sudo podman restart netdata
sleep 10

if curl -s -f http://localhost:19999 >/dev/null 2>&1; then
    log_info "✓ Netdata responde en http://localhost:19999"
else
    log_warn "Netdata aún iniciando..."
fi

################################################################################
# FASE 13: VERIFICACIONES FINALES
################################################################################

log_header "FASE 13: Verificaciones finales"

echo ""
log_step "Estado de contenedores:"
sudo podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
log_step "Redes:"
sudo podman network ls

echo ""
log_step "Puertos escuchando:"
sudo ss -tlnp 2>/dev/null | grep -E ":(8080|8081|8082|19999)" || true

echo ""
log_step "Conectividad phpMyAdmin → MySQL:"
sudo podman exec phpmyadmin ping -c 2 cont_mysql 2>/dev/null && \
    log_info "✓ Conectividad OK" || log_warn "⚠ Problema de conectividad"

################################################################################
# RESUMEN FINAL
################################################################################

log_header "¡INFRAESTRUCTURA CON PODMAN LEVANTADA!"

cat <<EOF

${BLUE}📱 SERVICIOS DISPONIBLES:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
  🌐 Apache      → ${GREEN}http://localhost:8080${NC}
  🌐 Nginx       → ${GREEN}http://localhost:8081${NC}
  📊 phpMyAdmin  → ${GREEN}http://localhost:8082${NC}
  🗄  MySQL      → ${GREEN}cont_mysql:3306${NC} (red: red_app)
  📈 Netdata     → ${GREEN}http://localhost:19999${NC}
${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

${BLUE}💡 COMANDOS ÚTILES:${NC}
  Ver logs:            ${GREEN}sudo podman logs <contenedor>${NC}
  Entrar a contenedor: ${GREEN}sudo podman exec -it <nombre> bash${NC}
  Reiniciar Netdata:   ${GREEN}sudo podman restart netdata${NC}
  Ver estado:          ${GREEN}sudo podman ps -a${NC}

${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${GREEN}✅ Transición a Podman completada${NC}
⏰ $(date)
${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

EOF
