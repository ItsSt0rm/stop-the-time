import 'package:para_el_tiempo/device/screen_awake.dart';

/// Doble de pruebas: registra si la pantalla se mantendría encendida.
class FakeScreenAwake implements ScreenAwake {
  final List<String> calls = [];
  bool enabled = false;

  @override
  void enable() {
    calls.add('enable');
    enabled = true;
  }

  @override
  void disable() {
    calls.add('disable');
    enabled = false;
  }
}
