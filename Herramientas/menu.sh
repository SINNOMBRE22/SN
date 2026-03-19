#!/bin/bash
# =========================================================
# SinNombre v2.1 - Menú de Herramientas (Ubuntu 22.04+)
# =========================================================

# 1. Cargar colores (Ruta absoluta para evitar errores)
source /root/SN/lib/colores.sh 2>/dev/null || true

# 2. Variables de entorno
VPS_src="/etc/SN"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 3. Funciones del menú
run_module() {
  local script_name="$1"
  local script_path="$2/$script_name"
  if [[ -f "$script_path" ]]; then
    chmod +x "$script_path"
    bash "$script_path"
  else
    echo -e "${R} Error: No se encontró $script_name${N}"; sleep 2
  fi
}

# (Otras funciones: clean_cache, update_system, etc... se mantienen igual)

# 4. Bucle del Menú
while true; do
    clear_screen
    msg -bar
    echo -e "${W}                        HERRAMIENTAS${N}"
    msg -bar
    echo -e " ${R}[${Y}01${R}] ${R}» ${C}LIMPIAR CACHE         ${R}[${Y}05${R}] ${R}» ${C}CAMBIAR PASS ROOT${N}"
    echo -e " ${R}[${Y}02${R}] ${R}» ${C}GESTION SWAP          ${R}[${Y}06${R}] ${R}» ${C}CONFIGURAR DOMINIO${N}"
    echo -e " ${R}[${Y}03${R}] ${R}» ${C}REINICIAR SERVICIOS   ${R}[${Y}07${R}] ${R}» ${C}ZONA HORARIA${N}"
    echo -e " ${R}[${Y}04${R}] ${R}» ${C}ACTUALIZAR SISTEMA    ${R}[${Y}08${R}] ${R}» ${Y}${BOLD}TEMAS DEL PANEL${N}"
    msg -bar3
    echo -e " ${R}[${Y}00${R}] ${R}« SALIR${N}"
    msg -bar
    echo -ne "${W}┌─[${G}${BOLD}Seleccione una opción${W}]${N}\n╰─> : ${G}"
    read -r op
    echo -ne "${N}"

    case "${op:-}" in
      1|01) clean_cache ;;
      2|02) run_module "swap.sh" "$ROOT_DIR" ;;
      3|03) restart_services ;;
      4|04) update_system ;;
      5|05) change_root_pass ;;
      6|06) configure_domain ;;
      7|07) run_module "zonahora.sh" "$ROOT_DIR" ;;
      # --- EL SECRETO DEL CAMBIO INSTANTÁNEO ---
      8|08) 
        run_module "menucolor.sh" "$ROOT_DIR"
        source /root/SN/lib/colores.sh # Recarga los colores al volver
        ;;
      0|00) exit 0 ;;
      *) echo -e "${R} Opción inválida${N}"; sleep 1 ;;
    esac
done

