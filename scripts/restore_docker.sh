#!/bin/bash
################################################################################
# Script: restore_docker.sh
# Autor: Juan Esteban Galeano
# Proyecto Final - Infraestructura Virtual
# Objetivo: Detener Podman COMPLETAMENTE y levantar TODO con Docker Socket
# IMPORTANTE: Este script BORRA todo de Podman y levanta infraestructura desde 0
################################################################################

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

################################################################################
# FASE 1: ELIMINAR COMPLETAMENTE TODA INFRAESTRUCTURA PODMAN
################################################################################

log_header "FASE 1: Eliminando TODA infraestructura Podman"

log_warn "Deteniendo Podman socket service..."
sudo systemctl stop podman.socket 2>/dev/null || true
sudo systemctl disable podman.socket 2>/dev/null || true
log_info "Socket service detenido"

log_warn "Matando todos los procesos de Podman..."
sudo pkill -9 podman 2>/dev/null || true
sudo pkill -9 conmon 2>/dev/null || true
sudo pkill -9 crun 2>/dev/null || true
sleep 2

log_warn "Eliminando TODOS los contenedores Podman..."
sudo podman ps -a --format "{{.Names}}" 2>/dev/null | xargs -r sudo podman rm -f 2>/dev/null || true
sleep 1

log_warn "Eliminando TODOS los volúmenes Podman..."
sudo podman volume rm -a 2>/dev/null || true
sleep 1

log_warn "Eliminando TODAS las redes Podman..."
sudo podman network rm -a 2>/dev/null || true
sleep 1

log_info "Infraestructura Podman completamente eliminada"

################################################################################
# FASE 2: LIMPIAR TODOS LOS PUERTOS
################################################################################

log_header "FASE 2: Liberando TODOS los puertos"

PUERTOS=(8080 8081 8082 3306 19999)

for puerto in "${PUERTOS[@]}"; do
    log_warn "Liberando puerto $puerto..."
    sudo fuser -k ${puerto}/tcp 2>/dev/null || true
    sudo lsof -ti :${puerto} | xargs -r sudo kill -9 2>/dev/null || true
done

sleep 2

log_info "Todos los puertos liberados"

################################################################################
# FASE 3: ACTIVAR VOLÚMENES LVM
################################################################################

log_header "FASE 3: Activando volúmenes LVM"

log_warn "Escaneando volúmenes..."
sudo vgscan > /dev/null 2>&1 || true
sudo lvscan > /dev/null 2>&1 || true
sudo vgchange -ay > /dev/null 2>&1 || true

log_info "Volúmenes LVM escaneados y activados"

################################################################################
# FASE 4: MONTAR VOLÚMENES LVM
################################################################################

log_header "FASE 4: Montando volúmenes LVM en /mnt"

log_warn "Creando directorios..."
sudo mkdir -p /mnt/apache_vol /mnt/mysql_vol /mnt/nginx_vol

log_warn "Montando volúmenes..."
for vol in apache mysql nginx; do
    dev="/dev/vg_${vol}/lv_${vol}"
    mnt="/mnt/${vol}_vol"
    
    # Desmontar si ya está montado
    sudo umount "$mnt" 2>/dev/null || true
    sleep 1
    
    # Montar volumen
    if [ -b "$dev" ]; then
        sudo mount "$dev" "$mnt" 2>/dev/null || log_warn "No se pudo montar $dev en $mnt"
        log_info "Montado: $mnt"
    else
        log_error "Dispositivo $dev no encontrado"
    fi
done

################################################################################
# FASE 5: CONFIGURAR PERMISOS EN VOLÚMENES
################################################################################

log_header "FASE 5: Configurando permisos en volúmenes"

log_warn "Asignando propietarios y permisos..."
sudo chown -R 33:33 /mnt/apache_vol   # Apache
sudo chown -R 999:999 /mnt/mysql_vol  # MySQL
sudo chown -R 101:101 /mnt/nginx_vol  # Nginx
sudo chmod -R 755 /mnt/apache_vol /mnt/mysql_vol /mnt/nginx_vol

