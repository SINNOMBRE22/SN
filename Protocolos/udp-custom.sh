#!/bin/bash
set -uo pipefail

# =========================================================
# UDP Custom Manager - SINNOMBRE
# Menú profesional con banner UDP Custom
# =========================================================

# -------------------------------
# Colores ANSI
# -------------------------------
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
M='\033[0;35m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'

# -------------------------------
# Rutas y configuración
# -------------------------------
CONFIG_DIR="/root/udp"
CONFIG_FILE="$CONFIG_DIR/config.json"
LOG_FILE="/var/log/udp-custom.log"
SERVICE_NAME="udp-custom"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
UDP_BIN="$CONFIG_DIR/udp-custom"

DEFAULT_UDP_PORT=36712
DEFAULT_PORT_RANGE="1-65535"

# -------------------------------
# Funciones mejoradas
# -------------------------------
get_public_ip() {
    curl -fsS --max-time 2 ifconfig.me 2>/dev/null \
    || curl -fsS --max-time 2 ipinfo.io/ip 2>/dev/null \
    || echo "No disponible"
}

get_service_status() {
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo "ACTIVO"
    else
        echo "INACTIVO"
    fi
}

count_ssh_users() {
    ls -1d /home/* 2>/dev/null | grep -v '/home/lost+found' | wc -l
}

count_udp_connections() {
    local port
    port="$(get_udp_port)"

    # Buscar conexiones UDP en el puerto especificado
    # Esta versión busca tanto udp-custom como badvpn-udpgw
    ss -u -a 2>/dev/null | grep -E ":$port\b" | wc -l
}

get_udp_process() {
    local port
    port="$(get_udp_port)"

    # Verificar qué proceso está usando el puerto
    if ss -ulpn 2>/dev/null | grep -q ":$port\b"; then
        # Buscar el nombre del proceso
        local process_info
        process_info=$(ss -ulpn 2>/dev/null | grep ":$port\b" | awk '{print $6}')

        # Extraer nombre del proceso
        if echo "$process_info" | grep -q "badvpn-udpgw"; then
            echo "badvpn-udpgw"
        elif echo "$process_info" | grep -q "udp-custom"; then
            echo "udp-custom"
        elif echo "$process_info" | grep -q "udp"; then
            echo "udp-custom/badvpn"
        else
            echo "desconocido"
        fi
    else
        echo "ninguno"
    fi
}

is_udp_installed() {
    # Verificar si UDP-Custom está instalado
    [[ -x "$UDP_BIN" ]] && [[ -f "$CONFIG_FILE" ]] && [[ -f "$SERVICE_FILE" ]]
}

get_udp_port() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # Intentar leer el puerto desde config.json
        local port
        port=$(jq -r '.listen // empty' "$CONFIG_FILE" 2>/dev/null | sed 's/://')

        if [[ -n "$port" ]] && [[ "$port" != "null" ]]; then
            echo "$port"
            return
        fi
    fi

    # Valor por defecto
    echo "$DEFAULT_UDP_PORT"
}

get_port_range() {
    if [[ -f "$CONFIG_FILE" ]]; then
        local range
        range=$(jq -r '.port_range // empty' "$CONFIG_FILE" 2>/dev/null)

        if [[ -n "$range" ]] && [[ "$range" != "null" ]]; then
            echo "$range"
            return
        fi
    fi

    echo "$DEFAULT_PORT_RANGE"
}

read_port() {
    while true; do
        read -p "Ingrese puerto UDP (default $DEFAULT_UDP_PORT): " user_port

        # Si está vacío, usar default
        if [[ -z "$user_port" ]]; then
            echo "$DEFAULT_UDP_PORT"
            return
        fi

        # Validar que sea un número válido
        if [[ "$user_port" =~ ^[0-9]+$ ]] && (( user_port >= 1 && user_port <= 65535 )); then
            echo "$user_port"
            return
        else
            echo -e "${R}Error: Puerto inválido. Debe ser entre 1 y 65535${N}"
        fi
    done
}

read_port_range() {
    while true; do
        read -p "Ingrese rango de puertos (default $DEFAULT_PORT_RANGE): " user_range

        # Si está vacío, usar default
        if [[ -z "$user_range" ]]; then
            echo "$DEFAULT_PORT_RANGE"
            return
        fi

        # Validar formato del rango
        if [[ "$user_range" =~ ^[0-9]+-[0-9]+$ ]]; then
            echo "$user_range"
            return
        else
            echo -e "${R}Error: Formato inválido. Use: inicio-fin (ej: 10000-60000)${N}"
        fi
    done
}

create_config() {
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" <<EOF
{
  "listen": ":$DEFAULT_UDP_PORT",
  "port_range": "$DEFAULT_PORT_RANGE",
  "stream_buffer": 67108864,
  "receive_buffer": 134217728,
  "auth": {
    "mode": "passwords"
  }
}
EOF
    echo -e "${G}✓ Configuración creada${N}"
    echo -e "${W}  Puerto: ${Y}$DEFAULT_UDP_PORT${N}"
    echo -e "${W}  Rango:  ${Y}$DEFAULT_PORT_RANGE${N}"
}

validate_repair_config() {
    if [[ -f "$CONFIG_FILE" ]] && jq empty "$CONFIG_FILE" &>/dev/null 2>&1; then
        return 0
    else
        echo -e "${Y}⚠ Reparando config.json...${N}"
        create_config
        return 1
    fi
}

restart_udp_custom() {
    echo -e "${Y}Reiniciando servicio UDP-Custom...${N}"
    systemctl daemon-reload 2>/dev/null
    systemctl restart "$SERVICE_NAME" 2>/dev/null
    sleep 2

    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${G}✓ Servicio reiniciado correctamente${N}"
    else
        echo -e "${R}✗ Error al reiniciar el servicio${N}"
    fi
}

toggle_service() {
    local status
    status="$(get_service_status)"

    if [[ "$status" == "ACTIVO" ]]; then
        echo -e "${Y}Deteniendo servicio...${N}"
        systemctl stop "$SERVICE_NAME" 2>/dev/null
        sleep 1
        echo -e "${G}✓ Servicio detenido${N}"
    else
        echo -e "${Y}Iniciando servicio...${N}"
        systemctl start "$SERVICE_NAME" 2>/dev/null
        sleep 2
        if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
            echo -e "${G}✓ Servicio iniciado${N}"
        else
            echo -e "${R}✗ Error al iniciar el servicio${N}"
        fi
    fi
}

install_udp_custom() {
    clear
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${Y}          INSTALANDO UDP-CUSTOM${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"

    # Actualizar e instalar dependencias
    echo -e "${W}Actualizando sistema...${N}"
    apt update -y >/dev/null 2>&1
    apt install -y wget jq curl net-tools >/dev/null 2>&1

    # Crear directorio
    mkdir -p "$CONFIG_DIR"

    # Descargar UDP-Custom
    echo -e "${W}Descargando UDP-Custom...${N}"
    if [[ ! -x "$UDP_BIN" ]]; then
        wget -q -O "$UDP_BIN" "https://github.com/http-custom/udpcustom/raw/main/folder/udp-custom-linux-amd64.bin"
        if [[ $? -eq 0 ]]; then
            chmod +x "$UDP_BIN"
            echo -e "${G}✓ UDP-Custom descargado${N}"
        else
            echo -e "${R}✗ Error al descargar UDP-Custom${N}"
            read -r -p "Presiona Enter para continuar..."
            return
        fi
    fi

    # Crear configuración
    create_config

    # Crear archivo de servicio
    echo -e "${W}Creando servicio systemd...${N}"
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=UDP Custom Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$CONFIG_DIR
ExecStart=$UDP_BIN server
Restart=always
RestartSec=5
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE

[Install]
WantedBy=multi-user.target
EOF

    # Recargar y activar servicio
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME" >/dev/null 2>&1

    # Iniciar servicio
    echo -e "${W}Iniciando servicio...${N}"
    systemctl start "$SERVICE_NAME"
    sleep 3

    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${G}✓ UDP-Custom instalado y activo${N}"
        echo -e "${W}  Puerto: ${Y}$(get_udp_port)${N}"
        echo -e "${W}  Proceso: ${Y}$(get_udp_process)${N}"
    else
        echo -e "${Y}⚠ Servicio instalado pero no iniciado${N}"
    fi

    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    read -r -p "Presiona Enter para continuar..."
}

uninstall_udp_custom() {
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${Y}         DESINSTALANDO UDP-CUSTOM${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"

    echo -e "${Y}¿Estás seguro de desinstalar UDP-Custom? (s/n): ${N}"
    read -r confirm

    if [[ "$confirm" == "s" || "$confirm" == "S" ]]; then
        echo -e "${W}Deteniendo servicio...${N}"
        systemctl stop "$SERVICE_NAME" 2>/dev/null
        systemctl disable "$SERVICE_NAME" 2>/dev/null

        echo -e "${W}Eliminando archivos...${N}"
        rm -f "$SERVICE_FILE"
        rm -f "$UDP_BIN"
        rm -rf "$CONFIG_DIR"

        systemctl daemon-reload

        echo -e "${G}✓ UDP-Custom desinstalado completamente${N}"
    else
        echo -e "${Y}✗ Desinstalación cancelada${N}"
    fi

    read -r -p "Presiona Enter para continuar..."
}

# -------------------------------
# Banner mejorado
# -------------------------------
show_udp_banner() {
    clear
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${R}[ ${G}●        UDP CUSTOM MANAGER ●${R} ]${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${R}[${N} ${W}IP Pública: ${Y}$(get_public_ip)${N}"
    echo -e "${R}[${N} ${W}Estado: ${G}$(get_service_status)${N} ${W}- Proceso: ${Y}$(get_udp_process)${N}"
    echo -e "${R}[${N} ${W}Puerto UDP: ${Y}$(get_udp_port)${N}"
    echo -e "${R}[${N} ${W}Rango Puertos: ${Y}$(get_port_range)${N}"
    echo -e "${R}[${N} ${W}Usuarios SSH: ${C}$(count_ssh_users)${N}"
    echo -e "${R}[${N} ${W}Conexiones UDP: ${C}$(count_udp_connections)${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
}

show_udp_menu() {
    echo -e "${W}              MENÚ UDP-CUSTOM${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"

    if ! is_udp_installed; then
        echo -e "${R}[${Y}1${R}]${N}  ${C}Instalar UDP-Custom${N}"
    else
        echo -e "${R}[${Y}1${R}]${N}  ${C}Iniciar / Detener Servicio${N}"
        echo -e "${R}[${Y}2${R}]${N}  ${C}Reiniciar Servicio${N}"
        echo -e "${R}[${Y}3${R}]${N}  ${C}Ver Configuración${N}"
        echo -e "${R}[${Y}4${R}]${N}  ${C}Modificar Puerto UDP${N}"
        echo -e "${R}[${Y}5${R}]${N}  ${C}Modificar Rango de Puertos${N}"
        echo -e "${R}[${Y}6${R}]${N}  ${C}Ver Logs del Servicio${N}"
        echo -e "${R}[${Y}7${R}]${N}  ${C}Ver Estado Detallado${N}"
        echo -e "${R}[${Y}8${R}]${N}  ${C}Desinstalar UDP-Custom${N}"
    fi

    echo -e "${R}[${Y}0${R}]${N}  ${C}Salir${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
}

show_detailed_status() {
    echo -e "${Y}─────────────────────────── / / / ──────────────────────────${N}"
    echo -e "${W}Servicio systemd:${N}"
    systemctl status "$SERVICE_NAME" --no-pager -l

    echo -e "\n${W}Puerto en uso:${N}"
    local port
    port="$(get_udp_port)"
    ss -ulpn 2>/dev/null | grep ":$port\b" || echo "Puerto no en uso"

    echo -e "\n${W}Procesos relacionados:${N}"
    ps aux | grep -E "(udp-custom|badvpn)" | grep -v grep || echo "No hay procesos activos"

    echo -e "\n${W}Conexiones activas:${N}"
    count_udp_connections
    read -r -p "Presiona Enter para continuar..."
}

# -------------------------------
# Menú principal
# -------------------------------
udp_custom_menu() {
    while true; do
        show_udp_banner
        show_udp_menu

        echo -ne "${W}Selecciona una opción [0-8]: ${G}"
        read -r option

        if ! is_udp_installed; then
            case "${option:-}" in
                1) install_udp_custom ;;
                0) 
                    echo -e "${G}Saliendo...${N}"
                    sleep 1
                    clear
                    break ;;
                *) 
                    echo -e "${R}Opción inválida${N}"
                    sleep 1 ;;
            esac
        else
            case "${option:-}" in
                1) toggle_service ;;
                2) restart_udp_custom ;;
                3) 
                    validate_repair_config
                    echo -e "${Y}Configuración actual:${N}"
                    cat "$CONFIG_FILE" 2>/dev/null | jq '.' || echo "Error al leer configuración"
                    read -r -p "Presiona Enter para continuar..." ;;
                4) 
                    new_port=$(read_port)
                    if jq ".listen = \":$new_port\"" "$CONFIG_FILE" > /tmp/udp_config.tmp 2>/dev/null; then
                        mv /tmp/udp_config.tmp "$CONFIG_FILE"
                        echo -e "${G}✓ Puerto actualizado a $new_port${N}"
                        restart_udp_custom
                    else
                        echo -e "${R}✗ Error al actualizar el puerto${N}"
                    fi ;;
                5)
                    new_range=$(read_port_range)
                    if jq ".port_range = \"$new_range\"" "$CONFIG_FILE" > /tmp/udp_config.tmp 2>/dev/null; then
                        mv /tmp/udp_config.tmp "$CONFIG_FILE"
                        echo -e "${G}✓ Rango actualizado a $new_range${N}"
                        restart_udp_custom
                    else
                        echo -e "${R}✗ Error al actualizar el rango${N}"
                    fi ;;
                6) 
                    echo -e "${Y}Últimas 50 líneas del log:${N}"
                    if [[ -f "$LOG_FILE" ]]; then
                        tail -n 50 "$LOG_FILE"
                    else
                        echo "No hay archivo de log"
                    fi
                    read -r -p "Presiona Enter para continuar..." ;;
                7) show_detailed_status ;;
                8) uninstall_udp_custom ;;
                0) 
                    echo -e "${G}Saliendo...${N}"
                    sleep 1
                    clear
                    break ;;
                *) 
                    echo -e "${R}Opción inválida${N}"
                    sleep 1 ;;
            esac
        fi
    done
}

# Iniciar el menú
udp_custom_menu
