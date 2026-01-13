#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# SinNombre - Installer Profesional + Licencia (FULL)
# =========================================================

REPO_OWNER="SINNOMBRE22"
REPO_NAME="SN"
REPO_BRANCH="main"

VALIDATOR_URL="http://74.208.112.115:8888/consume"

LIC_DIR="/etc/.sn"
LIC_PATH="${LIC_DIR}/lic"
INSTALL_DIR="/etc/SN"

# ============================
# COLORES
# ============================
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'
BOLD='\033[1m'; D='\033[2m'

sn_line() {
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
}

# ============================
# ARGUMENTOS
# ============================
START_AFTER=false
KEY_ARG=""

for arg in "$@"; do
  case "$arg" in
    --start) START_AFTER=true ;;
    --key=*) KEY_ARG="${arg#--key=}" ;;
  esac
done

get_key_arg() {
  local next=false
  for arg in "$@"; do
    $next && { echo "$arg"; return 0; }
    [[ "$arg" == "--key" ]] && next=true
  done
  return 1
}

# ============================
# VALIDACIONES
# ============================
require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] && return
  clear
  sn_line
  echo -e "${Y}Ejecuta como root:${N} sudo bash install.sh"
  sn_line
  exit 1
}

step() { printf " ${C}•${N} ${W}%s${N} " "$1"; }
ok()   { echo -e "${G}[OK]${N}"; }
fail() { echo -e "${R}[FAIL]${N}"; }

# ============================
# APT FIX
# ============================
apt_fix() {
  dpkg --configure -a >/dev/null 2>&1 || true
  apt-get -f install -y >/dev/null 2>&1 || true
}

# ============================
# DEPENDENCIAS (FULL)
# ============================
ensure_deps() {
  apt_fix

  step "Actualizando repositorios"
  apt-get update >/dev/null 2>&1 || { fail; exit 1; }
  ok

  step "Instalando dependencias del sistema"
  apt-get install -y \
    curl git ca-certificates sudo \
    zip unzip bsdmainutils util-linux \
    ufw iptables socat netcat-openbsd net-tools \
    python3 python3-pip openssl \
    screen cron lsof nano at mlocate \
    jq bc gawk grep \
    nodejs npm \
    toilet figlet cowsay lolcat \
    >/dev/null 2>&1 || { fail; exit 1; }

  ok
}

# ============================
# LICENCIA / KEY
# ============================
ask_and_validate_key() {
  local key="${1:-}"

  clear
  sn_line
  echo -e "${Y}${BOLD}Activación requerida${N}"
  sn_line

  [[ -z "$key" ]] && read -rp "KEY: " key
  key="$(echo "$key" | tr -d ' \r\n')"

  [[ "$key" == SN-* ]] || {
    echo -e "${R}Formato inválido (SN-XXXX)${N}"
    exit 1
  }

  step "Validando key"
  local resp
  resp="$(curl -fsS -X POST "$VALIDATOR_URL" \
    -H "Content-Type: application/json" \
    -d "{\"key\":\"$key\"}" || true)"

  echo "$resp" | grep -q '"ok"[[:space:]]*:[[:space:]]*true' || {
    fail
    echo -e "${R}Key inválida, usada o expirada${N}"
    exit 1
  }

  ok

  mkdir -p "$LIC_DIR"
  chmod 700 "$LIC_DIR"
  {
    echo "activated=$(date -u +%FT%TZ)"
    echo "validator=$VALIDATOR_URL"
  } > "$LIC_PATH"
  chmod 600 "$LIC_PATH"
}

# ============================
# INSTALACIÓN DEL PANEL
# ============================
install_project() {
  clear
  sn_line
  echo -e "${Y}${BOLD}Instalando panel SinNombre${N}"
  sn_line

  [[ "$INSTALL_DIR" == "/etc/SN" ]] || exit 1

  step "Clonando repositorio"
  rm -rf "$INSTALL_DIR"
  git clone --depth 1 -b "$REPO_BRANCH" \
    "https://github.com/${REPO_OWNER}/${REPO_NAME}.git" \
    "$INSTALL_DIR" >/dev/null 2>&1 || { fail; exit 1; }
  ok

  [[ -f "$INSTALL_DIR/menu" ]] || {
    echo -e "${R}Archivo menu no encontrado${N}"
    exit 1
  }

  step "Asignando permisos"
  chmod +x "$INSTALL_DIR/menu"
  find "$INSTALL_DIR" -type f -name "*.sh" -exec chmod +x {} \;
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
# FINAL
# ============================
finish() {
  sn_line
  echo -e "${G}${BOLD}Instalación completada${N}"
  sn_line
  echo -e "${W}Ejecuta:${N} ${C}menu${N} ${W}o${N} ${C}sn${N}"
  echo -e "${D}Licencia:${N} $LIC_PATH"
}

# ============================
# MAIN
# ============================
main() {
  require_root
  [[ -z "$KEY_ARG" ]] && KEY_ARG="$(get_key_arg "$@" || true)"
  ensure_deps
  ask_and_validate_key "$KEY_ARG"
  install_project
  finish
  $START_AFTER && exec menu
}

main "$@"
