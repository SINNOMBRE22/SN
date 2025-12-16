#!/bin/bash
# Helpers de estado para el menú "INSTALADORES - TÚNELES"
# Evita detecciones falsas por puerto (ej: confundir dropbear con python)

# ON si systemd tiene un unit python.<port>.service en active
py_socks_is_on() {
  local u
  # lista TODOS los servicios python.<n>.service existentes en systemd
  while read -r u; do
    [[ -z "${u:-}" ]] && continue
    systemctl is-active --quiet "$u" && return 0
  done < <(systemctl list-units --type=service --all 2>/dev/null \
            | awk '{print $1}' \
            | grep -E '^python\.[0-9]+\.service$' || true)
  return 1
}

# Lista puertos python registrados por units (no por lsof)
py_socks_ports() {
  ls /etc/systemd/system/python.*.service 2>/dev/null \
    | sed -n 's/.*python\.\([0-9]\+\)\.service/\1/p' \
    | sort -n \
    | tr '\n' ' ' | sed 's/[[:space:]]\+$//' || true
}

dropbear_is_on() {
  systemctl is-active --quiet dropbear 2>/dev/null && return 0
  service dropbear status 2>/dev/null | grep -qi "active" && return 0
  return 1
}

stunnel_is_on() {
  systemctl is-active --quiet stunnel4 2>/dev/null && return 0
  service stunnel4 status 2>/dev/null | grep -qi "active" && return 0
  return 1
}

squid_is_on() {
  systemctl is-active --quiet squid 2>/dev/null && return 0
  systemctl is-active --quiet squid3 2>/dev/null && return 0
  service squid status 2>/dev/null | grep -qi "active" && return 0
  service squid3 status 2>/dev/null | grep -qi "active" && return 0
  return 1
}

# Helpers para imprimir [ON]/[OFF] con tu estilo, si no tienes colores, deja así
badge_on_off() {
  if "$@"; then
    echo "[ON ]"
  else
    echo "[OFF]"
  fi
}
