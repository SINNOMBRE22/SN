#!/usr/bin/env bash
set -e

# =========================================================
# SinNombre - Installer Profesional + Licencia + Banner
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

step() { echo -e " ${C}•${N} ${W}$1${N}"; }
ok()   { echo -e "   ${G}[OK]${N}"; }

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
# DEPENDENCIAS (VISIBLE)
# ============================
install_deps() {
  clear
  line
  echo -e "${Y}${BOLD}INSTALANDO DEPENDENCIAS${N}"
  line

  step "Actualizando repositorios"
  apt-get update
  ok

  echo ""
  step "Herramientas base"
  apt-get install -y curl git sudo ca-certificates
  ok

  echo ""
  step "Compresión"
  apt-get install -y zip unzip
  ok

  echo ""
  step "Redes"
  apt-get install -y ufw iptables socat netcat-openbsd net-tools
  ok

  echo ""
  step "Python"
  apt-get install -y python3 python3-pip openssl
  ok

  echo ""
  step "Utilidades del sistema"
  apt-get install -y screen cron lsof nano at mlocate
  ok

  echo ""
  step "Procesamiento de datos"
  apt-get install -y jq bc gawk grep
  ok

  echo ""
  step "Node.js"
  apt-get install -y nodejs npm
  ok

  echo ""
  step "Banners y decoración"
  apt-get install -y toilet figlet cowsay lolcat
  ok
}

# ============================
# KEY / LICENCIA
# ============================
validate_key() {
  clear
  line
  echo -e "${Y}${BOLD}ACTIVACIÓN DE LICENCIA${N}"
  line

  read -rp "KEY: " KEY
  KEY="$(echo "$KEY" | tr -d ' ')"

  [[ "$KEY" == SN-* ]] || {
    echo -e "${R}Formato inválido${N}"
    exit 1
  }

  step "Validando key"
  RESP=$(curl -s -X POST "$VALIDATOR_URL" \
    -H "Content-Type: application/json" \
    -d "{\"key\":\"$KEY\"}")

  echo "$RESP" | grep -q '"ok":true' || {
    echo -e "${R}Key inválida o usada${N}"
    exit 1
  }

  mkdir -p "$LIC_DIR"
  echo "activated=$(date)" > "$LIC_PATH"
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
[[ \$(id -u) -eq 0 ]] || exit 1
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

  # Silenciar mensajes del sistema
  touch /root/.hushlogin
  chmod 600 /root/.hushlogin

  # Banner en bashrc
  grep -q "SinNombre - Welcome banner" /root/.bashrc 2>/dev/null || cat >> /root/.bashrc <<'EOF'

# ============================
# SinNombre - Welcome banner
# ============================
if [[ $- == *i* ]]; then
  [[ -n "${SN_WELCOME_SHOWN:-}" ]] && return
  export SN_WELCOME_SHOWN=1

  clear

  R='\033[0;31m'
  G='\033[0;32m'
  Y='\033[1;33m'
  C='\033[0;36m'
  W='\033[1;37m'
  N='\033[0m'
  BOLD='\033[1m'

  echo ""
  if command -v toilet >/dev/null 2>&1; then
    toilet -f slant -F metal "SinNombre" 2>/dev/null || true
  else
    echo -e "${C}${BOLD}SinNombre${N}"
  fi
  echo -e "${W}Creador:${N} ${C}@SIN_NOMBRE22${N}"
  echo -e "${W}Comandos:${N} ${G}menu${N} ${W}o${N} ${G}sn${N}"
  echo ""
fi
EOF

  # Asegurar carga desde profile (SSH)
  grep -q "SinNombre - Welcome banner" /root/.profile 2>/dev/null || cat >> /root/.profile <<'EOF'

# ============================
# SinNombre - Welcome banner
# ============================
if [ -n "$BASH_VERSION" ]; then
  [ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
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
  echo -e "${W}Reconecta SSH para ver el banner${N}"
}

# ============================
# EJECUCIÓN
# ============================
install_deps
validate_key
install_panel
install_banner
finish
