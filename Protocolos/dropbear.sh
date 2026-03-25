#!/bin/bash
# =========================================================
# SinNombre v2.4 - ADMINISTRADOR DROPBEAR (instalación directa mod)
# Archivo: SN/Protocolos/dropbear.sh
# =========================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Cargar colores desde lib ────────────────────────────
LIB_COLORES="$ROOT_DIR/lib/colores.sh"
if [[ -f "$LIB_COLORES" ]]; then
  source "$LIB_COLORES"
else
  R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'
  M='\033[0;35m'; C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'
  D='\033[2m'; BOLD='\033[1m'
  hr()  { echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }
  sep() { echo -e "${R}──────────────────────────────────────────────────────────${N}"; }
  pause(){ echo ""; read -r -p "Presiona Enter para continuar..."; }
fi

# ── Rutas de configuración ──────────────────────────────
DROPBEAR_CONF="/etc/default/dropbear"
DROPBEAR_BIN="/usr/sbin/dropbear"
DROPBEAR_KEYS="/etc/dropbear"
DROPBEAR_LOGS="/var/log/dropbear*"
CUSTOM_SERVICE="/etc/systemd/system/dropbear-custom.service"
SN_MOD_TAG="Dropbear_Mod_SN"    # Tag visible en SSH-2.0-<tag>_version
SN_MOD_FLAG="/etc/SN/.dropbear_mod"  # Marca que indica instalación mod

# =========================================================
#  VERIFICAR DEPENDENCIAS
# =========================================================
check_dependencies() {
  local deps=("bc" "tput" "ss" "ufw")
  local missing=()
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      missing+=("$dep")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo -e "  ${Y}⚠${N} ${W}Faltan dependencias: ${missing[*]}${N}"
    echo -ne "  ${W}¿Instalar automáticamente? (s/n): ${G}"
    read -r inst
    echo -ne "${N}"
    if [[ "${inst,,}" == "s" ]]; then
      apt-get update -y >/dev/null 2>&1 || true
      for dep in "${missing[@]}"; do
        apt-get install -y "$dep" >/dev/null 2>&1 || {
          echo -e "  ${R}✗${N} ${W}No se pudo instalar $dep${N}"
          if [[ "$dep" == "bc" || "$dep" == "tput" ]]; then
            echo -e "  ${Y}⚠${N} ${W}Las animaciones pueden fallar${N}"
          fi
        }
      done
    else
      echo -e "  ${Y}⚠${N} ${W}Continúa sin las dependencias (pueden fallar animaciones)${N}"
    fi
  fi
}

# =========================================================
#  ANIMACIONES PROFESIONALES (con fallback)
# =========================================================

