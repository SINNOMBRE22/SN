#!/bin/bash
# =========================================================
# SinNombre - Pi-hole / DNS (Placeholder)
# Archivo: Herramientas/pi.sh
# Estado: En desarrollo
# =========================================================

# Cargar colores y funciones compartidas
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/colores.sh" 2>/dev/null \
  || source "/etc/SN/lib/colores.sh" 2>/dev/null || true

clear
hr
echo -e "${W}               PI-HOLE / DNS${N}"
hr
echo ""
echo -e "${Y}Este módulo está en desarrollo.${N}"
echo -e "${W}Próximamente podrás:${N}"
echo -e "  ${C}•${N} Instalar y configurar Pi-hole"
echo -e "  ${C}•${N} Gestionar listas de bloqueo DNS"
echo -e "  ${C}•${N} Ver estadísticas de consultas DNS"
echo ""
hr
pause.
