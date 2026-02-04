#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# SinNombre - Installer 
# VALIDATOR FIXED (usa el que SÍ funciona)
# =========================================================

REPO_OWNER="SINNOMBRE22"
REPO_NAME="SN"
REPO_BRANCH="main"

VALIDATOR_URL="http://67.217.244.52:8888/consume" 

LIC_DIR="/etc/.sn"
LIC_PATH="$LIC_DIR/lic"
INSTALL_DIR="/etc/SN"

# ============================
# COLORES
# ============================
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'
BOLD='\033[1m'

line() {
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
}

step() { printf " ${C}•${N} ${W}%s${N} " "$1"; }
ok()   { echo -e "${G}[OK]${N}"; }
fail() { echo -e "${R}[FAIL]${N}"; }

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
# DEPENDENCIAS
# ============================
install_deps() {
  clear
  line
  echo -e "${Y}${BOLD}INSTALANDO DEPENDENCIAS${N}"
  line

  step "Actualizando repositorios"
  apt-get update && ok

  step "Herramientas base"
  apt-get install -y curl git sudo ca-certificates && ok

  step "Compresión"
  apt-get install -y zip unzip && ok

  step "Redes"
  apt-get install -y ufw iptables socat netcat-openbsd net-tools && ok

  step "Python"
  apt-get install -y python3 python3-pip openssl && ok

  step "Utilidades"
  apt-get install -y screen cron lsof nano at mlocate && ok

  step "Procesamiento"
  apt-get install -y jq bc gawk grep && ok

  step "Node.js"
  apt-get install -y nodejs npm && ok

  step "Banners"
  apt-get install -y toilet figlet cowsay lolcat && ok
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

    # Valida: debe empezar por SN- y tener mínimo 10 letras/números más
    if [[ ! "$KEY" =~ ^SN-[a-zA-Z0-9]{10,}$ ]]; then
      echo -e "${R}Formato inválido. Debe empezar con SN- y tener mínimo 10 caract. alfanuméricos.${N}"
      continue
    fi
    break
  done

  step "Validando key"
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

  # Debe tener "ok": true en JSON
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
# INSTALAR PANEL
# ============================
install_panel() {
  clear
  line
  echo -e "${Y}${BOLD}INSTALANDO PANEL${N}"
  line

  step "Clonando repositorio"
  rm -rf "$INSTALL_DIR"
  git clone --depth 1 -b "$REPO_BRANCH" \
    "https://github.com/$REPO_OWNER/$REPO_NAME.git" \
    "$INSTALL_DIR"
  ok

  step "Asignando permisos"
  chmod +x "$INSTALL_DIR/menu"
  find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} \;
  ok

  step "Creando comandos globales"

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
# BANNER DE BIENVENIDA MEJORADO
# ============================
install_banner() {
  step "Instalando banner de bienvenida mejorado"

  touch /root/.hushlogin
  chmod 600 /root/.hushlogin

  # Reemplazar cualquier banner anterior de SinNombre
  sed -i '/SinNombre - Welcome banner/,/fi/d' /root/.bashrc 2>/dev/null || true
  sed -i '/SinNombre - Welcome banner/,/fi$/d' /root/.bashrc 2>/dev/null || true

  # Agregar el banner mejorado - VERSIÓN CORREGIDA
  cat >> /root/.bashrc <<'EOF'

# ============================
# SinNombre - Welcome banner (MEJORADO)
# ============================
if [[ $- == *i* ]]; then
    [[ -n "${SN_WELCOME_SHOWN:-}" ]] && return
    export SN_WELCOME_SHOWN=1
    
    clear
    
    # Definir colores (ANSI escape codes)
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    BOLD='\033[1m'
    RESET='\033[0m'
    
    # Función para centrar texto
    center() {
        local text="$1"
        local width="${2:-80}"
        local padding=$(( (width - ${#text}) / 2 ))
        printf "%${padding}s%s%${padding}s\n" "" "$text" ""
    }
    
    # Obtener información del sistema
    USER_INFO="${USER}@$(hostname)"
    OS_INFO="$(grep '^PRETTY_NAME' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || uname -s)"
    UPTIME_INFO="$(uptime -p 2>/dev/null | sed 's/up //' || uptime)"
    MEM_INFO="$(free -h 2>/dev/null | awk '/^Mem:/ {print $3 "/" $2}' || echo 'N/A')"
    SHELL_INFO="${SHELL##*/}"
    
    # Banner principal
    echo ""
    
    # Intentar usar herramientas disponibles para el banner
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
    
    # Línea decorativa
    echo -e "${BLUE}$(printf '%.0s═' $(seq 1 $(tput cols 2>/dev/null || echo 60)))${RESET}"
    
    # Información del sistema
    echo -e "${BOLD}${YELLOW}💻  Sistema:${RESET} ${WHITE}${OS_INFO}${RESET}"
    echo -e "${BOLD}${YELLOW}👤  Usuario:${RESET} ${GREEN}${USER_INFO}${RESET}"
    echo -e "${BOLD}${YELLOW}⏱️   Uptime:${RESET} ${CYAN}${UPTIME_INFO}${RESET}"
    echo -e "${BOLD}${YELLOW}🧠  Memoria:${RESET} ${MAGENTA}${MEM_INFO}${RESET}"
    echo -e "${BOLD}${YELLOW}🐚  Shell:${RESET} ${RED}${SHELL_INFO}${RESET}"
    
    # Línea decorativa
    echo -e "${BLUE}$(printf '%.0s═' $(seq 1 $(tput cols 2>/dev/null || echo 60)))${RESET}"
    
    # Comandos disponibles
    echo -e "${BOLD}${WHITE}Comandos disponibles:${RESET}"
    echo -e "  ${GREEN}menu${RESET}   - Menú principal interactivo"
    echo -e "  ${GREEN}sn${RESET}     - Acceso rápido a funciones"
    
    # Fecha y hora actual
    echo -e "\n${BOLD}${WHITE}📅  $(date '+%A, %d de %B de %Y - %H:%M:%S')${RESET}"
    
    # Mensaje personalizado según la hora
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
# CONFIGURACIÓN ADICIONAL
# ============================
setup_additional() {
  step "Configurando entorno adicional"
  
  # Crear alias útiles
  cat > /root/.bash_aliases <<'EOF'
# Alias útiles para SinNombre
alias ll='ls -la --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias cls='clear'
alias sn-status='systemctl status sn-panel 2>/dev/null || echo "Servicio no configurado"'
alias sn-logs='tail -f /var/log/sn-panel.log 2>/dev/null || echo "Log no encontrado"'
alias sn-update='cd /etc/SN && git pull'
EOF

  # Cargar aliases en .bashrc si no están ya
  if ! grep -q "\.bash_aliases" /root/.bashrc; then
    echo -e "\n# Cargar aliases" >> /root/.bashrc
    echo "[[ -f ~/.bash_aliases ]] && . ~/.bash_aliases" >> /root/.bashrc
  fi

  ok
}

# ============================
# VERIFICACIÓN FINAL
# ============================
verify_installation() {
  step "Verificando instalación"
  
  # Verificar que los comandos estén instalados
  if [[ -f "/usr/local/bin/sn" && -f "/usr/local/bin/menu" ]]; then
    echo -e "${G}✓ Comandos instalados correctamente${N}"
  else
    echo -e "${R}✗ Error en la instalación de comandos${N}"
    return 1
  fi
  
  # Verificar licencia
  if [[ -f "$LIC_PATH" ]]; then
    echo -e "${G}✓ Licencia activada${N}"
  else
    echo -e "${R}✗ Licencia no encontrada${N}"
    return 1
  fi
  
  # Verificar instalación del panel
  if [[ -d "$INSTALL_DIR" && -f "$INSTALL_DIR/menu" ]]; then
    echo -e "${G}✓ Panel instalado correctamente${N}"
  else
    echo -e "${R}✗ Error en la instalación del panel${N}"
    return 1
  fi
  
  ok
}

# ============================
# FIN
# ============================
finish() {
  line
  echo -e "${G}${BOLD}INSTALACIÓN COMPLETA${N}"
  line
  echo -e "${W}Usa:${N} ${C}menu${N} ${W}o${N} ${C}sn${N}"
  echo -e "${W}Reinicia la sesión SSH o ejecuta:${N} ${C}source ~/.bashrc${N}"
  echo ""
  
  # Mostrar banner de prueba (corregido)
  echo -e "${Y}${BOLD}Vista previa del banner:${N}"
  echo -e "${C}$(printf '%.0s─' $(seq 1 60))${N}"
  
  # Simular el banner (versión simplificada)
  echo -e "${C}╔════════════════════════════════╗${N}"
  echo -e "${C}║        S I N N O M B R E        ║${N}"
  echo -e "${C}╚════════════════════════════════╝${N}"
  echo -e "${BOLD}${C}$(printf '%.0s═' $(seq 1 60))${N}"
  OS_INFO=$(grep '^PRETTY_NAME' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo 'Linux')
  echo -e "${Y}💻  Sistema:${N} ${W}${OS_INFO}${N}"
  echo -e "${Y}👤  Usuario:${N} ${G}${USER}@$(hostname)${N}"
  UPTIME_INFO=$(uptime -p 2>/dev/null | sed 's/up //' || echo 'N/A')
  echo -e "${Y}⏱️   Uptime:${N} ${C}${UPTIME_INFO}${N}"
  echo ""
}

# ============================
# LIMPIAR BANNER ANTERIOR SI HAY ERROR
# ============================
cleanup_old_banner() {
  step "Limpiando banners anteriores"
  
  # Limpiar posibles banners corruptos
  sed -i '/SN_WELCOME_SHOWN/d' /root/.bashrc 2>/dev/null || true
  sed -i '/SinNombre - Welcome/,/^fi$/d' /root/.bashrc 2>/dev/null || true
  sed -i '/if \[\[ \$- == \*i\* \]\]; then/,/^fi$/d' /root/.bashrc 2>/dev/null || true
  
  # Limpiar variables de color duplicadas
  sed -i '/^RED=.*/d' /root/.bashrc 2>/dev/null || true
  sed -i '/^GREEN=.*/d' /root/.bashrc 2>/dev/null || true
  sed -i '/^YELLOW=.*/d' /root/.bashrc 2>/dev/null || true
  sed -i '/^BLUE=.*/d' /root/.bashrc 2>/dev/null || true
  
  ok
}

# ============================
# EJECUCIÓN PRINCIPAL
# ============================
main() {
  # Limpiar primero banners viejos
  cleanup_old_banner
  
  # Instalar dependencias
  install_deps
  
  # Validar licencia
  validate_key
  
  # Instalar panel
  install_panel
  
  # Instalar banner
  install_banner
  
  # Configuración adicional
  setup_additional
  
  # Verificar instalación
  if verify_installation; then
    finish
  else
    echo -e "${R}Instalación completada con advertencias.${N}"
    echo -e "${Y}Algunos componentes pueden necesitar configuración manual.${N}"
  fi
}

# Ejecutar
main
