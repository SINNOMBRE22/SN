#!/bin/bash
set -euo pipefail

# =========================================================
# SinNombre v1.0 - SOCKS PYTHON2 (PDirect)
# Archivo: SN/Protocolos/socks.sh
#
# MENÚ NUEVO (funcional):
# [1] INSTALAR / VERIFICAR
# [2] CONFIGURAR SOCKS (CREAR PUERTO)
# [3] AGREGAR NUEVO PUERTO (IGUAL A CONFIGURAR)
# [4] INICIAR / PARAR PUERTO
# [5] DETENER / ELIMINAR PUERTO
# [6] REPARAR (FIX ERRORES COMUNES)
# [7] DESINSTALAR TODO
# [0] VOLVER
#
# Notas:
# - Estado real por systemd: python.<puerto>.service
# - Ejecuta PDirect.py con python2
# - Crea launcher por puerto: /usr/local/bin/pydirect-<puerto>.sh (evita escapes raros en systemd)
# =========================================================

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'
D='\033[2m'
BOLD='\033[1m'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/python" && pwd)"
PDIRECT="${PY_DIR}/PDirect.py"

pause(){ echo ""; read -r -p "Presiona Enter para continuar..."; }
hr(){ echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }
sep(){ echo -e "${R}------------------------------------------------------------${N}"; }
require_root(){ [[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo -e "${R}Ejecuta como root.${N}"; exit 1; }; }

python2_bin() {
  command -v python2 >/dev/null 2>&1 && { echo "python2"; return; }
  command -v python2.7 >/dev/null 2>&1 && { echo "python2.7"; return; }
  echo ""
}

install_python2() {
  apt-get update -y >/dev/null 2>&1 || true
  apt-get install -y python2 >/dev/null 2>&1 && return 0
  apt-get install -y python2-minimal >/dev/null 2>&1 && return 0
  apt-get install -y python2.7 >/dev/null 2>&1 && return 0
  return 1
}

install_deps() {
  apt-get update -y >/dev/null 2>&1 || true
  apt-get install -y curl lsof >/dev/null 2>&1 || true
}

ensure_pdirect_file() {
  [[ -f "$PDIRECT" ]] || { echo -e "${R}Falta:${N} ${Y}${PDIRECT}${N}"; return 1; }
  chmod +x "$PDIRECT" >/dev/null 2>&1 || true
  return 0
}

port_in_use() {
  local p="$1"
  ss -H -lnt 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${p}$"
}

unit_name(){ echo "python.$1"; }
unit_path(){ echo "/etc/systemd/system/python.$1.service"; }
launcher_path(){ echo "/usr/local/bin/pydirect-$1.sh"; }

list_ports_lines() {
  ls /etc/systemd/system/python.*.service 2>/dev/null \
    | sed -n 's/.*python\.\([0-9]\+\)\.service/\1/p' \
    | sort -n || true
}

ports_registered_one_line() {
  local ports
  ports="$(list_ports_lines | tr '\n' ' ' | sed 's/[[:space:]]\+$//' || true)"
  [[ -n "${ports:-}" ]] && echo "$ports" || echo "Ninguno"
}

status_raw() {
  systemctl is-active "$(unit_name "$1")" 2>/dev/null || echo "unknown"
}

status_badge() {
  [[ "$(status_raw "$1")" == "active" ]] && echo -e "${G}[ON ]${N}" || echo -e "${R}[OFF]${N}"
}

write_unit_and_launcher() {
  local listen="$1" localp="$2" resp="$3" banner="$4" pass="$5"
  local py; py="$(python2_bin)"

  # launcher (evita escapes en systemd)
  cat >"$(launcher_path "$listen")" <<EOF
#!/bin/bash
exec /usr/bin/env ${py} ${PDIRECT} -p ${listen} -l ${localp} -r ${resp} -t "${banner}" -c "${pass}"
EOF
  chmod +x "$(launcher_path "$listen")"

  cat >"$(unit_path "$listen")" <<EOF
[Unit]
Description=PDirect PY2 Service port ${listen}
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
  local p="$1"
  systemctl daemon-reload >/dev/null 2>&1 || true
  systemctl enable "$(unit_name "$p")" >/dev/null 2>&1 || true
  systemctl restart "$(unit_name "$p")" >/dev/null 2>&1 || true
  sleep 1
  [[ "$(status_raw "$p")" == "active" ]]
}

stop_port() {
  local p="$1"
  systemctl stop "$(unit_name "$p")" >/dev/null 2>&1 || true
}

remove_port() {
  local p="$1"
  stop_port "$p"
  systemctl disable "$(unit_name "$p")" >/dev/null 2>&1 || true
  rm -f "$(unit_path "$p")" >/dev/null 2>&1 || true
  rm -f "$(launcher_path "$p")" >/dev/null 2>&1 || true
  systemctl daemon-reload >/dev/null 2>&1 || true
}

choose_registered_port() {
  local ports n=1 op
  ports="$(list_ports_lines || true)"
  [[ -n "${ports:-}" ]] || { echo ""; return 0; }

  declare -A MAP
  while read -r p; do
    [[ -z "${p:-}" ]] && continue
    echo -e " ${G}[${n}]${N} ${W}>${N} ${Y}${p}${N}  $(status_badge "$p")"
    MAP["$n"]="$p"
    n=$((n+1))
  done <<<"$ports"

  sep
  echo -e " ${G}[0]${N} ${W}>${N} VOLVER"
  sep
  read -r -p " opcion: " op
  [[ "${op:-}" == "0" ]] && { echo ""; return 0; }
  [[ "${op:-}" =~ ^[0-9]+$ ]] || { echo ""; return 0; }
  [[ -n "${MAP[$op]:-}" ]] || { echo ""; return 0; }
  echo "${MAP[$op]}"
}

# ==========================
# [1] INSTALAR / VERIFICAR
# ==========================
install_verify() {
  clear; hr
  echo -e "${W}${BOLD}INSTALAR / VERIFICAR${N}"
  hr

  install_deps
  ensure_pdirect_file || { pause; return; }

  if [[ -z "$(python2_bin)" ]]; then
    echo -e "${Y}Python2 no está instalado. Instalando...${N}"
    if ! install_python2; then
      echo -e "${R}No pude instalar Python2 en este sistema (repos).${N}"
      pause
      return
    fi
  fi

  echo -e "${G}OK${N}  Python2: ${Y}$(python2_bin)${N}"
  echo -e "${W}Puertos registrados:${N} ${Y}$(ports_registered_one_line)${N}"
  pause
}

# ==========================
# [2]/[3] CONFIGURAR / AGREGAR
# ==========================
configure_port() {
  clear; hr
  echo -e "${W}${BOLD}CONFIGURAR SOCKS (CREAR PUERTO)${N}"
  hr

  install_deps
  ensure_pdirect_file || { pause; return; }

  if [[ -z "$(python2_bin)" ]]; then
    echo -e "${Y}Python2 no está instalado. Usa opción [1].${N}"
    pause
    return
  fi

  local listen localp resp banner pass

  while true; do
    read -r -p "PUERTO PARA SOCKS PY (listen): " listen
    [[ "${listen:-}" =~ ^[0-9]+$ ]] || continue
    if port_in_use "$listen"; then
      echo -e "${R}Puerto ${listen} ocupado.${N}"
      continue
    fi
    break
  done

  while true; do
    read -r -p "PUERTO LOCAL DESTINO (ej 22): " localp
    [[ "${localp:-}" =~ ^[0-9]+$ ]] || continue
    break
  done

  read -r -p "RESPUESTA (101/200) [200]: " resp
  resp="${resp:-200}"
  [[ "$resp" != "101" && "$resp" != "200" ]] && resp="200"

  echo -e "${Y}Mini-Banner (Enter=default)${N}"
  read -r banner
  if [[ -z "${banner:-}" ]]; then
    [[ "$resp" == "101" ]] && banner="SN Switching Protocols" || banner="Connection Established"
  fi

  read -r -p "X-Pass (opcional): " pass
  pass="${pass:-}"

  write_unit_and_launcher "$listen" "$localp" "$resp" "$banner" "$pass"

  if start_port "$listen"; then
    echo -e "${G}PUERTO ${listen} ACTIVADO.${N}"
    echo -e "${W}Servicio:${N} ${Y}python.${listen}${N}  Estado: $(status_badge "$listen")"
  else
    echo -e "${R}No se pudo iniciar python.${listen}.${N}"
    sep
    systemctl status "$(unit_name "$listen")" --no-pager 2>/dev/null || true
    sep
    journalctl -u "$(unit_name "$listen")" -n 120 --no-pager 2>/dev/null || true
    sep
    echo -e "${Y}Revirtiendo (borrando registro) para que no quede OFF...${N}"
    remove_port "$listen"
  fi

  pause
}

# ==========================
# [4] INICIAR / PARAR PUERTO
# ==========================
start_stop_port_menu() {
  clear; hr
  echo -e "${W}${BOLD}INICIAR / PARAR PUERTO${N}"
  hr

  local p
  p="$(choose_registered_port)"
  [[ -n "${p:-}" ]] || return

  if [[ "$(status_raw "$p")" == "active" ]]; then
    stop_port "$p"
    echo -e "${Y}Puerto ${p} detenido.${N}"
  else
    if start_port "$p"; then
      echo -e "${G}Puerto ${p} iniciado.${N}"
    else
      echo -e "${R}No pudo iniciar.${N}"
      journalctl -u "$(unit_name "$p")" -n 80 --no-pager 2>/dev/null || true
    fi
  fi
  pause
}

# ==========================
# [5] DETENER / ELIMINAR PUERTO
# ==========================
remove_port_menu() {
  clear; hr
  echo -e "${W}${BOLD}DETENER / ELIMINAR PUERTO${N}"
  hr

  local p
  p="$(choose_registered_port)"
  [[ -n "${p:-}" ]] || return

  read -r -p "¿Eliminar python.${p}? (s/n): " yn
  [[ "${yn,,}" == "s" ]] || return

  remove_port "$p"
  echo -e "${G}Eliminado python.${p}.${N}"
  pause
}

# ==========================
# [6] REPARAR (FIX)
# ==========================
repair_menu() {
  clear; hr
  echo -e "${W}${BOLD}REPARAR (FIX ERRORES COMUNES)${N}"
  hr

  echo -e "${W}Acciones:${N}"
  echo -e "  ${Y}- Daemon reload + restart de puertos activos${N}"
  echo -e "  ${Y}- Permisos PDirect.py${N}"
  echo -e "  ${Y}- Verifica python2 instalado${N}"
  sep

  ensure_pdirect_file || { pause; return; }

  if [[ -z "$(python2_bin)" ]]; then
    echo -e "${Y}Python2 no está. Intentando instalar...${N}"
    install_python2 || true
  fi

  systemctl daemon-reload >/dev/null 2>&1 || true

  local ports restarted=0
  ports="$(list_ports_lines || true)"
  if [[ -n "${ports:-}" ]]; then
    while read -r p; do
      [[ -z "${p:-}" ]] && continue
      if [[ "$(status_raw "$p")" == "active" ]]; then
        systemctl restart "$(unit_name "$p")" >/dev/null 2>&1 || true
        restarted=$((restarted+1))
      fi
    done <<<"$ports"
  fi

  echo -e "${G}Repair aplicado.${N} Reiniciados: ${Y}${restarted}${N}"
  pause
}

# ==========================
# [7] DESINSTALAR TODO
# ==========================
uninstall_all() {
  clear; hr
  echo -e "${R}${BOLD}DESINSTALAR TODO${N}"
  hr
  echo -e "${Y}Esto elimina todos los python.<puerto> y sus launchers.${N}"
  read -r -p "¿Confirmas? (s/n): " yn
  [[ "${yn,,}" == "s" ]] || return

  local ports
  ports="$(list_ports_lines || true)"
  if [[ -n "${ports:-}" ]]; then
    while read -r p; do
      [[ -z "${p:-}" ]] && continue
      remove_port "$p"
    done <<<"$ports"
  fi

  # opcional: desinstalar python2
  apt-get purge -y python2 python2-minimal python2.7 >/dev/null 2>&1 || true
  apt-get autoremove -y >/dev/null 2>&1 || true

  echo -e "${G}Desinstalado.${N}"
  pause
}

menu() {
  require_root
  while true; do
    clear
    local py ports
    py="$(python2_bin)"
    [[ -z "$py" ]] && py="(no instalado)"
    ports="$(ports_registered_one_line)"

    hr
    echo -e "${W}                     SOCKS (PYTHON2)${N}"
    hr
    echo -e "${W}Python2:${N} ${Y}${py}${N}"
    echo -e "${W}Puertos registrados:${N} ${Y}${ports}${N}"
    hr
    echo -e "${R}[${Y}1${R}]${N} ${C}INSTALAR / VERIFICAR${N}"
    echo -e "${R}[${Y}2${R}]${N} ${C}CONFIGURAR SOCKS (CREAR PUERTO)${N}"
    echo -e "${R}[${Y}3${R}]${N} ${C}AGREGAR NUEVO PUERTO (IGUAL A CONFIGURAR)${N}"
    echo -e "${R}[${Y}4${R}]${N} ${C}INICIAR / PARAR PUERTO${N}"
    echo -e "${R}[${Y}5${R}]${N} ${C}DETENER / ELIMINAR PUERTO${N}"
    echo -e "${R}[${Y}6${R}]${N} ${C}REPARAR (FIX ERRORES COMUNES)${N}"
    echo -e "${R}[${Y}7${R}]${N} ${C}DESINSTALAR TODO${N}"
    echo -e "${R}[${Y}0${R}]${N} ${W}VOLVER${N}"
    hr
    read -r -p "Opción: " op

    case "${op:-}" in
      1) install_verify ;;
      2) configure_port ;;
      3) configure_port ;;
      4) start_stop_port_menu ;;
      5) remove_port_menu ;;
      6) repair_menu ;;
      7) uninstall_all ;;
      0) bash "${ROOT_DIR}/Protocolos/menu.sh" ;;
      *) echo -e "${B}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

menu
