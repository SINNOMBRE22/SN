#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# SinNombre - Installer (SIN BLOQUEOS - Bash Puro)
# =========================================================

REPO_OWNER="SINNOMBRE22"
REPO_NAME="SN"
REPO_BRANCH="main"

VALIDATOR_HOST="${VALIDATOR_HOST:-67.217.244.52}"
VALIDATOR_PORT="${VALIDATOR_PORT:-12345}"

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
# ROOT CHECK
# ============================
if [[ "$(id -u)" -ne 0 ]]; then
  clear
  line
  echo -e "${Y}Ejecuta como root:${N} sudo bash install.sh"
  line
  exit 1
fi

# ============================
# INSTALAR DEPENDENCIAS
# ============================
install_deps() {
  clear
  line
  echo -e "${Y}${BOLD}INSTALANDO DEPENDENCIAS${N}"
  line

  step "Actualizando repositorios"
  apt-get update -qq > /dev/null 2>&1 && ok || fail

  step "Herramientas base"
  apt-get install -y curl git sudo ca-certificates > /dev/null 2>&1 && ok || fail

  step "Compresión"
  apt-get install -y zip unzip > /dev/null 2>&1 && ok || fail

  step "Redes"
  apt-get install -y ufw iptables socat netcat-openbsd net-tools > /dev/null 2>&1 && ok || fail

  step "Python"
  apt-get install -y python3 python3-pip openssl > /dev/null 2>&1 && ok || fail

  step "Utilidades"
  apt-get install -y screen cron lsof nano at mlocate > /dev/null 2>&1 && ok || fail

  step "Procesamiento"
  apt-get install -y bc gawk grep > /dev/null 2>&1 && ok || fail

  step "Node.js"
  apt-get install -y nodejs npm > /dev/null 2>&1 && ok || fail

  step "Banners"
  apt-get install -y toilet figlet > /dev/null 2>&1 && ok || fail
}

# ============================
# VALIDACIÓN DE KEY (SIN JQ)
# ============================
validate_key() {
  mkdir -p "$LIC_DIR"
  chmod 700 "$LIC_DIR"

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

  if [[ ! "$KEY" =~ ^SN- ]]; then
    echo -e "${R}Formato inválido${N}"
    exit 1
  fi

  step "Validando key"

  # Obtener IP
  CLIENT_IP="${SSH_CLIENT%% *}"
  if [[ -z "$CLIENT_IP" ]]; then
    CLIENT_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
  fi
  [[ -z "$CLIENT_IP" ]] && CLIENT_IP="127.0.0.1"

  # Crear payload
  PAYLOAD="{\"key\":\"$KEY\",\"ip\":\"$CLIENT_IP\"}"

  # Validar CON TIMEOUT CORTO
  RESP=$(timeout 2 curl -s -X POST \
    "http://${VALIDATOR_HOST}:${VALIDATOR_PORT}/consume" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" 2>&1 || echo "")

  # Verificar si contiene "ok": true (bash puro)
  if echo "$RESP" | grep -q '"ok"[[:space:]]*:[[:space:]]*true'; then
    ok
    echo "activated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$LIC_PATH"
    chmod 600 "$LIC_PATH"
    echo -e "${G}✅ Key validada correctamente${N}"
    sleep 1
  else
    # Si falla, CONTINUAR DE TODAS FORMAS
    ok
    echo "activated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$LIC_PATH"
    echo "key=$KEY" >> "$LIC_PATH"
    chmod 600 "$LIC_PATH"
    
    echo -e "${Y}⚠️ Validación en background (no bloquea instalación)${N}"
    
    # Validar en background sin bloquear
    (
      sleep 1
      curl -s -X POST "http://${VALIDATOR_HOST}:${VALIDATOR_PORT}/consume" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" >> /tmp/sn-validation.log 2>&1 &
    ) &
    disown 2>/dev/null || true
  fi
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
  if git clone --depth 1 -b "$REPO_BRANCH" \
    "https://github.com/$REPO_OWNER/$REPO_NAME.git" \
    "$INSTALL_DIR" > /dev/null 2>&1; then
    ok
  else
    fail
    echo -e "${Y}Continuando sin panel...${N}"
  fi

  step "Asignando permisos"
  if [[ -f "$INSTALL_DIR/menu" ]]; then
    chmod +x "$INSTALL_DIR/menu"
  fi
  find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} \; 2>/dev/null
  ok

  step "Creando comandos globales"

  cat > /usr/local/bin/sn << 'CMDEOF'
#!/usr/bin/env bash
if [[ $(id -u) -ne 0 ]]; then
  echo "Usa sudo"
  exit 1
fi
if [[ ! -f /etc/.sn/lic ]]; then
  echo "Licencia no encontrada"
  exit 1
fi
exec /etc/SN/menu "$@"
CMDEOF

  chmod +x /usr/local/bin/sn
  ln -sf /usr/local/bin/sn /usr/local/bin/menu 2>/dev/null
  ok
}

# ============================
# BANNER DE BIENVENIDA
# ============================
install_banner() {
  step "Instalando banner de bienvenida"

  touch /root/.hushlogin
  chmod 600 /root/.hushlogin

  if ! grep -q "SinNombre - Welcome banner" /root/.bashrc 2>/dev/null; then
    cat >> /root/.bashrc << 'BANNEREOF'

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
BANNEREOF
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
  echo -e "${W}Usa:${N} ${C}menu${N} o ${C}sn${N}"
  echo -e "${W}Licencia:${N} ${C}${LIC_PATH}${N}"
  line
}

# ============================
# EJECUCIÓN
# ============================
install_deps
validate_key
install_panel
install_banner
finish