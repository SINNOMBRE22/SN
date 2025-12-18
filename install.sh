#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# SinNombre - Installer Profesional (Modo Discreto)
# Muestra lista de dependencias antes de instalar
# Configura inicio limpio con solo el banner visible
# =========================================================

REPO_OWNER="SINNOMBRE22"
REPO_NAME="SN"
REPO_BRANCH="main"
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}.git"

INSTALL_DIR="/etc/SN"
MENU_PATH="${INSTALL_DIR}/menu"

# Colores (manteniendo tu esquema)
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'
W='\033[1;37m'; N='\033[0m'; D='\033[2m'; BOLD='\033[1m'

# Línea decorativa
sn_line() { echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }

# ----------------------------
# Argumentos
# ----------------------------
START_AFTER=false
for arg in "$@"; do
  case "$arg" in
    --start) START_AFTER=true ;;
  esac
done

# ----------------------------
# Funciones Principales
# ----------------------------
require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    clear
    sn_line
    echo -e "${Y}⚠️  Permisos insuficientes${N}"
    echo -e "${W}Ejecuta con:${N} ${C}sudo bash install.sh${N}"
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
  echo -e "${D}Instalador profesional${N}"
  echo ""
}

step() {
  local msg="$1"
  printf " ${C}›${N} %b" "${W}${msg}${N}"
  local pad=$(( 30 - ${#msg} ))
  (( pad < 1 )) && pad=1
  printf "%*s" "$pad" "" | tr ' ' '.'
  printf " "
}
ok()   { echo -e "${G}✓${N}"; }
fail() { echo -e "${R}✗${N}"; }

# ----------------------------
# Lista de Dependencias
# ----------------------------
show_dependency_list() {
  echo ""
  sn_line
  echo -e "${Y}${BOLD}📦 Dependencias requeridas:${N}"
  sn_line
  
  local deps=(
    "Sistema base: ca-certificates, curl, git"
    "Interfaz: toilet, figlet, cowsay, lolcat"
    "Utilidades: sudo, zip, unzip, nano, screen"
    "Redes: ufw, iptables, net-tools, socat, netcat"
    "Lenguajes: python3, python3-pip, nodejs, npm, jq"
    "Servicios: openssl, cron, at, lsof, mlocate"
    "Herramientas: gawk, grep, bc, bsdutils"
  )
  
  for dep in "${deps[@]}"; do
    echo -e " ${C}•${N} ${W}${dep}${N}"
  done
  
  echo ""
  sn_line
  echo -e "${D}Se instalarán automáticamente si no están presentes${N}"
  sn_line
  echo ""
}

# ----------------------------
# Gestión de Paquetes (Discreta)
# ----------------------------
apt_fix_if_needed() {
  dpkg --configure -a >/dev/null 2>&1 || true
  apt-get -f install -y >/dev/null 2>&1 || true
}

run_discreet() {
  local cmd="$1"
  local log="/tmp/sn_install.log"
  
  # Solo muestra errores si ocurren
  if bash -lc "${cmd}" >>"${log}" 2>&1; then
    return 0
  else
    # Reintento con reparación
    apt_fix_if_needed
    if bash -lc "${cmd}" >>"${log}" 2>&1; then
      return 0
    fi
    return 1
  fi
}

apt_update() {
  step "Sincronizando repositorios"
  if run_discreet "apt-get update"; then
    ok
  else
    fail
    return 1
  fi
}

apt_upgrade() {
  step "Actualizando sistema base"
  run_discreet "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y" && ok || fail
}

install_pkg() {
  local pkg="$1"
  step "Instalando ${pkg}"
  if run_discreet "DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${pkg}"; then
    ok
  else
    fail
  fi
}

install_any_of() {
  local label="$1"; shift
  local candidates=("$@")
  step "Instalando ${label}"
  
  for p in "${candidates[@]}"; do
    if run_discreet "DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${p}"; then
      ok
      return 0
    fi
  done
  fail
  return 1
}

# ----------------------------
# Configuración de Banner Limpio
# ----------------------------
ensure_clean_banner() {
  step "Configurando inicio limpio"
  
  # Crear archivo para silenciar mensajes del sistema
  touch /root/.hushlogin >/dev/null 2>&1
  
  # Configurar .bashrc para limpiar pantalla y mostrar banner
  local bashrc="/root/.bashrc"
  local marker="# === SinNombre Banner === #"
  
  if ! grep -q "${marker}" "${bashrc}" 2>/dev/null; then
    cat >>"${bashrc}" <<'EOF'

# === SinNombre Banner === #
if [[ $- == *i* ]] && [[ -z "${SN_BANNER_SHOWN:-}" ]]; then
  export SN_BANNER_SHOWN=1
  
  # Limpiar pantalla completamente
  clear
  
  # Mostrar banner
  echo ""
  if command -v toilet >/dev/null 2>&1; then
    toilet -f slant -F metal "SinNombre" 2>/dev/null || echo "=== SinNombre ==="
  else
    echo -e "\033[0;36m\033[1mSinNombre\033[0m"
  fi
  echo -e "\033[2mSistema profesional\033[0m"
  echo ""
  echo -e "\033[1;37mPara iniciar digite:\033[0m \033[0;32mmenu\033[0m \033[1;37mo\033[0m \033[0;32msn\033[0m"
  echo ""
fi
EOF
  fi
  
  # Configurar .profile también
  local profile="/root/.profile"
  if [[ -f "${profile}" ]] && ! grep -q "${marker}" "${profile}" 2>/dev/null; then
    cat >>"${profile}" <<'EOF'

# === SinNombre Banner === #
if [[ $- == *i* ]] && [[ -z "${SN_BANNER_SHOWN:-}" ]]; then
  export SN_BANNER_SHOWN=1
  clear
  # El banner se carga desde .bashrc
fi
EOF
  fi
  
  ok
}

# ----------------------------
# Instalación de Dependencias
# ----------------------------
install_dependencies() {
  echo ""
  sn_line
  echo -e "${Y}${BOLD}🔧 Preparando sistema...${N}"
  sn_line

  apt_fix_if_needed
  apt_update
  apt_upgrade

  echo ""
  sn_line
  echo -e "${Y}${BOLD}📥 Instalando componentes${N}"
  sn_line

  # Instalación en bloques temáticos
  echo -e "\n${C}📦 Sistema base${N}"
  install_pkg ca-certificates
  install_pkg curl
  install_pkg git
  install_pkg toilet

  echo -e "\n${C}🛠️  Utilidades esenciales${N}"
  install_pkg sudo
  install_any_of "bsd utils" bsdextrautils bsdmainutils util-linux
  install_pkg zip
  install_pkg unzip
  install_pkg ufw
  install_any_of "python" python-is-python3 python3
  install_pkg python3-pip
  install_pkg openssl
  install_pkg screen
  install_any_of "cron" cron cronie
  install_pkg iptables
  install_pkg lsof
  install_pkg nano
  install_pkg at
  install_pkg mlocate
  install_pkg gawk
  install_pkg grep
  install_pkg bc

  echo -e "\n${C}🌐 Componentes de red${N}"
  install_pkg jq
  install_pkg nodejs
  install_pkg npm
  install_pkg socat
  install_any_of "netcat" netcat-openbsd netcat-traditional netcat
  install_pkg net-tools

  echo -e "\n${C}🎨 Elementos visuales${N}"
  install_pkg figlet
  install_pkg cowsay
  install_any_of "lolcat" lolcat ruby-lolcat
}

# ----------------------------
# Instalación del Proyecto
# ----------------------------
install_project() {
  echo ""
  sn_line
  echo -e "${Y}${BOLD}🚀 Instalando aplicación${N}"
  sn_line

  step "Preparando entorno"
  mkdir -p "${INSTALL_DIR}" && ok || { fail; exit 1; }

  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    step "Actualizando versión"
    (cd "${INSTALL_DIR}" && git fetch --all --prune && git reset --hard "origin/${REPO_BRANCH}") && ok || { fail; exit 1; }
  else
    step "Descargando componentes"
    git clone --depth 1 -b "${REPO_BRANCH}" "${REPO_URL}" "${INSTALL_DIR}" >/dev/null 2>&1 && ok || { fail; exit 1; }
  fi

  step "Verificando integridad"
  [[ -f "${MENU_PATH}" ]] && ok || { fail; exit 1; }
}

apply_permissions() {
  echo ""
  sn_line
  echo -e "${Y}${BOLD}🔐 Configurando permisos${N}"
  sn_line

  step "Habilitando ejecución"
  chmod +x "${MENU_PATH}" && ok || fail
  
  step "Configurando scripts"
  find "${INSTALL_DIR}" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \; 2>/dev/null && ok || ok
}

setup_commands() {
  echo ""
  sn_line
  echo -e "${Y}${BOLD}⚡ Configurando accesos${N}"
  sn_line

  step "Creando comando 'sn'"
  cat >/usr/local/bin/sn <<'EOF'
#!/usr/bin/env bash
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Acceso restringido. Use: sudo sn"
  exit 1
fi
exec /etc/SN/menu "$@"
EOF
  chmod +x /usr/local/bin/sn && ok || fail

  step "Creando comando 'menu'"
  cat >/usr/local/bin/menu <<'EOF'
#!/usr/bin/env bash
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Acceso restringido. Use: sudo menu"
  exit 1
fi
exec /etc/SN/menu "$@"
EOF
  chmod +x /usr/local/bin/menu && ok || fail
}

# ----------------------------
# Finalización
# ----------------------------
finish() {
  echo ""
  sn_line
  echo -e "${G}${BOLD}✅ Instalación completada${N}"
  sn_line
  echo ""
  echo -e "${W}Comandos disponibles:${N}"
  echo -e "  ${C}sn${N}    - Acceso principal"
  echo -e "  ${C}menu${N}  - Menú del sistema"
  echo ""
  echo -e "${D}Reinicia la sesión o ejecuta:${N}"
  echo -e "  ${C}source ~/.bashrc${N}"
  echo ""
}

# ----------------------------
# Función Principal
# ----------------------------
main() {
  require_root
  
  clear
  banner
  
  # Mostrar resumen de dependencias
  show_dependency_list
  
  # Proceso de instalación
  install_dependencies
  install_project
  apply_permissions
  setup_commands
  ensure_clean_banner
  finish

  # Iniciar automáticamente si se solicita
  if [[ "${START_AFTER}" == "true" ]]; then
    exec "${MENU_PATH}"
  fi
}

# Ejecutar
main "$@"
