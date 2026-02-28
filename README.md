<h1 align="center">
  <img src="https://img.shields.io/badge/Shell-88.7%25-green?logo=gnu-bash&logoColor=white" />
  <img src="https://img.shields.io/badge/Python-11.3%25-blue?logo=python&logoColor=white" />
  <img src="https://img.shields.io/github/license/SINNOMBRE22/SN?color=blueviolet" />
  <br>
  <img width="300" src="https://github.com/SINNOMBRE22/SN/raw/main/IMG-20251219-WA0021.jpg" alt="SinNombre VPS Manager">
  <br>
  <b>SinNombre - VPS Manager</b>
</h1>

<p align="center">
  Gestiona tu VPS <b>fácilmente</b> desde el terminal.<br>
  Automatización avanzada, gestión de usuarios y servicios, monitoreo de recursos, todo en una suite profesional.<br>
</p>

---

## 🚀 Descripción

<details>
<summary><b>Ver menú y funciones (click para expandir)</b></summary>

<p align="center">
<img src="https://raw.githubusercontent.com/SINNOMBRE22/SN/main/IMG-20251219-WA0020.jpg" alt="SinNombre VPS Manager Menu" width="320"/>
</p>

El panel principal te permite:
- Administrar **usuarios SSH** y **V2Ray/XRay**
- Instalar servicios y herramientas *(speedtest, banner SSH, gestión de puertos)*
- Visualizar el uso de RAM, uptime, espacio disponible y puertos de servicios activos, todo a color  
</details>

---

## 🏗️ Estructura

```
├── install.sh           # Script principal de instalación y actualización
├── menu                # Script Bash, interfaz principal
├── pythonproxy.py      # Herramienta en Python
├── Herramientas/       
├── Protocolos/       
├── Sistema/
├── Usuarios/
```

---

## 📦 Instalación

Copia y ejecuta lo siguiente en tu terminal:

```sh
rm -f install.sh* \
&& wget -q https://raw.githubusercontent.com/SINNOMBRE22/SN/main/install.sh \
&& chmod 775 install.sh \
&& sudo bash install.sh --start
```

---

## ♻️ Actualización

Actualiza a la última versión con:


## 🔑 Requisitos

- Linux (preferible Ubuntu 18+, probado en Ubuntu 22.04)
- Bash y wget
- Permisos sudo/superuser

---

## ⭐ Características principales

- Interfaz de terminal interactiva, colorida y amigable 👍
- Gestión de usuarios SSH y sistemas proxy/moderno
- Monitoreo en tiempo real de memoria, disco, puertos y uptime
- Instalador y actualizador automatizados
- Modular: fácilmente extensible (carpetas modulares)
- Scripts Bash y Python 🚀

---

## 🛡️ Licencia

[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)

---

## ✨ Autor

- Proyecto desarrollado por [SINNOMBRE22](https://github.com/SINNOMBRE22)

---

<p align="center">
  <i>¡Comparte, contribuye y automatiza tu VPS con estilo!</i> <br>
  <img src="https://img.shields.io/badge/made%20with-Bash%20%26%20Python-brightgreen?logo=linux"/>
</p>
