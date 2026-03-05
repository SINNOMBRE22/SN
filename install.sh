#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# SinNombre - Installer 
# VALIDATOR con ANIMACIONES (progress bar/spinner estilo SN)
# =========================================================

REPO_OWNER="SINNOMBRE22"
REPO_NAME="SN"
REPO_BRANCH="main"

VALIDATOR_URL="http://67.217.244.52:7777/consume" 

LIC_DIR="/etc/.sn"
LIC_PATH="$LIC_DIR/lic"
INSTALL_DIR="/etc/SN"

# ============================
# COLORES
# ============================
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'
BOLD='\033[1m'; D='\033[2m'

line() {
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
}

step() { printf " ${C}•${N} ${W}%s${N} " "$1"; }
ok()   { echo -e "${G}[OK]${N}"; }
fail() { echo -e "${R}[FAIL]${N}"; }

# ============================
# ANIMACIONES (Barra & Spinner)
# ============================
progress_bar() {
  local msg="$1"
  local duration="${2:-3}"
  local width=20

  tput civis 2>/dev/null || true

  for ((i = 0; i <= width; i++)); do
    local pct=$(( i * 100 / width ))

    # Color de la parte completada según progreso
    local bar_color="$R"
    (( pct > 33 )) && bar_color="$Y"
    (( pct > 66 )) && bar_color="$G"

    printf "\r  ${C}•${N} ${W}%-20s${N} " "$msg"

    # Parte completada
    printf "${bar_color}"
    for ((j = 0; j < i; j++)); do printf "━"; done

    # Cabeza de la barra (detalle estético)
    if (( i < width )); then
      printf "╸"
    else
      printf "━"
    fi

    # Parte restante (dim/gris)
    printf "${D}"
    for ((j = i + 1; j < width; j++)); do printf "━"; done

    printf "${N} ${W}%3d%%${N}" "$pct"

    sleep "$(echo "scale=4; $duration / $width" | bc 2>/dev/null || echo "0.08")"
  done

  echo -e "  ${G}✓${N}"
  tput cnorm 2>/dev/null || true
}

