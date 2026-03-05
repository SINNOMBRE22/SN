#!/bin/bash
# =========================================================
# SinNombre v2.0 - SOCKS PYTHON2 (PDirect)
# Archivo: SN/Protocolos/socks.sh
#
# CAMBIOS v2.0 (2026-03-05):
# - Usa lib/colores.sh (sin colores duplicados)
# - Menú simplificado: 5 opciones claras
# - Flujo rápido: instala python2 automáticamente si falta
#   y va directo a configurar el puerto
# - Respuesta HTTP: 200, 101 o personalizada (el usuario elige)
# - Barra de progreso fina (━╸) + spinner profesional
# - Desinstalación real y completa
# - Corrección de errores en validaciones y arrays
#
# MENÚ:
# [1] CREAR PUERTO SOCKS (instala si falta)
# [2] INICIAR / PARAR PUERTO
# [3] ELIMINAR PUERTO
# [4] REPARAR (FIX)
# [5] DESINSTALAR TODO
# [0] VOLVER
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

# ── Rutas ───────────────────────────────────────────────
PY_DIR="$(dirname "${BASH_SOURCE[0]}")/python"
PDIRECT="${PY_DIR}/PDirect.py"

# =========================================================
#  ANIMACIONES
# =========================================================

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

    if (( i < width )); then
      printf "╸"
    else
      printf "━"
    fi

    printf "${D}"
    for ((j = i + 1; j < width; j++)); do printf "━"; done

    printf "${N} ${W}%3d%%${N}" "$pct"

    sleep "$(echo "scale=4; $duration / $width" | bc 2>/dev/null || echo "0.08")"
  done

  echo -e "  ${G}✓${N}"
  tput cnorm 2>/dev/null || true
}

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

# =========================================================
#  UTILIDADES
# =========================================================

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    hr
    echo -e "  ${R}✗${N} ${W}Ejecuta como root${N}"
    echo -e "  ${W}Usa:${N} ${C}sudo menu${N}  ${W}o${N}  ${C}sudo sn${N}"
    hr
    exit 1
  fi
}

python2_bin() {
  command -v python2 >/dev/null 2>&1 && { echo "python2"; return; }
  command -v python2.7 >/dev/null 2>&1 && { echo "python2.7"; return; }
  echo ""
}

ensure_python2() {
  [[ -n "$(python2_bin)" ]] && return 0

  echo ""
  echo -e "  ${Y}⚠${N} ${W}Python2 no está instalado${N}"
  echo -e "  ${D}Se necesita para ejecutar PDirect.py${N}"
  echo ""

  (
    apt-get update -y >/dev/null 2>&1 || true
  ) &
  spinner $! "Actualizando repositorios..."

  progress_bar "Instalando Python2" 3
  apt-get install -y python2 >/dev/null 2>&1 \
    || apt-get install -y python2-minimal >/dev/null 2>&1 \
    || apt-get install -y python2.7 >/dev/null 2>&1

  if [[ -z "$(python2_bin)" ]]; then
    echo -e "  ${R}✗${N} ${W}No se pudo instalar Python2${N}"
    echo -e "  ${D}Tu sistema puede no tener repos de python2 disponibles${N}"
    return 1
  fi

  echo -e "  ${G}✓${N} ${W}Python2 instalado:${N} ${Y}$(python2_bin)${N}"
  return 0
}

ensure_deps() {
  local need_install=false

  command -v curl >/dev/null 2>&1 || need_install=true
  command -v lsof >/dev/null 2>&1 || need_install=true

  if $need_install; then
    (
      apt-get update -y >/dev/null 2>&1 || true
      apt-get install -y curl lsof >/dev/null 2>&1 || true
    ) &
    spinner $! "Instalando dependencias..."
  fi
}

ensure_pdirect() {
  if [[ ! -f "$PDIRECT" ]]; then
    echo -e "  ${R}✗${N} ${W}Falta:${N} ${C}${PDIRECT}${N}"
    echo -e "  ${D}Asegúrate de que el archivo PDirect.py exista en Protocolos/python/${N}"
    return 1
  fi
  chmod +x "$PDIRECT" >/dev/null 2>&1 || true
  return 0
}

