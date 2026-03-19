#!/bin/bash
set -euo pipefail

# =========================================================
# SinNombre v1.0 - GESTIÓN DE CERTIFICADOS SSL
# Adaptación visual: @SIN_NOMBRE22
# =========================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Cargar colores desde lib ────────────────────────────
LIB_COLORES="$ROOT_DIR/lib/colores.sh"
if [[ -f "$LIB_COLORES" ]]; then
  source "$LIB_COLORES"
else
  # Fallback: colores básicos por si falla la carga
  R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'
  W='\033[1;37m'; N='\033[0m'; BOLD='\033[1m'
  hr()  { echo -e "${R}══════════════════════════ / / / ══════════════════════════${N}"; }
  sep() { echo -e "${R}──────────────────────────────────────────────────────────${N}"; }
  pause() { echo ""; read -r -p "Presiona Enter para continuar..."; }
fi

# ── Rutas Base ──────────────────────────────────────────
VPS_src="/etc/SN"
VPS_crt="/etc/SN/cert"
VPS_tmp="/tmp"

mkdir -p "$VPS_src" "$VPS_crt"

# ── Utilidades Visuales ─────────────────────────────────
title() {
  clear
  hr
  echo -e "${W}${BOLD}      $*${N}"
  hr
}

# ── Funciones Lógicas ───────────────────────────────────

stop_port(){
  echo -e "  ${Y}•${N} ${W}Comprobando puertos 80 y 443...${N}"
  local ports=('80' '443')
  for i in "${ports[@]}"; do
    if lsof -i:"$i" | grep -i -q "listen"; then
      echo -ne "  ${R}•${N} ${W}Liberando puerto: ${Y}$i${N}"
      lsof -i:"$i" | awk '{print $2}' | grep -v "PID" | xargs kill -9 2>/dev/null || true
      echo -e " ${G}[OK]${N}"
      sleep 1
    fi
  done
}

cert_install(){
  local domain="$1"
  local mail="${2:-}"

  if [[ ! -e $HOME/.acme.sh/acme.sh ]]; then
    echo -e "  ${Y}•${N} ${W}Instalando script acme.sh...${N}"
    curl -s "https://get.acme.sh" | sh &>/dev/null || true
  fi

  if [[ -n "$mail" ]]; then
    echo -e "  ${Y}•${N} ${W}Registrando cuenta en ${C}ZeroSSL${N}..."
    "$HOME/.acme.sh/acme.sh" --register-account -m "$mail" --server zerossl
    "$HOME/.acme.sh/acme.sh" --set-default-ca --server zerossl
  else
    echo -e "  ${Y}•${N} ${W}Aplicando servidor ${C}Let's Encrypt${N}..."
    "$HOME/.acme.sh/acme.sh" --set-default-ca --server letsencrypt
  fi

  echo -e "  ${Y}•${N} ${W}Generando certificado para: ${G}$domain${N}"
  if "$HOME"/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256 --force; then
    "$HOME"/.acme.sh/acme.sh --installcert -d "$domain" --fullchainpath "$VPS_crt/$domain.crt" --keypath "$VPS_crt/$domain.key" --ecc --force &>/dev/null
    rm -rf "$HOME/.acme.sh/${domain}_ecc"
    echo -e "\n  ${G}✓ Certificado SSL generado con éxito.${N}"
    echo "$domain" > "$VPS_src/dominio.txt"
  else
    rm -rf "$HOME/.acme.sh/${domain}_ecc"
    echo -e "\n  ${R}✗ Error al generar el certificado SSL.${N}"
    echo -e "  ${Y}Asegúrate que el dominio apunte a esta IP.${N}"
  fi
  pause
}

