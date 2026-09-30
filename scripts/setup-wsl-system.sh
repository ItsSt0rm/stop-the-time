#!/usr/bin/env bash
# Paquetes del sistema para compilar "Para el tiempo" dentro de WSL2 (Ubuntu).
# Ejecutar UNA vez, por la persona usuaria, con:  bash scripts/setup-wsl-system.sh
# Pide la contraseña de sudo. Solo usa los repositorios oficiales de Ubuntu (apt).
set -euo pipefail

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  openjdk-17-jdk-headless \
  ca-certificates curl git unzip xz-utils zip

java -version
echo "OK: paquetes del sistema instalados."
