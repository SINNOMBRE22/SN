#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# SinNombre - Installer (Con validación NO BLOQUEANTE)
# =========================================================

REPO_OWNER="SINNOMBRE22"
REPO_NAME="SN"
REPO_BRANCH="main"

# IP DEL SERVIDOR DEL BOT (cambiar según tu caso)
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
[[ "$(id -u)" -ne 0 ]] && {
  clear
  line
  echo -e "${Y}Ejecuta como root:${N} sudo bash install.sh"
  line
  exit 1
}

# ============================
# INSTALAR DEPENDENCIAS
# ============================
install_deps() {
  clear
  line
  echo -e "${Y}${BOLD}INSTALANDO DEPENDENCIAS${N}"
  line

  step "Actualizando repositorios"
  apt-get update -qq && ok || fail

  step "Herramientas base"
  apt-get install -y curl git sudo ca-certificates jq > /dev/null 2>&1 && ok || fail

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
# VALIDACIÓN DE KEY
# ============================
validate_key() {
  mkdir -p "$LIC_DIR"
  chmod 700 "$LIC_DIR"

  # Si ya existe licencia, continuar
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

  # Obtener IP del cliente
  CLIENT_IP="${SSH_CLIENT%% *}"
  [[ -z "$CLIENT_IP" ]] && CLIENT_IP=$(hostname -I | awk '{print $1}')

  # Crear payload
  PAYLOAD="{\"key\":\"$KEY\",\"ip\":\"$CLIENT_IP\"}"

  # Validar CON TIMEOUT CORTO (no bloquea más de 3 segundos)
  # Si falla, continúa de todas formas
  RESP=$(timeout 3 curl -s -X POST \
    "http://${VALIDATOR_HOST}:${VALIDATOR_PORT}/consume" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" 2>/dev/null || echo "{\"ok\":false}")

  # Verificar respuesta
  if echo "$RESP" | jq . > /dev/null 2>&1; then
    OK=$(echo "$RESP" | jq -r '.ok // false')
  else
    OK="false"
  fi

  if [[ "$OK" == "true" ]]; then
    ok
    echo "activated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$LIC_PATH"
    chmod 600 "$LIC_PATH"
  else
    # Si falla la validación, guardar key igual (validación asíncrona)
    ok
    echo "activated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$LIC_PATH"
    echo "key=$KEY" >> "$LIC_PATH"
    chmod 600 "$LIC_PATH"
    
    echo -e "${Y}⚠️  Validación en segundo plano...${N}"
    # Validar async sin bloquear
    (
      sleep 1
      curl -s -X POST "http://${VALIDATOR_HOST}:${VALIDATOR_PORT}/consume" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" > /dev/null 2>&1
    ) &
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
  git clone --depth 1 -b "$REPO_BRANCH" \
    "https://github.com/$REPO_OWNER/$REPO_NAME.git" \
    "$INSTALL_DIR" > /dev/null 2>&1 && ok || fail

  step "Asignando permisos"
  chmod +x "$INSTALL_DIR/menu" 2>/dev/null
  find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} \; 2>/dev/null
  ok

  step "Creando comandos globales"

  cat > /usr/local/bin/sn <<CMDEOF
#!/usr/bin/env bash
[[ \$(id -u) -eq 0 ]] || { echo "Usa sudo"; exit 1; }
[[ -f $LIC_PATH ]] || { echo "Licencia no encontrada"; exit 1; }
exec $INSTALL_DIR/menu "\$@"
CMDEOF

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

  grep -q "SinNombre - Welcome banner" /root/.bashrc 2>/dev/null || cat >> /root/.bashrc <<'BANNEREOF'

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