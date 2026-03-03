#!/bin/bash
# =========================================================
# SinNombre - Actualizador Completo
# Actualiza TODOS los archivos del panel, no solo el menu
# =========================================================

set -euo pipefail

INSTALL_DIR="/etc/SN"
REPO_URL="https://github.com/SINNOMBRE22/SN.git"
REPO_BRANCH="main"

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/colores.sh" 2>/dev/null || source "/etc/SN/lib/colores.sh" 2>/dev/null || true

update_full() {
  clear
  hr
  echo -e "${W}            ACTUALIZAR SCRIPT (COMPLETO)${N}"
  hr

  if [[ ! -d "$INSTALL_DIR/.git" ]]; then
    echo -e "${Y}No se detectó repositorio git en $INSTALL_DIR${N}"
    echo -e "${Y}Reinstalando desde cero...${N}"
    rm -rf "$INSTALL_DIR"
    git clone --depth 1 -b "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR"
  else
    cd "$INSTALL_DIR"
    echo -e "${C}Obteniendo cambios desde GitHub...${N}"

    # Guardar hash actual
    OLD_HASH=$(git rev-parse HEAD 2>/dev/null || echo "desconocido")

    # Reset y pull
    git fetch origin "$REPO_BRANCH" --depth 1
    git reset --hard "origin/$REPO_BRANCH"

    NEW_HASH=$(git rev-parse HEAD 2>/dev/null || echo "desconocido")

    if [[ "$OLD_HASH" == "$NEW_HASH" ]]; then
      echo -e "${G}Ya tienes la última versión.${N}"
    else
      echo -e "${G}Actualizado: ${Y}${OLD_HASH:0:8}${N} -> ${G}${NEW_HASH:0:8}${N}"
    fi
  fi

  # Reasignar permisos
  echo -e "${C}Asignando permisos...${N}"
  chmod +x "$INSTALL_DIR/menu"
  find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} \;

  # Recrear symlinks
  cat > /usr/local/bin/sn <<EOF
#!/usr/bin/env bash
[[ \$(id -u) -eq 0 ]] || { echo "Usa sudo"; exit 1; }
[[ -f /etc/.sn/lic ]] || { echo "Licencia no encontrada"; exit 1; }
exec $INSTALL_DIR/menu "\$@"
EOF
  chmod +x /usr/local/bin/sn
  ln -sf /usr/local/bin/sn /usr/local/bin/menu

  hr
  echo -e "${G}Actualización completa.${N}"
  echo -e "${Y}Reinicia el menú para aplicar cambios: ${C}menu${N}"
  hr
  pause
}

require_root
update_full
