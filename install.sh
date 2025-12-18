#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# SinNombre - Installer Profesional
# Configuración discreta con líneas decorativas conservadas
# Banner limpio al iniciar sesión en la VPS
# =========================================================

REPO_OWNER="SINNOMBRE22"
REPO_NAME="SN"
REPO_BRANCH="main"

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'
W='\033[1;37m'; N='\033[0m'; D='\033[2m'; BOLD='\033[1m'

sn_line() { echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }

# ----------------------------
# Args
# ----------------------------
START_AFTER=false
for arg in "$@"; do
  case "$arg" in
    --start) START_AFTER=true ;;
  esac
done

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

apt_fix_if_needed() {
  dpkg --configure -a >/dev/null 2>&1 || true
  apt-get -f install -y >/dev/null 2>&1 || true
}

# ---------- Lista de dependencias ----------
show_dependency_list() {
  echo ""
  sn_line
  echo -e "${Y}${BOLD}Dependencias a instalar:${N}"
  sn_line
  echo ""
  echo -e "${W}▸${N} ${C}Herramientas base${N} (curl, git, sudo, zip, unzip)"
  echo -e "${W}▸${N} ${C}Redes${N} (ufw, iptables, socat, netcat, net-tools)"
  echo -e "${W}▸${N} ${C}Python${N} (python3, python3-pip, openssl)"
  echo -e "${W}▸${N} ${C}Utilidades${N} (screen, cron, lsof, nano, at, mlocate)"
  echo -e "${W}▸${N} ${C}Procesamiento${N} (jq, bc, gawk, grep)"
  echo -e "${W}▸${N} ${C}Node.js${N} (nodejs, npm)"
  echo -e "${W}▸${N} ${C}Banners decorativos${N} (toilet, figlet, cowsay, lolcat)"
  echo ""
  sn_line
  echo -e "${D}Las dependencias ya instaladas serán omitidas automáticamente.${N}"
  sn_line
  echo ""
}

install_dependencies() {
  echo ""
  sn_line
  echo -e "${Y}${BOLD}Preparando sistema...${N}"
  sn_line

  apt_fix_if_needed
  
  step "Actualizando repositorios"
  apt-get update >/dev/null 2>&1 && ok || fail
  
  step "Actualizando sistema base"
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -y >/dev/null 2>&1 && ok || fail

  echo ""
  sn_line
  echo -e "${Y}${BOLD}Instalando dependencias${N}"
  sn_line

  # Grupo 1: Herramientas esenciales
  echo -e "\n${W}┌─ ${C}Herramientas esenciales${N}"
  step "  • curl, git, sudo"
  apt-get install -y curl git sudo >/dev/null 2>&1 && ok || fail
  
  step "  • zip, unzip"
  apt-get install -y zip unzip >/dev/null 2>&1 && ok || fail
  
  step "  • bsd utils"
  apt-get install -y bsdmainutils util-linux >/dev/null 2>&1 && ok || fail
  
  # Grupo 2: Redes y seguridad
  echo -e "\n${W}┌─ ${C}Redes y seguridad${N}"
  step "  • ufw, iptables"
  apt-get install -y ufw iptables >/dev/null 2>&1 && ok || fail
  
  step "  • socat, netcat"
  apt-get install -y socat netcat-openbsd >/dev/null 2>&1 && ok || fail
  
  step "  • net-tools"
  apt-get install -y net-tools >/dev/null 2>&1 && ok || fail

  # Grupo 3: Python
  echo -e "\n${W}┌─ ${C}Python${N}"
  step "  • python3"
  apt-get install -y python3 python3-pip >/dev/null 2>&1 && ok || fail
  
  step "  • openssl"
  apt-get install -y openssl >/dev/null 2>&1 && ok || fail

  # Grupo 4: Utilidades del sistema
  echo -e "\n${W}┌─ ${C}Utilidades del sistema${N}"
  step "  • screen, cron"
  apt-get install -y screen cron >/dev/null 2>&1 && ok || fail
  
  step "  • lsof, nano"
  apt-get install -y lsof nano >/dev/null 2>&1 && ok || fail
  
  step "  • at, mlocate"
  apt-get install -y at mlocate >/dev/null 2>&1 && ok || fail

  # Grupo 5: Procesamiento de datos
  echo -e "\n${W}┌─ ${C}Procesamiento de datos${N}"
  step "  • jq, bc"
  apt-get install -y jq bc >/dev/null 2>&1 && ok || fail
  
  step "  • gawk, grep"
  apt-get install -y gawk grep >/dev/null 2>&1 && ok || fail

  # Grupo 6: Node.js
  echo -e "\n${W}┌─ ${C}Node.js${N}"
  step "  • nodejs, npm"
  apt-get install -y nodejs npm >/dev/null 2>&1 && ok || fail

  # Grupo 7: Elementos decorativos
  echo -e "\n${W}┌─ ${C}Elementos decorativos${N}"
  step "  • toilet (banner)"
  apt-get install -y toilet >/dev/null 2>&1 && ok || fail
  
  step "  • figlet, cowsay"
  apt-get install -y figlet cowsay >/dev/null 2>&1 && ok || fail
  
  step "  • lolcat"
  apt-get install -y lolcat >/dev/null 2>&1 && ok || fail

  echo ""
  sn_line
  echo -e "${G}${BOLD}Dependencias instaladas correctamente${N}"
  sn_line
}

