# Para el tiempo — reglas del proyecto

App Android personal (uso propio, sin tiendas, sin monetización, sin backend). Un solo botón que
inicia una secuencia guiada de ~90 s orientada a modificar el tiempo percibido y la atención al presente.

## Reglas de producto (no negociables)
- **Sin afirmaciones médicas ni terapéuticas** en ningún texto (UI, README, comentarios visibles).
  Nada de "reduce ansiedad", "trata", "cura", "terapia", "clínicamente".
- Sin reloj, sin cuenta regresiva, sin barra de progreso visibles.
- Pantalla oscura y de baja estimulación. El efecto de oscurecido total es **solo** en la entrada (0–5 s).
- Círculo de respiración: crece al inhalar (4 s), se encoge al exhalar (6 s). Movimiento lento, bajo contraste.
- Pantalla encendida solo mientras corre la secuencia.
- Cualquier paso se puede omitir y se puede salir en cualquier momento (incluido el botón atrás).
- Pregunta final opcional 1–5 "¿Qué tan presente te sentiste?", guardada **solo en el dispositivo**.
- Sin cuentas, sin analítica, sin red. El APK de release **no** debe declarar `android.permission.INTERNET`.
- Todos los recursos (audio, fuentes) van empaquetados; nada se descarga en tiempo de ejecución.

## Secuencia
| Tramo | Paso | Contenido |
|---|---|---|
| 0–5 s | Entrada | El círculo del botón se contrae a un punto y se expande al reposo + ancla (vibración y sonido siempre idénticos). Nunca pantalla vacía. |
| 5–20 s | Apoyo | "Siente el peso de tu cuerpo y la presión de tus pies en el suelo." |
| 20–55 s | Respiración | 5 s "Sigue el círculo…" + 3 ciclos inhala 4 s / exhala 6 s, pulso háptico lento + círculo |
| 55–69 s | Escaneo | "Lleva la atención a tu mandíbula." / "Ahora, a tus hombros." (7 s c/u). Sin corregir. |
| 69–81 s | Grounding | "Siente lo que tocan tus manos." / "Escucha un sonido a tu alrededor." (6 s c/u) |
| 81–90 s | Cierre | "Cuando quieras, sigue con tu día." (5 s) + 4 s sin texto: el círculo vuelve a ser el botón |

Decisiones de diseño (validadas por la persona usuaria en el teléfono):
- Verbos variados; no repetir "Nota". Sin abdomen. Sin "algo que ves" (obliga a dejar de mirar la pantalla).
- El cierre es una afirmación, no una pregunta (la pregunta 1–5 viene después).
- Reposo del círculo pequeño (0.4) para que la inhalación se vea completa.
- Salir de la app a mitad de la secuencia y volver puede reiniciarla: aceptado.

La secuencia es diseño propio, no un protocolo validado. La definición vive en datos (una lista de pasos),
no dispersa en widgets, para poder testear la temporización.

## Stack
- Flutter (stable, fijado en `scripts/setup-wsl-toolchain.sh`), solo Android.
- Paquetes: `vibration` (patrones + intensidades), `wakelock_plus` (pantalla encendida, sin permisos),
  `audioplayers` (audio local), `shared_preferences` (dato local). Añadir otro paquete requiere justificarlo
  y pasar por el subagente `security-reviewer`.
- `pubspec.lock` se versiona. Nada de rangos abiertos tipo `any`. Revisar el diff del lock en cada `pub upgrade`.
- `vibration` NO tiene publisher verificado en pub.dev (mantenedor individual): versión fijada por el lock,
  código Android revisado (usa `createWaveform` con `USAGE_ALARM`). Revisar su diff antes de actualizarlo.
- Háptica validada en el A55: ancla = pulso que sube/baja + eco; respiración = un pulso simple de 70 ms en
  cada extremo del círculo (las rampas largas se sentían anticlimáticas). Sonido del ancla: preset "soplo".
- Audio: solo `AssetSource` (nunca `UrlSource`/`setSourceUrl`). El ancla se genera con
  `scripts/generate_anchor_sound.py` (determinista; su sha256 lo fija `test/anchor_asset_test.dart`).
- Vibración y sonido pasan por la interfaz `SensoryCues`; los tests usan `FakeCues` (test/flutter_test_config.dart).

## Entorno de compilación
- Windows tiene **Smart App Control** activo y bloquea el Dart SDK de Windows. **No se desactiva.**
  Toda compilación corre dentro de **WSL2 Ubuntu**: `wsl -d Ubuntu -- bash -lc '<comando>'`.
- El repo vive en Windows (`C:\Users\esteb\Repositorios\stop-the-time` = `/mnt/c/Users/esteb/Repositorios/stop-the-time` en WSL).
- Teléfono de prueba: Samsung A55, Android 16, conectado por depuración inalámbrica (`adb pair` / `adb connect`).
- Descargas de herramientas: solo fuentes oficiales y con verificación SHA256.
- Los comandos con `sudo` los ejecuta la persona usuaria, nunca Claude.

## Seguridad
- Keystore de release fuera del repo (`~/.keystores/` en WSL). `key.properties`, `*.jks`, `*.keystore` en `.gitignore`.
- Nunca commitear secretos. Revisar el manifiesto combinado de release antes de entregar un APK.

## Forma de trabajo
- Fases pequeñas: (0) entorno, (1) base con botón, (2) secuencia + temporización, (3) háptica y audio,
  (4) pantalla encendida + omitir/salir, (5) pregunta final local, (6) APK instalable.
- Al terminar cada fase: explicar exactamente cómo probarla.
- Si algo no se sabe, verificarlo en la documentación oficial; no inventar APIs.
- Explicaciones breves de decisiones importantes (la persona usuaria viene de Power Platform/Python
  y se orienta a DevSecOps).
- Usar `security-reviewer` al añadir dependencias/permisos y antes del APK final; usar `tester` al cerrar cada fase.
- Idioma de la UI y de la documentación: español.
