#!/bin/bash
# =========================================================
# SinNombre v2.0 - INSTALADOR V2RAY (Dependencias + Core)
# Archivo: SN/Sistema/v2ray.sh
#
# CAMBIOS v2.0 (2026-03-05):
# - Shebang corregido (#!bin/bash → #!/bin/bash)
# - Usa lib/colores.sh
# - Spinner en cada dependencia
# - Usa Sistema/go.sh local para instalar el core
# - Mejor manejo de errores
# =========================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Cargar colores desde lib ────────────────────────────
LIB_COLORES="$ROOT_DIR/lib/colores.sh"
if [[ -f "$LIB_COLORES" ]]; then
  source "$LIB_COLORES"
else
  R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'
  C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'; D='\033[2m'; BOLD='\033[1m'
  hr()  { echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }
  sep() { echo -e "${R}──────────────────────────────────────────────────────────${N}"; }
  pause(){ echo ""; read -r -p "Presiona Enter para continuar..."; }
fi

BEIJING_UPDATE_TIME=3
BEGIN_PATH=$(pwd)
BASE_SOURCE_PATH="https://multi.netlify.app"
UTIL_PATH="/etc/v2ray_util/util.cfg"
UTIL_CFG="$BASE_SOURCE_PATH/v2ray_util/util_core/util.cfg"
BASH_COMPLETION_SHELL="$BASE_SOURCE_PATH/v2ray"

[[ -f /etc/redhat-release && -z $(echo $SHELL | grep zsh) ]] && unalias -a
[[ -z $(echo $SHELL | grep zsh) ]] && ENV_FILE=".bashrc" || ENV_FILE=".zshrc"

# =========================================================
#  ANIMACIONES
# =========================================================

spinner() {
  local pid="$1"
  local msg="${2:-Procesando...}"
  local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
  local i=0
  tput civis 2>/dev/null || true
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${C}${frames[$i]}${N} ${W}%s${N}" "$msg"
    i=$(( (i + 1) % ${#frames[@]} ))
    sleep 0.1
  done
  wait "$pid" 2>/dev/null
  local exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    printf "\r  ${G}✓${N} ${W}%-50s${N}\n" "$msg"
  else
    printf "\r  ${R}✗${N} ${W}%-50s${N}\n" "$msg"
  fi
  tput cnorm 2>/dev/null || true
  return $exit_code
}

progress_bar() {
  local msg="$1"
  local duration="${2:-3}"
  local width=30
  tput civis 2>/dev/null || true
  for ((i = 0; i <= width; i++)); do
    local pct=$(( i * 100 / width ))
    local bar_color="$R"
    (( pct > 33 )) && bar_color="$Y"
    (( pct > 66 )) && bar_color="$G"
    printf "\r  ${C}•${N} ${W}%-25s${N} " "$msg"
    printf "${bar_color}"
    for ((j = 0; j < i; j++)); do printf "━"; done
    if (( i < width )); then printf "╸"; else printf "━"; fi
    printf "${D}"
    for ((j = i + 1; j < width; j++)); do printf "━"; done
    printf "${N} ${W}%3d%%${N}" "$pct"
    sleep "$(echo "scale=4; $duration / $width" | bc 2>/dev/null || echo "0.08")"
  done
  echo -e "  ${G}✓${N}"
  tput cnorm 2>/dev/null || true
}

# =========================================================
#  DEPENDENCIAS
# =========================================================

install_dependencies() {
  clear
  hr
  echo -e "${W}${BOLD}          INSTALANDO DEPENDENCIAS V2RAY${N}"
  hr
  echo ""

  # Actualizar repos
  (
    apt-get update -y >/dev/null 2>&1 || true
  ) &
  spinner $! "Actualizando repositorios..."

  # Lista de dependencias
  local deps=(socat cron bash-completion ntpdate gawk jq uuid-runtime python3 python3-pip curl wget)
  local failed=()

  for pkg in "${deps[@]}"; do
    if dpkg -l "$pkg" 2>/dev/null | grep -qE '^[hi]i'; then
      echo -e "  ${G}✓${N} ${W}${pkg}${N} ${D}(ya instalado)${N}"
      continue
    fi

    (
      DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >/dev/null 2>&1
    ) &
    if spinner $! "Instalando ${pkg}..."; then
      : # OK
    else
      # Intentar fix
      (
        dpkg --configure -a >/dev/null 2>&1 || true
        DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >/dev/null 2>&1
      ) &
      if ! spinner $! "Reintentando ${pkg} (fix dpkg)..."; then
        failed+=("$pkg")
      fi
    fi
  done

  # Asegurar pip links
  if [[ ! -e '/usr/bin/pip' ]]; then
    local _pip
    _pip=$(type -p pip 2>/dev/null || true)
    [[ -n "$_pip" ]] && ln -sf "$_pip" /usr/bin/pip
  fi
  if [[ ! -e '/usr/bin/pip3' ]]; then
    local _pip3
    _pip3=$(type -p pip3 2>/dev/null || true)
    [[ -n "$_pip3" ]] && ln -sf "$_pip3" /usr/bin/pip3
  fi

  echo ""
  if (( ${#failed[@]} > 0 )); then
    echo -e "  ${Y}⚠${N} ${W}Paquetes con fallos: ${R}${failed[*]}${N}"
  else
    echo -e "  ${G}✓${N} ${W}Todas las dependencias instaladas${N}"
  fi

  hr
}

# =========================================================
#  SELINUX
# =========================================================

close_selinux() {
  if [[ -s /etc/selinux/config ]] && grep -q 'SELINUX=enforcing' /etc/selinux/config; then
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0 2>/dev/null || true
    echo -e "  ${G}✓${N} ${W}SELinux deshabilitado${N}"
  fi
}

# =========================================================
#  SINCRONIZAR TIEMPO
# =========================================================

time_sync() {
  echo ""
  (
    if command -v ntpdate >/dev/null 2>&1; then
      ntpdate pool.ntp.org >/dev/null 2>&1 || true
    elif command -v chronyc >/dev/null 2>&1; then
      chronyc -a makestep >/dev/null 2>&1 || true
    fi
  ) &
  spinner $! "Sincronizando tiempo..."

  echo -e "  ${D}Fecha actual: $(date -R)${N}"
  hr
}

# =========================================================
#  INSTALAR V2RAY CORE + UTIL
# =========================================================

update_project() {
  echo ""
  echo -e "  ${W}${BOLD}Instalando V2Ray Util...${N}"
  sep

  if ! command -v pip3 >/dev/null 2>&1 && ! command -v pip >/dev/null 2>&1; then
    echo -e "  ${R}✗${N} ${W}pip no disponible, no se puede continuar${N}"
    pause
    return 1
  fi

  # Instalar v2ray_util
  (
    pip3 install -U v2ray_util >/dev/null 2>&1 || pip install -U v2ray_util >/dev/null 2>&1 || true
  ) &
  spinner $! "Instalando v2ray_util (pip)..."

  # Configurar util
  if [[ -e "$UTIL_PATH" ]]; then
    grep -q 'lang' "$UTIL_PATH" || echo "lang=en" >> "$UTIL_PATH"
  else
    mkdir -p /etc/v2ray_util
    curl -fsS "$UTIL_CFG" > "$UTIL_PATH" 2>/dev/null || echo "lang=en" > "$UTIL_PATH"
  fi

  # Crear symlinks
  rm -f /usr/local/bin/v2ray >/dev/null 2>&1 || true
  local v2ray_util_bin
  v2ray_util_bin="$(which v2ray-util 2>/dev/null || true)"
  if [[ -n "$v2ray_util_bin" ]]; then
    ln -sf "$v2ray_util_bin" /usr/local/bin/v2ray
    ln -sf "$v2ray_util_bin" /usr/local/bin/xray
  fi

  # Bash completion
  rm -f /etc/bash_completion.d/v2ray.bash /usr/share/bash-completion/completions/v2ray.bash 2>/dev/null || true
  curl -fsS "$BASH_COMPLETION_SHELL" > /usr/share/bash-completion/completions/v2ray 2>/dev/null || true
  curl -fsS "$BASH_COMPLETION_SHELL" > /usr/share/bash-completion/completions/xray 2>/dev/null || true
  [[ -z $(echo "$SHELL" | grep zsh) ]] && {
    source /usr/share/bash-completion/completions/v2ray 2>/dev/null || true
    source /usr/share/bash-completion/completions/xray 2>/dev/null || true
  }

  echo ""

  # Instalar V2Ray core usando go.sh LOCAL
  local go_sh="$ROOT_DIR/Sistema/go.sh"
  if [[ -f "$go_sh" ]]; then
    echo -e "  ${W}${BOLD}Instalando V2Ray Core (go.sh local)...${N}"
    sep
    chmod +x "$go_sh"
    bash "$go_sh" --version v4.45.2
  else
    echo -e "  ${Y}⚠${N} ${W}go.sh local no encontrado, descargando...${N}"
    (
      bash <(curl -L -s https://raw.githubusercontent.com/SINNOMBRE22/SN/main/Sistema/go.sh) --version v4.45.2
    )
  fi

  hr
}

# =========================================================
#  CONFIGURAR PERFIL
# =========================================================

profile_init() {
  [[ $(grep v2ray ~/$ENV_FILE 2>/dev/null) ]] && sed -i '/v2ray/d' ~/$ENV_FILE
  [[ -z $(grep PYTHONIOENCODING=utf-8 ~/$ENV_FILE 2>/dev/null) ]] && echo "export PYTHONIOENCODING=utf-8" >> ~/$ENV_FILE
  source ~/$ENV_FILE 2>/dev/null || true

  (
    v2ray new >/dev/null 2>&1 || true
  ) &
  spinner $! "Inicializando configuración V2Ray..."
}

# =========================================================
#  FINALIZAR INSTALACIÓN
# =========================================================

install_finish() {
  cd "${BEGIN_PATH}" || true

  local config='/etc/v2ray/config.json'

  if [[ ! -f "$config" ]]; then
    echo ""
    echo -e "  ${R}✗${N} ${W}Config no encontrado después de instalar${N}"
    pause
    return
  fi

  progress_bar "Configurando WebSocket" 2

  # Configurar WS por defecto
  local temp
  temp=$(mktemp)
  jq 'del(.inbounds[0].streamSettings.kcpSettings)' "$config" > "$temp" 2>/dev/null || cp "$config" "$temp"
  jq '.inbounds[0].streamSettings += {"network":"ws","wsSettings":{"path":"/SinNombre/","headers":{"Host":"ejemplo.com"}}}' "$temp" > "$config" 2>/dev/null || mv "$temp" "$config"
  chmod 644 "$config"
  rm -f "$temp"

  # Reiniciar
  echo ""
  (
    if command -v v2ray >/dev/null 2>&1; then
      v2ray restart >/dev/null 2>&1 || true
    else
      systemctl restart v2ray >/dev/null 2>&1 || true
    fi
    sleep 2
  ) &
  spinner $! "Reiniciando V2Ray..."

  echo ""
  hr

  # Mostrar info
  if command -v v2ray >/dev/null 2>&1; then
    echo -e "  ${W}${BOLD}INFORMACIÓN DE V2RAY:${N}"
    sep
    v2ray info 2>/dev/null || true
    sep
  fi

  if systemctl is-active --quiet v2ray 2>/dev/null; then
    echo -e "  ${G}${BOLD}✓ INSTALACIÓN FINALIZADA${N}"
  else
    echo -e "  ${Y}⚠ Instalado pero el servicio puede necesitar reinicio${N}"
  fi

  hr
  echo ""
  echo -e "  ${D}Verifica con: v2ray info${N}"
  pause
}

# =========================================================
#  MAIN
# =========================================================

main() {
  install_dependencies
  close_selinux
  time_sync
  update_project
  profile_init
  install_finish
}

main