port_in_use() {
  ss -H -lnt 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${1}$"
}

# ── Funciones de systemd por puerto ─────────────────────
unit_name()    { echo "python.$1"; }
unit_path()    { echo "/etc/systemd/system/python.$1.service"; }
launcher_path(){ echo "/usr/local/bin/pydirect-$1.sh"; }

list_ports() {
  ls /etc/systemd/system/python.*.service 2>/dev/null \
    | sed -n 's/.*python\.\([0-9]\+\)\.service/\1/p' \
    | sort -n || true
}

ports_summary() {
  local ports
  ports="$(list_ports | tr '\n' ' ' | sed 's/[[:space:]]\+$//' || true)"
  [[ -n "${ports:-}" ]] && echo "$ports" || echo "Ninguno"
}

status_raw() {
  systemctl is-active "$(unit_name "$1")" 2>/dev/null || echo "unknown"
}

status_badge() {
  if [[ "$(status_raw "$1")" == "active" ]]; then
    echo -e "${G}${BOLD}● ON${N}"
  else
    echo -e "${R}${BOLD}● OFF${N}"
  fi
}

write_unit_and_launcher() {
  local listen="$1" localp="$2" resp="$3" banner="$4" pass="$5"
  local py
  py="$(python2_bin)"

  cat > "$(launcher_path "$listen")" <<EOF
#!/bin/bash
exec /usr/bin/env ${py} ${PDIRECT} -p ${listen} -l ${localp} -r ${resp} -t "${banner}" -c "${pass}"
EOF
  chmod +x "$(launcher_path "$listen")"

  cat > "$(unit_path "$listen")" <<EOF
[Unit]
Description=PDirect SOCKS port ${listen}
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=$(launcher_path "$listen")
Restart=always
RestartSec=2s

[Install]
WantedBy=multi-user.target
EOF
}

start_port() {
  systemctl daemon-reload >/dev/null 2>&1 || true
  systemctl enable "$(unit_name "$1")" >/dev/null 2>&1 || true
  systemctl restart "$(unit_name "$1")" >/dev/null 2>&1 || true
  sleep 1
  [[ "$(status_raw "$1")" == "active" ]]
}

stop_port() {
  systemctl stop "$(unit_name "$1")" >/dev/null 2>&1 || true
}

remove_port() {
  stop_port "$1"
  systemctl disable "$(unit_name "$1")" >/dev/null 2>&1 || true
  rm -f "$(unit_path "$1")" >/dev/null 2>&1 || true
  rm -f "$(launcher_path "$1")" >/dev/null 2>&1 || true
  systemctl daemon-reload >/dev/null 2>&1 || true
}

# Selector de puerto registrado
choose_port() {
  local ports n=1
  ports="$(list_ports || true)"

  if [[ -z "${ports:-}" ]]; then
    echo -e "  ${Y}⚠${N} ${W}No hay puertos registrados${N}"
    echo ""
    return 1
  fi

  declare -A MAP=()
  while read -r p; do
    [[ -z "${p:-}" ]] && continue
    echo -e "  ${G}[${W}${n}${G}]${N} ${W}▸${N} Puerto ${Y}${p}${N}  $(status_badge "$p")"
    MAP["$n"]="$p"
    n=$((n + 1))
  done <<< "$ports"

  sep
  echo -e "  ${G}[${W}0${G}]${N}  ${W}Cancelar${N}"
  sep

  local op=""
  echo -ne "  ${W}Opción: ${G}"
  read -r op
  echo -ne "${N}"

  [[ "${op:-}" == "0" ]] && return 1
  [[ "${op:-}" =~ ^[0-9]+$ ]] || return 1
  [[ -n "${MAP[$op]:-}" ]] || return 1

  SELECTED_PORT="${MAP[$op]}"
  return 0
}

