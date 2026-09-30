#!/usr/bin/env bash
# Instala Flutter y las Android command-line tools en el HOME del usuario de WSL (sin sudo).
# Versiones fijadas y verificadas por SHA256 (valores publicados por Google):
#   Flutter:  https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json
#   cmdline-tools: https://developer.android.com/studio#command-line-tools-only
# Para actualizar: cambiar versión + hash juntos, nunca desactivar la verificación.
set -euo pipefail

FLUTTER_VERSION="3.47.5"
FLUTTER_SHA256="2132e990f236f8d22e7c6314b29a191a95b10d7cbcfec9b4e2e303d996652cbb"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

CMDLINE_BUILD="15859902"
CMDLINE_SHA256="4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583"
CMDLINE_URL="https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_BUILD}_latest.zip"

DEV_DIR="$HOME/develop"
ANDROID_SDK="$HOME/Android/Sdk"
DL_DIR="$(mktemp -d)"
trap 'rm -rf "$DL_DIR"' EXIT

download_verified() { # url sha256 destino
  curl -fsSL --proto '=https' --tlsv1.2 -o "$3" "$1"
  echo "$2  $3" | sha256sum -c -
}

mkdir -p "$DEV_DIR" "$ANDROID_SDK/cmdline-tools"

if [ ! -x "$DEV_DIR/flutter/bin/flutter" ]; then
  download_verified "$FLUTTER_URL" "$FLUTTER_SHA256" "$DL_DIR/flutter.tar.xz"
  tar -xJf "$DL_DIR/flutter.tar.xz" -C "$DEV_DIR"
fi

if [ ! -x "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" ]; then
  download_verified "$CMDLINE_URL" "$CMDLINE_SHA256" "$DL_DIR/cmdline.zip"
  unzip -q "$DL_DIR/cmdline.zip" -d "$DL_DIR/cmdline"
  mv "$DL_DIR/cmdline/cmdline-tools" "$ANDROID_SDK/cmdline-tools/latest"
fi

# Variables de entorno (idempotente). ~/.profile lo leen las shells de login de WSL.
MARK="# >>> para-el-tiempo toolchain >>>"
if ! grep -qF "$MARK" "$HOME/.profile"; then
  cat >> "$HOME/.profile" <<EOF

$MARK
export ANDROID_HOME="\$HOME/Android/Sdk"
export PATH="\$HOME/develop/flutter/bin:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$PATH"
# <<< para-el-tiempo toolchain <<<
EOF
fi

export ANDROID_HOME="$ANDROID_SDK"
export PATH="$DEV_DIR/flutter/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

# Sin telemetría (coherente con la regla "sin analítica" del proyecto).
flutter --disable-analytics
dart --disable-analytics
flutter config --no-enable-web --no-enable-linux-desktop --android-sdk "$ANDROID_HOME"
flutter --version
# Nota: Flutter solo reconoce el SDK si existe 'licenses/' o 'platform-tools/', por eso las licencias
# se aceptan con sdkmanager (no con 'flutter doctor --android-licenses') en una instalación nueva.
echo "OK: toolchain instalada. Siguiente paso (manual): 'source ~/.profile && sdkmanager --licenses'."
