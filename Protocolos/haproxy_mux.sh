#!/bin/bash
# haproxy_mux.sh - Panel rápido para instalar / desinstalar / administrar HAProxy MUX
# Multiplexa Stunnel <-> V2Ray/XRay en el puerto 443 usando SNI
# Diseñado para integrarse en SN/Protocolos/menu.sh
#
# Predefinido para:
#  - V2Ray/XRay en 127.0.0.1:8443 (TLS)
#  - Stunnel en 127.0.0.1:4443 (TLS)
#
# Requisitos: root
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF_DIR="/etc/SN"
CONF_JSON="$CONF_DIR/haproxy-mux.json"
HAPROXY_CFG="/etc/haproxy/haproxy.cfg"
SERVICE_NAME="haproxy-mux"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"
BACKUP_SUFFIX=".sn-orig-$(date +%Y%m%d%H%M%S)"

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'

require_root(){ [[ "$(id -u)" -eq 0 ]] || { echo -e "${R}Ejecuta como root.${N}"; exit 1; } }
pause(){ echo ""; read -r -p "Presiona Enter para continuar..."; }

# -------------------------
# Helpers JSON / conf
# -------------------------
init_conf() {
  mkdir -p "$CONF_DIR"
  if [[ ! -f "$CONF_JSON" ]]; then
    cat > "$CONF_JSON" <<'JSON'
{
  "stunnel_port": 4443,
  "mappings": [
    {
      "host": "v2ray.example.com",
      "port": 8443
    }
  ]
}
JSON
  fi
}

read_conf() { jq -r '.' "$CONF_JSON" 2>/dev/null || echo "{}"; }

save_conf_tmp() {
  local tmp; tmp="$(mktemp)"
  cat > "$tmp" && mv -f "$tmp" "$CONF_JSON"
}

backup_file() {
  local f="$1"
  [[ -f "$f" ]] && cp -a "$f" "${f}${BACKUP_SUFFIX}" || true
}

# -------------------------
# Dependencias
# -------------------------
ensure_deps() {
  local need=""
  command -v haproxy >/dev/null 2>&1 || need="haproxy"
  command -v jq >/dev/null 2>&1 || need="${need:+$need }jq"
  command -v ss >/dev/null 2>&1 || need="${need:+$need }iproute2"
  if [[ -n "$need" ]]; then
    echo -e "${Y}Instalando dependencias: $need${N}"
    apt-get update -y >/dev/null 2>&1 || true
    DEBIAN_FRONTEND=noninteractive apt-get install -y $need >/dev/null 2>&1 || true
  fi
  # Advertencia si haproxy no tiene soporte SSL inspect (opcional)
  if ! haproxy -vv 2>/dev/null | grep -qiE 'SSL|OPENSSL|req_ssl'; then
    echo -e "${Y}Advertencia: HAProxy puede no tener soporte para inspección TLS (req_ssl_sni).${N}"
    echo -e "${Y}Si el ruteo por SNI no funciona, instala una build con OpenSSL/ssl (p. ej. haproxy-full).${N}"
  fi
}

# -------------------------
# Auto-detección (opcional)
# -------------------------
detect_stunnel_port() {
  local p=""
  local cfg="/etc/stunnel/stunnel.conf"
  if [[ -f "$cfg" ]]; then
    p=$(grep -Eo 'accept\s*=\s*[0-9.:]+' "$cfg" | awk -F'=' '{print $2}' | sed 's/^[[:space:]]*//' | sed 's/.*://g' | head -n1 || true)
  fi
  if [[ -z "$p" ]]; then
    p=$(ss -ltnp 2>/dev/null | grep -i stunnel | awk '{print $4}' | awk -F: '{print $NF}' | head -n1 || true)
  fi
  echo "${p:-}"
}

detect_v2ray_port() {
  local p=""
  local files=(/etc/v2ray/config.json /usr/local/etc/v2ray/config.json /etc/xray/config.json /usr/local/etc/xray/config.json)
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    p=$(jq -r '.inbounds[]?.port // empty' "$f" 2>/dev/null | head -n1 || true)
    if [[ -n "$p" ]]; then
      echo "$p"
      return
    fi
  done
  p=$(ss -ltnp 2>/dev/null | grep -E 'v2ray|xray' | awk '{print $4}' | awk -F: '{print $NF}' | head -n1 || true)
  echo "${p:-}"
}

