#!/usr/bin/env bash
# Hace que los archivos de Windows (/mnt/c) pertenezcan al usuario de Linux y acepten permisos (chmod),
# necesario para compilar el repo desde /mnt/c. Documentación:
#   https://learn.microsoft.com/windows/wsl/wsl-config  (sección [automount])
#   https://learn.microsoft.com/windows/wsl/file-permissions
# Ejecutar UNA vez, por la persona usuaria:  bash scripts/setup-wsl-automount.sh
# Después, desde Windows:  wsl --shutdown   (y volver a abrir Ubuntu)
set -euo pipefail

CONF=/etc/wsl.conf
if grep -q '^\[automount\]' "$CONF"; then
  echo "Ya existe una sección [automount] en $CONF; revísala a mano:"; cat "$CONF"; exit 1
fi

sudo cp "$CONF" "$CONF.bak"
printf '\n[automount]\noptions = "metadata,uid=%s,gid=%s,umask=022,fmask=011"\n' "$(id -u)" "$(id -g)" \
  | sudo tee -a "$CONF" > /dev/null
cat "$CONF"
echo "OK. Ahora ejecuta 'wsl --shutdown' en PowerShell y vuelve a abrir Ubuntu."
