#!/usr/bin/env bash
# Crea la keystore de release y su archivo de propiedades en ~/.keystores/ (WSL), fuera del repo.
# La ejecuta la persona usuaria: la contraseña se pide por teclado y no se muestra.
set -euo pipefail

dir="$HOME/.keystores"
ks="$dir/para-el-tiempo.jks"
props="$dir/para-el-tiempo.properties"
alias_name="para-el-tiempo"

if [ -e "$ks" ] || [ -e "$props" ]; then
  echo "Ya existe $ks o $props; no se sobrescribe." >&2
  exit 1
fi

read -rsp "Contraseña de la keystore (mínimo 12 caracteres, sin '\\'): " pw; echo
read -rsp "Repítela: " pw2; echo
[ "$pw" = "$pw2" ] || { echo "No coinciden." >&2; exit 1; }
[ "${#pw}" -ge 12 ] || { echo "Demasiado corta." >&2; exit 1; }
LC_ALL=C; case "$pw" in *[![:print:]]*) echo "Usa solo caracteres ASCII (sin ñ ni tildes): Gradle lee el archivo en ISO-8859-1." >&2; exit 1 ;; esac
case "$pw" in *\\*) echo "No uses '\\' (rompe el archivo de propiedades)." >&2; exit 1 ;; esac

umask 077
mkdir -p "$dir"
chmod 700 "$dir"

# PKCS12: la clave usa la misma contraseña que el almacén. El CN queda visible en el certificado del APK.
KS_PW="$pw" keytool -genkeypair \
  -keystore "$ks" -storetype PKCS12 \
  -alias "$alias_name" -keyalg RSA -keysize 4096 -validity 10000 \
  -dname "CN=ItsSt0rm" \
  -storepass:env KS_PW -keypass:env KS_PW

cat > "$props" <<EOF
storeFile=$ks
storePassword=$pw
keyAlias=$alias_name
keyPassword=$pw
EOF
chmod 600 "$ks" "$props"

echo
echo "Listo: $ks y $props (permisos 600)."
echo "Huella SHA-256 del certificado (anótala; sirve para verificar APKs futuros):"
KS_PW="$pw" keytool -list -keystore "$ks" -storepass:env KS_PW -alias "$alias_name" | grep -i sha
echo
echo "IMPORTANTE: guarda una copia de ambos archivos fuera de este PC (USB cifrado o gestor de contraseñas)."
echo "Sin esta keystore no se pueden publicar actualizaciones que se instalen encima."