# -------------------------
# Generar haproxy.cfg
# -------------------------
generate_haproxy_cfg() {
  local st_port mappings_json
  st_port=$(jq -r '.stunnel_port // 0' "$CONF_JSON")
  mappings_json=$(jq -c '.mappings' "$CONF_JSON")
  if [[ -z "$st_port" || "$st_port" == "0" ]]; then
    echo -e "${R}stunnel_port no definido. Usa 'Configurar puerto Stunnel'.${N}"
    return 1
  fi

  backup_file "$HAPROXY_CFG"

  cat > "$HAPROXY_CFG" <<EOF
global
    log /dev/log local0
    maxconn 4096
    daemon

defaults
    mode tcp
    timeout connect 5s
    timeout client 1m
    timeout server 1m

frontend ft_tls
    bind *:443
    tcp-request inspect-delay 5s
    tcp-request content accept if { req_ssl_hello_type 1 }
EOF

  # mappings -> use_backend lines
  if [[ "$mappings_json" != "null" ]]; then
    echo "$mappings_json" | jq -c '.[]' | while read -r m; do
      local host port esc_host
      host=$(echo "$m" | jq -r '.host')
      port=$(echo "$m" | jq -r '.port')
      esc_host="${host// /}" # simple escape for spaces (shouldn't have)
      echo "    use_backend bk_v_${esc_host} if { req.ssl_sni -i ${host} }" >> "$HAPROXY_CFG"
    done
  fi

  echo "    default_backend bk_stunnel" >> "$HAPROXY_CFG"
  echo "" >> "$HAPROXY_CFG"

  if [[ "$mappings_json" != "null" ]]; then
    echo "$mappings_json" | jq -c '.[]' | while read -r m; do
      local host port esc_host
      host=$(echo "$m" | jq -r '.host')
      port=$(echo "$m" | jq -r '.port')
      esc_host="${host// /}"
      cat >> "$HAPROXY_CFG" <<EOF
backend bk_v_${esc_host}
    mode tcp
    option tcp-smart-connect
    server v2ray_${esc_host} 127.0.0.1:${port} check

EOF
    done
  fi

  cat >> "$HAPROXY_CFG" <<EOF
backend bk_stunnel
    mode tcp
    option tcp-smart-connect
    server stunnel_local 127.0.0.1:${st_port} check

EOF

  echo -e "${G}haproxy.cfg generado en ${HAPROXY_CFG}${N}"
  return 0
}

# -------------------------
# Service install/uninstall
# -------------------------
install_service() {
  cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=HAProxy Multiplexor Stunnel + V2Ray en 443 (SinNombre)
After=network.target

[Service]
ExecStart=/usr/sbin/haproxy -f $HAPROXY_CFG -db
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now "$SERVICE_NAME" || true
}

uninstall_service() {
  systemctl stop "$SERVICE_NAME" 2>/dev/null || true
  systemctl disable "$SERVICE_NAME" 2>/dev/null || true
  rm -f "$SERVICE_PATH" 2>/dev/null || true
  systemctl daemon-reload
}

# -------------------------
# CRUD mappings
# -------------------------
list_mappings() {
  echo -e "${W}Archivo de configuración: ${CONF_JSON}${N}"
  jq -r '.' "$CONF_JSON"
  echo ""
  echo -e "${W}Mappings:${N}"
  jq -r '.mappings[]? | " - Host: \(.host) -> Puerto: \(.port)"' "$CONF_JSON" || echo "  (ninguno)"
  echo ""
}

add_mapping() {
  read -r -p "Dominio/SNI (ej: v2ray.example.com): " host
  host="${host,,}"
  [[ -z "$host" ]] && { echo "Dominio inválido"; return; }
  read -r -p "Puerto local destino (ej: 8443): " port
  [[ "$port" =~ ^[0-9]+$ ]] || { echo "Puerto inválido"; return; }
  tmp=$(mktemp)
  jq --arg h "$host" --argjson p "$port" '.mappings += [{host:$h, port:$p}]' "$CONF_JSON" > "$tmp" && mv -f "$tmp" "$CONF_JSON"
  echo -e "${G}Mapping agregado: $host -> $port${N}"
  generate_haproxy_cfg || true
  systemctl restart "$SERVICE_NAME" 2>/dev/null || true
}

