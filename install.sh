#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# SinNombre - Installer Profesional + LICENCIA
# Valida key ANTES de instalar y crea /etc/.sn/lic
# =========================================================

REPO_OWNER="SINNOMBRE22"
REPO_NAME="SN"
REPO_BRANCH="main"

# ============================
# VALIDACIÓN DE KEY
# ============================
VALIDATOR_URL="http://74.208.112.115:8888/validate"
VALIDATOR_SECRET="zFBujS1Hjc8M0FgqpuhEd_zWbBQko3VFvQLxPJPBHqc"

# ============================
# LICENCIA LOCAL (marca)
# ============================
LIC_DIR="/etc/.sn"
LIC_PATH="${LIC_DIR}/lic"

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'
W='\033[1;37m'; N='\033[0m'; D='\033[2m'; BOLD='\033[1m'

sn_line() { echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }

# ----------------------------
# Args
# ----------------------------
START_AFTER=false
KEY_ARG=""
for arg in "$@"; do
  case "$arg" in
    --start) START_AFTER=true ;;
    --key=*) KEY_ARG="${arg#--key=}" ;;
  esac
done

# Permite: --key SN-XXXX (dos args)
get_key_arg() {
  local next_is_key=false
  for arg in "$@"; do
    if $next_is_key; then
      echo "$arg"
      return 0
    fi
    if [[ "$arg" == "--key" ]]; then
      next_is_key=true
    fi
  done
  return 1
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    clear
    sn_line
    echo -e "${Y}Debes ejecutar como root.${N}"
    echo -e "${W}Usa:${N} ${C}sudo bash install.sh${N}"
    sn_line
    exit 1
  fi
}

banner() {
  echo ""
  if command -v toilet >/dev/null 2>&1; then
    toilet -f slant -F metal "SinNombre" 2>/dev/null || true
  else
    echo -e "${C}${BOLD}SinNombre${N}"
  fi
  echo -e "${D}Instalador del panel${N}"
  echo ""
}

