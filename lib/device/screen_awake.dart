import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Mantiene la pantalla encendida mientras corre la secuencia.
///
/// En Android, `wakelock_plus` solo activa `FLAG_KEEP_SCREEN_ON` en la ventana de la app: sin
/// permisos y sin efecto cuando la app no está visible. Interfaz para sustituirla en los tests.
abstract class ScreenAwake {
  static ScreenAwake instance = DeviceScreenAwake();

  void enable();
  void disable();
}

class DeviceScreenAwake implements ScreenAwake {
  @override
  void enable() => _guard(WakelockPlus.enable);

  @override
  void disable() => _guard(WakelockPlus.disable);

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      // Si falla, la secuencia sigue: como mucho la pantalla se apaga según el sistema.
      debugPrint('ScreenAwake: $e');
    }
  }
}
