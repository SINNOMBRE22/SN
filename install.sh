#!/usr/bin/env bash
set -e

# =========================================================
# SinNombre - Installer Profesional + Licencia + Banner (FIX)
# =========================================================

REPO_OWNER="SINNOMBRE22"
REPO_NAME="SN"
REPO_BRANCH="main"

VALIDATOR_URL="http://74.208.112.115:8888/consume"

LIC_DIR="/etc/.sn"
LIC_PATH="$LIC_DIR/lic"
ACTIVATED="$LIC_DIR/.activated"
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
# DEPENDENCIAS
# ============================
install_deps() {
  clear
  line
  echo -e "${Y}${BOLD}INSTALANDO DEPENDENCIAS${N}"
  line

  step "Actualizando repositorios"
  apt-get update
  ok

  step "Instalando paquetes base"
  apt-get install -y curl git sudo ca-certificates \
    zip unzip ufw iptables socat netcat-openbsd net-tools \
    python3 python3-pip openssl screen cron lsof nano at \
    jq bc gawk nodejs npm toilet figlet cowsay lolcat
  ok
}

# ============================
# LICENCIA (FIX REAL)
# ============================
validate_key() {
  mkdir -p "$LIC_DIR"
  chmod 700 "$LIC_DIR"

  # Ya activado alguna vez → NO volver a consumir key
  if [[ -f "$ACTIVATED" ]]; then
    echo -e "${G}Licencia ya activada anteriormente${N}"

    # Si borraron lic, se restaura
    if [[ ! -f "$LIC_PATH" ]]; then
      echo "restored=$(date)" > "$LIC_PATH"
      chmod 600 "$LIC_PATH"
    fi
    sleep 1
    return
  fi

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

  echo "activated=$(date)" > "$ACTIVATED"
  echo "$KEY" > "$LIC_PATH"
  chmod 600 "$ACTIVATED" "$LIC_PATH"

  ok
}

# ============================
# PANEL
# ============================
install_panel() {
  clear
  line
  echo -e "${Y}${BOLD}INSTALANDO PANEL${N}"
  line

  step "Clonando repositorio"
  rm -rf "$INSTALL_DIR"
  git clone --depth 1 -b "$REPO_BRANCH" \
    "https://github.com/$REPO_OWNER/$REPO_NAME.git" "$INSTALL_DIR"
  ok

  step "Permisos"
  chmod +x "$INSTALL_DIR/menu"
  find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} \;
  ok

  step "Comando global"
  cat > /usr/local/bin/sn <<EOF
#!/usr/bin/env bash
[[ \$(id -u) -eq 0 ]] || exit 1
[[ -f "$LIC_PATH" ]] || { echo "Licencia no encontrada"; exit 1; }
exec "$INSTALL_DIR/menu" "\$@"
EOF

  chmod +x /usr/local/bin/sn
  ln -sf /usr/local/bin/sn /usr/local/bin/menu
  ok
}

# ============================
# BANNER
# ============================
install_banner() {
  step "Instalando banner de bienvenida"

  touch /root/.hushlogin

  grep -q "SinNombre - Welcome banner" /root/.bashrc 2>/dev/null || cat >> /root/.bashrc <<'EOF'

# === SinNombre - Welcome banner ===
if [[ $- == *i* ]]; then
  clear
  if command -v toilet >/dev/null; then
    toilet -f slant -F metal "SinNombre"
  else
    echo "SinNombre"
  fi
  echo "Comando: menu | sn"
fi
EOF

  ok
}

# ============================
# FIN
# ============================
install_deps
validate_key
install_panel
install_banner

line
echo -e "${G}${BOLD}INSTALACIÓN COMPLETA${N}"
line
echo -e "${W}Reinicia la vps Con reboot${N}"
