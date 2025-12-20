<h1 align="center">
  <img src="https://raw.githubusercontent.com/SINNOMBRE22/SN/main/install.sh" width="0" height="0"/>
  <img src="https://img.shields.io/badge/Shell-88.7%25-green?logo=gnu-bash&logoColor=white" />
  <img src="https://img.shields.io/badge/Python-11.3%25-blue?logo=python&logoColor=white" />
  <img src="https://img.shields.io/github/license/SINNOMBRE22/SN?color=blueviolet" />
  <br>
  <img width="300" src="https://raw.githubusercontent.com/SINNOMBRE22/SN/main/IMG-20251219-WA0020.jpg" alt="SinNombre VPS Manager">
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
- Administrar <span style="color:#41e614;"><b>usuarios SSH</b></span> y <span style="color:#0891b2;"><b>V2Ray/XRay</b></span>
- Instalar servicios y herramientas <span style="color:#eab308;">(speedtest, banner SSH, gestión de puertos)</span>
- Visualizar el uso de RAM, uptime, espacio disponible y puertos de servicios activos, todo a color

</details>

---

## 🖥️ Captura de Pantalla

<p align="center">
  <img src="![image1](image1)" alt="Menu principal" width="350">
</p>

---

## 🏗️ Estructura

```
├── install.sh           # Script principal de instalación y actualización
├── menu                # Script Bash, interface principal
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

```sh
rm -f install.sh* \
&& wget -q https://raw.githubusercontent.com/SINNOMBRE22/SN/main/install.sh \
&& chmod +x install.sh \
&& bash install.sh --update
```

---

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