step() {
  local msg="$1"
  printf " ${C}•${N} %b" "${W}${msg}${N}"
  local pad=$(( 30 - ${#msg} ))
  (( pad < 1 )) && pad=1
  printf "%*s" "$pad" "" | tr ' ' '.'
  printf " "
}
ok()   { echo -e "${G}[OK]${N}"; }
fail() { echo -e "${R}[FAIL]${N}"; }

apt_fix_if_needed() {
  dpkg --configure -a >/dev/null 2>&1 || true
  apt-get -f install -y >/dev/null 2>&1 || true
}

ensure_deps() {
  apt_fix_if_needed
  step "Actualizando repositorios"
  apt-get update >/dev/null 2>&1 && ok || fail

  step "Instalando dependencias mínimas"
  apt-get install -y curl git ca-certificates >/dev/null 2>&1 && ok || fail
}

ask_and_validate_key() {
  local provided_key="${1:-}"

  clear
  sn_line
  echo -e "${Y}${BOLD}Activación requerida${N}"
  sn_line
  echo ""

  local key=""
  if [[ -n "$provided_key" ]]; then
    key="$provided_key"
  else
    echo -e "${W}Ingresa tu Key:${N}"
    read -r -p "KEY: " key
  fi

  key="$(echo -n "$key" | tr -d ' \r\n')"
  if [[ -z "$key" ]]; then
    echo -e "${R}Key vacía.${N}"
    exit 1
  fi
  if [[ "$key" != SN-* ]]; then
    echo -e "${R}Formato inválido.${N} Debe iniciar con ${Y}SN-${N}"
    exit 1
  fi

  step "Validando key"

  local resp
  resp="$(curl -fsS -G "$VALIDATOR_URL" \
    --data-urlencode "key=$key" \
    -H "X-API-KEY: $VALIDATOR_SECRET" 2>/dev/null || true)"

  if echo "$resp" | grep -q '"ok"[[:space:]]*:[[:space:]]*true'; then
    ok
    echo -e "${G}${BOLD}Key válida. Continuando instalación...${N}"

    # Crear marca local de licencia (NO es la seguridad real, solo marca)
    mkdir -p "$LIC_DIR"
    chmod 700 "$LIC_DIR"
    {
      echo "activated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
      echo "validator=$VALIDATOR_URL"
    } > "$LIC_PATH"
    chmod 600 "$LIC_PATH"

    sleep 1
    return 0
  fi

  fail
  echo ""
  echo -e "${R}${BOLD}Key inválida, expirada o ya usada.${N}"
  echo -e "${D}Respuesta: ${resp:-"(sin respuesta)"}${N}"
  echo ""
  exit 1
}

setup_login_banner() {
  step "Configurando banner de login"

  touch /root/.hushlogin 2>/dev/null || true
  chmod 600 /root/.hushlogin 2>/dev/null || true

  grep -q "SinNombre - Welcome banner" /root/.bashrc 2>/dev/null || cat >> /root/.bashrc << 'EOF'

# ============================
# SinNombre - Welcome banner
# ============================
if [[ $- == *i* ]]; then
  [[ -n "${SN_WELCOME_SHOWN:-}" ]] && return
  export SN_WELCOME_SHOWN=1

  clear

  echo ""
  if command -v toilet >/dev/null 2>&1; then
    toilet -f slant -F metal "SinNombre" 2>/dev/null || true
  else
    echo "SinNombre"
  fi
  echo "Para iniciar digite: menu o sn"
  echo ""
fi
EOF

  ok
}

install_project() {
  echo ""
  sn_line
  echo -e "${Y}${BOLD}Instalando panel...${N}"
  sn_line

  step "Creando directorio discreto"
  INSTALL_DIR="/etc/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)"
  mkdir -p "$INSTALL_DIR" >/dev/null 2>&1
  ok

  step "Clonando repositorio"
  REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}.git"
  git clone --depth 1 -b "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR" >/dev/null 2>&1 && ok || fail

  MENU_PATH="$INSTALL_DIR/menu"

  step "Asignando permisos"
  chmod +x "$MENU_PATH" 2>/dev/null || true
  find "$INSTALL_DIR" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
  ok

  step "Creando comandos globales (sn/menu)"
  cat > /usr/local/bin/sn <<EOF
#!/usr/bin/env bash
if [[ "\${EUID:-\$(id -u)}" -ne 0 ]]; then
  echo "Acceso denegado. Ejecuta en root o con sudo."
  echo "Usa: sudo sn"
  exit 1
fi
exec "$MENU_PATH" "\$@"
EOF
  chmod +x /usr/local/bin/sn

  cat > /usr/local/bin/menu <<EOF
#!/usr/bin/env bash
if [[ "\${EUID:-\$(id -u)}" -ne 0 ]]; then
  echo "Acceso denegado. Ejecuta en root o con sudo."
  echo "Usa: sudo menu"
  exit 1
fi
exec "$MENU_PATH" "\$@"
EOF
  chmod +x /usr/local/bin/menu
  ok
}

finish() {
  echo ""
  sn_line
  echo -e "${G}${BOLD}Instalación completada${N}"
  sn_line
  echo ""
  echo -e "${W}Inicia con:${N} ${C}menu${N} ${W}o${N} ${C}sn${N}"
  echo -e "${D}Licencia local:${N} ${C}${LIC_PATH}${N}"
  echo ""
}

main() {
  require_root

  # Obtener key por --key= o --key SN-XXXX o pedirla
  if [[ -z "$KEY_ARG" ]]; then
    KEY_ARG="$(get_key_arg "$@" || true)"
  fi

  ensure_deps
  ask_and_validate_key "${KEY_ARG:-}"

  clear
  banner

  install_project
  setup_login_banner

  finish

  if [[ "${START_AFTER}" == "true" ]]; then
    exec /usr/local/bin/menu
  fi
}

main "$@"
