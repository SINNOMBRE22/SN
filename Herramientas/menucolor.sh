#!/bin/bash
# =========================================================
# SN Plus - SELECTOR DE 30 TEMAS (Versión ANSI)
# Compatible con JuiceSSH y terminales básicas
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
    LIB_DIR="/etc/SN/lib"
    mkdir -p "$LIB_DIR"
fi

# ------------------------------------------------------------------
# 2. Definir la ruta del archivo de configuración del tema
# ------------------------------------------------------------------
CONFIG_TEMA="$LIB_DIR/tema.conf"

# ------------------------------------------------------------------
# 3. Definición de 30 Temas ANSI (colores estándar)
# ------------------------------------------------------------------
declare -A T
T[1]='\033[0;31m'     # Rojo
T[2]='\033[0;32m'     # Verde
T[3]='\033[0;34m'     # Azul
T[4]='\033[0;36m'     # Cian
T[5]='\033[1;33m'     # Amarillo (oro)
T[6]='\033[0;35m'     # Magenta (rosa)
T[7]='\033[1;35m'     # Magenta brillante (viola)
T[8]='\033[1;31m'     # Rojo brillante (naranja)
T[9]='\033[0;32m'     # Verde (spring)
T[10]='\033[1;31m'    # Rojo brillante (hotpink)
T[11]='\033[0;32m'    # Verde lima
T[12]='\033[1;33m'    # Amarillo kaki
T[13]='\033[1;37m'    # Blanco nieve
T[14]='\033[0;37m'    # Gris
T[15]='\033[0;34m'    # Azul (bluep)
T[16]='\033[0;31m'    # Rojo bordó
T[17]='\033[0;36m'    # Cian teal
T[18]='\033[0;35m'    # Magenta índigo
T[19]='\033[1;33m'    # Amarillo oro
T[20]='\033[0;36m'    # Cian turquesa
T[21]='\033[1;31m'    # Rojo salmón
T[22]='\033[0;32m'    # Verde lawn
T[23]='\033[1;37m'    # Blanco puro
T[24]='\033[0;34m'    # Azul dodger
T[25]='\033[1;31m'    # Rojo saddle
T[26]='\033[1;31m'    # Rojo dark orange
T[27]='\033[0;32m'    # Verde palegreen
T[28]='\033[1;35m'    # Magenta plum
T[29]='\033[0;34m'    # Azul steel
T[30]='\033[0;30m'    # Negro (black)

# Nombres de los temas (coincidentes)
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
        # Guardar color en el archivo de configuración (código ANSI)
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
