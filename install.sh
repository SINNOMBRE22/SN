#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# SinNombre - Installer (simple, sin animaciones)
# Muestra lista de dependencias antes de instalar
# Asegura que al iniciar la VPS solo se vea el banner (crea /root/.hushlogin)
# =========================================================

REPO_OWNER="SINNOMBRE22"
REPO_NAME="SN"
REPO_BRANCH="main"
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}.git"

INSTALL_DIR="/etc/SN"
MENU_PATH="${INSTALL_DIR}/menu"

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
  dpkg --configure -a || true
  apt-get -f install -y || true
}

# ---------- Lista de dependencias a mostrar ----------
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

# Ejecuta comando en primer plano y muestra salida en tiempo real.
run_quiet() {
  local cmd="$*"
  local out
  out="$(mktemp /tmp/sninout.XXXXXX)" || out="/tmp/sninout.$$"

  echo ""
  echo -e "${D}--- Ejecutando:${N} ${cmd}"
  if bash -lc "$cmd" 2>&1 | tee "$out"; then
    rm -f "$out" 2>/dev/null || true
    return 0
  fi

  echo ""
  echo -e "${Y}Intentando reparar paquetes (dpkg --configure -a / apt -f)...${N}"
  apt_fix_if_needed

  echo -e "${D}Reintentando:${N} ${cmd}"
  if bash -lc "$cmd" 2>&1 | tee "$out"; then
    rm -f "$out" 2>/dev/null || true
    return 0
  fi

  echo ""
  echo -e "${R}Comando falló:${N} $cmd"
  echo "Salida (últimas 200 líneas):"
  tail -n 200 "$out" || true
  echo "Fin de salida."
  rm -f "$out" 2>/dev/null || true
  return 1
}

apt_update() {
  step "Actualizando repos (apt update)"
  if run_quiet "apt-get update"; then
    ok
  else
    fail
    echo -e "${R}Error en apt-get update. Ejecuta manualmente: ${C}apt-get update${N}"
    exit 1
  fi
}

apt_upgrade() {
  step "Aplicando upgrade básico"
  run_quiet "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y" && ok || fail
}

install_pkg() {
  local pkg="$1"
  step "Instalando ${pkg}"
  if run_quiet "DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${pkg}"; then
    ok; return 0
  else
    fail; return 1
  fi
}

install_any_of() {
  local label="$1"; shift
  local candidates=("$@")
  step "Instalando ${label}"
  for p in "${candidates[@]}"; do
    if run_quiet "DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${p}"; then
      ok; return 0
    fi
  done
  fail; return 1
}

# -------------------------
# Asegurar banner al login y suprimir MOTD
# -------------------------
ensure_root_login_banner() {
  step "Asegurando banner en /root/.bashrc y /root/.profile y creando /root/.hushlogin"
  local bashrc="/root/.bashrc"
  local profile="/root/.profile"
  local hush="/root/.hushlogin"

  # Crear hushlogin para suprimir MOTD y last login
  if [[ ! -f "$hush" ]]; then
    touch "$hush" && chmod 600 "$hush"
  fi

  # Function to append banner snippet if not present
  append_banner_if_missing() {
    local file="$1"
    if grep -q "SN_WELCOME_SHOWN" "$file" 2>/dev/null; then
      return 0
    fi

    cat >>"$file" <<'EOF'

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
  }

  # Añadir a ambos archivos (perfil y bashrc) si faltan
  touch "$bashrc" "$profile"
  append_banner_if_missing "$bashrc"
  append_banner_if_missing "$profile"

  ok
}

install_dependencies() {
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

  install_pkg ca-certificates || true
  install_pkg curl || true
  install_pkg git || true

  # toilet primero para que el banner pueda usarse inmediatamente
  install_pkg toilet || true

  install_pkg sudo || true
  install_any_of "bsd utils" bsdextrautils bsdmainutils util-linux || true
  install_pkg zip || true
  install_pkg unzip || true
  install_pkg ufw || true
  install_any_of "python (compat)" python-is-python3 python3 || true
  install_pkg python3 || true
  install_pkg python3-pip || true
  install_pkg openssl || true
  install_pkg screen || true
  install_any_of "cron" cron cronie || true
  install_pkg iptables || true
  install_pkg lsof || true
  install_pkg nano || true
  install_pkg at || true
  install_pkg mlocate || true
  install_pkg gawk || true
  install_pkg grep || true
  install_pkg bc || true
  install_pkg jq || true
  install_pkg nodejs || true
  install_pkg npm || true
  install_pkg socat || true
  install_any_of "netcat" netcat-openbsd netcat-traditional netcat || true
  install_pkg net-tools || true

  install_pkg figlet || true
  install_pkg cowsay || true
  install_any_of "lolcat" lolcat ruby-lolcat || true
}

