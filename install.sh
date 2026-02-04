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
# BANNER DE BIENVENIDA ACTUALIZADO
# ============================
install_banner() {
  step "Instalando banner de bienvenida mejorado"

  # Reemplazar cualquier banner anterior
  sed -i '/SinNombre - Welcome banner/,/^fi$/d' /root/.bashrc 2>/dev/null || true

  # Agregar el banner actualizado
  cat >> /root/.bashrc <<'EOF'

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
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    BOLD='\033[1m'
    RESET='\033[0m'
    
    center() {
        local text="$1"
        local width="${2:-80}"
        local padding=$(( (width - ${#text}) / 2 ))
        printf "%${padding}s%s%${padding}s\n" "" "$text" ""
    }
    
    USER_INFO="${USER}@$(hostname)"
    OS_INFO="$(grep '^PRETTY_NAME' /etc/os-release | cut -d= -f2 | tr -d '"')"
    UPTIME="$(uptime -p | sed 's/up //')"

    echo -e "${CYAN}"
    center "╔════════════════════════════════╗"
    center "║     Bienvenido a SinNombre     ║"
    center "╚════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "${YELLOW}💻 Sistema:${RESET} ${WHITE}${OS_INFO}${RESET}"
    echo -e "${YELLOW}👤 Usuario:${RESET} ${GREEN}${USER_INFO}${RESET}"
    echo -e "${YELLOW}⏱️  Uptime:${RESET} ${CYAN}${UPTIME}${RESET}"
    echo -e "${YELLOW}📜 Comandos:${RESET} ${GREEN}sn${RESET}, ${GREEN}menu${RESET}"
    echo ""
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
