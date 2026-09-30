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

Preparación del entorno (una vez): `scripts/setup-wsl-system.sh` (sudo), `scripts/setup-wsl-toolchain.sh`,
`sdkmanager --licenses`, `scripts/setup-wsl-automount.sh` (sudo) y `wsl --shutdown`.