ext_cert(){
  title "INSTALADOR DE CERTIFICADO EXTERNO"
  echo -e "  ${W}Requiere el contenido del ${C}.crt${N}${W} y la ${C}.key${N}"
  sep
  echo -ne "  ${W}¿Continuar? [s/n]: ${G}"
  read -r opcion
  [[ "$opcion" != @(S|s|Y|y) ]] && return

  title "PEGUE EL CONTENIDO DEL CERTIFICADO (.crt)"
  echo -e "  ${Y}Se abrirá nano. Pegue, guarde (Ctrl+O) y salga (Ctrl+X)${N}"
  pause
  nano "$VPS_tmp/tmp.crt"

  title "PEGUE EL CONTENIDO DE LA CLAVE (.key)"
  pause
  nano "$VPS_tmp/tmp.key"

  if openssl x509 -in "$VPS_tmp/tmp.crt" -text -noout &>/dev/null; then
    local DNS
    DNS=$(openssl x509 -in "$VPS_tmp/tmp.crt" -text -noout | grep 'DNS:' | sed 's/, /\n/g' | sed 's/DNS:\| //g' | head -n 1 || echo "certificado")
    
    mv "$VPS_tmp/tmp.crt" "$VPS_crt/$DNS.crt"
    mv "$VPS_tmp/tmp.key" "$VPS_crt/$DNS.key"
    echo "$DNS" > "$VPS_src/dominio.txt"

    title "INSTALACIÓN COMPLETA"
    echo -e "  ${W}Dominio:${N} ${G}$DNS${N}"
    echo -e "  ${W}Expira:${N}  ${Y}$(openssl x509 -noout -in "$VPS_crt/$DNS.crt" -enddate | cut -d= -f2)${N}"
    hr
  else
    echo -e "  ${R}✗ ERROR: Los datos ingresados no son válidos.${N}"
  fi
  pause
}

ger_cert(){
  local modo=$1
  local d_name=""
  local d_mail=""

  title "$([[ $modo == 1 ]] && echo "CERTIFICADO LET'S ENCRYPT" || echo "CERTIFICADO ZEROSSL")"
  
  if [[ $modo == 2 ]]; then
    echo -ne "  ${W}Ingrese correo ZeroSSL: ${G}"
    read -r d_mail
  fi

  if [[ -f "${VPS_src}/dominio.txt" ]]; then
    local actual
    actual=$(cat "${VPS_src}/dominio.txt")
    echo -e "  ${W}Dominio detectado: ${G}$actual${N}"
    echo -ne "  ${W}¿Usar este dominio? [s/n]: ${G}"
    read -r use_old
    [[ "$use_old" == @(s|S) ]] && d_name="$actual"
  fi

  if [[ -z "$d_name" ]]; then
    echo -ne "  ${W}Ingrese su dominio: ${G}"
    read -r d_name
  fi

  [[ -z "$d_name" ]] && return
  stop_port
  cert_install "$d_name" "$d_mail"
}

del_cert() {
  title "ELIMINAR CERTIFICADO SSL"
  if [[ -d "$VPS_crt" && $(ls "$VPS_crt"/*.crt 2>/dev/null | wc -l) -gt 0 ]]; then
    rm -rf "$VPS_crt"/*
    rm -f "$VPS_src/dominio.txt"
    echo -e "  ${G}✓ Certificados eliminados correctamente.${N}"
  else
    echo -e "  ${Y}⚠ No hay certificados para eliminar.${N}"
  fi
  pause
}

# ── Menú Principal ───────────────────────────────────────

menu_cert(){
  while true; do
    title "SUB-DOMINIO Y CERTIFICADO SSL"
    echo -e "  ${R}[${Y}1${R}]${N} ${C}GENERAR CERT SSL (Let's Encrypt)${N}"
    echo -e "  ${R}[${Y}2${R}]${N} ${C}GENERAR CERT SSL (ZeroSSL)${N}"
    echo -e "  ${R}[${Y}3${R}]${N} ${C}INGRESAR CERT SSL EXTERNO${N}"
    sep
    echo -e "  ${R}[${Y}4${R}]${N} ${C}ELIMINAR CERTIFICADO SSL${N}"
    hr
    echo -e "  ${R}[${Y}0${R}]${N} ${W}VOLVER${N}"
    hr
    echo ""
    echo -ne "  ${W}Opcion: ${G}"
    read -r opcion
    echo -ne "${N}"

    case $opcion in
      1) ger_cert 1 ;;
      2) ger_cert 2 ;;
      3) ext_cert ;;
      4) del_cert ;;
      0) break ;;
      *) echo -e "  ${R}Opción inválida${N}"; sleep 1 ;;
    esac
  done
}

menu_cert