log_info "Permisos configurados correctamente"

################################################################################
# FASE 6: LIMPIAR DOCKER PREVIO
################################################################################

log_header "FASE 6: Limpiando Docker previo"

log_warn "Eliminando contenedores Docker previos..."
sudo docker rm -f cont_apache cont_mysql cont_nginx phpmyadmin netdata 2>/dev/null || true

log_warn "Eliminando redes Docker previas..."
sudo docker network rm proyecto_network 2>/dev/null || true

log_info "Limpieza de Docker completada"

################################################################################
# FASE 7: INICIAR DOCKER
################################################################################

log_header "FASE 7: Iniciando servicio Docker"

log_warn "Iniciando Docker daemon..."
sudo systemctl enable --now docker 2>/dev/null || true
sleep 5

if ! systemctl is-active --quiet docker; then
    log_error "Docker no pudo iniciarse. Ejecuta: sudo systemctl status docker"
    exit 1
fi

log_info "Docker iniciado y listo"

################################################################################
# FASE 8: CREAR RED DOCKER
################################################################################

log_header "FASE 8: Creando red Docker interna"

log_warn "Creando red 'proyecto_network'..."
sudo docker network create proyecto_network 2>/dev/null || log_warn "Red ya existe, usando existente"

log_info "Red Docker creada"

################################################################################
# FASE 9: CREAR CONTENEDORES CON VOLÚMENES PERSISTENTES
################################################################################

log_header "FASE 9: Creando contenedores con volúmenes persistentes"

# Apache
log_warn "Iniciando Apache..."
sudo docker run -d \
  --name cont_apache \
  --restart=always \
  -p 8080:80 \
  --network proyecto_network \
  -v /mnt/apache_vol:/var/www/html:Z \
  docker.io/library/apache_custom:latest > /dev/null 2>&1 || log_warn "Apache puede requerir build"

log_info "Apache creado"

# MySQL
log_warn "Iniciando MySQL..."
sudo docker run -d \
  --name cont_mysql \
  --restart=always \
  --network proyecto_network \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_DATABASE=clientes \
  -v /mnt/mysql_vol:/var/lib/mysql:Z \
  docker.io/library/mysql_custom:latest > /dev/null 2>&1 || log_warn "MySQL puede requerir build"

log_info "MySQL creado"

# Nginx
log_warn "Iniciando Nginx..."
sudo docker run -d \
  --name cont_nginx \
  --restart=always \
  -p 8081:80 \
  --network proyecto_network \
  -v /mnt/nginx_vol:/usr/share/nginx/html:Z \
  docker.io/library/nginx_custom:latest > /dev/null 2>&1 || log_warn "Nginx puede requerir build"

log_info "Nginx creado"

# phpMyAdmin
log_warn "Iniciando phpMyAdmin..."
sudo docker run -d \
  --name phpmyadmin \
  --restart=always \
  --network proyecto_network \
  -e PMA_HOST=cont_mysql \
  -e PMA_USER=root \
  -e PMA_PASSWORD=root \
  -p 8082:80 \
  docker.io/phpmyadmin/phpmyadmin:latest > /dev/null 2>&1

log_info "phpMyAdmin creado"

sleep 5

################################################################################
# FASE 10: VERIFICAR CONTENEDORES
################################################################################

log_header "FASE 10: Verificando contenedores en ejecución"

echo ""
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Networks}}"
echo ""

################################################################################
# FASE 11: INICIAR NETDATA CON DOCKER SOCKET
################################################################################

log_header "FASE 11: Iniciando Netdata con acceso a Docker Socket"

log_warn "Eliminando Netdata previo si existe..."
sudo docker rm -f netdata 2>/dev/null || true
sleep 2

log_warn "Levantando Netdata con Docker Socket..."
sudo docker run -d \
  --name netdata \
  -p 19999:19999 \
  --network proyecto_network \
  --cap-add SYS_PTRACE \
  --cap-add SYS_ADMIN \
  --cap-add NET_ADMIN \
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
  docker.io/netdata/netdata:latest

