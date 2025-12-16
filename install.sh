#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# SinNombre - Installer (Ubuntu/Debian apt)
# - Instala dependencias (lista completa tipo Multi-Script)
# - Instala banner deps (toilet/figlet/cowsay/lolcat opcional)
# - Comandos globales: sn y menu (solo root)
# - Banner en /root/.bashrc (solo root)
#
# Ruta de tu menu:
SN_MENU_PATH="/root/etc/sn/menu"
# =========================================================

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'
D='\033[2m'
BOLD='\033[1m'

sn_line() { echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }

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

# " • Instalando curl .......... [OK]"
step() {
  local msg="$1"
  printf " ${C}•${N} %b" "${W}${msg}${N}"
  local pad=$(( 55 - ${#msg} ))
  (( pad < 1 )) && pad=1
  printf "%*s" "$pad" "" | tr ' ' '.'
  printf " "
}
ok()   { echo -e "${G}[OK]${N}"; }
fail() { echo -e "${R}[FAIL]${N}"; }

apt_fix_if_needed() {
  dpkg --configure -a &>/dev/null || true
  apt-get -f install -y &>/dev/null || true
}

run_quiet() {
  local cmd="$*"
  if bash -lc "$cmd" &>/dev/null; then
    return 0
  fi
  apt_fix_if_needed
  bash -lc "$cmd" &>/dev/null
}

apt_update() {
  step "Actualizando repos (apt update)"
  run_quiet "apt-get update -y" && ok || { fail; exit 1; }
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
      ok
      return 0
    fi
  done
  fail
  return 1
}

ensure_menu_exists() {
  if [[ -f "${SN_MENU_PATH}" ]]; then
    chmod +x "${SN_MENU_PATH}" || true
  fi
}

create_root_only_wrappers() {
  # wrappers root-only con mensaje rojo si no es root
  cat >/usr/local/bin/sn <<EOF
#!/usr/bin/env bash
if [[ "\${EUID:-\$(id -u)}" -ne 0 ]]; then
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${R}Acceso denegado.${N} ${Y}Ejecuta en root o con sudo.${N}"
  echo -e "${W}Usa:${N} ${C}sudo sn${N}"
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  exit 1
fi
exec "${SN_MENU_PATH}" "\$@"
EOF
  chmod +x /usr/local/bin/sn

  cat >/usr/local/bin/menu <<EOF
#!/usr/bin/env bash
if [[ "\${EUID:-\$(id -u)}" -ne 0 ]]; then
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  echo -e "${R}Acceso denegado.${N} ${Y}Ejecuta en root o con sudo.${N}"
  echo -e "${W}Usa:${N} ${C}sudo menu${N}"
  echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
  exit 1
fi
exec "${SN_MENU_PATH}" "\$@"
EOF
  chmod +x /usr/local/bin/menu
}

ensure_root_bashrc_banner() {
  local bashrc="/root/.bashrc"
  touch "$bashrc"

  # evita duplicarlo
  grep -q "SN_WELCOME_SHOWN" "$bashrc" 2>/dev/null && return 0

  cat >>"$bashrc" <<'EOF'

# ============================
# SinNombre - Welcome banner
# ============================
if [[ $- == *i* ]]; then
  [[ -n "${SN_WELCOME_SHOWN:-}" ]] && return
  export SN_WELCOME_SHOWN=1

  R='\033[0;31m'
  G='\033[0;32m'
  Y='\033[1;33m'
  C='\033[0;36m'
  W='\033[1;37m'
  N='\033[0m'
  D='\033[2m'
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

install_all_dependencies() {
  sn_line
  echo -e "${Y}${BOLD}Preparando sistema...${N}"
  sn_line

  apt_fix_if_needed
  apt_update
  apt_upgrade

  echo ""
  sn_line
  echo -e "${Y}${BOLD}Instalando dependencias${N}"
  echo -e "${D}Puede tardar. Algunas pueden fallar si el paquete no existe;${N}"
  echo -e "${D}se intentan alternativas para Ubuntu/Debian.${N}"
  sn_line

  install_pkg sudo || true
  install_pkg ca-certificates || true
  install_pkg curl || true

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

  # banner deps (tu menu usa toilet)
  install_pkg toilet || true
  install_pkg figlet || true
  install_pkg cowsay || true
  install_any_of "lolcat" lolcat ruby-lolcat || true
}

main() {
  require_root
  command -v apt-get >/dev/null 2>&1 || exit 1

  clear
  banner

  ensure_menu_exists
  install_all_dependencies

  echo ""
  sn_line
  echo -e "${Y}${BOLD}Configurando accesos...${N}"
  sn_line

  create_root_only_wrappers
  ensure_root_bashrc_banner

  echo ""
  sn_line
  echo -e "${G}${BOLD}Instalación finalizada.${N}"
  sn_line
  echo ""
  echo -e "${W}Prueba ahora:${N} ${C}sn${N}"
  echo ""
}

main "$@"