# =========================================================
#  [1] CREAR PUERTO SOCKS
# =========================================================
create_port() {
  clear
  hr
  echo -e "${W}${BOLD}          CREAR PUERTO SOCKS${N}"
  hr

  ensure_deps
  ensure_python2 || { pause; return; }
  ensure_pdirect || { pause; return; }

  echo ""
  sep
  echo -e "  ${C}Configuración del nuevo puerto SOCKS${N}"
  sep
  echo ""

  # ── Puerto de escucha ─────────────────────────────
  local listen=""
  while [[ -z "$listen" ]]; do
    echo -ne "  ${W}Puerto SOCKS (escucha): ${G}"
    read -r listen
    echo -ne "${N}"
    if [[ ! "$listen" =~ ^[0-9]+$ ]] || (( listen < 1 || listen > 65535 )); then
      echo -e "  ${R}✗${N} ${W}Puerto inválido (1-65535)${N}"
      listen=""
      continue
    fi
    if port_in_use "$listen"; then
      echo -e "  ${R}✗${N} ${W}Puerto ${Y}${listen}${W} ya está en uso${N}"
      listen=""
      continue
    fi
    if [[ -f "$(unit_path "$listen")" ]]; then
      echo -e "  ${Y}⚠${N} ${W}Ya existe un servicio en el puerto ${listen}${N}"
      echo -ne "  ${W}¿Recrear? (s/n): ${G}"
      read -r redo
      echo -ne "${N}"
      [[ "${redo,,}" == "s" ]] || { listen=""; continue; }
      remove_port "$listen"
    fi
    echo -e "  ${G}✓${N} ${W}Puerto ${Y}${listen}${W} disponible${N}"
  done

  # ── Puerto local destino ──────────────────────────
  local localp=""
  while [[ -z "$localp" ]]; do
    echo -ne "  ${W}Puerto destino local (ej: 22 para SSH): ${G}"
    read -r localp
    echo -ne "${N}"
    if [[ ! "$localp" =~ ^[0-9]+$ ]] || (( localp < 1 || localp > 65535 )); then
      echo -e "  ${R}✗${N} ${W}Puerto inválido${N}"
      localp=""
    fi
  done

  # ── Tipo de respuesta HTTP ────────────────────────
  local resp="" banner=""

  echo ""
  echo -e "  ${W}${BOLD}Tipo de respuesta HTTP:${N}"
  echo -e "    ${G}[${W}1${G}]${N} ${C}200${N} ${D}─ Connection Established${N}"
  echo -e "    ${G}[${W}2${G}]${N} ${C}101${N} ${D}─ Switching Protocols${N}"
  echo -e "    ${G}[${W}3${G}]${N} ${Y}???${N} ${D}─ Personalizado (tú eliges código y texto)${N}"
  echo ""

  local resp_op=""
  while [[ -z "$resp_op" ]]; do
    echo -ne "  ${W}Opción [1]: ${G}"
    read -r resp_op
    echo -ne "${N}"
    resp_op="${resp_op:-1}"

    case "$resp_op" in
      1)
        resp="200"
        banner="Connection Established"
        ;;
      2)
        resp="101"
        banner="SN Switching Protocols"
        ;;
      3)
        # ── Código personalizado ──────────────────
        resp=""
        while [[ -z "$resp" ]]; do
          echo ""
          echo -e "  ${W}${BOLD}Códigos HTTP comunes:${N}"
          echo -e "    ${D}200${N} ${D}─ OK / Connection Established${N}"
          echo -e "    ${D}101${N} ${D}─ Switching Protocols${N}"
          echo -e "    ${D}301${N} ${D}─ Moved Permanently${N}"
          echo -e "    ${D}302${N} ${D}─ Found (Redirect)${N}"
          echo -e "    ${D}400${N} ${D}─ Bad Request${N}"
          echo -e "    ${D}403${N} ${D}─ Forbidden${N}"
          echo -e "    ${D}404${N} ${D}─ Not Found${N}"
          echo -e "    ${D}500${N} ${D}─ Internal Server Error${N}"
          echo ""
          echo -ne "  ${W}Código HTTP (100-599): ${G}"
          read -r resp
          echo -ne "${N}"
          if [[ ! "$resp" =~ ^[0-9]+$ ]] || (( resp < 100 || resp > 599 )); then
            echo -e "  ${R}✗${N} ${W}Código inválido (debe ser 100-599)${N}"
            resp=""
          fi
        done

        # ── Texto personalizado ───────────────────
        echo -ne "  ${W}Texto de respuesta: ${G}"
        read -r banner
        echo -ne "${N}"
        if [[ -z "${banner:-}" ]]; then
          banner="SN Custom Response"
          echo -e "  ${D}Usando default:${N} ${Y}${banner}${N}"
        fi
        ;;
      *)
        echo -e "  ${R}✗${N} ${W}Opción inválida (1, 2 o 3)${N}"
        resp_op=""
        ;;
    esac
  done

  echo -e "  ${G}✓${N} ${W}Respuesta:${N} ${C}${resp}${N} ${D}─ ${banner}${N}"

  # ── Banner personalizado (override) ───────────────
  # Solo preguntar si eligió opción 1 o 2 (las predefinidas)
  if [[ "$resp_op" != "3" ]]; then
    echo ""
    echo -ne "  ${W}¿Cambiar banner? ${D}(Enter = mantener \"${banner}\")${W}: ${G}"
    read -r custom_banner
    echo -ne "${N}"
    [[ -n "${custom_banner:-}" ]] && banner="$custom_banner"
  fi

  # ── Contraseña (X-Pass) ──────────────────────────
  echo -ne "  ${W}X-Pass ${D}(Enter = sin contraseña)${W}: ${G}"
  read -r pass
  echo -ne "${N}"
  pass="${pass:-}"

  # ── Resumen antes de crear ────────────────────────
  echo ""
  hr
  echo -e "  ${W}${BOLD}RESUMEN DE CONFIGURACIÓN:${N}"
  hr
  echo ""
  echo -e "    ${W}Puerto SOCKS:${N}      ${Y}${listen}${N}"
  echo -e "    ${W}Destino:${N}           ${C}127.0.0.1:${localp}${N}"
  echo -e "    ${W}Respuesta HTTP:${N}    ${C}${resp}${N} ${D}─ ${banner}${N}"
  [[ -n "$pass" ]] && \
  echo -e "    ${W}X-Pass:${N}            ${Y}${pass}${N}" || \
  echo -e "    ${W}X-Pass:${N}            ${D}(ninguna)${N}"
  echo ""
  hr
  echo -ne "  ${W}¿Crear servicio? (s/n): ${G}"
  read -r confirm
  echo -ne "${N}"
  [[ "${confirm,,}" == "s" ]] || { echo -e "  ${Y}Cancelado${N}"; pause; return; }

  echo ""

  # ── Crear servicio ────────────────────────────────
  progress_bar "Creando servicio" 2
  write_unit_and_launcher "$listen" "$localp" "$resp" "$banner" "$pass"

  (
    start_port "$listen"
  ) &
  spinner $! "Iniciando python.${listen}..."

  echo ""

  if [[ "$(status_raw "$listen")" == "active" ]]; then
    hr
    echo -e "  ${G}${BOLD}✓ PUERTO SOCKS CREADO Y ACTIVO${N}"
    hr
    echo ""
    echo -e "  ${W}Servicio:${N}    ${Y}python.${listen}${N}  $(status_badge "$listen")"
    echo -e "  ${W}Escucha:${N}     ${G}${listen}${N} ${W}━━▸${N} ${C}127.0.0.1:${localp}${N}"
    echo -e "  ${W}Respuesta:${N}   ${C}${resp}${N} ${D}─ ${banner}${N}"
    [[ -n "$pass" ]] && \
    echo -e "  ${W}X-Pass:${N}      ${Y}${pass}${N}"
    echo ""
    hr
  else
    hr
    echo -e "  ${R}✗ No se pudo iniciar python.${listen}${N}"
    hr
    echo ""
    echo -e "  ${D}Log del servicio:${N}"
    sep
    journalctl -u "$(unit_name "$listen")" -n 15 --no-pager 2>/dev/null || true
    sep
    echo ""
    echo -e "  ${Y}Eliminando servicio fallido...${N}"
    remove_port "$listen"
    echo -e "  ${D}Revisa que PDirect.py funcione correctamente${N}"
  fi

  pause
}

