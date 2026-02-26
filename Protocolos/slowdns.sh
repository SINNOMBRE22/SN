#!/usr/bin/env bash
#
# slowdns.sh
# Instalador / Configurador independiente de SlowDNS (corregido para seleccionar SSH en puerto 22 automáticamente)
#
set -euo pipefail
IFS=$'\n\t'

# -----------------------
# Configuración (rutas)
# -----------------------
VPS_DIR="/etc/SN"
PROT_DIR="${VPS_DIR}/protocolos"
ADM_inst="${VPS_DIR}/Slow/install"
ADM_slow="${VPS_DIR}/Slow/Key"
CONF_AUTOSTART="/etc/autostart"
DNS_BIN_NAME="dns-server"
DNS_BIN_PATH="${ADM_inst}/${DNS_BIN_NAME}"
BACKUP_DIR="/etc/slowdns_backups"
SERVICE_FILE="/etc/systemd/system/slowdns.service"
RESOLV_BACKUP="${BACKUP_DIR}/resolv.conf.bak"
AUTOSTART_BACKUP="${BACKUP_DIR}/autostart.bak"
BACKUP_SUFFIX=".bak_$(date +%Y%m%d%H%M%S)"
DEFAULT_DNS_URL="https://raw.githubusercontent.com/lacasitamx/SCRIPTMOD-LACASITA/master/SLOWDNS/dns-server"

# -----------------------
# Utilidades de salida
# -----------------------
_color_reset() { printf '\033[0m'; }
_color_yel()   { printf '\033[1;33m'; }
_color_grn()   { printf '\033[1;92m'; }
_color_red()   { printf '\033[1;91m'; }
_color_blu()   { printf '\033[1;34m'; }

msg() {
  if [[ "${1:-}" == "-bar" ]]; then
    printf '%s\n' "------------------------------------------------------------------"
    return 0
  fi
  local flag="$1"; shift || true
  local text="$*"
  case "$flag" in
    -ama) printf "%s%s%s\n" "$(_color_yel)" "$text" "$(_color_reset)";;
    -verd) printf "%s%s%s\n" "$(_color_grn)" "$text" "$(_color_reset)";;
    -verm) printf "%s%s%s\n" "$(_color_red)" "$text" "$(_color_reset)";;
    -azu) printf "%s%s%s\n" "$(_color_blu)" "$text" "$(_color_reset)";;
    *) printf "%s\n" "$text";;
  esac
}

# -----------------------
# Helpers
# -----------------------
ensure_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    msg -verm "Este script necesita ejecutarse como root. Usa sudo."
    exit 1
  fi
}

has_cmd() { command -v "$1" >/dev/null 2>&1; }

download_to() {
  local url="$1"; local out="$2"
  if has_cmd curl; then
    curl -fsSL "$url" -o "$out"
  elif has_cmd wget; then
    wget -qO "$out" "$url"
  else
    return 1
  fi
}

selection_fun() {
  local max=${1:-0}
  local sel
  while true; do
    read -r -p "Seleccione una opción [1-${max}]: " sel
    if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= max )); then
      echo "$sel"
      return 0
    fi
    echo "Opción inválida."
  done
}

# -----------------------
# Prepara dirs y backups
# -----------------------
ensure_dirs_and_backups() {
  mkdir -p "$PROT_DIR" "$ADM_inst" "$ADM_slow" "$BACKUP_DIR"
  touch "$CONF_AUTOSTART" 2>/dev/null || true
}

backup_resolv_conf() {
  if [[ -f /etc/resolv.conf && ! -f "$RESOLV_BACKUP" ]]; then
    cp -a /etc/resolv.conf "$RESOLV_BACKUP" || true
  fi
}
restore_resolv_conf() {
  if [[ -f "$RESOLV_BACKUP" ]]; then
    cp -a "$RESOLV_BACKUP" /etc/resolv.conf || true
    rm -f "$RESOLV_BACKUP" || true
  fi
}
backup_autostart() {
  if [[ -f "$CONF_AUTOSTART" && ! -f "$AUTOSTART_BACKUP" ]]; then
    cp -a "$CONF_AUTOSTART" "$AUTOSTART_BACKUP" || true
  fi
}
restore_autostart() {
  if [[ -f "$AUTOSTART_BACKUP" ]]; then
    mv -f "$AUTOSTART_BACKUP" "$CONF_AUTOSTART" || true
  fi
}

