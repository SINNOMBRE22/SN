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
eval "$(echo "IyEvdXNyL2Jpbi9lbnYgYmFzaApzZXQgLWV1byBwaXBlZmFpbAoKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyBTaW5Ob21icmUgLSBJbnN0YWxsZXIgCiMgRVNUSUxPIFBST0ZFU0lPTkFMIC0gQkFOTkVSIE9SSUdJTkFMIC0gQ09SUkVHSURPCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CgojIC0tLSBDT05GSUdVUkFDScOTTiBQUklWQURBIChOTyBTRSBNVUVTVFJBIEVOIEVKRUNVQ0nDk04pIC0tLQpSRVBPX09XTkVSPSJTSU5OT01CUkUyMiIKUkVQT19OQU1FPSJTTiIKUkVQT19CUkFOQ0g9Im1haW4iClZBTElEQVRPUl9VUkw9Imh0dHA6Ly82Ny4yMTcuMjQ0LjUyOjc3NzcvY29uc3VtZSIKTElDX0RJUj0iL2V0Yy8uc24iCkxJQ19QQVRIPSIkTElDX0RJUi9saWMiCklOU1RBTExfRElSPSIvZXRjL1NOIgoKIyAtLS0gQ09MT1JFUyBTT0JSSU9TIChDT1JSRUdJRE9TKSAtLS0KUj0kJ1wwMzNbMDszMW0nICAgICAgIyBSb2pvIHBhcmEgZXJyb3JlcwpHPSQnXDAzM1swOzMybScgICAgICAjIFZlcmRlIHBhcmEgT0sKWT0kJ1wwMzNbMTszM20nICAgICAgIyBBbWFyaWxsbyBwYXJhIGFkdmVydGVuY2lhcwpDPSQnXDAzM1swOzM2bScgICAgICAjIEN5YW4gcGFyYSBkZXRhbGxlcwpXPSQnXDAzM1sxOzM3bScgICAgICAjIEJsYW5jbyBicmlsbGFudGUKTj0kJ1wwMzNbMG0nICAgICAgICAgIyBSZXNldApCT0xEPSQnXDAzM1sxbScgICAgICAKRD0kJ1wwMzNbMm0nICAgICAgICAgIyBEaW0gKGdyaXMpCgojIC0tLSBGVU5DSU9ORVMgREUgRVNUSUxPIC0tLQpsaW5lKCkgewogICAgZWNobyAtZSAiJHtSfeKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkCR7Tn0iCn0KCnByaW50X2NlbnRlcigpIHsKICAgIGxvY2FsIHRleHQ9IiQxIgogICAgbG9jYWwgd2lkdGg9JCh0cHV0IGNvbHMgMj4vZGV2L251bGwgfHwgZWNobyA4MCkKICAgIGxvY2FsIHBhZGRpbmc9JCgoICh3aWR0aCAtICR7I3RleHR9KSAvIDIgKSkKICAgIHByaW50ZiAiJSR7cGFkZGluZ31zJXNcbiIgIiIgIiR0ZXh0Igp9CgojIC0tLSBGVU5DSU9ORVMgREUgQU5JTUFDScOTTiBDT1JSRUdJREFTIC0tLQoKIyBCYXJyYSBkZSBwcm9ncmVzbyBob3Jpem9udGFsIChvcHRpbWl6YWRhIHBhcmEgZXZpdGFyIHNhbHRvcyBkZSBsw61uZWEpCnByb2dyZXNzX2JhcigpIHsKICAgIGxvY2FsIG1zZz0iJDEiCiAgICBsb2NhbCBkdXJhdGlvbj0iJHsyOi0yfSIKICAgIGxvY2FsIHdpZHRoPTIwICAKICAgIAogICAgdHB1dCBjaXZpcyAyPi9kZXYvbnVsbCB8fCB0cnVlCiAgICAKICAgIGZvciAoKGkgPSAwOyBpIDw9IHdpZHRoOyBpKyspKTsgZG8KICAgICAgICBsb2NhbCBwY3Q9JCgoIGkgKiAxMDAgLyB3aWR0aCApKQogICAgICAgIAogICAgICAgIGxvY2FsIGJhcj0iIgogICAgICAgIAogICAgICAgIGlmIFtbICRpIC1sdCAkd2lkdGggXV07IHRoZW4KICAgICAgICAgICAgYmFyPSIke2Jhcn0ke1J9IgogICAgICAgIGVsc2UKICAgICAgICAgICAgYmFyPSIke2Jhcn0ke0d9IgogICAgICAgIGZpCiAgICAgICAgCiAgICAgICAgZm9yICgoaiA9IDA7IGogPCBpOyBqKyspKTsgZG8gYmFyPSIke2Jhcn3ilqAiOyBkb25lCiAgICAgICAgCiAgICAgICAgYmFyPSIke2Jhcn0ke0R9IgogICAgICAgIGZvciAoKGogPSBpOyBqIDwgd2lkdGg7IGorKykpOyBkbyBiYXI9IiR7YmFyfeKWoSI7IGRvbmUKICAgICAgICBiYXI9IiR7YmFyfSR7Tn0iCiAgICAgICAgCiAgICAgICAgcHJpbnRmICJcclwwMzNbSyAgJHtDfeKWtiR7Tn0gJHtXfSUtMjRzJHtOfSBbJXNdICR7V30lM2QlJSR7Tn0iICIkbXNnIiAiJGJhciIgIiRwY3QiCiAgICAgICAgCiAgICAgICAgc2xlZXAgIiQoZWNobyAic2NhbGU9NDsgJGR1cmF0aW9uIC8gJHdpZHRoIiB8IGJjIDI+L2Rldi9udWxsIHx8IGVjaG8gIjAuMDUiKSIKICAgIGRvbmUKICAgIAogICAgZWNobyAtZSAiICR7R33inJMke059IgogICAgdHB1dCBjbm9ybSAyPi9kZXYvbnVsbCB8fCB0cnVlCn0KCiMgU3Bpbm5lciBtaW5pbWFsaXN0YQpzcGlubmVyKCkgewogICAgbG9jYWwgcGlkPSQxCiAgICBsb2NhbCBtc2c9IiQyIgogICAgbG9jYWwgc3BpbnN0cj0nfC8tXCcKICAgIGxvY2FsIGRlbGF5PTAuMQogICAgCiAgICB0cHV0IGNpdmlzIDI+L2Rldi9udWxsIHx8IHRydWUKICAgIAogICAgd2hpbGUga2lsbCAtMCAiJHBpZCIgMj4vZGV2L251bGw7IGRvCiAgICAgICAgbG9jYWwgdGVtcD0ke3NwaW5zdHIjP30KICAgICAgICBwcmludGYgIlxyXDAzM1tLICAke0N94pa2JHtOfSAke1d9JS0yNHMke059ICR7Q31bJWNdJHtOfSIgIiRtc2ciICIkc3BpbnN0ciIKICAgICAgICBzcGluc3RyPSR0ZW1wJHtzcGluc3RyJSIkdGVtcCJ9CiAgICAgICAgc2xlZXAgJGRlbGF5CiAgICBkb25lCiAgICAKICAgIHdhaXQgIiRwaWQiIDI+L2Rldi9udWxsCiAgICBsb2NhbCBleGl0X2NvZGU9JD8KICAgIAogICAgaWYgW1sgJGV4aXRfY29kZSAtZXEgMCBdXTsgdGhlbgogICAgICAgIHByaW50ZiAiXHJcMDMzW0sgICR7R33ilrYke059ICR7V30lLTI0cyR7Tn0gJHtHfVvinJNdJHtOfVxuIiAiJG1zZyIKICAgIGVsc2UKICAgICAgICBwcmludGYgIlxyXDAzM1tLICAke1J94pa2JHtOfSAke1d9JS0yNHMke059ICR7Un1b4pyXXSR7Tn1cbiIgIiRtc2ciCiAgICAgICAgcmV0dXJuICRleGl0X2NvZGUKICAgIGZpCiAgICAKICAgIHRwdXQgY25vcm0gMj4vZGV2L251bGwgfHwgdHJ1ZQp9CgojIC0tLSBWRVJJRklDQUNJw5NOIERFIFJPT1QgLS0tCmNoZWNrX3Jvb3QoKSB7CiAgICBpZiBbWyAiJChpZCAtdSkiIC1uZSAwIF1dOyB0aGVuCiAgICAgICAgY2xlYXIKICAgICAgICBsaW5lCiAgICAgICAgcHJpbnRfY2VudGVyICIke0JPTER9RVJST1IgREUgUEVSTUlTT1Mke059IgogICAgICAgIGxpbmUKICAgICAgICBlY2hvIC1lICJcbiAgJHtSfUVzdGUgaW5zdGFsYWRvciBkZWJlIGVqZWN1dGFyc2UgY29tbyByb290LiR7Tn0iCiAgICAgICAgZWNobyAtZSAiICAke1l9RWplY3V0ZToke059IHN1ZG8gYmFzaCBpbnN0YWxsLnNoXG4iCiAgICAgICAgbGluZQogICAgICAgIGV4aXQgMQogICAgZmkKfQoKIyAtLS0gSU5TVEFMQUNJw5NOIERFIERFUEVOREVOQ0lBUyAoU0lMRU5DSU9TQSkgLS0tCmluc3RhbGxfZGVwcygpIHsKICAgIGNsZWFyCiAgICBsaW5lCiAgICBwcmludF9jZW50ZXIgIiR7Qk9MRH0ke1d9RkFTRSAxOiBQUkVQQVJBQ0nDk04gREVMIFNJU1RFTUEke059IgogICAgbGluZQogICAgZWNobyAiIgogICAgCiAgICBhcHQtZ2V0IHVwZGF0ZSAtcXEgPiAvZGV2L251bGwgMj4mMSAmIHNwaW5uZXIgJCEgIkFjdHVhbGl6YW5kbyByZXBvc2l0b3Jpb3MiIHx8IHsKICAgICAgICBlY2hvIC1lICJcbiAgJHtSfVtFUlJPUl0gTm8gc2UgcHVkbyBhY3R1YWxpemFyIGxvcyByZXBvc2l0b3Jpb3Mke059IgogICAgICAgIGV4aXQgMQogICAgfQogICAgCiAgICBsb2NhbCBwYWNrYWdlcz0oCiAgICAgICAgY3VybCBnaXQgc3VkbyBjYS1jZXJ0aWZpY2F0ZXMKICAgICAgICB6aXAgdW56aXAgdWZ3IGlwdGFibGVzIHNvY2F0IG5ldGNhdC1vcGVuYnNkCiAgICAgICAgcHl0aG9uMyBweXRob24zLXBpcCBvcGVuc3NsCiAgICAgICAgc2NyZWVuIGNyb24gbHNvZiBuYW5vCiAgICAgICAganEgYmMgZ2F3awogICAgICAgIHRvaWxldCBmaWdsZXQgY293c2F5IGxvbGNhdAogICAgKQogICAgCiAgICBmb3IgcGtnIGluICIke3BhY2thZ2VzW0BdfSI7IGRvCiAgICAgICAgaWYgZHBrZyAtbCAiJHBrZyIgMj4vZGV2L251bGwgfCBncmVwIC1xICJeaWkiOyB0aGVuCiAgICAgICAgICAgIHByaW50ZiAiXHJcMDMzW0sgICR7R33ilrYke059ICR7V30lLTI0cyR7Tn0gJHtHfVvinJNdJHtOfSAoeWEgaW5zdGFsYWRvKVxuIiAiVmVyaWZpY2FuZG8gJHBrZyIKICAgICAgICBlbHNlCiAgICAgICAgICAgIGFwdC1nZXQgaW5zdGFsbCAteSAtcXEgIiRwa2ciID4gL2Rldi9udWxsIDI+JjEgJgogICAgICAgICAgICBzcGlubmVyICQhICJJbnN0YWxhbmRvICRwa2ciIHx8IHsKICAgICAgICAgICAgICAgIGVjaG8gLWUgIlxuICAke1l9W0FEVkVSVEVOQ0lBXSBObyBzZSBwdWRvIGluc3RhbGFyICRwa2cke059IgogICAgICAgICAgICB9CiAgICAgICAgZmkKICAgICAgICBzbGVlcCAwLjEKICAgIGRvbmUKICAgIAogICAgZWNobyAiIgogICAgbGluZQogICAgZWNobyAtZSAiICAke0d94pyTIFByZXBhcmFjacOzbiBjb21wbGV0YWRhJHtOfSIKICAgIGxpbmUKICAgIHNsZWVwIDEKfQoKIyAtLS0gVkFMSURBQ0nDk04gREUgTElDRU5DSUEgLS0tCnZhbGlkYXRlX2tleSgpIHsKICAgIGNsZWFyCiAgICBsaW5lCiAgICBwcmludF9jZW50ZXIgIiR7Qk9MRH0ke1d9RkFTRSAyOiBWQUxJREFDScOTTiR7Tn0iCiAgICBsaW5lCiAgICBlY2hvICIiCiAgICAKICAgIG1rZGlyIC1wICIkTElDX0RJUiIgMj4vZGV2L251bGwKICAgIGNobW9kIDcwMCAiJExJQ19ESVIiIDI+L2Rldi9udWxsCiAgICAKICAgIGlmIFtbIC1mICIkTElDX1BBVEgiIF1dOyB0aGVuCiAgICAgICAgZWNobyAtZSAiICAke0d94pa2IExpY2VuY2lhIHZlcmlmaWNhZGEgICAgICR7R31b4pyTXSR7Tn0iCiAgICAgICAgZWNobyAiIgogICAgICAgIGxpbmUKICAgICAgICBzbGVlcCAxCiAgICAgICAgcmV0dXJuIDAKICAgIGZpCiAgICAKICAgIGxvY2FsIEtFWT0iIgogICAgbG9jYWwgbWF4X2F0dGVtcHRzPTMKICAgIGxvY2FsIGF0dGVtcHQ9MQogICAgCiAgICB3aGlsZSBbWyAkYXR0ZW1wdCAtbGUgJG1heF9hdHRlbXB0cyBdXTsgZG8KICAgICAgICBlY2hvIC1uICIgIEtFWTogIgogICAgICAgIHJlYWQgLXIgS0VZCiAgICAgICAgS0VZPSIkKGVjaG8gLW4gIiRLRVkiIHwgdHIgLWQgJyBcclxuJykiCiAgICAgICAgCiAgICAgICAgaWYgW1sgISAiJEtFWSIgPX4gXlNOLVthLXpBLVowLTldezEwLH0kIF1dOyB0aGVuCiAgICAgICAgICAgIGVjaG8gLWUgIiAgJHtSfVtFUlJPUl0gRm9ybWF0byBpbmNvcnJlY3RvJHtOfSIKICAgICAgICAgICAgKChhdHRlbXB0KyspKQogICAgICAgICAgICBbICRhdHRlbXB0IC1sZSAkbWF4X2F0dGVtcHRzIF0gJiYgZWNobyAiIgogICAgICAgICAgICBjb250aW51ZQogICAgICAgIGZpCiAgICAgICAgCiAgICAgICAgKAogICAgICAgICAgICBjdXJsIC1mc1NMIC1YIFBPU1QgIiRWQUxJREFUT1JfVVJMIiBcCiAgICAgICAgICAgICAgICAtSCAiQ29udGVudC1UeXBlOiBhcHBsaWNhdGlvbi9qc29uIiBcCiAgICAgICAgICAgICAgICAtZCAie1wia2V5XCI6XCIkS0VZXCJ9IiAyPi9kZXYvbnVsbCB8IGdyZXAgLXEgJyJvayJbWzpzcGFjZTpdXSo6W1s6c3BhY2U6XV0qdHJ1ZScKICAgICAgICApICYgc3Bpbm5lciAkISAiVmVyaWZpY2FuZG8ga2V5IgogICAgICAgIAogICAgICAgIGlmIFsgJD8gLWVxIDAgXTsgdGhlbgogICAgICAgICAgICBlY2hvICJhY3RpdmF0ZWRfYXQ9JChkYXRlIC11ICsiJVktJW0tJWRUJUg6JU06JVNaIikiID4gIiRMSUNfUEFUSCIKICAgICAgICAgICAgY2htb2QgNjAwICIkTElDX1BBVEgiIDI+L2Rldi9udWxsCiAgICAgICAgICAgIGVjaG8gLWUgIlxuICAke0d94pyTIEtleSB2w6FsaWRhJHtOfSIKICAgICAgICAgICAgZWNobyAiIgogICAgICAgICAgICBsaW5lCiAgICAgICAgICAgIHNsZWVwIDEKICAgICAgICAgICAgcmV0dXJuIDAKICAgICAgICBlbHNlCiAgICAgICAgICAgIGVjaG8gLWUgIlxuICAke1J9W0VSUk9SXSBLZXkgaW52w6FsaWRhJHtOfSIKICAgICAgICAgICAgKChhdHRlbXB0KyspKQogICAgICAgICAgICBbICRhdHRlbXB0IC1sZSAkbWF4X2F0dGVtcHRzIF0gJiYgZWNobyAiIgogICAgICAgIGZpCiAgICBkb25lCiAgICAKICAgIGVjaG8gLWUgIlxuICAke1J9W0VSUk9SXSBObyBzZSBwdWRvIHZhbGlkYXIgbGEgbGljZW5jaWEke059IgogICAgZXhpdCAzCn0KCiMgLS0tIElOU1RBTEFDScOTTiBERUwgUEFORUwgKFRFWFRPUyBHRU7DiVJJQ09TL09DVUxUT1MpIC0tLQppbnN0YWxsX3BhbmVsKCkgewogICAgY2xlYXIKICAgIGxpbmUKICAgIHByaW50X2NlbnRlciAiJHtCT0xEfSR7V31GQVNFIDM6IElOU1RBTEFDScOTTiR7Tn0iCiAgICBsaW5lCiAgICBlY2hvICIiCiAgICAKICAgIGlmIFtbIC1kICIkSU5TVEFMTF9ESVIiIF1dOyB0aGVuCiAgICAgICAgcm0gLXJmICIkSU5TVEFMTF9ESVIiID4gL2Rldi9udWxsIDI+JjEgJiBzcGlubmVyICQhICJQcmVwYXJhbmRvIGVudG9ybm8iCiAgICBmaQogICAgCiAgICAjIEdpdCBjbG9uZSAxMDAlIHNpbGVuY2lvc28gY29uIHRleHRvIGdlbsOpcmljbwogICAgZ2l0IGNsb25lIC0tZGVwdGggMSAtYiAiJFJFUE9fQlJBTkNIIiBcCiAgICAgICAgImh0dHBzOi8vZ2l0aHViLmNvbS8kUkVQT19PV05FUi8kUkVQT19OQU1FLmdpdCIgXAogICAgICAgICIkSU5TVEFMTF9ESVIiID4gL2Rldi9udWxsIDI+JjEgJiBzcGlubmVyICQhICJJbnN0YWxhbmRvIHNjcmlwdCIgfHwgewogICAgICAgIGVjaG8gLWUgIlxuICAke1J9W0VSUk9SXSBObyBzZSBwdWRvIGNvbXBsZXRhciBsYSBpbnN0YWxhY2nDs24ke059IgogICAgICAgIGV4aXQgMQogICAgfQogICAgCiAgICBjaG1vZCAreCAiJElOU1RBTExfRElSL21lbnUiIDI+L2Rldi9udWxsIHx8IHRydWUKICAgIGZpbmQgIiRJTlNUQUxMX0RJUiIgLW5hbWUgIiouc2giIC1leGVjIGNobW9kICt4IHt9IFw7IDI+L2Rldi9udWxsCiAgICBwcm9ncmVzc19iYXIgIkFwbGljYW5kbyBjb25maWd1cmFjaW9uZXMiIDEKICAgIAogICAgY2F0ID4gL3Vzci9sb2NhbC9iaW4vc24gPDxFT0YKIyEvdXNyL2Jpbi9lbnYgYmFzaApbWyBcJChpZCAtdSkgLWVxIDAgXV0gfHwgeyBlY2hvIC1lICJcMDMzWzA7MzFtQWNjZXNvIGRlbmVnYWRvXDAzM1swbSI7IGV4aXQgMTsgfQpbWyAtZiAkTElDX1BBVEggXV0gfHwgeyBlY2hvIC1lICJcMDMzWzA7MzFtTGljZW5jaWEgbm8gZW5jb250cmFkYVwwMzNbMG0iOyBleGl0IDE7IH0KZXhlYyAkSU5TVEFMTF9ESVIvbWVudSAiXCRAIgpFT0YKICAgIAogICAgY2htb2QgK3ggL3Vzci9sb2NhbC9iaW4vc24gMj4vZGV2L251bGwKICAgIGxuIC1zZiAvdXNyL2xvY2FsL2Jpbi9zbiAvdXNyL2xvY2FsL2Jpbi9tZW51IDI+L2Rldi9udWxsCiAgICAKICAgIGVjaG8gLWUgIlxuICAke0d94pyTIEluc3RhbGFjacOzbiBjb21wbGV0YWRhJHtOfSIKICAgIGVjaG8gIiIKICAgIGxpbmUKICAgIHNsZWVwIDEKfQoKIyAtLS0gSU5TVEFMQUNJw5NOIERFTCBCQU5ORVIgT1JJR0lOQUwgLS0tCmluc3RhbGxfYmFubmVyKCkgewogICAgaWYgISBncmVwIC1xICIjIFNpbk5vbWJyZSAtIFdlbGNvbWUgYmFubmVyIG1lam9yYWRvIiAvcm9vdC8uYmFzaHJjIDI+L2Rldi9udWxsOyB0aGVuCiAgICAgICAgY2F0ID4+IC9yb290Ly5iYXNocmMgPDwgJ0VPRicKCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PQojIFNpbk5vbWJyZSAtIFdlbGNvbWUgYmFubmVyIG1lam9yYWRvCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PQppZiBbWyAkLSA9PSAqaSogXV07IHRoZW4KICAgIFtbIC1uICIke1NOX1dFTENPTUVfU0hPV046LX0iIF1dICYmIHJldHVybgogICAgZXhwb3J0IFNOX1dFTENPTUVfU0hPV049MQogICAgCiAgICBjbGVhcgogICAgCiAgICBSRUQ9J1wwMzNbMDszMW0nCiAgICBHUkVFTj0nXDAzM1swOzMybScKICAgIFlFTExPVz0nXDAzM1sxOzMzbScKICAgIEJMVUU9J1wwMzNbMDszNG0nCiAgICBNQUdFTlRBPSdcMDMzWzA7MzVtJwogICAgQ1lBTj0nXDAzM1swOzM2bScKICAgIFdISVRFPSdcMDMzWzE7MzdtJwogICAgQk9MRD0nXDAzM1sxbScKICAgIFJFU0VUPSdcMDMzWzBtJwogICAgCiAgICBjZW50ZXIoKSB7CiAgICAgICAgbG9jYWwgdGV4dD0iJDEiCiAgICAgICAgbG9jYWwgd2lkdGg9IiR7MjotNTB9IgogICAgICAgIGxvY2FsIHBhZGRpbmc9JCgoICh3aWR0aCAtICR7I3RleHR9KSAvIDIgKSkKICAgICAgICBwcmludGYgIiUke3BhZGRpbmd9cyVzJSR7cGFkZGluZ31zXG4iICIiICIkdGV4dCIgIiIKICAgIH0KICAgIAogICAgVVNFUl9JTkZPPSIke1VTRVJ9QCQoaG9zdG5hbWUpIgogICAgT1NfSU5GTz0iJChncmVwICdeUFJFVFRZX05BTUUnIC9ldGMvb3MtcmVsZWFzZSAyPi9kZXYvbnVsbCB8IGN1dCAtZD0gLWYyIHwgdHIgLWQgJyInIHx8IHVuYW1lIC1zKSIKICAgIFVQVElNRV9JTkZPPSIkKHVwdGltZSAtcCAyPi9kZXYvbnVsbCB8IHNlZCAncy91cCAvLycgfHwgdXB0aW1lKSIKICAgIE1FTV9JTkZPPSIkKGZyZWUgLWggMj4vZGV2L251bGwgfCBhd2sgJy9eTWVtOi8ge3ByaW50ICQzICIvIiAkMn0nIHx8IGVjaG8gJ04vQScpIgogICAgU0hFTExfSU5GTz0iJHtTSEVMTCMjKi99IgogICAgCiAgICBlY2hvICIiCiAgICAKICAgIGlmIGNvbW1hbmQgLXYgZmlnbGV0ID4vZGV2L251bGwgMj4mMTsgdGhlbgogICAgICAgIGlmIGNvbW1hbmQgLXYgbG9sY2F0ID4vZGV2L251bGwgMj4mMTsgdGhlbgogICAgICAgICAgICBmaWdsZXQgLWYgc2xhbnQgIlNOIC0gUGx1cyIgfCBsb2xjYXQKICAgICAgICBlbGlmIGNvbW1hbmQgLXYgdG9pbGV0ID4vZGV2L251bGwgMj4mMTsgdGhlbgogICAgICAgICAgICB0b2lsZXQgLWYgc2xhbnQgLUYgbWV0YWwgIlNOIC0gUGx1cyIgMj4vZGV2L251bGwgfHwgXAogICAgICAgICAgICBmaWdsZXQgIlNOIC0gUGx1cyIKICAgICAgICBlbHNlCiAgICAgICAgICAgIGZpZ2xldCAiU04gLSBQbHVzIgogICAgICAgIGZpCiAgICBlbGlmIGNvbW1hbmQgLXYgdG9pbGV0ID4vZGV2L251bGwgMj4mMTsgdGhlbgogICAgICAgIHRvaWxldCAtZiBzbGFudCAtRiBtZXRhbCAiU2luTm9tYnJlIiAyPi9kZXYvbnVsbCB8fCBcCiAgICAgICAgZWNobyAtZSAiJHtCT0xEfSR7Q1lBTn1TaW5Ob21icmUke1JFU0VUfSIKICAgIGVsc2UKICAgICAgICBjZW50ZXIgIiR7Qk9MRH0ke0NZQU594pWU4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWXJHtSRVNFVH0iCiAgICAgICAgY2VudGVyICIke0JPTER9JHtDWUFOfeKVkSAgICAgICAgUyBJIE4gTiBPIE0gQiBSIEUgICAgICAg4pWRJHtSRVNFVH0iCiAgICAgICAgY2VudGVyICIke0JPTER9JHtDWUFOfeKVmuKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVkOKVnSR7UkVTRVR9IgogICAgZmkKICAgIAogICAgZWNobyAtZSAiJHtCTFVFfSQocHJpbnRmICclLjBz4pWQJyAkKHNlcSAxICQodHB1dCBjb2xzIDI+L2Rldi9udWxsIHx8IGVjaG8gNTApKSkke1JFU0VUfSIKICAgIAogICAgZWNobyAtZSAiJHtCT0xEfSR7WUVMTE9XffCfkrsgIFNpc3RlbWE6JHtSRVNFVH0gJHtXSElURX0ke09TX0lORk99JHtSRVNFVH0iCiAgICBlY2hvIC1lICIke0JPTER9JHtZRUxMT1d98J+RpCAgVXN1YXJpbzoke1JFU0VUfSAke0dSRUVOfSR7VVNFUl9JTkZPfSR7UkVTRVR9IgogICAgZWNobyAtZSAiJHtCT0xEfSR7WUVMTE9XfeKPse+4jyAgIFVwdGltZToke1JFU0VUfSAke0NZQU59JHtVUFRJTUVfSU5GT30ke1JFU0VUfSIKICAgIGVjaG8gLWUgIiR7Qk9MRH0ke1lFTExPV33wn6egICBNZW1vcmlhOiR7UkVTRVR9ICR7TUFHRU5UQX0ke01FTV9JTkZPfSR7UkVTRVR9IgogICAgZWNobyAtZSAiJHtCT0xEfSR7WUVMTE9XffCfkJogIFNoZWxsOiR7UkVTRVR9ICR7UkVEfSR7U0hFTExfSU5GT30ke1JFU0VUfSIKICAgIAogICAgZWNobyAtZSAiJHtCTFVFfSQocHJpbnRmICclLjBz4pWQJyAkKHNlcSAxICQodHB1dCBjb2xzIDI+L2Rldi9udWxsIHx8IGVjaG8gNTApKSkke1JFU0VUfSIKICAgIAogICAgZWNobyAtZSAiJHtCT0xEfSR7V0hJVEV9Q29tYW5kb3MgZGlzcG9uaWJsZXM6JHtSRVNFVH0iCiAgICBlY2hvIC1lICIgICR7R1JFRU59bWVudS9zbiR7UkVTRVR9ICAgLSBQYXJhIGFicmlyIGVsIG1lbnUiCiAgICBlY2hvIC1lICIgICR7R1JFRU59c3RhdHVzJHtSRVNFVH0gLSBFc3RhZG8gZGVsIHNpc3RlbWEiCiAgICAKICAgIGVjaG8gLWUgIlxuJHtCT0xEfSR7V0hJVEV98J+ThSAgJChkYXRlICcrJUEsICVkIGRlICVCIGRlICVZIC0gJUg6JU06JVMnKSR7UkVTRVR9IgogICAgCiAgICBIT1VSPSQoZGF0ZSArJUgpCiAgICBpZiBbICRIT1VSIC1sdCAxMiBdOyB0aGVuCiAgICAgICAgZWNobyAtZSAiJHtCT0xEfSR7WUVMTE9XfeKYgO+4jyAgIMKhQnVlbm9zIGTDrWFzISR7UkVTRVR9XG4iCiAgICBlbGlmIFsgJEhPVVIgLWx0IDE5IF07IHRoZW4KICAgICAgICBlY2hvIC1lICIke0JPTER9JHtZRUxMT1d98J+MpO+4jyAgIMKhQnVlbmFzIHRhcmRlcyEke1JFU0VUfVxuIgogICAgZWxzZQogICAgICAgIGVjaG8gLWUgIiR7Qk9MRH0ke1lFTExPV33wn4yZICAgwqFCdWVuYXMgbm9jaGVzISR7UkVTRVR9XG4iCiAgICBmaQpmaQpFT0YKICAgIGZpCiAgICAKICAgIHByb2dyZXNzX2JhciAiRmluYWxpemFuZG8gYWp1c3RlcyIgMQp9CgojIC0tLSBDVUVOVEEgUkVHUkVTSVZBIC0tLQpjb3VudGRvd24oKSB7CiAgICBjbGVhcgogICAgbGluZQogICAgcHJpbnRfY2VudGVyICIke0JPTER9JHtXfUlOU1RBTEFDScOTTiBDT01QTEVUQSR7Tn0iCiAgICBsaW5lCiAgICBlY2hvICIiCiAgICBwcmludF9jZW50ZXIgIkVsIHNpc3RlbWEgc2UgdmEgYSByZWluaWNpYXIgZW4iCiAgICBlY2hvICIiCiAgICAKICAgIGxvY2FsIHNlY29uZHM9MTAKICAgIGxvY2FsIGNvbHM9JCh0cHV0IGNvbHMgMj4vZGV2L251bGwgfHwgZWNobyA4MCkKICAgIAogICAgdHB1dCBjaXZpcyAyPi9kZXYvbnVsbCB8fCB0cnVlCiAgICAKICAgIHdoaWxlIFtbICRzZWNvbmRzIC1ndCAwIF1dOyBkbwogICAgICAgIGxvY2FsIG51bV9zdHI9IiR7Qk9MRH0ke1l9JHtzZWNvbmRzfSR7Tn0iCiAgICAgICAgbG9jYWwgbnVtX3dpZHRoPSR7I3NlY29uZHN9CiAgICAgICAgbG9jYWwgcGFkZGluZz0kKCggKGNvbHMgLSBudW1fd2lkdGgpIC8gMiApKQogICAgICAgIAogICAgICAgIHByaW50ZiAiXHJcMDMzW0slJHtwYWRkaW5nfXMlcyIgIiIgIiRudW1fc3RyIgogICAgICAgIAogICAgICAgIHNsZWVwIDEKICAgICAgICAoKHNlY29uZHMtLSkpCiAgICBkb25lCiAgICAKICAgIHByaW50ZiAiXG5cbiIKICAgIHByaW50X2NlbnRlciAiJHtSfVJlaW5pY2lhbmRvLi4uJHtOfSIKICAgIHRwdXQgY25vcm0gMj4vZGV2L251bGwgfHwgdHJ1ZQogICAgc2xlZXAgMQp9CgojIC0tLSBMSU1QSUVaQSBGSU5BTCAtLS0KY2xlYW51cCgpIHsKICAgIGhpc3RvcnkgLWMgMj4vZGV2L251bGwgfHwgdHJ1ZQogICAgc3luYwp9CgojIC0tLSBFSkVDVUNJw5NOIFBSSU5DSVBBTCAtLS0KbWFpbigpIHsKICAgIGNoZWNrX3Jvb3QKICAgIGluc3RhbGxfZGVwcwogICAgdmFsaWRhdGVfa2V5CiAgICBpbnN0YWxsX3BhbmVsCiAgICBpbnN0YWxsX2Jhbm5lcgogICAgY2xlYW51cAogICAgY291bnRkb3duCiAgICByZWJvb3QKfQoKIyBBdHJhcGFyIEN0cmwrQwp0cmFwICdlY2hvIC1lICJcbiR7WX1JbnN0YWxhY2nDs24gY2FuY2VsYWRhJHtOfSI7IGV4aXQgMCcgSU5UIFRFUk0KCiMgSW5pY2lhcgptYWluCg==" | base64 -d)"