# =========================================================
#  [2] INICIAR / PARAR PUERTO
# =========================================================
start_stop_menu() {
  clear
  hr
  echo -e "${W}${BOLD}          INICIAR / PARAR PUERTO${N}"
  hr
  echo ""

  SELECTED_PORT=""
  choose_port || { pause; return; }

  local p="$SELECTED_PORT"
  echo ""

  if [[ "$(status_raw "$p")" == "active" ]]; then
    (
      stop_port "$p"
      sleep 0.3
    ) &
    spinner $! "Deteniendo puerto ${p}..."

    echo ""
    hr
    echo -e "  ${Y}■ Puerto ${p} detenido${N}"
    hr
  else
    (
      start_port "$p"
    ) &
    spinner $! "Iniciando puerto ${p}..."

    echo ""
    if [[ "$(status_raw "$p")" == "active" ]]; then
      hr
      echo -e "  ${G}${BOLD}✓ Puerto ${p} iniciado${N}"
      hr
    else
      hr
      echo -e "  ${R}✗ No se pudo iniciar puerto ${p}${N}"
      hr
      echo ""
      echo -e "  ${D}Últimas líneas del log:${N}"
      journalctl -u "$(unit_name "$p")" -n 10 --no-pager 2>/dev/null || true
    fi
  fi

  pause
}

