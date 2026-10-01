# Para el tiempo

App Android personal: un botón que inicia una secuencia guiada de ~90 s para atender al presente.
Sin cuentas, sin analítica, sin red. Uso propio; no es una herramienta médica ni terapéutica.

Reglas del proyecto y entorno: ver [CLAUDE.md](CLAUDE.md).

## Compilar (dentro de WSL2 Ubuntu)
```bash
cd /mnt/c/Users/esteb/Repositorios/stop-the-time
flutter test
flutter build apk --debug
```

## Firmar el APK de release
La keystore vive fuera del repo, en `~/.keystores/` dentro de WSL. Sin ella, el build de release falla
a propósito: nunca se firma con la clave de debug.

```bash
bash scripts/create-release-keystore.sh   # una sola vez; pide la contraseña
flutter build apk --release --target-platform android-arm64
# APK: build/app/outputs/flutter-apk/app-release.apk
```

Guarda una copia de `~/.keystores/para-el-tiempo.jks` y `para-el-tiempo.properties` fuera del PC:
sin ellos no se pueden publicar actualizaciones que se instalen encima de la versión anterior.

Preparación del entorno (una vez): `scripts/setup-wsl-system.sh` (sudo), `scripts/setup-wsl-toolchain.sh`,
`sdkmanager --licenses`, `scripts/setup-wsl-automount.sh` (sudo) y `wsl --shutdown`.