progress_bar() {
  local msg="$1"
  local duration="${2:-3}"
  local width=20

  if ! command -v bc >/dev/null 2>&1; then
    echo -ne "  ${C}•${N} ${W}${msg}${N} ["
    for ((j=0; j<width; j++)); do
      echo -n "━"
      sleep 0.1
    done
    echo "]  ${G}✓${N}"
    return
  fi

  tput civis 2>/dev/null || true

  for ((i = 0; i <= width; i++)); do
    local pct=$(( i * 100 / width ))

    local bar_color="$R"
    (( pct > 33 )) && bar_color="$Y"
    (( pct > 66 )) && bar_color="$G"

    printf "\r  ${C}•${N} ${W}%-20s${N} " "$msg"

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

show_header() {
  clear
  hr
  echo -e "${W}${BOLD}         ADMINISTRADOR DROPBEAR SSH${N}"
  hr
}

is_installed() {
  command -v dropbear >/dev/null 2>&1 || [[ -f "$DROPBEAR_BIN" ]]
}

get_ports() {
  local ports=""
  ports=$(ss -H -lntp 2>/dev/null \
    | awk '/dropbear/ {print $4}' \
    | awk -F: '{print $NF}' \
    | sort -nu | tr '\n' ',' | sed 's/,$//') || true

  if [[ -z "$ports" ]] && [[ -f "$DROPBEAR_CONF" ]]; then
    ports=$(grep -oP 'DROPBEAR_EXTRA_ARGS=".*?-p \K[0-9]+' "$DROPBEAR_CONF" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
  fi

  [[ -n "${ports//,/}" ]] && echo "$ports" || echo ""
}

is_running() {
  pgrep -x dropbear >/dev/null 2>&1
}

# ── Gestión de servicios robusta ────────────────────────
stop_all_dropbear() {
  pkill dropbear 2>/dev/null || true
  if command -v systemctl >/dev/null 2>&1; then
    systemctl stop dropbear 2>/dev/null || true
    systemctl stop dropbear-custom 2>/dev/null || true
  elif command -v service >/dev/null 2>&1; then
    service dropbear stop 2>/dev/null || true
  fi
  sleep 0.5
}

restart_dropbear_service() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl restart dropbear 2>/dev/null || {
      systemctl restart dropbear-custom 2>/dev/null
    }
  elif command -v service >/dev/null 2>&1; then
    service dropbear restart 2>/dev/null
  else
    pkill dropbear 2>/dev/null || true
    dropbear -R -E >/dev/null 2>&1 &
  fi
  sleep 1
}

# ── Asegurar /bin/false en shells ───────────────────────
ensure_false_shell() {
  if ! grep -q "^/bin/false$" /etc/shells 2>/dev/null; then
    echo "/bin/false" >> /etc/shells
  fi
}

# ── Firewall: abrir puertos en UFW/iptables ────────────
open_firewall_ports() {
  local ports="$1"
  if command -v ufw >/dev/null 2>&1 && ufw status | grep -q active; then
    for port in $(echo "$ports" | tr ',' ' '); do
      ufw allow "$port"/tcp >/dev/null 2>&1
    done
    echo -e "  ${G}✓${N} ${W}Puertos abiertos en UFW${N}"
  elif command -v iptables >/dev/null 2>&1; then
    for port in $(echo "$ports" | tr ',' ' '); do
      iptables -A INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null
    done
    echo -e "  ${G}✓${N} ${W}Puertos abiertos en iptables${N}"
  fi
}

close_firewall_ports() {
  local ports="$1"
  if command -v ufw >/dev/null 2>&1 && ufw status | grep -q active; then
    for port in $(echo "$ports" | tr ',' ' '); do
      ufw delete allow "$port"/tcp >/dev/null 2>&1
    done
  elif command -v iptables >/dev/null 2>&1; then
    for port in $(echo "$ports" | tr ',' ' '); do
      iptables -D INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null
    done
  fi
}

# ── Verificar que dropbear esté corriendo ───────────────
verify_dropbear_running() {
  local max_tries=5
  local wait_time=2
  for ((i=1; i<=max_tries; i++)); do
    if is_running; then
      return 0
    fi
    sleep "$wait_time"
  done
  return 1
}

# ── Crear servicio systemd personalizado ────────────────
create_custom_service() {
  local ports_array=("$@")
  local exec_args=""
  for p in "${ports_array[@]}"; do
    exec_args="$exec_args -p $p"
  done
  exec_args="$exec_args -K 300 -I 600 -R -F"

  # Matar servicio estandar antes para evitar conflicto de puertos
  systemctl disable dropbear 2>/dev/null || true
  systemctl stop dropbear 2>/dev/null || true
  pkill -x dropbear 2>/dev/null || true
  sleep 1

  cat > "$CUSTOM_SERVICE" << EOF
[Unit]
Description=Dropbear SSH Server (Custom)
After=network.target
Conflicts=dropbear.service

[Service]
Type=simple
ExecStart=$DROPBEAR_BIN $exec_args
Restart=always
RestartSec=5
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload >/dev/null 2>&1
  systemctl enable dropbear-custom >/dev/null 2>&1
  systemctl start dropbear-custom >/dev/null 2>&1
  sleep 2
}

# ── Función para escribir configuración limpia ──────────
write_dropbear_config() {
  local ports_array=("$@")
  local extra_args=""
  for p in "${ports_array[@]}"; do
    extra_args="$extra_args -p $p"
  done
  extra_args="$extra_args -K 300 -I 600"

  cat > "$DROPBEAR_CONF" << EOF
# Configuración Dropbear - SinNombre SSH
NO_START=0
DROPBEAR_EXTRA_ARGS="$extra_args"
DROPBEAR_BANNER=""
DROPBEAR_RECEIVE_WINDOW=65536
EOF
}

# ── Forzar inicio con servicio personalizado ────────────
force_start_dropbear() {
  local ports_array=("$@")
  echo -e "  ${Y}⚠${N} ${W}Fallo el inicio estándar. Creando servicio personalizado...${N}"
  stop_all_dropbear
  create_custom_service "${ports_array[@]}"
  if verify_dropbear_running; then
    echo -e "  ${G}✓${N} ${W}Servicio personalizado iniciado correctamente${N}"
    return 0
  else
    echo -e "  ${R}✗${N} ${W}No se pudo iniciar ni con servicio personalizado${N}"
    return 1
  fi
}

# =========================================================
#  COMPILAR E INSTALAR DROPBEAR MOD (DISCRETO)
# =========================================================
compile_dropbear_mod() {
  # Dependencias (sin mensajes)
  (
    apt-get install -y build-essential libz-dev wget libpam0g-dev >/dev/null 2>&1 || true
  ) &
  spinner $! "Preparando entorno"

  # Versión instalada vía apt
  local db_ver
  db_ver=$(apt-cache show dropbear 2>/dev/null | grep -m1 "^Version:" | awk '{print $2}' | cut -d- -f1 | tr -d '\n\r')
  [[ -z "$db_ver" ]] && db_ver="2022.83"

  local src_dir="/tmp/dropbear_sn_build"
  rm -rf "$src_dir" && mkdir -p "$src_dir"

  # Descargar y descomprimir
  (
    wget -q "https://matt.ucc.asn.au/dropbear/releases/dropbear-${db_ver}.tar.bz2"          -O "${src_dir}/dropbear.tar.bz2" 2>/dev/null     || wget -q "https://matt.ucc.asn.au/dropbear/releases/dropbear-2022.83.tar.bz2"              -O "${src_dir}/dropbear.tar.bz2" 2>/dev/null
    tar -xjf "${src_dir}/dropbear.tar.bz2" -C "$src_dir" --strip-components=1 2>/dev/null
  ) &
  spinner $! "Descargando fuentes"

  if [[ ! -f "${src_dir}/svr-session.c" ]]; then
    echo -e "  ${R}✗${N} ${W}Error al descargar el código fuente${N}"
    rm -rf "$src_dir"
    return 1
  fi

  local mod_tag="${SN_MOD_TAG}"

  # Patch 1: sysoptions.h — cambiar string de versión
  sed -i 's|"SSH-2.0-dropbear_" DROPBEAR_VERSION|"SSH-2.0-'"${SN_MOD_TAG}"'_" DROPBEAR_VERSION|'     "${src_dir}/sysoptions.h"

  # Patch 2: svr-auth.c — hook post-auth + banner dinámico (sin mensajes)
  cat > /tmp/sn_patch.py << 'PEOF' 2>/dev/null
import sys
f = sys.argv[1]
with open(f) as fh: src = fh.read()
if "sn_post_auth" in src:
    sys.exit(0)
h1 = '{ char _sn[512]; snprintf(_sn,sizeof(_sn),"SN_USER=\'%s\' /etc/sn_post_auth.sh 2>/dev/null",ses.authstate.pw_name?ses.authstate.pw_name:""); system(_sn); } '
src = src.replace("send_msg_userauth_success();", h1 + "send_msg_userauth_success();", 1)
h2 = '{ FILE *_f=fopen("/etc/motd","r"); if(_f){ buffer *_b=buf_new(4096); int _c; while((_c=fgetc(_f))!=EOF && _b->len<4090) buf_putbyte(_b,(unsigned char)_c); fclose(_f); if(_b->len>0){ buf_setpos(_b,0); send_msg_userauth_banner(_b); } buf_free(_b); } } '
src = src.replace("ses.authstate.authdone = 1;", h2 + "ses.authstate.authdone = 1;", 1)
with open(f, "w") as fh: fh.write(src)
PEOF
  python3 /tmp/sn_patch.py "${src_dir}/svr-auth.c" >/dev/null 2>&1
  rm -f /tmp/sn_patch.py

  # Compilar con PAM habilitado
  (
    cd "$src_dir" || exit 1
    ./configure --prefix=/usr --disable-zlib --enable-pam >/dev/null 2>&1
    make -j"$(nproc)" >/dev/null 2>&1
  ) &
  spinner $! "Compilando"

  if [[ ! -f "${src_dir}/dropbear" ]]; then
    echo -e "  ${R}✗${N} ${W}Error en la compilación${N}"
    rm -rf "$src_dir"
    return 1
  fi

  # Instalar y marcar
  cp -f "${src_dir}/dropbear" "$DROPBEAR_BIN"
  cp -f "${src_dir}/dropbearkey" /usr/bin/dropbearkey 2>/dev/null || true
  chmod +x "$DROPBEAR_BIN"
  mkdir -p "$(dirname "$SN_MOD_FLAG")"
  echo "${mod_tag}_${db_ver}" > "$SN_MOD_FLAG"
  rm -rf "$src_dir"

  # Crear /etc/pam.d/dropbear si no existe
  if [[ ! -f /etc/pam.d/dropbear ]]; then
    cp /etc/pam.d/sshd /etc/pam.d/dropbear 2>/dev/null ||     printf '%s\n' '@include common-auth' '@include common-account' '@include common-session' '@include common-password' > /etc/pam.d/dropbear
  fi

  # Crear script post-auth vacío
  if [[ ! -f /etc/sn_post_auth.sh ]]; then
    printf '%s\n' '#!/bin/bash' 'exit 0' > /etc/sn_post_auth.sh
    chmod +x /etc/sn_post_auth.sh
  fi

  echo -e "  ${G}✓${N} ${W}Compilación finalizada${N}"
  return 0
}

# =========================================================
#  LÓGICA COMÚN POST-INSTALACIÓN (puertos, keys, servicio)
# =========================================================
_finalize_install() {
  local final_ports=("$@")

  # Crear directorio de claves
  mkdir -p "$DROPBEAR_KEYS" 2>/dev/null || true

  # Generar claves RSA
  if [[ ! -f "${DROPBEAR_KEYS}/dropbear_rsa_host_key" ]]; then
    (
      dropbearkey -t rsa -f "${DROPBEAR_KEYS}/dropbear_rsa_host_key" -s 2048 >/dev/null 2>&1 || {
        ssh-keygen -t rsa -f "${DROPBEAR_KEYS}/dropbear_rsa_host_key" -N "" >/dev/null 2>&1 || true
      }
    ) &
    spinner $! "Generando claves"
  fi

  # Escribir configuración
  progress_bar "Aplicando configuración" 1
  write_dropbear_config "${final_ports[@]}"

  # Deshabilitar servicio estándar
  if command -v systemctl >/dev/null 2>&1; then
    systemctl disable dropbear >/dev/null 2>&1 || true
    systemctl stop dropbear >/dev/null 2>&1 || true
  fi

  # Crear e iniciar servicio personalizado
  (
    create_custom_service "${final_ports[@]}"
  ) &
  spinner $! "Iniciando servicio"

  if verify_dropbear_running; then
    echo -e "  ${G}✓${N} ${W}Servicio iniciado correctamente${N}"
  else
    echo -e "  ${R}✗${N} ${W}No se pudo iniciar el servicio${N}"
  fi

  open_firewall_ports "$(echo "${final_ports[@]}" | tr " " ",")"

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ DROPBEAR INSTALADO CON ÉXITO${N}"
  hr
  echo ""
  echo -e "  ${W}Puerto(s):${N}        ${G}${final_ports[*]}${N}"
  echo ""
  hr
  pause
}

# =========================================================
#  INSTALAR DROPBEAR (DIRECTAMENTE EL MOD)
# =========================================================
install_dropbear_custom() {
  show_header
  echo -e "  ${W}${BOLD}INSTALAR DROPBEAR${N}"
  hr

  if is_installed; then
    echo -e "  ${Y}⚠${N} ${W}Dropbear ya está instalado${N}"
    pause
    return 0
  fi

  ensure_false_shell

  # ── Pedir puertos ──────────────────────────────────────
  echo ""
  echo -e "  ${W}Puedes ingresar varios puertos separados por espacio${N}"
  echo -e "  ${W}Ejemplo: 80 90 443 2222${N}"
  local ports_input=""
  while [[ -z "$ports_input" ]]; do
    echo -ne "  ${W}Ingresa los puertos [1-65535]: ${G}"
    read -r ports_input
    echo -ne "${N}"
    local valid=true
    for p in $ports_input; do
      if [[ ! "$p" =~ ^[0-9]+$ ]] || (( p < 1 || p > 65535 )); then
        echo -e "  ${R}✗${N} ${W}Puerto inválido: $p${N}"
        valid=false
        break
      fi
    done
    [[ "$valid" != true ]] && ports_input=""
  done

  # Verificar conflictos
  local used_ports="" final_ports=()
  for p in $ports_input; do
    if ss -H -lnt 2>/dev/null | awk '{print $4}' | awk -F: '{print $NF}' | grep -qx "$p"; then
      used_ports="$used_ports $p"
    else
      final_ports+=("$p")
    fi
  done

  if [[ -n "$used_ports" ]]; then
    echo -e "  ${R}✗${N} ${W}Puertos ya en uso:${Y}$used_ports${N}"
    echo -ne "  ${W}¿Continuar con los puertos libres? (s/n): ${G}"
    read -r force
    echo -ne "${N}"
    [[ "${force,,}" != "s" ]] && { pause; return 0; }
  fi

  if [[ ${#final_ports[@]} -eq 0 ]]; then
    echo -e "  ${R}✗${N} ${W}No hay puertos válidos libres${N}"
    pause
    return 1
  fi

  echo ""
  sep

  # Paso 1: Actualizar repos e instalar paquete base
  (
    apt-get update -y >/dev/null 2>&1 || true
  ) &
  spinner $! "Actualizando repositorios"

  progress_bar "Instalando paquete base" 3
  apt-get install -y dropbear >/dev/null 2>&1 || {
    echo -e "  ${R}✗${N} ${W}Error al instalar dropbear${N}"
    pause
    return 1
  }
  rm -f "$SN_MOD_FLAG"

  # Paso 2: Compilar e instalar la versión modificada
  compile_dropbear_mod || {
    echo -e "  ${Y}⚠${N} ${W}No se pudo compilar la versión personalizada, se usará la normal${N}"
    sleep 2
  }

  # Paso 3: Finalizar
  _finalize_install "${final_ports[@]}"
}

# =========================================================
#  CONFIGURAR PUERTO (MÚLTIPLES PUERTOS)
# =========================================================
set_port_custom() {
  show_header
  echo -e "  ${W}${BOLD}CONFIGURAR PUERTO DROPBEAR${N}"
  hr

  local current_ports
  current_ports=$(get_ports)
  echo ""
  echo -e "  ${W}Puerto(s) actual(es):${N} ${Y}${current_ports:-Ninguno}${N}"
  sep

  echo -e "  ${W}Ingresa nuevos puertos separados por espacio${N}"
  echo -e "  ${W}Ejemplo: 80 90 443${N}"
  local new_ports_input=""
  while [[ -z "$new_ports_input" ]]; do
    echo -ne "  ${W}Ingresa los puertos [1-65535]: ${G}"
    read -r new_ports_input
    echo -ne "${N}"
    valid=true
    for p in $new_ports_input; do
      if [[ ! "$p" =~ ^[0-9]+$ ]] || (( p < 1 || p > 65535 )); then
        echo -e "  ${R}✗${N} ${W}Puerto inválido: $p${N}"
        valid=false
        break
      fi
    done
    if [[ "$valid" != true ]]; then
      new_ports_input=""
    fi
  done

  local new_ports=($new_ports_input)
  if [[ ${#new_ports[@]} -eq 0 ]]; then
    echo -e "  ${R}✗${N} ${W}No ingresaste puertos válidos${N}"
    pause
    return 1
  fi

  echo ""
  # Detener todo
  stop_all_dropbear &
  spinner $! "Deteniendo servicios existentes"

  # Escribir nueva configuración estándar
  progress_bar "Actualizando configuración" 1
  write_dropbear_config "${new_ports[@]}"

  # Reiniciar servicio (método estándar)
  (
    restart_dropbear_service
  ) &
  spinner $! "Reiniciando con nuevos puertos"

  # Verificar que arrancó
  if ! verify_dropbear_running; then
    force_start_dropbear "${new_ports[@]}"
  fi

  # Actualizar firewall: cerrar antiguos, abrir nuevos
  if [[ -n "$current_ports" ]]; then
    close_firewall_ports "$current_ports"
  fi
  open_firewall_ports "$(echo "${new_ports[@]}" | tr ' ' ',')"

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ Puertos configurados: ${Y}${new_ports[*]}${N}"
  hr
  pause
  return 0
}

# =========================================================
#  REINICIAR SERVICIO
# =========================================================
restart_service() {
  show_header
  echo ""

  stop_all_dropbear
  restart_dropbear_service

  if is_running; then
    echo -e "  ${G}${BOLD}✓ Servicio Dropbear reiniciado${N}"
  else
    echo -e "  ${R}✗ Falla al reiniciar Dropbear${N}"
  fi

  hr
  pause
  return 0
}

# =========================================================
#  DESINSTALAR DROPBEAR (COMPLETO)
# =========================================================
uninstall_dropbear_custom() {
  show_header
  echo -e "  ${W}${BOLD}DESINSTALAR DROPBEAR${N}"
  hr

  if ! is_installed; then
    echo -e "  ${Y}⚠${N} ${W}Dropbear no está instalado${N}"
    pause
    return 0
  fi

  echo ""
  echo -e "  ${Y}⚠ Se eliminará completamente:${N}"
  echo -e "    ${W}•${N} Paquete dropbear"
  echo -e "    ${W}•${N} Claves SSH ${C}${DROPBEAR_KEYS}/${N}"
  echo -e "    ${W}•${N} Configuración ${C}${DROPBEAR_CONF}${N}"
  echo -e "    ${W}•${N} Servicio personalizado (si existe)"
  echo -e "    ${W}•${N} Logs del servicio"
  echo -e "    ${W}•${N} Reglas de firewall asociadas"
  echo ""
  echo -ne "  ${W}¿Estás seguro? (s/n): ${G}"
  read -r confirm
  echo -ne "${N}"

  if [[ "${confirm,,}" != "s" ]]; then
    echo -e "  ${Y}Cancelado${N}"
    pause
    return 0
  fi

  echo ""
  sep

  # Obtener puertos actuales antes de desinstalar
  local current_ports
  current_ports=$(get_ports)

  # Detener y deshabilitar servicios
  (
    stop_all_dropbear
    if command -v systemctl >/dev/null 2>&1; then
      systemctl disable dropbear 2>/dev/null || true
      systemctl disable dropbear-custom 2>/dev/null || true
      systemctl stop dropbear-custom 2>/dev/null || true
      rm -f "$CUSTOM_SERVICE" 2>/dev/null || true
      systemctl daemon-reload 2>/dev/null || true
    fi
  ) &
  spinner $! "Deteniendo servicios"

  # Purgar paquete
  progress_bar "Eliminando paquete" 3
  apt-get purge -y dropbear dropbear-bin dropbear-run 2>/dev/null || true
  apt-get purge -y 'dropbear*' >/dev/null 2>&1 || true
  apt-get autoremove -y >/dev/null 2>&1 || true

  # Eliminar configuración y claves
  progress_bar "Limpiando configuración" 2
  rm -rf "$DROPBEAR_KEYS" >/dev/null 2>&1 || true
  rm -f /etc/default/dropbear* >/dev/null 2>&1 || true

  # Limpiar logs
  (
    journalctl --rotate >/dev/null 2>&1 || true
    journalctl --vacuum-time=1s --unit=dropbear 2>/dev/null || true
    journalctl --vacuum-time=1s --unit=dropbear-custom 2>/dev/null || true
    rm -f $DROPBEAR_LOGS 2>/dev/null || true
  ) &
  spinner $! "Limpiando logs y restos"

  # Cerrar puertos en firewall
  if [[ -n "$current_ports" ]]; then
    close_firewall_ports "$current_ports"
  fi

  echo ""
  hr
  echo -e "  ${G}${BOLD}✓ DROPBEAR DESINSTALADO COMPLETAMENTE${N}"
  hr
  echo ""
  sleep 1
  pause
  return 0
}

# =========================================================
#  VER PUERTOS ACTIVOS
# =========================================================
list_ports_menu() {
  show_header
  echo -e "  ${W}${BOLD}PUERTOS DROPBEAR ACTIVOS${N}"
  hr

  local ports
  ports=$(get_ports)

  if [[ -z "$ports" ]]; then
    echo ""
    echo -e "  ${Y}⚠${N} ${W}No hay puertos Dropbear activos${N}"
    echo ""
    if is_running; then
      echo -e "  ${D}Dropbear está corriendo pero no se detectaron puertos${N}"
    else
      echo -e "  ${D}Dropbear no está corriendo${N}"
    fi
  else
    local -a arr_ports
    IFS=',' read -ra arr_ports <<< "$ports"
    echo ""
    local i=1
    for port in "${arr_ports[@]}"; do
      echo -e "  ${G}[${W}${i}${G}]${N} ${W}▸${N} Puerto ${Y}${port}${N}"
      ((i++))
    done
  fi

  echo ""

  # Mostrar estado del proceso
  sep
  if is_running; then
    local pid_count
    pid_count="$(pgrep -cx dropbear 2>/dev/null || echo "0")"
    echo -e "  ${W}Estado:${N}    ${G}${BOLD}● Corriendo${N}  ${D}(${pid_count} procesos)${N}"
  else
    echo -e "  ${W}Estado:${N}    ${R}${BOLD}● Detenido${N}"
  fi
  sep

  pause
  return 0
}

# =========================================================
#  VER LOGS
# =========================================================
show_log() {
  show_header
  echo -e "  ${W}${BOLD}LOGS DE DROPBEAR${N} ${D}(últimas 20 líneas)${N}"
  hr
  echo ""

  local log_output
  log_output="$(journalctl -u dropbear --no-pager -n 20 2>/dev/null || journalctl -u dropbear-custom --no-pager -n 20 2>/dev/null || true)"

  if [[ -n "$log_output" ]]; then
    echo -e "${D}${log_output}${N}"
  else
    echo -e "  ${Y}⚠${N} ${W}No hay logs disponibles${N}"
    echo -e "  ${D}SSH-2.0-dropbear (sin registros recientes)${N}"
  fi

  echo ""
  hr
  pause
  return 0
}

# =========================================================
#  MENÚ PRINCIPAL
# =========================================================
main_menu() {
  require_root
  check_dependencies

  while true; do
    show_header

    local ports st
    ports=$(get_ports)

    if ! is_installed; then
      # ── Menú: NO instalado ──────────────────────────
      echo ""
      echo -e "  ${W}Estado:${N} ${R}${BOLD}● NO INSTALADO${N}"
      hr
      echo ""
      echo -e "  ${G}[${W}1${G}]${N}  ${C}Instalar Dropbear${N}"
      hr
      echo -e "  ${G}[${W}0${G}]${N}  ${W}Volver${N}"
      hr
      echo ""
      echo -ne "  ${W}Opción: ${G}"
      read -r opt
      echo -ne "${N}"

      case "${opt:-}" in
        1) install_dropbear_custom ;;
        0) break ;;
        *) echo -e "  ${R}Opción inválida${N}"; sleep 1 ;;
      esac
      continue
    fi

    # ── Menú: Instalado ────────────────────────────────
    if is_running; then
      st="${G}${BOLD}● ON${N}"
    else
      st="${R}${BOLD}● OFF${N}"
    fi

    echo ""
    echo -e "  ${W}ESTADO:${N}    ${st}"
    echo -e "  ${W}PUERTOS:${N}   ${Y}${ports:-Ninguno}${N}"
    hr
    echo ""
    echo -e "  ${G}[${W}1${G}]${N}  ${C}Reiniciar servicio${N}"
    echo -e "  ${G}[${W}2${G}]${N}  ${C}Configurar puerto${N}"
    echo -e "  ${G}[${W}3${G}]${N}  ${C}Ver puertos activos${N}"
    echo -e "  ${G}[${W}4${G}]${N}  ${C}Ver logs${N}"
    sep
    echo -e "  ${G}[${W}5${G}]${N}  ${C}Instalar / Reinstalar${N}"
    echo -e "  ${G}[${W}6${G}]${N}  ${R}Desinstalar Dropbear${N}"
    hr
    echo -e "  ${G}[${W}0${G}]${N}  ${W}Volver${N}"
    hr
    echo ""
    echo -ne "  ${W}Opción: ${G}"
    read -r opt
    echo -ne "${N}"

    case "${opt:-}" in
      1) restart_service ;;
      2) set_port_custom ;;
      3) list_ports_menu ;;
      4) show_log ;;
      5) install_dropbear_custom ;;
      6) uninstall_dropbear_custom ;;
      0) break ;;
      *) echo -e "  ${R}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

# ── Manejo de señales (salir limpio) ────────────────────
trap 'echo -ne "${N}"; tput cnorm 2>/dev/null; exit 0' SIGINT SIGTERM

# ── Soporte para argumentos de línea de comandos ────────
case "${1:-}" in
  "--install"|"-i")   require_root; check_dependencies; install_dropbear_custom ;;
  "--set-port"|"-p")  require_root; check_dependencies; set_port_custom ;;
  "--restart"|"-r")   require_root; check_dependencies; restart_service ;;
  "--uninstall"|"-u") require_root; check_dependencies; uninstall_dropbear_custom ;;
  "--ports"|"-pt")    require_root; check_dependencies; list_ports_menu ;;
  "--log"|"-l")       require_root; check_dependencies; show_log ;;
  *)                  main_menu ;;
esac