spinner() {
  local pid="$1"
  local msg="${2:-Procesando...}"
  local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
  local i=0
  tput civis 2>/dev/null || true
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${C}${frames[$i]}${N} ${W}%s${N}" "$msg"
    i=$(( (i + 1) % ${#frames[@]} ))
    sleep 0.1
  done
  wait "$pid" 2>/dev/null
  local exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    printf "\r  ${G}✓${N} ${W}%-50s${N}\n" "$msg"
  else
    printf "\r  ${R}✗${N} ${W}%-50s${N}\n" "$msg"
  fi
  tput cnorm 2>/dev/null || true
  return $exit_code
}

# ============================
# ROOT
# ============================
[[ "$(id -u)" -ne 0 ]] && {
  clear
  line
  echo -e "${Y}Ejecuta como root:${N} sudo bash install.sh"
  line
  exit 1
}

# ============================
# DEPENDENCIAS (con animaciones)
# ============================
install_deps() {
  clear
  line
  echo -e "${Y}${BOLD}INSTALANDO DEPENDENCIAS${N}"
  line

  # Cada grupo de dependencias con barra y spinner
  progress_bar "Actualizando repositorios" 2
  apt-get update & spinner $! "Esperando apt-get update (puede tardar)..."

  progress_bar "Herramientas base" 1
  apt-get install -y curl git sudo ca-certificates & spinner $! "Instalando curl/git/sudo..."

  progress_bar "Compresión" 1
  apt-get install -y zip unzip & spinner $! "Instalando zip/unzip..."

  progress_bar "Redes" 1
  apt-get install -y ufw iptables socat netcat-openbsd net-tools & spinner $! "Instalando socat/netcat/ufw..."

  progress_bar "Python" 1
  apt-get install -y python3 python3-pip openssl & spinner $! "Instalando python3/pip/openssl..."

  progress_bar "Utilidades" 1
  apt-get install -y screen cron lsof nano at mlocate & spinner $! "Instalando utilidades..."

  progress_bar "Procesamiento" 1
  apt-get install -y jq bc gawk grep & spinner $! "Instalando jq/bc/gawk/grep..."

  progress_bar "Node.js" 1
  apt-get install -y nodejs npm & spinner $! "Instalando nodejs/npm..."

  progress_bar "Banners" 1
  apt-get install -y toilet figlet cowsay lolcat & spinner $! "Instalando toilet/figlet/cowsay/lolcat..."
}

# ============================
# KEY / LICENCIA 
# ============================
validate_key() {
  mkdir -p "$LIC_DIR"
  chmod 700 "$LIC_DIR"

  # Si ya existe licencia, NO volver a consumir key
  if [[ -f "$LIC_PATH" ]]; then
    echo -e "${G}Licencia ya activada. Continuando...${N}"
    sleep 1
    return 0
  fi

  clear
  line
  echo -e "${Y}${BOLD}ACTIVACIÓN DE LICENCIA${N}"
  line

  # Ciclo seguro: pide hasta tener patrón válido
  while :; do
    read -rp "KEY: " KEY
    KEY="$(echo -n "$KEY" | tr -d ' \r\n')"

    if [[ ! "$KEY" =~ ^SN-[a-zA-Z0-9]{10,}$ ]]; then
      echo -e "${R}Formato inválido. Debe empezar con SN- y tener mínimo 10 caract. alfanuméricos.${N}"
      continue
    fi
    break
  done

  progress_bar "Validando key" 2
  set +e
  RESP=$(curl -fsSL -X POST "$VALIDATOR_URL" \
    -H "Content-Type: application/json" \
    -d "{\"key\":\"$KEY\"}" 2>/dev/null)
  CODE=$?
  set -e

  if [[ $CODE -ne 0 || -z "$RESP" ]]; then
    echo -e "${R}Error de conexión al servidor de licencias.${N}"
    exit 2
  fi

  OK=$(echo "$RESP" | grep -o '"ok"[[:space:]]*:[[:space:]]*true')
  if [[ -z "$OK" ]]; then
    MSG=$(echo "$RESP" | grep -o '"error"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    [ -z "$MSG" ] && MSG="$(echo "$RESP" | cut -c1-120) ..."
    echo -e "${R}Key inválida. Detalle: $MSG${N}"
    exit 3
  fi

  echo "activated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$LIC_PATH"
  chmod 600 "$LIC_PATH"

  ok
}

# ============================
# INSTALAR PANEL (con animaciones)
# ============================
install_panel() {
  clear
  line
  echo -e "${Y}${BOLD}INSTALANDO PANEL${N}"
  line

  progress_bar "Clonando repositorio" 2
  rm -rf "$INSTALL_DIR" & spinner $! "Borrando instalación previa (si existe)..."
  git clone --depth 1 -b "$REPO_BRANCH" \
    "https://github.com/$REPO_OWNER/$REPO_NAME.git" \
    "$INSTALL_DIR" & spinner $! "Clonando repo SN..."

  progress_bar "Asignando permisos" 1
  chmod +x "$INSTALL_DIR/menu"
  find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} \;
  sleep 0.3

  progress_bar "Creando comandos globales" 1

  cat > /usr/local/bin/sn <<EOF
#!/usr/bin/env bash
[[ \$(id -u) -eq 0 ]] || { echo "Usa sudo"; exit 1; }
[[ -f $LIC_PATH ]] || { echo "Licencia no encontrada"; exit 1; }
exec $INSTALL_DIR/menu "\$@"
EOF

  chmod +x /usr/local/bin/sn
  ln -sf /usr/local/bin/sn /usr/local/bin/menu
  ok
}

# ============================
# BANNER DE BIENVENIDA ACTUALIZADO (con animación)
# ============================
install_banner() {
  progress_bar "Instalando banner mejorado" 2

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
            figlet -f slant "SinNombre" | lolcat
        elif command -v toilet >/dev/null 2>&1; then
            toilet -f slant -F metal "SinNombre" 2>/dev/null || \
            figlet "SinNombre"
        else
            figlet "SinNombre"
        fi
    elif command -v toilet >/dev/null 2>&1; then
        toilet -f slant -F metal "SinNombre" 2>/dev/null || \
        echo -e "${BOLD}${CYAN}SinNombre${RESET}"
    else
        center "${BOLD}${CYAN}╔════════════════════════════════╗${RESET}"
        center "${BOLD}${CYAN}║        S I N N O M B R E        ║${RESET}"
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
    echo -e "  ${GREEN}menu${RESET}   - Menú principal interactivo"
    echo -e "  ${GREEN}sn${RESET}     - Acceso rápido a funciones"
    echo -e "  ${GREEN}help${RESET}   - Mostrar ayuda"
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

  ok
}

# ============================
# FINALIZAR 
# ============================
finish() {
  line
  echo -e "${G}${BOLD}INSTALACIÓN COMPLETA${N}"
  line
  echo -e "${W}Reinicia la sesión SSH para aplicar los cambios.${N}"
}

# ============================
# EJECUCIÓN
# ============================
install_deps
validate_key
install_panel
install_banner
finish
