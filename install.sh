#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# SinNombre - Installer 
# ESTILO PROFESIONAL - BANNER ORIGINAL - CORREGIDO
# =========================================================

# --- CONFIGURACIÓN PRIVADA (NO SE MUESTRA EN EJECUCIÓN) ---
REPO_OWNER="SINNOMBRE22"
REPO_NAME="SN"
REPO_BRANCH="main"
VALIDATOR_URL="http://67.217.244.52:7777/consume"
LIC_DIR="/etc/.sn"
LIC_PATH="$LIC_DIR/lic"
INSTALL_DIR="/etc/SN"

# --- COLORES SOBRIOS (CORREGIDOS) ---
R=$'\033[0;31m'      # Rojo para errores
G=$'\033[0;32m'      # Verde para OK
Y=$'\033[1;33m'      # Amarillo para advertencias
C=$'\033[0;36m'      # Cyan para detalles
W=$'\033[1;37m'      # Blanco brillante
N=$'\033[0m'         # Reset
BOLD=$'\033[1m'      
D=$'\033[2m'         # Dim (gris)

# --- FUNCIONES DE ESTILO ---
line() {
    echo -e "${R}════════════════════════════════════════════════════════════════${N}"
}

print_center() {
    local text="$1"
    local width=$(tput cols 2>/dev/null || echo 80)
    local padding=$(( (width - ${#text}) / 2 ))
    printf "%${padding}s%s\n" "" "$text"
}

# --- FUNCIONES DE ANIMACIÓN CORREGIDAS ---

# Barra de progreso horizontal (optimizada para evitar saltos de línea)
progress_bar() {
    local msg="$1"
    local duration="${2:-2}"
    local width=20  
    
    tput civis 2>/dev/null || true
    
    for ((i = 0; i <= width; i++)); do
        local pct=$(( i * 100 / width ))
        
        local bar=""
        
        if [[ $i -lt $width ]]; then
            bar="${bar}${R}"
        else
            bar="${bar}${G}"
        fi
        
        for ((j = 0; j < i; j++)); do bar="${bar}■"; done
        
        bar="${bar}${D}"
        for ((j = i; j < width; j++)); do bar="${bar}□"; done
        bar="${bar}${N}"
        
        printf "\r\033[K  ${C}▶${N} ${W}%-24s${N} [%s] ${W}%3d%%${N}" "$msg" "$bar" "$pct"
        
        sleep "$(echo "scale=4; $duration / $width" | bc 2>/dev/null || echo "0.05")"
    done
    
    echo -e " ${G}✓${N}"
    tput cnorm 2>/dev/null || true
}

# Spinner minimalista
spinner() {
    local pid=$1
    local msg="$2"
    local spinstr='|/-\'
    local delay=0.1
    
    tput civis 2>/dev/null || true
    
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r\033[K  ${C}▶${N} ${W}%-24s${N} ${C}[%c]${N}" "$msg" "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    
    wait "$pid" 2>/dev/null
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        printf "\r\033[K  ${G}▶${N} ${W}%-24s${N} ${G}[✓]${N}\n" "$msg"
    else
        printf "\r\033[K  ${R}▶${N} ${W}%-24s${N} ${R}[✗]${N}\n" "$msg"
        return $exit_code
    fi
    
    tput cnorm 2>/dev/null || true
}

# --- VERIFICACIÓN DE ROOT ---
check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        clear
        line
        print_center "${BOLD}ERROR DE PERMISOS${N}"
        line
        echo -e "\n  ${R}Este instalador debe ejecutarse como root.${N}"
        echo -e "  ${Y}Ejecute:${N} sudo bash install.sh\n"
        line
        exit 1
    fi
}

# --- INSTALACIÓN DE DEPENDENCIAS (SILENCIOSA) ---
install_deps() {
    clear
    line
    print_center "${BOLD}${W}FASE 1: PREPARACIÓN DEL SISTEMA${N}"
    line
    echo ""
    
    apt-get update -qq > /dev/null 2>&1 & spinner $! "Actualizando repositorios" || {
        echo -e "\n  ${R}[ERROR] No se pudo actualizar los repositorios${N}"
        exit 1
    }
    
    local packages=(
        curl git sudo ca-certificates
        zip unzip ufw iptables socat netcat-openbsd
        python3 python3-pip openssl
        screen cron lsof nano
        jq bc gawk
        toilet figlet cowsay lolcat
    )
    
    for pkg in "${packages[@]}"; do
        if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            printf "\r\033[K  ${G}▶${N} ${W}%-24s${N} ${G}[✓]${N} (ya instalado)\n" "Verificando $pkg"
        else
            apt-get install -y -qq "$pkg" > /dev/null 2>&1 &
            spinner $! "Instalando $pkg" || {
                echo -e "\n  ${Y}[ADVERTENCIA] No se pudo instalar $pkg${N}"
            }
        fi
        sleep 0.1
    done
    
    echo ""
    line
    echo -e "  ${G}✓ Preparación completada${N}"
    line
    sleep 1
}

# --- VALIDACIÓN DE LICENCIA ---
validate_key() {
    clear
    line
    print_center "${BOLD}${W}FASE 2: VALIDACIÓN${N}"
    line
    echo ""
    
    mkdir -p "$LIC_DIR" 2>/dev/null
    chmod 700 "$LIC_DIR" 2>/dev/null
    
    if [[ -f "$LIC_PATH" ]]; then
        echo -e "  ${G}▶ Licencia verificada     ${G}[✓]${N}"
        echo ""
        line
        sleep 1
        return 0
    fi
    
    local KEY=""
    local max_attempts=3
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        echo -n "  KEY: "
        read -r KEY
        KEY="$(echo -n "$KEY" | tr -d ' \r\n')"
        
        if [[ ! "$KEY" =~ ^SN-[a-zA-Z0-9]{10,}$ ]]; then
            echo -e "  ${R}[ERROR] Formato incorrecto${N}"
            ((attempt++))
            [ $attempt -le $max_attempts ] && echo ""
            continue
        fi
        
        (
            curl -fsSL -X POST "$VALIDATOR_URL" \
                -H "Content-Type: application/json" \
                -d "{\"key\":\"$KEY\"}" 2>/dev/null | grep -q '"ok"[[:space:]]*:[[:space:]]*true'
        ) & spinner $! "Verificando key"
        
        if [ $? -eq 0 ]; then
            echo "activated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$LIC_PATH"
            chmod 600 "$LIC_PATH" 2>/dev/null
            echo -e "\n  ${G}✓ Key válida${N}"
            echo ""
            line
            sleep 1
            return 0
        else
            echo -e "\n  ${R}[ERROR] Key inválida${N}"
            ((attempt++))
            [ $attempt -le $max_attempts ] && echo ""
        fi
    done
    
    echo -e "\n  ${R}[ERROR] No se pudo validar la licencia${N}"
    exit 3
}

# --- INSTALACIÓN DEL PANEL (TEXTOS GENÉRICOS/OCULTOS) ---
install_panel() {
    clear
    line
    print_center "${BOLD}${W}FASE 3: INSTALACIÓN${N}"
    line
    echo ""
    
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR" > /dev/null 2>&1 & spinner $! "Preparando entorno"
    fi
    
    # Git clone 100% silencioso con texto genérico
    git clone --depth 1 -b "$REPO_BRANCH" \
        "https://github.com/$REPO_OWNER/$REPO_NAME.git" \
        "$INSTALL_DIR" > /dev/null 2>&1 & spinner $! "Instalando script" || {
        echo -e "\n  ${R}[ERROR] No se pudo completar la instalación${N}"
        exit 1
    }
    
    chmod +x "$INSTALL_DIR/menu" 2>/dev/null || true
    find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} \; 2>/dev/null
    progress_bar "Aplicando configuraciones" 1
    
    cat > /usr/local/bin/sn <<EOF
#!/usr/bin/env bash
[[ \$(id -u) -eq 0 ]] || { echo -e "\033[0;31mAcceso denegado\033[0m"; exit 1; }
[[ -f $LIC_PATH ]] || { echo -e "\033[0;31mLicencia no encontrada\033[0m"; exit 1; }
exec $INSTALL_DIR/menu "\$@"
EOF
    
    chmod +x /usr/local/bin/sn 2>/dev/null
    ln -sf /usr/local/bin/sn /usr/local/bin/menu 2>/dev/null
    
    echo -e "\n  ${G}✓ Instalación completada${N}"
    echo ""
    line
    sleep 1
}

# --- INSTALACIÓN DEL BANNER ORIGINAL ---
install_banner() {
    if ! grep -q "# SinNombre - Welcome banner mejorado" /root/.bashrc 2>/dev/null; then
        cat >> /root/.bashrc << 'EOF'

# ============================
# SinNombre - Welcome banner mejorado
# ============================
if [[ $- == *i* ]]; then
    [[ -n "${SN_WELCOME_SHOWN:-}" ]] && return
    export SN_WELCOME_SHOWN=1
    
    clear
    
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    BOLD='\033[1m'
    RESET='\033[0m'
    
    center() {
        local text="$1"
        local width="${2:-50}"
        local padding=$(( (width - ${#text}) / 2 ))
        printf "%${padding}s%s%${padding}s\n" "" "$text" ""
    }
    
    USER_INFO="${USER}@$(hostname)"
    OS_INFO="$(grep '^PRETTY_NAME' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || uname -s)"
    UPTIME_INFO="$(uptime -p 2>/dev/null | sed 's/up //' || uptime)"
    MEM_INFO="$(free -h 2>/dev/null | awk '/^Mem:/ {print $3 "/" $2}' || echo 'N/A')"
    SHELL_INFO="${SHELL##*/}"
    
    echo ""
    
    if command -v figlet >/dev/null 2>&1; then
        if command -v lolcat >/dev/null 2>&1; then
            figlet -f slant "SN - Plus" | lolcat
        elif command -v toilet >/dev/null 2>&1; then
            toilet -f slant -F metal "SN - Plus" 2>/dev/null || \
            figlet "SN - Plus"
        else
            figlet "SN - Plus"
        fi
    elif command -v toilet >/dev/null 2>&1; then
        toilet -f slant -F metal "SinNombre" 2>/dev/null || \
        echo -e "${BOLD}${CYAN}SinNombre${RESET}"
    else
        center "${BOLD}${CYAN}╔════════════════════════════════╗${RESET}"
        center "${BOLD}${CYAN}║        S I N N O M B R E       ║${RESET}"
        center "${BOLD}${CYAN}╚════════════════════════════════╝${RESET}"
    fi
    
    echo -e "${BLUE}$(printf '%.0s═' $(seq 1 $(tput cols 2>/dev/null || echo 50)))${RESET}"
    
    echo -e "${BOLD}${YELLOW}💻  Sistema:${RESET} ${WHITE}${OS_INFO}${RESET}"
    echo -e "${BOLD}${YELLOW}👤  Usuario:${RESET} ${GREEN}${USER_INFO}${RESET}"
    echo -e "${BOLD}${YELLOW}⏱️   Uptime:${RESET} ${CYAN}${UPTIME_INFO}${RESET}"
    echo -e "${BOLD}${YELLOW}🧠  Memoria:${RESET} ${MAGENTA}${MEM_INFO}${RESET}"
    echo -e "${BOLD}${YELLOW}🐚  Shell:${RESET} ${RED}${SHELL_INFO}${RESET}"
    
    echo -e "${BLUE}$(printf '%.0s═' $(seq 1 $(tput cols 2>/dev/null || echo 50)))${RESET}"
    
    echo -e "${BOLD}${WHITE}Comandos disponibles:${RESET}"
    echo -e "  ${GREEN}menu/sn${RESET}   - Para abrir el menu"
    echo -e "  ${GREEN}status${RESET} - Estado del sistema"
    
    echo -e "\n${BOLD}${WHITE}📅  $(date '+%A, %d de %B de %Y - %H:%M:%S')${RESET}"
    
    HOUR=$(date +%H)
    if [ $HOUR -lt 12 ]; then
        echo -e "${BOLD}${YELLOW}☀️   ¡Buenos días!${RESET}\n"
    elif [ $HOUR -lt 19 ]; then
        echo -e "${BOLD}${YELLOW}🌤️   ¡Buenas tardes!${RESET}\n"
    else
        echo -e "${BOLD}${YELLOW}🌙   ¡Buenas noches!${RESET}\n"
    fi
fi
EOF
    fi
    
    progress_bar "Finalizando ajustes" 1
}

# --- CUENTA REGRESIVA ---
countdown() {
    clear
    line
    print_center "${BOLD}${W}INSTALACIÓN COMPLETA${N}"
    line
    echo ""
    print_center "El sistema se va a reiniciar en"
    echo ""
    
    local seconds=10
    local cols=$(tput cols 2>/dev/null || echo 80)
    
    tput civis 2>/dev/null || true
    
    while [[ $seconds -gt 0 ]]; do
        local num_str="${BOLD}${Y}${seconds}${N}"
        local num_width=${#seconds}
        local padding=$(( (cols - num_width) / 2 ))
        
        printf "\r\033[K%${padding}s%s" "" "$num_str"
        
        sleep 1
        ((seconds--))
    done
    
    printf "\n\n"
    print_center "${R}Reiniciando...${N}"
    tput cnorm 2>/dev/null || true
    sleep 1
}

# --- LIMPIEZA FINAL ---
cleanup() {
    history -c 2>/dev/null || true
    sync
}

# --- EJECUCIÓN PRINCIPAL ---
main() {
    check_root
    install_deps
    validate_key
    install_panel
    install_banner
    cleanup
    countdown
    reboot
}

# Atrapar Ctrl+C
trap 'echo -e "\n${Y}Instalación cancelada${N}"; exit 0' INT TERM

# Iniciar
main