# =========================================================
#  [3] ELIMINAR PUERTO
# =========================================================
remove_port_menu() {
  clear
  hr
  echo -e "${W}${BOLD}          ELIMINAR PUERTO SOCKS${N}"
  hr
  echo ""

  SELECTED_PORT=""
  choose_port || { pause; return; }

  local p="$SELECTED_PORT"

  echo ""
  echo -e "  ${Y}⚠ Se eliminará:${N}"
  echo -e "    ${W}•${N} Servicio ${C}python.${p}${N}"
  echo -e "    ${W}•${N} Launcher ${C}$(launcher_path "$p")${N}"
  echo ""
  echo -ne "  ${W}¿Confirmar? (s/n): ${G}"
  read -r yn
  echo -ne "${N}"
  [[ "${yn,,}" == "s" ]] || { echo -e "  ${Y}Cancelado${N}"; pause; return; }

  echo ""
  progress_bar "Eliminando puerto ${p}" 2
  remove_port "$p"

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ Puerto ${p} eliminado${N}"
  hr
  pause
}

# =========================================================
#  [4] REPARAR (FIX)
# =========================================================
repair_menu() {
  clear
  hr
  echo -e "${W}${BOLD}          REPARAR SOCKS${N}"
  hr
  echo ""
  echo -e "  ${W}Acciones:${N}"
  echo -e "    ${C}•${N} Verificar Python2"
  echo -e "    ${C}•${N} Verificar PDirect.py"
  echo -e "    ${C}•${N} Daemon reload"
  echo -e "    ${C}•${N} Reiniciar puertos activos"
  sep

  ensure_python2 || true

  if ensure_pdirect; then
    echo -e "  ${G}✓${N} ${W}PDirect.py encontrado${N}"
  fi

  (
    systemctl daemon-reload >/dev/null 2>&1 || true
    sleep 0.3
  ) &
  spinner $! "Recargando systemd..."

  local ports restarted=0
  ports="$(list_ports || true)"
  if [[ -n "${ports:-}" ]]; then
    while read -r p; do
      [[ -z "${p:-}" ]] && continue
      if [[ "$(status_raw "$p")" == "active" ]]; then
        (
          systemctl restart "$(unit_name "$p")" >/dev/null 2>&1 || true
          sleep 0.5
        ) &
        spinner $! "Reiniciando puerto ${p}..."
        restarted=$((restarted + 1))
      fi
    done <<< "$ports"
  fi

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ Reparación completa${N}"
  echo -e "  ${W}Puertos reiniciados:${N} ${Y}${restarted}${N}"
  hr
  pause
}

