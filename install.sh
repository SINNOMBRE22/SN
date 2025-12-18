#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# SinNombre - Installer (Ubuntu/Debian apt)
# - Instala dependencias
# - Descarga e instala el proyecto en: /etc/SN
# - chmod +x menu + *.sh + *.py
# - Comandos globales: sn y menu (root-only)
# - Banner en /root/.bashrc (root)
#
# Repo:
REPO_OWNER="SINNOMBRE22"
REPO_NAME="SN"
REPO_BRANCH="main"
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}.git"

INSTALL_DIR="/etc/SN"
MENU_PATH="${INSTALL_DIR}/menu"
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
  local pad=$(( 30 - ${#msg} ))   # ancho reducido para líneas más cortas
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

# -------------------------------------
# Espera por locks de apt/dpkg (evita quedarse indefinido)
wait_for_apt() {
  local waited=0
  local max_wait=120  # segundos a esperar antes de continuar/advertir
  local sleep_step=2
  local msg="Esperando bloqueo de apt/dpkg..."
  # comprueba locks comunes
  while lsof /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/cache/apt/archives/lock 2>/dev/null | grep -q . || fuser /var/lib/dpkg/lock-frontend 2>/dev/null | grep -q .; do
    if (( waited >= max_wait )); then
      echo ""
      echo -e "${Y}Advertencia:${N} apt/dpkg sigue bloqueado después de ${max_wait}s. Se intentará continuar."
      return 1
    fi
    printf "\r ${C}%s${N}" "$msg"
    sleep "$sleep_step"
    waited=$((waited + sleep_step))
  done
  printf "\r"
  return 0
}
# -------------------------------------

# run_quiet: ejecuta el comando en primer plano, muestra salida en tiempo real,
# usa timeout si está disponible y guarda salida en temporal para volcar en fallo.
run_quiet() {
  local cmd="$*"
  local msg="$(printf '%s' "$cmd" | cut -c1-36)"
  local out
  out="$(mktemp /tmp/sninout.XXXXXX)" || out="/tmp/sninout.$$"

  # si hay locks, esperar (pero no bloquear indefinidamente)
  wait_for_apt || true

  local exec_cmd
  if command -v timeout >/dev/null 2>&1; then
    # timeout razonable por comando (300s)
    exec_cmd=(timeout 300s bash -lc "$cmd")
  else
    exec_cmd=(bash -lc "$cmd")
  fi

  echo ""    # salto visual antes de la salida del comando
  echo -e "${D}--- Salida: ${cmd} ---${N}"
  # ejecutar y mostrar en tiempo real, guardar en archivo
  if "${exec_cmd[@]}" 2>&1 | tee "$out"; then
    echo -e "${D}--- Fin salida ---${N}"
    tail -n 3 "$out" 2>/dev/null || true
    rm -f "$out" 2>/dev/null || true
    return 0
  fi

  # intento de reparación y reintento
  echo ""
  echo -e "${Y}Intentando reparación (dpkg --configure -a / apt -f)...${N}"
  apt_fix_if_needed

  echo -e "${D}Reintentando: ${cmd}${N}"
  if "${exec_cmd[@]}" 2>&1 | tee "$out"; then
    echo -e "${D}--- Fin salida (2º intento) ---${N}"
    tail -n 3 "$out" 2>/dev/null || true
    rm -f "$out" 2>/dev/null || true
    return 0
  fi

  # en caso de fallo, volcar salida para diagnóstico
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
  # ejecutar apt-get update (no -y)
  if run_quiet "apt-get update"; then
    ok
  else
    fail
    echo -e "${R}Error al ejecutar apt-get update. Ejecuta manualmente: ${C}apt-get update${N}"
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
      ok
      return 0
    fi
  done
  fail
  return 1
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

  # Base útil
  install_pkg ca-certificates || true
  install_pkg curl || true
  install_pkg git || true

  # Instalar primero toilet (genera banner) para que quede disponible al finalizar
  install_pkg toilet || true

  # Lista grande tipo Multi-Script (con compat)
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

  # Otras deps de banner/estética
  install_pkg figlet || true
  install_pkg cowsay || true
  install_any_of "lolcat" lolcat ruby-lolcat || true
}

install_project_into_etc() {
  echo ""
  sn_line
  echo -e "${Y}${BOLD}Instalando script en /etc/SN${N}"
  sn_line

  # Descarga/actualiza con git (más pro y actualizable)
  step "Creando carpeta /etc/SN"
  mkdir -p "${INSTALL_DIR}" && ok || { fail; exit 1; }

  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    step "Actualizando proyecto (git pull)"
    (cd "${INSTALL_DIR}" && git fetch --all --prune && git reset --hard "origin/${REPO_BRANCH}") && ok || { fail; exit 1; }
  else
    # Si hay algo ahí, lo respaldamos
    if [[ -n "$(ls -A "${INSTALL_DIR}" 2>/dev/null || true)" ]]; then
      step "Respaldando contenido previo"
      local bk="/etc/SN.backup.$(date +%Y%m%d-%H%M%S)"
      mv "${INSTALL_DIR}" "${bk}" && mkdir -p "${INSTALL_DIR}" && ok || { fail; exit 1; }
    fi

    step "Clonando proyecto desde GitHub"
    git clone --depth 1 -b "${REPO_BRANCH}" "${REPO_URL}" "${INSTALL_DIR}" &>/dev/null && ok || { fail; exit 1; }
  fi

  # Verifica menu
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

  # Por si hay scripts sin extensión con shebang
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

ensure_root_bashrc_banner() {
  step "Agregando banner a /root/.bashrc"

  local bashrc="/root/.bashrc"
  touch "$bashrc"

  if grep -q "SN_WELCOME_SHOWN" "$bashrc" 2>/dev/null; then
    ok
    return 0
  fi

  cat >>"$bashrc" <<'EOF'

# ============================
# SinNombre - Welcome banner
# ============================
if [[ $- == *i* ]]; then
  [[ -n "${SN_WELCOME_SHOWN:-}" ]] && return
  export SN_WELCOME_SHOWN=1

  # limpiar pantalla para que solo se vea el banner
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

  ok
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
  command -v apt-get >/dev/null 2>&1 || exit 1

  clear
  banner

  install_dependencies
  install_project_into_etc
  apply_permissions
  create_root_only_wrappers
  ensure_root_bashrc_banner
  finish

  if [[ "${START_AFTER}" == "true" ]]; then
    exec "${MENU_PATH}"
  fi
}

main "$@"
