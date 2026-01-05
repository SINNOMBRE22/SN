#!/bin/bash
# Motor del módulo SN-BANNER

CONF="/etc/SN/banner/banner.conf"
TPL="/etc/SN/banner/banner.tpl"

[[ ! -f "$CONF" ]] && exit 0
source "$CONF"

[[ "$BANNER_SN" != "ON" ]] && exit 0

USER_NOW="$(whoami)"
[[ "$USER_NOW" == "root" ]] && exit 0  # Evitar para root

# EXPIRACIÓN
EXP=$(chage -l "$USER_NOW" 2>/dev/null | awk -F': ' '/Account expires/{print $2}')
[[ "$EXP" == "never" ]] && EXP="Ilimitado"

# DÍAS RESTANTES
NOW=$(date +%s)
if [[ "$EXP" != "Ilimitado" ]]; then
    EXPSEC=$(date -d "$EXP" +%s 2>/dev/null)
    [[ -n "$EXPSEC" ]] && DAYS=$(( (EXPSEC - NOW) / 86400 )) || DAYS="∞"
    [[ $DAYS -lt 0 ]] && DAYS="Expirado"
else
    DAYS="Ilimitado"
fi

# LÍMITE DE CONEXIONES (desde GECOS en /etc/passwd)
LIMIT=$(getent passwd "$USER_NOW" 2>/dev/null | cut -d: -f5 | awk -F',' '{print $NF}')
[[ -z "$LIMIT" ]] || [[ "$LIMIT" =~ ^(hwid|token)$ ]] && LIMIT="Sin límite"

# TRÁFICO (placeholder - requiere módulo adicional de monitoreo)
TRF="N/A"

# GENERAR BANNER (limpia pantalla y muestra)
clear
sed \
  -e "s|USER|$USER_NOW|g" \
  -e "s|EXP|$EXP|g" \
  -e "s|DAYS|$DAYS|g" \
  -e "s|LIMIT|$LIMIT|g" \
  -e "s|TRF|$TRF|g" \
  "$TPL"
