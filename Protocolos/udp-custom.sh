#!/bin/bash
set -uo pipefail

# =========================================================
# UDP Custom Manager - Módulo para SinNombre
# Integrado en Protocolos/
# Creador: @SIN_NOMBRE22
# =========================================================

# Colores ANSI (igual que el menú principal)
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
M='\033[0;35m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'
BOLD='\033[1m'

# Rutas del servicio UDP-Custom
CONFIG_DIR="/etc/udp-custom"
CONFIG_FILE="${CONFIG_DIR}/config.json"
LOG_FILE="/var/log/udp-custom.log"
SERVICE_NAME="udp-custom"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# Puertos por defecto
DEFAULT_UDP_PORT=36712
DEFAULT_HTTP_PORT=8080

# Función para obtener IP pública
get_public_ip() {
    curl -fsS --max-time 2 ifconfig.me 2>/dev/null \
    || curl -fsS --max-time 2 ipinfo.io/ip 2>/dev/null \
    || echo "No disponible"
}

# Función para obtener estado del servicio
get_service_status() {
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo "ACTIVO"
    else
        echo "INACTIVO"
    fi
}

# Función para obtener puerto UDP del config
get_udp_port() {
    if [[ -f "$CONFIG_FILE" ]]; then
        jq -r '.udp_port // empty' "$CONFIG_FILE" 2>/dev/null || echo "$DEFAULT_UDP_PORT"
    else
        echo "$DEFAULT_UDP_PORT"
    fi
}

# Función para obtener puerto HTTP del config
get_http_port() {
    if [[ -f "$CONFIG_FILE" ]]; then
        jq -r '.http_port // empty' "$CONFIG_FILE" 2>/dev/null || echo "$DEFAULT_HTTP_PORT"
    else
        echo "$DEFAULT_HTTP_PORT"
    fi
}