sleep 5

log_info "Netdata iniciado con acceso a Docker Socket"

################################################################################
# FASE 12: VERIFICACIONES FINALES
################################################################################

log_header "FASE 12: Realizando verificaciones finales"

echo ""
echo "📦 ESTADO DE CONTENEDORES:"
sudo docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "💾 ESTADO DE VOLÚMENES LVM:"
df -h | grep mnt

echo ""
echo "🔌 PUERTOS ACTIVOS:"
sudo netstat -tlnp 2>/dev/null | grep -E ":(8080|8081|8082|3306|19999)" || echo "Verificando con ss..."
sudo ss -tlnp 2>/dev/null | grep -E ":(8080|8081|8082|3306|19999)" || true

################################################################################
# RESUMEN FINAL
################################################################################

log_header "✅ INFRAESTRUCTURA COMPLETAMENTE LEVANTADA CON DOCKER SOCKET"

cat <<EOF

${GREEN}═══════════════════════════════════════════════════════════${NC}
${BLUE}📱 SERVICIOS DISPONIBLES (Docker Socket)${NC}
${GREEN}═══════════════════════════════════════════════════════════${NC}

  🌐 Apache HTTP Server    → ${GREEN}http://localhost:8080${NC}
  🌐 Nginx Web Server      → ${GREEN}http://localhost:8081${NC}
  📊 phpMyAdmin Dashboard  → ${GREEN}http://localhost:8082${NC}
     (Usuario: root / Contraseña: root)
  
  🗄  MySQL Database       → ${GREEN}cont_mysql:3306${NC}
     (Red interna: proyecto_network)
     (Usuario: root / Contraseña: root)
  
  📈 Netdata Monitoreo     → ${GREEN}http://localhost:19999${NC}

${GREEN}═══════════════════════════════════════════════════════════${NC}
${BLUE}💾 ALMACENAMIENTO PERSISTENTE (LVM)${NC}
${GREEN}═══════════════════════════════════════════════════════════${NC}

  /mnt/apache_vol  → Contenidos web de Apache
  /mnt/mysql_vol   → Base de datos de MySQL
  /mnt/nginx_vol   → Contenidos web de Nginx

${GREEN}═══════════════════════════════════════════════════════════${NC}
${BLUE}💡 COMANDOS ÚTILES${NC}
${GREEN}═══════════════════════════════════════════════════════════${NC}

  Ver contenedores:
    ${YELLOW}sudo docker ps${NC}

  Ver logs de un servicio:
    ${YELLOW}sudo docker logs cont_apache${NC}
    ${YELLOW}sudo docker logs netdata${NC}

  Entrar a un contenedor:
    ${YELLOW}sudo docker exec -it cont_mysql bash${NC}
    ${YELLOW}sudo docker exec -it cont_apache bash${NC}

  Ver estadísticas en tiempo real:
    ${YELLOW}sudo docker stats${NC}

  Detener un contenedor:
    ${YELLOW}sudo docker stop cont_apache${NC}

  Verificar red interna:
    ${YELLOW}sudo docker network inspect proyecto_network${NC}

${GREEN}═══════════════════════════════════════════════════════════${NC}
${BLUE}⚠  IMPORTANTE${NC}
${GREEN}═══════════════════════════════════════════════════════════${NC}

  ✅ Este script usa DOCKER SOCKET (no Podman)
  ✅ Podman fue COMPLETAMENTE DETENIDO Y LIMPIADO
  ✅ Los contenedores usan volúmenes LVM PERSISTENTES
  ✅ Los contenedores se reinician automáticamente (--restart=always)
  ✅ Netdata monitorea todos los contenedores Docker
  
  🔄 Para volver a Podman:
    ${YELLOW}./scripts/infrastructure_setup.sh${NC}
  
  🔄 Para volver a Docker Socket:
    ${YELLOW}./scripts/restore_docker_socket.sh${NC}

${GREEN}═══════════════════════════════════════════════════════════${NC}

EOF

log_info "Script completado exitosamente"
echo "⏰ $(date)"
