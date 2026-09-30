import 'package:para_el_tiempo/cues/sensory_cues.dart';

/// Doble de pruebas: registra las señales en orden en vez de vibrar o sonar.
class FakeCues implements SensoryCues {
  final List<String> calls = [];

  @override
  Future<void> preload() async => calls.add('preload');

  @override
  void anchor() => calls.add('anchor');

  @override
  void inhale() => calls.add('inhale');

  @override
  void exhale() => calls.add('exhale');

  @override
  void stop() => calls.add('stop');
}
