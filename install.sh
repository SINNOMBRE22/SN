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

# Colores (EXACTAMENTE como los tenías)
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'
W='\033[1;37m'; N='\033[0m'; D='\033[2m'; BOLD='\033[1m'

# Línea decorativa (EXACTAMENTE como la tenías)
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
    echo -e "${Y}Debes ejecutar como root.${N}"
    echo -e "${W}Usa:${N} ${C}sudo bash install.sh${N}"
    sn_line
    exit 1
  fi
}

# Banner del instalador (IGUAL al tuyo)
banner() {
  echo ""
  if command -v toilet >/dev/null 2>&1; then
    toilet -f slant -F metal "SinNombre" 2>/dev/null || true
  else
    echo -e "${C}${BOLD}SinNombre${N}"
  fi
  echo -e "${D}Instalador de dependencias${N}"
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

# ----------------------------
# Lista de Dependencias
# ----------------------------
show_dependency_list() {
  echo ""
  sn_line
  echo -e "${Y}${BOLD}Dependencias que se instalarán (resumen):${N}"
  sn_line
  local i=1
  printf "%2d) %s\n" $((i++)) "ca-certificates"
  printf "%2d) %s\n" $((i++)) "curl"
  printf "%2d) %s\n" $((i++)) "git"
  printf "%2d) %s\n" $((i++)) "toilet (banner)"
  printf "%2d) %s\n" $((i++)) "sudo"
  printf "%2d) %s\n" $((i++)) "bsd utils (bsdextrautils | bsdmainutils | util-linux)"
  printf "%2d) %s\n" $((i++)) "zip"
  printf "%2d) %s\n" $((i++)) "unzip"
  printf "%2d) %s\n" $((i++)) "ufw"
  printf "%2d) %s\n" $((i++)) "python (python-is-python3 | python3)"
  printf "%2d) %s\n" $((i++)) "python3"
  printf "%2d) %s\n" $((i++)) "python3-pip"
  printf "%2d) %s\n" $((i++)) "openssl"
  printf "%2d) %s\n" $((i++)) "screen"
  printf "%2d) %s\n" $((i++)) "cron (cron | cronie)"
  printf "%2d) %s\n" $((i++)) "iptables"
  printf "%2d) %s\n" $((i++)) "lsof"
  printf "%2d) %s\n" $((i++)) "nano"
  printf "%2d) %s\n" $((i++)) "at"
  printf "%2d) %s\n" $((i++)) "mlocate"
  printf "%2d) %s\n" $((i++)) "gawk"
  printf "%2d) %s\n" $((i++)) "grep"
  printf "%2d) %s\n" $((i++)) "bc"
  printf "%2d) %s\n" $((i++)) "jq"
  printf "%2d) %s\n" $((i++)) "nodejs"
  printf "%2d) %s\n" $((i++)) "npm"
  printf "%2d) %s\n" $((i++)) "socat"
  printf "%2d) %s\n" $((i++)) "netcat (netcat-openbsd | netcat-traditional | netcat)"
  printf "%2d) %s\n" $((i++)) "net-tools"
  printf "%2d) %s\n" $((i++)) "figlet"
  printf "%2d) %s\n" $((i++)) "cowsay"
  printf "%2d) %s\n" $((i++)) "lolcat (lolcat | ruby-lolcat)"
  echo ""
  sn_line
  echo -e "${D}Se procederá a instalar las dependencias en el orden mostrado. Si ya están instaladas, apt las omitirá o actualizará.${N}"
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
  step "Actualizando repos (apt update)"
  if run_discreet "apt-get update"; then
    ok
  else
    fail
    return 1
  fi
}

apt_upgrade() {
  step "Aplicando upgrade básico"
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
# Configuración de Banner Limpio (CON TEXTO EXACTO)
# ----------------------------
ensure_clean_banner() {
  step "Configurando banner de inicio limpio"
  
  # Crear archivo para silenciar mensajes del sistema
  touch /root/.hushlogin >/dev/null 2>&1
  
  # Configurar .bashrc para limpiar pantalla y mostrar banner EXACTO
  local bashrc="/root/.bashrc"
  local marker="# === SinNombre Banner === #"
  
  if ! grep -q "${marker}" "${bashrc}" 2>/dev/null; then
    cat >>"${bashrc}" <<'EOF'

# === SinNombre Banner === #
if [[ $- == *i* ]] && [[ -z "${SN_WELCOME_SHOWN:-}" ]]; then
  export SN_WELCOME_SHOWN=1
  
  # Limpiar pantalla completamente
  clear
  
  # Mostrar banner EXACTO como en tu script original
  echo ""
  if command -v toilet >/dev/null 2>&1; then
    toilet -f slant -F metal "SinNombre" 2>/dev/null || true
  else
    echo -e "\033[0;36m\033[1mSinNombre\033[0m"
  fi
  echo -e "\033[1;37mCreador:\033[0m \033[0;36m@SIN_NOMBRE22\033[0m  \033[1;33m(en desarrollo)\033[0m"
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
if [[ $- == *i* ]] && [[ -z "${SN_WELCOME_SHOWN:-}" ]]; then
  export SN_WELCOME_SHOWN=1
  clear
  # El banner se carga desde .bashrc
fi
EOF
  fi
  
  ok
}

# ----------------------------
# Instalación de Dependencias (IGUAL a tu orden)
# ----------------------------
install_dependencies() {
  echo ""
  sn_line
  echo -e "${Y}${BOLD}Preparando sistema...${N}"
  sn_line

  apt_fix_if_needed
  apt_update
  apt_upgrade

  echo ""
  sn_line
  echo -e "${Y}${BOLD}Instalando dependencias${N}"
  sn_line

  install_pkg ca-certificates
  install_pkg curl
  install_pkg git
  install_pkg toilet
  install_pkg sudo
  install_any_of "bsd utils" bsdextrautils bsdmainutils util-linux
  install_pkg zip
  install_pkg unzip
  install_pkg ufw
  install_any_of "python (compat)" python-is-python3 python3
  install_pkg python3
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
  install_pkg jq
  install_pkg nodejs
  install_pkg npm
  install_pkg socat
  install_any_of "netcat" netcat-openbsd netcat-traditional netcat
  install_pkg net-tools
  install_pkg figlet
  install_pkg cowsay
  install_any_of "lolcat" lolcat ruby-lolcat
}

# ----------------------------
# Instalación del Proyecto (Discreta)
# ----------------------------
install_project() {
  echo ""
  sn_line
  echo -e "${Y}${BOLD}Instalando script${N}"
  sn_line

  step "Creando carpeta de instalación"
  mkdir -p "${INSTALL_DIR}" && ok || { fail; exit 1; }

  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    step "Actualizando proyecto"
    (cd "${INSTALL_DIR}" && git fetch --all --prune && git reset --hard "origin/${REPO_BRANCH}") && ok || { fail; exit 1; }
  else
    step "Descargando desde repositorio"
    git clone --depth 1 -b "${REPO_BRANCH}" "${REPO_URL}" "${INSTALL_DIR}" >/dev/null 2>&1 && ok || { fail; exit 1; }
  fi

  step "Verificando archivos principales"
  [[ -f "${MENU_PATH}" ]] && ok || { fail; exit 1; }
}

apply_permissions() {
  echo ""
  sn_line
  echo -e "${Y}${BOLD}Aplicando permisos${N}"
  sn_line

  step "chmod +x menu"
  chmod +x "${MENU_PATH}" && ok || fail

  step "chmod +x *.sh"
  find "${INSTALL_DIR}" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null && ok || ok

  step "chmod +x *.py"
  find "${INSTALL_DIR}" -type f -name "*.py" -exec chmod +x {} \; 2>/dev/null && ok || ok
}

setup_commands() {
  echo ""
  sn_line
  echo -e "${Y}${BOLD}Configurando accesos...${N}"
  sn_line

  step "Creando comando global sn"
  cat >/usr/local/bin/sn <<EOF
#!/usr/bin/env bash
if [[ "\${EUID:-\$(id -u)}" -ne 0 ]]; then
  echo -e "\033[0;31m══════════════════════════ / / / ══════════════════════════\033[0m"
  echo -e "\033[0;31mAcceso denegado.\033[0m \033[1;33mEjecuta en root o con sudo.\033[0m"
  echo -e "\033[1;37mUsa:\033[0m \033[0;36msudo sn\033[0m"
  echo -e "\033[0;31m══════════════════════════ / / / ══════════════════════════\033[0m"
  exit 1
fi
exec "${MENU_PATH}" "\$@"
EOF
  chmod +x /usr/local/bin/sn && ok || fail

  step "Creando comando global menu"
  cat >/usr/local/bin/menu <<EOF
#!/usr/bin/env bash
if [[ "\${EUID:-\$(id -u)}" -ne 0 ]]; then
  echo -e "\033[0;31m══════════════════════════ / / / ══════════════════════════\033[0m"
  echo -e "\033[0;31mAcceso denegado.\033[0m \033[1;33mEjecuta en root o con sudo.\033[0m"
  echo -e "\033[1;37mUsa:\033[0m \033[0;36msudo menu\033[0m"
  echo -e "\033[0;31m══════════════════════════ / / / ══════════════════════════\033[0m"
  exit 1
fi
exec "${MENU_PATH}" "\$@"
EOF
  chmod +x /usr/local/bin/menu && ok || fail
}

# ----------------------------
# Finalización
# ----------------------------
finish() {
  echo ""
  sn_line
  echo -e "${G}${BOLD}Instalación finalizada.${N}"
  sn_line
  echo ""
  echo -e "${W}Prueba ahora:${N} ${C}sn${N}"
  echo ""
}

# ----------------------------
# Función Principal
# ----------------------------
main() {
  require_root
  command -v apt-get >/dev/null 2>&1 || { echo "Se requiere apt-get"; exit 1; }

  clear
  banner

  # Mostrar lista de dependencias antes de instalar
  show_dependency_list

  install_dependencies
  install_project
  apply_permissions
  setup_commands
  ensure_clean_banner
  finish

  if [[ "${START_AFTER}" == "true" ]]; then
    exec "${MENU_PATH}"
  fi
}

# Ejecutar
main "$@"