install_project_into_etc() {
  echo ""
  sn_line
  echo -e "${Y}${BOLD}Instalando script en /etc/SN${N}"
  sn_line

  step "Creando carpeta /etc/SN"
  mkdir -p "${INSTALL_DIR}" && ok || { fail; exit 1; }

  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    step "Actualizando proyecto (git pull)"
    (cd "${INSTALL_DIR}" && git fetch --all --prune && git reset --hard "origin/${REPO_BRANCH}") && ok || { fail; exit 1; }
  else
    if [[ -n "$(ls -A "${INSTALL_DIR}" 2>/dev/null || true)" ]]; then
      step "Respaldando contenido previo"
      local bk="/etc/SN.backup.$(date +%Y%m%d-%H%M%S)"
      mv "${INSTALL_DIR}" "${bk}" && mkdir -p "${INSTALL_DIR}" && ok || { fail; exit 1; }
    fi
    step "Clonando proyecto desde GitHub"
    git clone --depth 1 -b "${REPO_BRANCH}" "${REPO_URL}" "${INSTALL_DIR}" &>/dev/null && ok || { fail; exit 1; }
  fi

  step "Verificando archivo menu"
  [[ -f "${MENU_PATH}" ]] && ok || { fail; echo -e "${Y}No existe:${N} ${C}${MENU_PATH}${N}"; exit 1; }
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

  step "chmod +x (shebang)"
  find "${INSTALL_DIR}" -type f ! -name "*.*" -exec sh -lc 'head -n 1 "$1" | grep -q "^#!" && chmod +x "$1" || true' _ {} \; 2>/dev/null && ok || ok
}

create_root_only_wrappers() {
  echo ""
  sn_line
  echo -e "${Y}${BOLD}Configurando accesos...${N}"
  sn_line

  step "Creando comando global sn"
  cat >/usr/local/bin/sn <<EOF
#!/usr/bin/env bash
if [[ "\${EUID:-\$(id -u)}" -ne 0 ]]; then
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${R}Acceso denegado.${N} ${Y}Ejecuta en root o con sudo.${N}"
  echo -e "${W}Usa:${N} ${C}sudo sn${N}"
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  exit 1
fi
exec "${MENU_PATH}" "\$@"
EOF
  chmod +x /usr/local/bin/sn && ok || fail

  step "Creando comando global menu"
  cat >/usr/local/bin/menu <<EOF
#!/usr/bin/env bash
if [[ "\${EUID:-\$(id -u)}" -ne 0 ]]; then
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${R}Acceso denegado.${N} ${Y}Ejecuta en root o con sudo.${N}"
  echo -e "${W}Usa:${N} ${C}sudo menu${N}"
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  exit 1
fi
exec "${MENU_PATH}" "\$@"
EOF
  chmod +x /usr/local/bin/menu && ok || fail
}

finish() {
  echo ""
  sn_line
  echo -e "${G}${BOLD}Instalación finalizada.${N}"
  sn_line
  echo ""
  echo -e "${W}Prueba ahora:${N} ${C}sn${N}"
  echo ""
}

main() {
  require_root
  command -v apt-get >/dev/null 2>&1 || { echo "Se requiere apt-get"; exit 1; }

  clear
  banner

  # Mostrar lista de dependencias antes de instalar
  show_dependency_list

  install_dependencies
  install_project_into_etc
  apply_permissions
  create_root_only_wrappers
  ensure_root_login_banner
  finish

  if [[ "${START_AFTER}" == "true" ]]; then
    exec "${MENU_PATH}"
  fi
}

main "$@"