# -------------------------
# Configuración discreta del banner al login
# -------------------------
setup_login_banner() {
  step "Configurando entorno de inicio"
  
  # Crear archivo para suprimir mensajes del sistema
  touch /root/.hushlogin 2>/dev/null
  chmod 600 /root/.hushlogin 2>/dev/null
  
  # Configurar .bashrc para root
  cat >> /root/.bashrc << 'EOF'

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
  echo -e "${W}Creador:${N} ${C}@SIN_NOMBRE22${N}  ${Y}(en desarrollo)${N}"
  echo -e "${W}Para iniciar digite:${N} ${G}menu${N} ${W}o${N} ${G}sn${N}"
  echo ""
fi
EOF

  # Replicar en .profile
  grep -q "SinNombre - Welcome banner" /root/.profile 2>/dev/null || {
    cat >> /root/.profile << 'EOF'

# ============================
# SinNombre - Welcome banner
# ============================
if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi
EOF
  }
  
  ok
}

# -------------------------
# Instalación discreta del proyecto
# -------------------------
install_project() {
  echo ""
  sn_line
  echo -e "${Y}${BOLD}Configurando entorno...${N}"
  sn_line

  step "Obteniendo recursos necesarios"
  
  # Crear directorio de instalación
  INSTALL_DIR="/etc/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)"
  mkdir -p "$INSTALL_DIR" 2>/dev/null
  
  # Descargar recursos (ejemplo simplificado)
  REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}.git"
  git clone --depth 1 -b "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR" >/dev/null 2>&1
  
  MENU_PATH="$INSTALL_DIR/menu"
  
  # Aplicar permisos discretamente
  chmod +x "$MENU_PATH" 2>/dev/null
  find "$INSTALL_DIR" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null
  find "$INSTALL_DIR" -type f -name "*.py" -exec chmod +x {} \; 2>/dev/null
  
  ok

  step "Configurando accesos globales"
  
  # Comando 'sn'
  cat > /usr/local/bin/sn << EOF
#!/usr/bin/env bash
if [[ "\${EUID:-\$(id -u)}" -ne 0 ]]; then
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${R}Acceso denegado.${N} ${Y}Ejecuta en root o con sudo.${N}"
  echo -e "${W}Usa:${N} ${C}sudo sn${N}"
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  exit 1
fi
exec "$MENU_PATH" "\$@"
EOF
  chmod +x /usr/local/bin/sn 2>/dev/null

  # Comando 'menu'
  cat > /usr/local/bin/menu << EOF
#!/usr/bin/env bash
if [[ "\${EUID:-\$(id -u)}" -ne 0 ]]; then
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${R}Acceso denegado.${N} ${Y}Ejecuta en root o con sudo.${N}"
  echo -e "${W}Usa:${N} ${C}sudo menu${N}"
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  exit 1
fi
exec "$MENU_PATH" "\$@"
EOF
  chmod +x /usr/local/bin/menu 2>/dev/null
  
  ok
}

finish() {
  echo ""
  sn_line
  echo -e "${G}${BOLD}Configuración completada${N}"
  sn_line
  echo ""
  echo -e "${W}Prueba ahora:${N} ${C}sn${N} ${W}o${N} ${C}menu${N}"
  echo ""
  echo -e "${D}Reinicia tu sesión SSH para ver el nuevo banner.${N}"
  echo ""
}

main() {
  require_root
  
  clear
  banner
  
  show_dependency_list
  
  install_dependencies
  install_project
  setup_login_banner
  
  finish

  if [[ "${START_AFTER}" == "true" ]]; then
    exec "$MENU_PATH" 2>/dev/null || echo -e "${Y}Ejecuta manualmente: ${C}sn${N}"
  fi
}

main "$@"