# =========================================================
#  [5] DESINSTALAR TODO
# =========================================================
uninstall_all() {
  clear
  hr
  echo -e "${W}${BOLD}          DESINSTALAR SOCKS COMPLETO${N}"
  hr

  local ports
  ports="$(list_ports || true)"
  local port_count=0
  [[ -n "${ports:-}" ]] && port_count="$(echo "$ports" | wc -l)"

  echo ""
  echo -e "  ${Y}⚠ Se eliminará completamente:${N}"
  echo -e "    ${W}•${N} ${Y}${port_count}${N} servicio(s) python.*"
  echo -e "    ${W}•${N} Todos los launchers en ${C}/usr/local/bin/pydirect-*${N}"
  echo -e "    ${W}•${N} Paquete Python2"
  echo ""
  echo -ne "  ${W}¿Estás seguro? (s/n): ${G}"
  read -r yn
  echo -ne "${N}"
  [[ "${yn,,}" == "s" ]] || { echo -e "  ${Y}Cancelado${N}"; pause; return; }

  echo ""
  sep

  if [[ -n "${ports:-}" ]]; then
    while read -r p; do
      [[ -z "${p:-}" ]] && continue
      (
        remove_port "$p"
        sleep 0.2
      ) &
      spinner $! "Eliminando puerto ${p}..."
    done <<< "$ports"
  fi

  progress_bar "Eliminando Python2" 3
  apt-get purge -y python2 python2-minimal python2.7 >/dev/null 2>&1 || true
  apt-get autoremove -y >/dev/null 2>&1 || true

  (
    rm -f /usr/local/bin/pydirect-*.sh >/dev/null 2>&1 || true
    systemctl daemon-reload >/dev/null 2>&1 || true
    sleep 0.3
  ) &
  spinner $! "Limpiando restos..."

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ SOCKS DESINSTALADO COMPLETAMENTE${N}"
  hr
  echo ""
  sleep 1
  pause
}

# =========================================================
#  MENÚ PRINCIPAL
# =========================================================
main_menu() {
  require_root

  while true; do
    clear

    local py ports_text
    py="$(python2_bin)"
    [[ -z "$py" ]] && py="${R}No instalado${N}" || py="${G}${py}${N}"
    ports_text="$(ports_summary)"

    hr
    echo -e "${W}${BOLD}              SOCKS PYTHON2 (PDirect)${N}"
    hr
    echo -e "  ${W}Python2:${N}   ${py}"
    echo -e "  ${W}Puertos:${N}   ${Y}${ports_text}${N}"

    local ports_list
    ports_list="$(list_ports || true)"
    if [[ -n "${ports_list:-}" ]]; then
      sep
      while read -r p; do
        [[ -z "${p:-}" ]] && continue
        echo -e "    ${W}▸${N} python.${Y}${p}${N}  $(status_badge "$p")"
      done <<< "$ports_list"
    fi

    hr
    echo ""
    echo -e "  ${G}[${W}1${G}]${N}  ${C}Crear puerto SOCKS${N}"
    echo -e "  ${G}[${W}2${G}]${N}  ${C}Iniciar / Parar puerto${N}"
    echo -e "  ${G}[${W}3${G}]${N}  ${C}Eliminar puerto${N}"
    sep
    echo -e "  ${G}[${W}4${G}]${N}  ${C}Reparar (fix)${N}"
    echo -e "  ${G}[${W}5${G}]${N}  ${R}Desinstalar todo${N}"
    hr
    echo -e "  ${G}[${W}0${G}]${N}  ${W}Volver${N}"
    hr
    echo ""
    echo -ne "  ${W}Opción: ${G}"
    read -r op
    echo -ne "${N}"

    case "${op:-}" in
      1) create_port ;;
      2) start_stop_menu ;;
      3) remove_port_menu ;;
      4) repair_menu ;;
      5) uninstall_all ;;
      0) break ;;
      *) echo -e "  ${R}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

# ── Manejo de señales ───────────────────────────────────
trap 'echo -ne "${N}"; tput cnorm 2>/dev/null; exit 0' SIGINT SIGTERM

main_menu
