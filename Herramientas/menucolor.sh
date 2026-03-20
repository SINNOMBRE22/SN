#!/bin/bash
# =========================================================
# SN Plus - SELECTOR DE 30 TEMAS (Versión Portable)
# =========================================================

# ------------------------------------------------------------------
# 1. Cargar librería de colores (busca en /root/SN y /etc/SN)
# ------------------------------------------------------------------
if [[ -f "/root/SN/lib/colores.sh" ]]; then
    source "/root/SN/lib/colores.sh"
    LIB_DIR="/root/SN/lib"
elif [[ -f "/etc/SN/lib/colores.sh" ]]; then
    source "/etc/SN/lib/colores.sh"
    LIB_DIR="/etc/SN/lib"
else
    # Fallback: definir funciones mínimas para que el script funcione
    R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'
    M='\033[0;35m'; C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'
    BOLD='\033[1m'
    hr()  { echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }
    sep() { echo -e "${R}──────────────────────────────────────────────────────────${N}"; }
    clear_screen() { clear; }
    # Crear directorio por defecto para guardar el tema
    LIB_DIR="/etc/SN/lib"
    mkdir -p "$LIB_DIR"
fi

# ------------------------------------------------------------------
# 2. Definir la ruta del archivo de configuración del tema
# ------------------------------------------------------------------
CONFIG_TEMA="$LIB_DIR/tema.conf"

# ------------------------------------------------------------------
# 3. Definición de 30 Temas RGB y sus nombres
# ------------------------------------------------------------------
declare -A T
T[1]='\033[38;2;255;0;0m';      T[2]='\033[38;2;0;255;0m';        T[3]='\033[38;2;0;100;255m'
T[4]='\033[38;2;0;255;255m';    T[5]='\033[38;2;255;215;0m';      T[6]='\033[38;2;255;20;147m'
T[7]='\033[38;2;148;0;211m';    T[8]='\033[38;2;255;69;0m';       T[9]='\033[38;2;0;255;127m'
T[10]='\033[38;2;255;105;180m'; T[11]='\033[38;2;173;255;47m';    T[12]='\033[38;2;240;230;140m'
T[13]='\033[38;2;224;224;224m'; T[14]='\033[38;2;105;105;105m';   T[15]='\033[38;2;0;0;255m'
T[16]='\033[38;2;128;0;0m';     T[17]='\033[38;2;0;128;128m';     T[18]='\033[38;2;75;0;130m'
T[19]='\033[38;2;218;165;32m';  T[20]='\033[38;2;0;206;209m';     T[21]='\033[38;2;255;160;122m'
T[22]='\033[38;2;124;252;0m';   T[23]='\033[38;2;255;255;255m';   T[24]='\033[38;2;30;144;255m'
T[25]='\033[38;2;139;69;19m';   T[26]='\033[38;2;255;140;0m';     T[27]='\033[38;2;152;251;152m'
T[28]='\033[38;2;221;160;221m'; T[29]='\033[38;2;70;130;180m';    T[30]='\033[38;2;30;30;30m'

N=("" "Rojo" "Verde" "Azul" "Cian" "Oro" "Rosa" "Viola" "Naranja" "Spring" "HotPk" "Lima" "Kaki" "Nieve" "Gris" "BlueP" "Bord" "Teal" "Indig" "Gold" "Turq" "Salmon" "Lawn" "PureW" "Dodger" "Saddle" "DarkOr" "PalGr" "Plum" "Steel" "Black")

# ------------------------------------------------------------------
# 4. Bucle principal del selector
# ------------------------------------------------------------------
while true; do
    clear_screen
    hr
    echo -e "             ${W}${BOLD}ESTILOS DE INTERFAZ SN-PLUS (30 TEMAS)${N}"
    hr
    for i in {1..10}; do
        j=$((i + 10)); k=$((i + 20))
        printf " ${R}[${Y}%2d${R}]${N} ${T[$i]}%-12s${N}" "$i" "${N[$i]}"
        printf " ${R}[${Y}%2d${R}]${N} ${T[$j]}%-12s${N}" "$j" "${N[$j]}"
        printf " ${R}[${Y}%2d${R}]${N} ${T[$k]}%-12s${N}" "$k" "${N[$k]}"
        echo ""
    done
    sep
    echo -e "  ${R}[${Y}0${R}]${N} ${W}VOLVER AL MENU PRINCIPAL${N}"
    hr
    echo -ne "  ${W}Elige un tema (1-30): ${G}"
    read -r opt
    [[ "$opt" == "0" ]] && break
    if [[ -n "${T[$opt]:-}" ]]; then
        # Guardar color en el archivo de configuración
        echo "L_COLOR='${T[$opt]}'" > "$CONFIG_TEMA"
        # Aplicar el color en la sesión actual para que se vea de inmediato
        L_COLOR="${T[$opt]}"
        echo -e "\n  ${G}✓ ¡Tema '${N[$opt]}' aplicado!${N}"
        sleep 1
    else
        echo -e "\n  ${R}✗ Opción inválida.${N}"
        sleep 1
    fi
done