# -----------------------
# iptables helpers
# -----------------------
add_iptables_rules() {
  if ! has_cmd iptables; then
    msg -verm "iptables no encontrado: no se aplicarán reglas automáticas."
    return
  fi
  if ! iptables -C INPUT -p udp --dport 5300 -j ACCEPT &>/dev/null; then
    iptables -I INPUT -p udp --dport 5300 -j ACCEPT || true
  fi
  if ! iptables -t nat -C PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 &>/dev/null; then
    iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 || true
  fi
}
remove_iptables_rules() {
  if ! has_cmd iptables; then return; fi
  iptables -D INPUT -p udp --dport 5300 -j ACCEPT 2>/dev/null || true
  iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 2>/dev/null || true
}

# -----------------------
# drop_port (mejorada) — detecta puertos locales escuchando
# -----------------------
drop_port() {
  DPB=""
  declare -A seen_ports=()

  if has_cmd ss; then
    local lines
    lines=$(ss -ltnp 2>/dev/null || true)
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      # Considerar solo líneas con LISTEN (tcp)
      if [[ "$line" != *LISTEN* ]]; then continue; fi
      local localaddr port proc
      localaddr=$(awk '{print $4}' <<<"$line")
      port="${localaddr##*:}"
      proc=$(sed -n 's/.*users:(("'\''\?\([^"'\''),]*\).*/\1/p' <<<"$line" | awk -F, '{print $1}')
      proc="${proc:-unknown}"
      # normalizar proc (ssh saltaría como sshd)
      proc="${proc#\"}"; proc="${proc%\"}"
      if [[ -z "${seen_ports[$port]:-}" ]]; then
        DPB+="${proc}:${port} "
        seen_ports[$port]=1
      fi
    done <<<"$lines"
    # También comprobar UDP listening (opcional) - combinamos si es necesario
    lines=$(ss -lunp 2>/dev/null || true)
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      # No filtrar por LISTEN para UDP (no aparece); extraer localaddr campo 4
      localaddr=$(awk '{print $4}' <<<"$line")
      port="${localaddr##*:}"
      proc=$(sed -n 's/.*users:(("'\''\?\([^"'\''),]*\).*/\1/p' <<<"$line" | awk -F, '{print $1}')
      proc="${proc:-unknown}"
      proc="${proc#\"}"; proc="${proc%\"}"
      if [[ -n "$port" && -z "${seen_ports[$port]:-}" ]]; then
        DPB+="${proc}:${port} "
        seen_ports[$port]=1
      fi
    done <<<"$lines"
  elif has_cmd lsof; then
    local l
    l=$(lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null || true)
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      [[ "$line" == COMMAND* ]] && continue
      local proc namefield port
      proc=$(awk '{print $1}' <<<"$line")
      namefield=$(awk '{print $9}' <<<"$line")
      port="${namefield##*:}"
      if [[ -n "$port" && -z "${seen_ports[$port]:-}" ]]; then
        DPB+="${proc}:${port} "
        seen_ports[$port]=1
      fi
    done <<<"$l"
  else
    if has_cmd netstat; then
      local out
      out=$(netstat -ltnp 2>/dev/null || true)
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if [[ "$line" != *LISTEN* ]]; then continue; fi
        local localaddr port proc
        localaddr=$(awk '{print $4}' <<<"$line")
        port="${localaddr##*:}"
        proc=$(awk '{print $7}' <<<"$line" | cut -d'/' -f2)
        proc="${proc:-unknown}"
        if [[ -n "$port" && -z "${seen_ports[$port]:-}" ]]; then
          DPB+="${proc}:${port} "
          seen_ports[$port]=1
        fi
      done <<<"$out"
    fi
  fi

  DPB="${DPB%% }"
}

# -----------------------
# Mostrar información
# -----------------------
info() {
  clear
  msg -bar
  if [[ -f "${ADM_slow}/domain_ns" ]]; then
    msg -ama "NS (Nameserver): $(<"${ADM_slow}/domain_ns")"
  else
    msg -verm "No existe ${ADM_slow}/domain_ns"
  fi
  msg -bar
  if [[ -f "${ADM_slow}/server.pub" ]]; then
    msg -ama "Server public key: $(<"${ADM_slow}/server.pub")"
  else
    msg -verm "No existe ${ADM_slow}/server.pub"
  fi
  msg -bar
}

# -----------------------
# Instalador principal (ini_slow)
# - Añadida selección automática para sshd:22 (prefiere ssh si existe)
# -----------------------
ini_slow() {
  ensure_dirs_and_backups
  backup_resolv_conf
  backup_autostart

  clear
  msg -bar
  msg -ama "        INSTALADOR SLOWDNS"
  msg -bar
  echo ""

  drop_port

  declare -a arr
  local idx=1
  for entry in $DPB; do
    local proto=${entry%%:*}
    local port=${entry##*:}
    arr[$idx]="$proto:$port"
    printf " [%d] %s -> %s\n" "$idx" "$proto" "$port"
    ((idx++))
  done

  # NUEVO: Si se detecta sshd:22 o ssh:22 auto-seleccionamos para usar SSH
  local auto_selected=0
  if [[ -n "$DPB" ]]; then
    for e in $DPB; do
      case "$e" in
        sshd:22|ssh:22)
          # seleccionar sshd 22 automáticamente
          printf '%s\n' "22" > "${ADM_slow}/puerto"
          printf '%s\n' "sshd" > "${ADM_slow}/puertoloc"
          PORT="22"
          auto_selected=1
          msg -verd "Se detectó SSH en puerto 22 y se seleccionó automáticamente."
          ;;
      esac
      [[ $auto_selected -eq 1 ]] && break
    done
  fi

  if [[ $auto_selected -eq 0 ]]; then
    if [[ ${#arr[@]} -eq 0 ]]; then
      msg -verm "No se detectaron servicios compatibles para elegir puerto local."
      read -r -p "Puerto local manual (ej: 22) o ENTER para cancelar: " manu
      if [[ -z "$manu" ]]; then
        msg -verm "Cancelado."
        return 1
      fi
      printf '%s\n' "$manu" > "${ADM_slow}/puerto"
      printf '%s\n' "manual" > "${ADM_slow}/puertoloc"
      PORT="$manu"
    else
      local max=$((idx-1))
      msg -bar
      local opc
      opc=$(selection_fun "$max")
      local sel_entry=${arr[$opc]}
      local sel_proto=${sel_entry%%:*}
      local sel_port=${sel_entry##*:}
      printf '%s\n' "$sel_port" > "${ADM_slow}/puerto"
      printf '%s\n' "$sel_proto" > "${ADM_slow}/puertoloc"
      PORT="$sel_port"
    fi
  fi

  clear
  msg -bar
  msg -ama " Puerto de conexion a traves de SlowDNS: $PORT"
  msg -bar

  local NS=""
  while [[ -z "$NS" ]]; do
    read -r -p " Tu dominio NS (ej: ns.midominio.com): " NS
  done
  printf '%s\n' "$NS" > "${ADM_slow}/domain_ns"
  msg -ama " Tu dominio NS: $NS"
  msg -bar

  if [[ ! -f "$DNS_BIN_PATH" ]]; then
    msg -ama " Descargando binario dns-server..."
    read -r -p "Introduce URL para descargar dns-server (ENTER para usar la URL por defecto): " url
    url="${url:-$DEFAULT_DNS_URL}"
    if ! download_to "$url" "$DNS_BIN_PATH"; then
      msg -verm " DESCARGA FALLIDA"
      msg -ama "No se pudo descargar el binario: $url"
      return 1
    fi
    chmod +x "$DNS_BIN_PATH" || true
    msg -verd " DESCARGA CON EXITO: $DNS_BIN_PATH"
  else
    msg -ama "Binario dns-server ya presente en $DNS_BIN_PATH"
  fi

  local pub=""
  if [[ -f "${ADM_slow}/server.pub" ]]; then
    pub=$(<"${ADM_slow}/server.pub")
  fi

  if [[ -n "$pub" ]]; then
    read -r -p " Usar la clave existente? [S/n]: " ex_key
    ex_key="${ex_key:-S}"
    if [[ "$ex_key" =~ ^[sSyY]$ ]]; then
      msg -ama " Usando clave existente."
    else
      rm -f "${ADM_slow}/server.key" "${ADM_slow}/server.pub" || true
      if ! "$DNS_BIN_PATH" -gen-key -privkey-file "${ADM_slow}/server.key" -pubkey-file "${ADM_slow}/server.pub" &>/dev/null; then
        msg -verm "Error generando la clave con $DNS_BIN_PATH"
      fi
    fi
  else
    rm -f "${ADM_slow}/server.key" "${ADM_slow}/server.pub" || true
    if ! "$DNS_BIN_PATH" -gen-key -privkey-file "${ADM_slow}/server.key" -pubkey-file "${ADM_slow}/server.pub" &>/dev/null; then
      msg -verm "Error generando la clave con $DNS_BIN_PATH"
    fi
  fi

  msg -bar
  msg -ama "    INSTALANDO / CONFIGURANDO SLOWDNS ..."
  if has_cmd apt-get; then
    apt-get update -qq || true
    apt-get install -y -qq screen iptables || true
  fi

  add_iptables_rules
  backup_resolv_conf
  if [[ -w /etc/resolv.conf || -L /etc/resolv.conf ]]; then
    printf '%s\n' "nameserver 1.1.1.1" >/etc/resolv.conf
    printf '%s\n' "nameserver 1.0.0.1" >>/etc/resolv.conf
  fi

  if has_cmd screen; then
    screen -dmS slowdns "$DNS_BIN_PATH" -udp :5300 -privkey-file "${ADM_slow}/server.key" "$NS" "127.0.0.1:$PORT"
  else
    nohup "$DNS_BIN_PATH" -udp :5300 -privkey-file "${ADM_slow}/server.key" "$NS" "127.0.0.1:$PORT" >/dev/null 2>&1 &
  fi

  read -r -p "¿Deseas crear un servicio systemd para slowdns? [s/N]: " want_svc
  want_svc="${want_svc:-N}"
  if [[ "$want_svc" =~ ^[sSyY]$ ]]; then
    create_systemd_service || msg -verm "No fue posible crear el servicio systemd"
  fi

  backup_autostart
  aut_line="netstat -au | grep -w 7300 > /dev/null || {  screen -r -S 'slowdns' -X quit;  screen -dmS slowdns ${DNS_BIN_PATH} -udp :5300 -privkey-file ${ADM_slow}/server.key ${NS} 127.0.0.1:${PORT} ; }"
  sed -i.bak '/slowdns/d' "$CONF_AUTOSTART" 2>/dev/null || true
  printf '%s\n' "$aut_line" >>"$CONF_AUTOSTART"

  msg -verd " INSTALACION/CONFIGURACION COMPLETADA"
  return 0
}

# -----------------------
# Crear servicio systemd
# -----------------------
create_systemd_service() {
  if [[ ! -f "$DNS_BIN_PATH" ]]; then
    msg -verm "No se encontró $DNS_BIN_PATH. No se crea el servicio."
    return 1
  fi
  local ns=""
  if [[ -f "${ADM_slow}/domain_ns" ]]; then ns=$(<"${ADM_slow}/domain_ns"); fi
  local port=""
  if [[ -f "${ADM_slow}/puerto" ]]; then port=$(<"${ADM_slow}/puerto"); fi
  port="${port:-5300}"

  cat >"$SERVICE_FILE" <<EOF
[Unit]
Description=SlowDNS server (managed by slowdns.sh)
After=network.target

[Service]
Type=simple
ExecStart=${DNS_BIN_PATH} -udp :5300 -privkey-file ${ADM_slow}/server.key ${ns} 127.0.0.1:${port}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  chmod 644 "$SERVICE_FILE"
  systemctl daemon-reload || true
  systemctl enable --now slowdns.service || true
  msg -verd "Servicio systemd creado y arrancado: slowdns.service"
  return 0
}

# -----------------------
# Reiniciar/Stop/Uninstall/Status
# -----------------------
stop_background_processes() {
  if has_cmd screen; then
    screen -ls | awk '/slowdns/{print $1}' | while read -r s; do
      screen -S "$s" -X quit >/dev/null 2>&1 || true
    done || true
  fi
  pkill -f "$DNS_BIN_NAME" 2>/dev/null || true
  if systemctl list-unit-files | grep -q '^slowdns.service'; then
    systemctl disable --now slowdns.service 2>/dev/null || true
  fi
}
reset_slow() {
  stop_background_processes
  if [[ -f "${ADM_slow}/domain_ns" && -f "${ADM_slow}/puerto" ]]; then
    local NS=$(<"${ADM_slow}/domain_ns")
    local PORT=$(<"${ADM_slow}/puerto")
    if has_cmd screen; then
      screen -dmS slowdns "$DNS_BIN_PATH" -udp :5300 -privkey-file "${ADM_slow}/server.key" "$NS" "127.0.0.1:$PORT"
    else
      nohup "$DNS_BIN_PATH" -udp :5300 -privkey-file "${ADM_slow}/server.key" "$NS" "127.0.0.1:$PORT" >/dev/null 2>&1 &
    fi
    sed -i.bak '/slowdns/d' "$CONF_AUTOSTART" 2>/dev/null || true
    aut_line="netstat -au | grep -w 7300 > /dev/null || {  screen -r -S 'slowdns' -X quit;  screen -dmS slowdns ${DNS_BIN_PATH} -udp :5300 -privkey-file ${ADM_slow}/server.key ${NS} 127.0.0.1:${PORT} ; }"
    printf '%s\n' "$aut_line" >>"$CONF_AUTOSTART" 2>/dev/null || true
    msg -verd " SERVICIO SLOW REINICIADO"
  else
    msg -verm "Falta configuración (domain_ns/puerto)."
    return 1
  fi
}
stop_slow() {
  clear
  msg -bar
  msg -ama "    Deteniendo SlowDNS...."
  stop_background_processes
  if [[ -f "$CONF_AUTOSTART" ]]; then
    sed -i.bak '/dns-server/d' "$CONF_AUTOSTART" || true
    sed -i.bak '/slowdns/d' "$CONF_AUTOSTART" || true
  fi
  msg -verd " SERVICIO SLOW DETENIDO"
}
uninstall_slow() {
  ensure_root
  echo ""
  msg -verm "ATENCIÓN: Esto eliminará SlowDNS y RESTAURARÁ cambios aplicados."
  read -r -p "¿Continuar con la desinstalación completa? [n]: " yn
  yn="${yn:-n}"
  if [[ ! "$yn" =~ ^[sSyY]$ ]]; then
    msg -verm "Desinstalación cancelada."
    return 1
  fi
  msg -ama "Deteniendo procesos y servicios..."
  stop_background_processes
  msg -ama "Eliminando reglas iptables añadidas..."
  remove_iptables_rules
  msg -ama "Restaurando /etc/resolv.conf si existe backup..."
  restore_resolv_conf
  msg -ama "Restaurando /etc/autostart (si hay backup)..."
  if [[ -f "$AUTOSTART_BACKUP" ]]; then
    mv -f "$AUTOSTART_BACKUP" "$CONF_AUTOSTART" 2>/dev/null || true
  else
    sed -i.bak '/slowdns/d' "$CONF_AUTOSTART" 2>/dev/null || true
    sed -i.bak '/dns-server/d' "$CONF_AUTOSTART" 2>/dev/null || true
  fi
  msg -ama "Eliminando servicio systemd (si existe)..."
  if [[ -f "$SERVICE_FILE" ]]; then
    systemctl disable --now slowdns.service 2>/dev/null || true
    rm -f "$SERVICE_FILE" 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
  fi
  msg -ama "Eliminando binario y claves..."
  rm -f "$DNS_BIN_PATH" 2>/dev/null || true
  rm -rf "${ADM_slow:?}/"* 2>/dev/null || true
  msg -ama "Eliminando directorios creados (si están vacíos)..."
  rmdir --ignore-fail-on-non-empty "$ADM_inst" 2>/dev/null || true
  rmdir --ignore-fail-on-non-empty "$ADM_slow" 2>/dev/null || true
  rmdir --ignore-fail-on-non-empty "$PROT_DIR" 2>/dev/null || true
  msg -verd "Desinstalación completa realizada."
}

status() {
  echo "---- SlowDNS status ----"
  if has_cmd ss && ss -uapn 2>/dev/null | grep -q ":5300"; then
    echo "Puerto 5300: activo"
  elif has_cmd lsof && lsof -i udp:5300 >/dev/null 2>&1; then
    echo "Puerto 5300: activo"
  else
    echo "Puerto 5300: inactivo"
  fi
  if [[ -f "${ADM_slow}/domain_ns" ]]; then echo "NS: $(<"${ADM_slow}/domain_ns")"; else echo "NS: (no configurado)"; fi
  if [[ -f "${ADM_slow}/server.pub" ]]; then echo "Server.pub: existe"; else echo "Server.pub: no existe"; fi
  if systemctl list-unit-files | grep -q '^slowdns.service'; then
    systemctl status slowdns.service --no-pager || true
  fi
  echo "-------------------------"
}

main_menu() {
  ensure_root
  ensure_dirs_and_backups

  while true; do
    clear
    msg -bar
    msg -ama "        MENÚ DE GESTIÓN SLOWDNS"
    msg -bar
    echo "  [1] INSTALAR / CONFIGURAR SLOWDNS"
    echo "  [2] REINICIAR SLOWDNS"
    echo "  [3] DETENER SLOWDNS"
    echo "  [4] DATOS DE LA CUENTA"
    echo "  [5] ESTADO/STATUS"
    echo "  [6] DESINSTALAR / LIMPIAR COMPLETAMENTE"
    echo "  [0] SALIR"
    msg -bar
    read -r -p "Seleccione una opción: " opc
    case "$opc" in
      1) ini_slow ;;
      2) reset_slow ;;
      3) stop_slow ;;
      4) info ;;
      5) status ;;
      6) uninstall_slow ;;
      0) exit 0 ;;
      *) msg -verm "Opción inválida." ;;
    esac
    read -r -p "Presiona ENTER para continuar..." _ || true
  done
}

usage() {
  cat <<EOF
Uso: $0 [opcion]
Si se ejecuta sin parámetros se muestra el menú interactivo.

Opciones:
  --install   Instala/configura
  --start     Inicia
  --stop      Detiene
  --restart   Reinicia
  --status    Muestra estado
  --info      Muestra domain_ns y server.pub
  --uninstall Desinstala y limpia
EOF
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    --install) ensure_root; ini_slow ;;
    --start) ensure_root; reset_slow ;;
    --stop) ensure_root; stop_slow ;;
    --restart|--reload) ensure_root; reset_slow ;;
    --status) status ;;
    --info) info ;;
    --uninstall) ensure_root; uninstall_slow ;;
    --help|-h) usage ;;
    *) main_menu ;;
  esac
fi
