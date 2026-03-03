#!/bin/bash
# =========================================================
# SinNombre - Speedtest independiente
# Puede ejecutarse desde el menú principal directamente
# =========================================================

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'

clear
echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
echo -e "${W}                     SPEEDTEST${N}"
echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"

# Verificar si speedtest-cli está instalado
if command -v speedtest-cli &>/dev/null; then
  echo -e "${C}Ejecutando speedtest...${N}"
  echo ""
  speedtest-cli --simple
elif command -v speedtest &>/dev/null; then
  echo -e "${C}Ejecutando speedtest (Ookla)...${N}"
  echo ""
  speedtest
else
  echo -e "${Y}speedtest-cli no está instalado.${N}"
  echo -ne "${C}¿Deseas instalarlo ahora? (s/n): ${N}"
  read -r install_opt
  if [[ "$install_opt" =~ ^[sS]$ ]]; then
    echo -e "${Y}Instalando...${N}"
    apt-get update -y >/dev/null 2>&1
    apt-get install -y speedtest-cli >/dev/null 2>&1
    if command -v speedtest-cli &>/dev/null; then
      echo -e "${G}Instalado correctamente.${N}"
      echo ""
      speedtest-cli --simple
    else
      echo -e "${R}Error al instalar speedtest-cli.${N}"
    fi
  else
    echo -e "${R}Cancelado.${N}"
  fi
fi

echo ""
echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"
read -r -p "Presiona Enter para continuar..."