remove_mapping() {
  echo "Mappings actuales:"
  jq -r '.mappings[]? | @base64' "$CONF_JSON" | nl -ba -w2 -s'. ' | sed 's/^/  /'
  read -r -p "Número del mapping a eliminar (ENTER cancelar): " idx
  [[ -z "$idx" ]] && { echo "Cancelado"; return; }
  [[ "$idx" =~ ^[0-9]+$ ]] || { echo "Índice inválido"; return; }
  tmp=$(mktemp)
  jq "del(.mappings[$((idx-1))])" "$CONF_JSON" > "$tmp" && mv -f "$tmp" "$CONF_JSON"
  echo -e "${G}Mapping eliminado (índice $idx)${N}"
  generate_haproxy_cfg || true
  systemctl restart "$SERVICE_NAME" 2>/dev/null || true
}

set_stunnel_port() {
  read -r -p "Puerto donde escucha stunnel (ej 4443): " port
  [[ "$port" =~ ^[0-9]+$ ]] || { echo "Puerto inválido"; return; }
  tmp=$(mktemp)
  jq --argjson p "$port" '.stunnel_port = $p' "$CONF_JSON" > "$tmp" && mv -f "$tmp" "$CONF_JSON"
  echo -e "${G}stunnel_port seteado a $port${N}"
  generate_haproxy_cfg || true
  systemctl restart "$SERVICE_NAME" 2>/dev/null || true
}

# -------------------------
# Install / Uninstall quick
# -------------------------
do_install() {
  require_root
  ensure_deps
  init_conf
  echo -e "${G}Generando configuración por defecto (V2Ray:8443, Stunnel:4443)${N}"
  generate_haproxy_cfg
  install_service
  echo -e "${G}Instalación completada. Servicio: ${SERVICE_NAME}${N}"
  systemctl status "$SERVICE_NAME" --no-pager || true
}

do_uninstall() {
  require_root
  echo -e "${Y}Deteniendo servicio y limpiando...${N}"
  uninstall_service

  # Eliminar archivos de configuración y backups generados
  rm -fv "$CONF_JSON"
  rm -fv "$HAPROXY_CFG"
  rm -fv /etc/haproxy/haproxy.cfg.sn-orig*
  rm -fv /var/log/haproxy.log*
  rm -fv "$SERVICE_PATH"
  rm -fv /etc/haproxy/haproxy.cfg.sn-orig*

  # Eliminar posibles backups antiguos
  find /etc/haproxy/ -type f -name "haproxy.cfg.sn-orig*" -exec rm -fv {} \; 2>/dev/null

  # Borra el directorio de configuración SN si está vacío
  rmdir --ignore-fail-on-non-empty "$CONF_DIR" 2>/dev/null || true

  # Preguntar si borra completamente haproxy, jq e iproute2 del sistema
  read -r -p "¿Quieres eliminar haproxy, jq y dependencias del sistema? (s/N): " sure
  if [[ "$sure" =~ ^[sS]$ ]]; then
    apt-get remove --purge -y haproxy jq iproute2
    apt-get autoremove --purge -y
  fi

  # Limpiar y recargar servicios systemd
  systemctl daemon-reload
  systemctl reset-failed

  # Limpiar logs en el journal si es posible
  journalctl --user -q --rotate 2>/dev/null || true
  journalctl --user -q --vacuum-time=1s 2>/dev/null || true
  journalctl --vacuum-time=1s 2>/dev/null || true

  echo -e "${G}Desinstalación COMPLETA realizada. Ya no queda ningún rastro del servicio haproxy-mux ni su configuración.${N}"
}