# Función para contar usuarios SSH
count_ssh_users() {
    ls -1d /home/* 2>/dev/null | grep -v '/home/lost+found' | wc -l
}

# Función para contar conexiones UDP activas en el puerto
count_udp_connections() {
    local port
    port="$(get_udp_port)"
    ss -u -a 2>/dev/null | grep ":$port " | wc -l
}

# Función para verificar si badvpn está instalado
is_badvpn_installed() {
    command -v badvpn-udpgw &>/dev/null
}

# Función para instalar UDP-Custom (badvpn-udpgw)
install_udp_custom() {
    clear
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${Y}         INSTALANDO UDP-CUSTOM${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${W}Instalando dependencias...${N}"

    # Actualizar paquetes
    apt update -y >/dev/null 2>&1

    # Instalar jq si no está
    if ! command -v jq &>/dev/null; then
        apt install -y jq >/dev/null 2>&1
    fi

    # Instalar badvpn-udpgw
    if ! is_badvpn_installed; then
        apt install -y build-essential cmake git >/dev/null 2>&1
        cd /tmp || return 1
        git clone https://github.com/ambrop72/badvpn.git >/dev/null 2>&1
        cd badvpn || return 1
        mkdir build && cd build
        cmake .. -DCMAKE_INSTALL_PREFIX=/usr >/dev/null 2>&1
        make >/dev/null 2>&1
        make install >/dev/null 2>&1
        cd /tmp && rm -rf badvpn
    fi

    # Crear directorio de config
    mkdir -p "$CONFIG_DIR"

    # Crear config.json si no existe
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" <<EOF
{
  "udp_port": $DEFAULT_UDP_PORT,
  "http_port": $DEFAULT_HTTP_PORT
}
EOF
    fi

    # Crear archivo de log
    touch "$LOG_FILE"

    # Crear archivo de servicio systemd
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=UDP Custom Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 0.0.0.0:$(get_udp_port) --max-clients 1000 --loglevel 0
Restart=always
RestartSec=5
StandardOutput=file:$LOG_FILE
StandardError=file:$LOG_FILE

[Install]
WantedBy=multi-user.target
EOF

    # Recargar systemd y habilitar/iniciar servicio
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
    systemctl start "$SERVICE_NAME"

    echo -e "${G}UDP-Custom instalado y iniciado exitosamente!${N}"
    echo ""
    read -r -p "Presiona Enter para continuar..."
}

# Función para desinstalar UDP-Custom completamente
desinstall_udp_custom() {
    clear
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${Y}      DESINSTALANDO UDP-CUSTOM COMPLETAMENTE${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${W}¡ATENCIÓN! Esto eliminará:${N}"
    echo -e "${W}- Servicio UDP-Custom y archivos de configuración${N}"
    echo -e "${W}- Badvpn-udpgw y dependencias relacionadas${N}"
    echo -e "${W}- Archivos de log y configuración${N}"
    echo -e "${R}Esta acción es irreversible.${N}"
    echo ""
    echo -ne "${Y}¿Estás seguro de continuar? (s/n): ${N}"
    read -r confirm
    [[ "${confirm:-}" =~ ^[sS]$ ]] || { echo -e "${Y}Cancelado.${N}"; read -r -p "Presiona Enter para continuar..."; return; }

    # Detener y deshabilitar servicio
    systemctl stop "$SERVICE_NAME" 2>/dev/null
    systemctl disable "$SERVICE_NAME" 2>/dev/null
    systemctl daemon-reload

    # Remover archivo de servicio
    rm -f "$SERVICE_FILE"

    # Remover archivos de configuración y log
    rm -rf "$CONFIG_DIR"
    rm -f "$LOG_FILE"

    # Desinstalar badvpn (remover binarios instalados)
    if is_badvpn_installed; then
        rm -f /usr/bin/badvpn-*
        rm -rf /usr/include/badvpn* 2>/dev/null
        rm -rf /usr/lib/badvpn* 2>/dev/null
    fi

    # Remover dependencias instaladas si no son necesarias (opcional, pero completo)
    # Nota: jq podría usarse en otros lugares, así que no remover por defecto

    echo -e "${G}Desinstalación completa de UDP-Custom.${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo ""
    read -r -p "Presiona Enter para continuar..."
}

# Función para mostrar banner del panel (con toilet si disponible, como en menu principal)
show_udp_banner() {
    clear
    if command -v toilet &>/dev/null; then
        echo -e "\e[31m$(toilet -f slant -F metal "UDP Custom")\e[0m"
    fi

    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${R}[ ${G}●            UDP Custom Manager ●${R} ]${N}"
    echo -e "${R}══════════════════════════ / / / ════════════���═════════════${N}"
    echo -e "${R}[${N} ${W}IP Publica: ${Y}$(get_public_ip)${N}"
    echo -e "${R}[${N} ${W}Estado Servicio: ${G}$(get_service_status)${N}"
    echo -e "${R}[${N} ${W}Puerto UDP: ${Y}$(get_udp_port)${N}"
    echo -e "${R}[${N} ${W}Puerto HTTP: ${Y}$(get_http_port)${N}"
    echo -e "${R}[${N} ${W}Usuarios SSH: ${C}$(count_ssh_users)${N}"
    echo -e "${R}[${N} ${W}Conectados UDP: ${C}$(count_udp_connections)${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${R}[${N} ${W}Servicio UDP-Custom: ${G}$(is_badvpn_installed && echo "Instalado" || echo "No Instalado")${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
}

# Función para mostrar menú
show_udp_menu() {
    echo -e "${W}                     MENÚ UDP-CUSTOM${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    if ! is_badvpn_installed || ! systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
        echo -e "${R}[${Y}8${R}]${N}  ${C}Instalar UDP-Custom${N}"
    fi
    if is_badvpn_installed && systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
        echo -e "${R}[${Y}9${R}]${N}  ${C}Desinstalar UDP-Custom${N}"
    fi
    echo -e "${R}[${Y}1${R}]${N}  ${C}Iniciar / Detener Servicio${N}"
    echo -e "${R}[${Y}2${R}]${N}  ${C}Cambiar Puerto UDP${N}"
    echo -e "${R}[${Y}3${R}]${N}  ${C}Cambiar Puerto HTTP${N}"
    echo -e "${R}[${Y}4${R}]${N}  ${C}Ver usuarios SSH${N}"
    echo -e "${R}[${Y}5${R}]${N}  ${C}Ver conexiones UDP${N}"
    echo -e "${R}[${Y}6${R}]${N}  ${C}Ver logs${N}"
    echo -e "${R}[${Y}7${R}]${N}  ${C}Firewall UDP${N}"
    echo -e "${R}[${Y}0${R}]${N}  ${C}Volver${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
}

# Función para iniciar/detener servicio
toggle_service() {
    if ! is_badvpn_installed; then
        echo -e "${R}UDP-Custom no está instalado. Instálalo primero.${N}"
        read -r -p "Presiona Enter para continuar..."
        return
    fi
    local status
    status="$(get_service_status)"
    clear
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${Y}          INICIAR / DETENER SERVICIO${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo ""
    if [[ "$status" == "ACTIVO" ]]; then
        echo -e "${W}El servicio está ${G}ACTIVO${W}. ¿Detenerlo? (s/n): ${N}"
        read -r confirm
        if [[ "$confirm" =~ ^[sS]$ ]]; then
            systemctl stop "$SERVICE_NAME"
            echo -e "${G}Servicio detenido.${N}"
        fi
    else
        echo -e "${W}El servicio está ${R}INACTIVO${W}. ¿Iniciarlo? (s/n): ${N}"
        read -r confirm
        if [[ "$confirm" =~ ^[sS]$ ]]; then
            systemctl start "$SERVICE_NAME"
            echo -e "${G}Servicio iniciado.${N}"
        fi
    fi
    echo ""
    read -r -p "Presiona Enter para continuar..."
}

# Función para cambiar puerto UDP
change_udp_port() {
    if ! is_badvpn_installed; then
        echo -e "${R}UDP-Custom no está instalado. Instálalo primero.${N}"
        read -r -p "Presiona Enter para continuar..."
        return
    fi
    clear
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${Y}             CAMBIAR PUERTO UDP${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo ""
    local current_port
    current_port="$(get_udp_port)"
    echo -e "${W}Puerto actual: ${Y}$current_port${N}"
    echo -e "${W}Nuevo puerto (1-65535): ${N}"
    read -r new_port
    if [[ "$new_port" =~ ^[0-9]+$ ]] && [[ "$new_port" -ge 1 ]] && [[ "$new_port" -le 65535 ]]; then
        # Actualizar config.json
        jq ".udp_port = $new_port" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        # Recrear service file con nuevo puerto
        sed -i "s/--listen-addr 0.0.0.0:[0-9]\+ /--listen-addr 0.0.0.0:$new_port /" "$SERVICE_FILE"
        systemctl daemon-reload
        systemctl restart "$SERVICE_NAME" 2>/dev/null
        echo -e "${G}Puerto UDP cambiado a $new_port. Servicio reiniciado.${N}"
    else
        echo -e "${R}Puerto inválido.${N}"
    fi
    echo ""
    read -r -p "Presiona Enter para continuar..."
}

# Función para cambiar puerto HTTP
change_http_port() {
    clear
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${Y}             CAMBIAR PUERTO HTTP${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo ""
    local current_port
    current_port="$(get_http_port)"
    echo -e "${W}Puerto actual: ${Y}$current_port${N}"
    echo -e "${W}Nuevo puerto: ${N}"
    read -r new_port
    if [[ "$new_port" =~ ^[0-9]+$ ]]; then
        jq ".http_port = $new_port" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        echo -e "${G}Puerto HTTP cambiado a $new_port.${N}"
    else
        echo -e "${R}Puerto inválido.${N}"
    fi
    echo ""
    read -r -p "Presiona Enter para continuar..."
}

# Función para ver usuarios SSH
view_ssh_users() {
    clear
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${Y}               USUARIOS SSH${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo ""
    local users
    users="$(ls -1d /home/* 2>/dev/null | grep -v '/home/lost+found' | xargs -n1 basename)"
    if [[ -n "$users" ]]; then
        echo -e "${W}Usuarios SSH existentes:${N}"
        echo "$users" | while read -r user; do
            echo -e "${C}- $user${N}"
        done
    else
        echo -e "${Y}No se encontraron usuarios SSH.${N}"
    fi
    echo ""
    read -r -p "Presiona Enter para continuar..."
}

# Función para ver conexiones UDP
view_udp_connections() {
    if ! is_badvpn_installed; then
        echo -e "${R}UDP-Custom no está instalado. Instálalo primero.${N}"
        read -r -p "Presiona Enter para continuar..."
        return
    fi
    clear
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${Y}            CONEXIONES UDP ACTIVAS${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo ""
    local port
    port="$(get_udp_port)"
    local connections
    connections="$(ss -u -a 2>/dev/null | grep ":$port " | wc -l)"
    echo -e "${W}Conexiones UDP en puerto $port: ${G}$connections${N}"
    if [[ "$connections" -gt 0 ]]; then
        echo ""
        echo -e "${W}Detalles:${N}"
        ss -u -a 2>/dev/null | grep ":$port " | awk '{print $5}' | sort | uniq -c | sort -nr | while read -r count addr; do
            echo -e "${C}$count conexiones desde $addr${N}"
        done
    fi
    echo ""
    read -r -p "Presiona Enter para continuar..."
}

# Función para ver logs
view_logs() {
    clear
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${Y}                   LOGS UDP-CUSTOM${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo ""
    if [[ -f "$LOG_FILE" ]]; then
        tail -n 50 "$LOG_FILE"
    else
        echo -e "${Y}Archivo de log no encontrado: $LOG_FILE${N}"
    fi
    echo ""
    read -r -p "Presiona Enter para continuar..."
}

# Función para configurar firewall
configure_firewall() {
    if ! is_badvpn_installed; then
        echo -e "${R}UDP-Custom no está instalado. Instálalo primero.${N}"
        read -r -p "Presiona Enter para continuar..."
        return
    fi
    clear
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${Y}                FIREWALL UDP${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo ""
    local port
    port="$(get_udp_port)"
    echo -e "${W}Puerto UDP actual: ${Y}$port${N}"
    echo -e "${W}¿Abrir puerto UDP $port en firewall? (s/n): ${N}"
    read -r confirm
    if [[ "$confirm" =~ ^[sS]$ ]]; then
        if command -v ufw &>/dev/null; then
            ufw allow "$port"/udp
            echo -e "${G}Regla UFW añadida.${N}"
        elif command -v iptables &>/dev/null; then
            iptables -A INPUT -p udp --dport "$port" -j ACCEPT
            echo -e "${G}Regla iptables añadida.${N}"
        else
            echo -e "${R}No se encontró ufw ni iptables.${N}"
        fi
        echo -e "${Y}Nota: Asegúrate de guardar las reglas si es necesario.${N}"
    fi
    echo ""
    read -r -p "Presiona Enter para continuar..."
}

# Función principal del menú
udp_custom_menu() {
    while true; do
        show_udp_banner
        show_udp_menu
        echo -ne "${W}Selecciona una opción: ${G}"
        read -r option
        case "${option:-}" in
            1) toggle_service ;;
            2) change_udp_port ;;
            3) change_http_port ;;
            4) view_ssh_users ;;
            5) view_udp_connections ;;
            6) view_logs ;;
            7) configure_firewall ;;
            8) 
                if ! is_badvpn_installed || ! systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
                    install_udp_custom
                else
                    clear
                    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
                    echo -e "${B}                   OPCIÓN INVÁLIDA${N}"
                    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
                    sleep 2
                fi
                ;;
            9) 
                if is_badvpn_installed && systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
                    desinstall_udp_custom
                else
                    clear
                    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
                    echo -e "${B}                   OPCIÓN INVÁLIDA${N}"
                    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
                    sleep 2
                fi
                ;;
            0) return 0 ;;
            *) 
                clear
                echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
                echo -e "${B}                   OPCIÓN INVÁLIDA${N}"
                echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
                sleep 2
                ;;
        esac
    done
}

# Ejecutar el menú
udp_custom_menu
