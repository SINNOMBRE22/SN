#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# SinNombre - Installer 
# VALIDATOR FIXED (usa el que SÍ funciona)
# =========================================================

REPO_OWNER="SINNOMBRE22"
REPO_NAME="SN"
REPO_BRANCH="main"

VALIDATOR_URL="http://74.208.112.115:8888/consume"

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

  read -rp "KEY: " KEY
  KEY="$(echo -n "$KEY" | tr -d ' \r\n')"

  [[ "$KEY" == SN-* ]] || {
    echo -e "${R}Formato inválido${N}"
    exit 1
  }

  step "Validando key"

  RESP="$(curl -fsS -X POST "$VALIDATOR_URL" \
    -H "Content-Type: application/json" \
    -d "{\"key\":\"$KEY\"}" || true)"

  echo "$RESP" | grep -q '"ok"[[:space:]]*:[[:space:]]*true' || {
    echo -e "${R}Key inválida o usada${N}"
    exit 1
  }

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
# BANNER DE BIENVENIDA 
# ============================
install_banner() {
  step "Instalando banner de bienvenida"

  touch /root/.hushlogin
  chmod 600 /root/.hushlogin

  grep -q "SinNombre - Welcome banner" /root/.bashrc 2>/dev/null || cat >> /root/.bashrc <<'EOF'

# ============================
# SinNombre - Welcome banner
# ============================
if [[ $- == *i* ]]; then
  [[ -n "${SN_WELCOME_SHOWN:-}" ]] && return
  export SN_WELCOME_SHOWN=1

  clear

  if command -v toilet >/dev/null 2>&1; then
    toilet -f slant -F metal "SinNombre" 2>/dev/null || true
  else
    echo "SinNombre"
  fi
  echo "Comandos: menu | sn"
  echo ""
fi
EOF

  ok
}

# ============================
# FIN
# ============================
finish() {
  line
  echo -e "${G}${BOLD}INSTALACIÓN COMPLETA${N}"
  line
  echo -e "${W}Usa:${N} ${C}menu${N}"
  echo -e "${W}Licencia:${N} ${C}${LIC_PATH}${N}"
}

# ============================
# EJECUCIÓN
# ============================
install_deps
validate_key
install_panel
install_banner
finish