# -------------------------
# Help / Usage
# -------------------------
show_help() {
  cat <<EOF

Uso rápido - Guía de HAProxy MUX (SinNombre)
-------------------------------------------
Objetivo:
  Multiplexar TLS en 443 entre:
    - Backend "V2Ray" (por SNI) -> por defecto 127.0.0.1:8443
    - Backend "Stunnel" (por defecto) -> 127.0.0.1:4443

Flujo recomendado (predefinido):
  1) Instala V2Ray/XRay y configúralo para TLS en puerto 8443.
     - En el cliente V2Ray, configura TLS y SNI = dominio que registrarás (ej: v2ray.example.com).
  2) Instala Stunnel escuchando en 127.0.0.1:4443 (o tu puerto elegido).
  3) Desde este panel, ejecuta "Instalar" -> generará haproxy.cfg y activará el servicio.
  4) Agrega SNI con "Agregar SNI" usando el dominio que usarán tus clientes V2Ray.
  5) Comprueba con: ss -ltnp | grep haproxy  y journalctl -u ${SERVICE_NAME} -n 200

Comandos del panel (menu):
  - Instalar: instala dependencias, genera cfg por defecto y arranca servicio.
  - Desinstalar: detiene servicio, restaura backup si existe y borra config.
  - Detectar puertos: intenta autodescubrir puertos de stunnel y v2ray; guarda stunnel_port si lo detecta.
  - Agregar SNI: añade mapping SNI -> puerto.
  - Quitar SNI: elimina mapping por índice.
  - Setear puerto Stunnel: cambia el puerto destino por defecto.
  - Ver mappings: muestra /etc/SN/haproxy-mux.json

Notas importantes:
  - El ruteo se basa en SNI (req_ssl_sni). Asegúrate de que tus clientes V2Ray envíen SNI correcto.
  - Si V2Ray y Stunnel usan el mismo SNI, HAProxy no podrá diferenciarlos.
  - HAProxy debe tener soporte para inspección TLS. Si tu paquete no lo trae, instala una build con OpenSSL.
  - Puerto 443 requiere permisos root: ejecuta este script como root.

EOF
  pause
}

# -------------------------
# Menu
# -------------------------
main_menu() {
  require_root
  init_conf
  ensure_deps

  while true; do
    clear
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${W}       HAProxy MUX - Stunnel + V2Ray (SNI) - SinNombre${N}"
    echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
    echo -e "${Y}Servicio:${N} $(systemctl is-active --quiet "$SERVICE_NAME" && echo -e "${G}ACTIVO${N}" || echo -e "${R}INACTIVO${N}")"
    echo ""
    echo -e "${C}[1] Instalar / Activar (Instala dependencias y arranca servicio)${N}"
    echo -e "${C}[2] Desinstalar / Desactivar (Detiene y limpia)${N}"
    echo -e "${C}[3] Detectar puertos (auto)${N}"
    echo -e "${C}[4] Ver mappings y configuración${N}"
    echo -e "${C}[5] Agregar SNI (mapping)${N}"
    echo -e "${C}[6] Quitar SNI (mapping)${N}"
    echo -e "${C}[7] Setear puerto Stunnel (por defecto 4443)${N}"
    echo -e "${C}[8] Reiniciar servicio${N}"
    echo -e "${C}[9] Ayuda / Indicaciones de uso${N}"
    echo -e "${C}[0] Salir${N}"
    echo -ne "${W}Opción: ${G}"
    read -r opt
    case "${opt:-}" in
      1) do_install; pause ;;
      2) do_uninstall; pause ;;
      3)
         echo -e "${Y}Detectando puertos...${N}"
         sp=$(detect_stunnel_port)
         vp=$(detect_v2ray_port)
         echo "Stunnel detectado: ${sp:-(no detectado)}"
         echo "V2Ray detectado: ${vp:-(no detectado)}"
         if [[ -n "$sp" && "$sp" != "0" ]]; then
           tmp=$(mktemp); jq --argjson p "$sp" '.stunnel_port = $p' "$CONF_JSON" > "$tmp" && mv -f "$tmp" "$CONF_JSON"
           echo -e "${G}stunnel_port guardado: $sp${N}"
         fi
         pause
         ;;
      4) list_mappings; pause ;;
      5) add_mapping; pause ;;
      6) remove_mapping; pause ;;
      7) set_stunnel_port; pause ;;
      8) systemctl restart "$SERVICE_NAME" && echo -e "${G}Reiniciado${N}"; pause ;;
      9) show_help ;;
      0) break ;;
      *) echo -e "${R}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main_menu
fi
