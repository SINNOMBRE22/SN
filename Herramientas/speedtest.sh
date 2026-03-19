#!/bin/bash

# =========================================================
# SN Plus - Speedtest Pro (Fast & Clean Animations)
# =========================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Colores y Estética ──────────────────────────────────
LIB_COLORES="$ROOT_DIR/lib/colores.sh"
if [[ -f "$LIB_COLORES" ]]; then
  source "$LIB_COLORES"
else
  R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'; BOLD='\033[1m'
  hr(){ echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }
  sep(){ echo -e "${R}──────────────────────────────────────────────────────────${N}"; }
fi

# ── Spinner Ultra-Rápido ────────────────────────────────
loading_anim() {
    local pid=$1
    local delay=0.05
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    echo -ne "  ${C}Conectando con el servidor... ${N}"
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c] " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# ── Barra de Carga Minimalista ─────────────────────────
progress_bar() {
    local duration=0.5
    local columns=30
    echo -ne "  ${W}Procesando: ${G}"
    for ((i=1; i<=columns; i++)); do
        echo -ne "█"
        sleep 0.02
    done
    echo -e "${N} ${G}OK!${N}"
}

# ── Motor del Test ──────────────────────────────────────
run_speedtest() {
    # Verificar dependencias silenciosamente
    if ! command -v speedtest &>/dev/null; then
        echo -ne "  ${Y}Instalando motor Ookla...${N}"
        curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash &>/dev/null
        apt-get install speedtest -y &>/dev/null
        echo -e " ${G}Listo.${N}"
    fi
    if ! command -v jq &>/dev/null; then apt-get install jq -y &>/dev/null; fi

    clear
    hr
    echo -e "             ${W}${BOLD}TEST DE VELOCIDAD | SN-PLUS${N}"
    hr

    # Ejecución en segundo plano para el spinner
    speedtest --accept-license --accept-gdpr -f json > .st_raw.json 2>/dev/null &
    local st_pid=$!
    
    loading_anim $st_pid
    echo -e "${G}¡ÉXITO!${N}"
    echo ""

    # Lectura de datos
    local res=".st_raw.json"
    if [[ ! -s "$res" ]]; then
        echo -e "  ${R}Error de red. Intenta de nuevo.${N}"
        rm -f "$res"; return
    fi

    # Extracción de variables
    local isp=$(jq -r '.isp' "$res")
    local ip=$(jq -r '.interface.externalIp' "$res")
    local dl=$(echo "scale=2; $(jq -r '.download.bandwidth' "$res") / 125000" | bc -l)
    local ul=$(echo "scale=2; $(jq -r '.upload.bandwidth' "$res") / 125000" | bc -l)
    local ping=$(jq -r '.ping.latency' "$res")
    local share=$(jq -r '.result.url' "$res")

    # Animación de barra limpia
    progress_bar
    echo ""

    # Formateo de Información Estilo "Clean Table"
    echo -e "  ${W}ISP      :${N} ${C}$isp${N} (${Y}$ip${N})"
    echo -e "  ${W}LATENCIA :${N} ${G}${ping} ms${N}"
    sep
    echo -e "  ${W}BAJADA   :${N} ${BOLD}${G}${dl} Mbps${N}"
    echo -e "  ${W}SUBIDA   :${N} ${BOLD}${G}${ul} Mbps${N}"
    sep
    echo -e "  ${W}LINK     :${N} ${C}${share}${N}"
    hr
    
    rm -f .st_raw.json
    echo -ne "  ${Y}Presiona Enter para volver...${N}"
    read -r
}

run_speedtest
