/// Patrones de vibración como datos puros (testeables sin teléfono).
///
/// Formato de Android `VibrationEffect.createWaveform(timings, amplitudes)`: dos listas de la
/// misma longitud; cada tramo dura `timings[i]` ms con intensidad `amplitudes[i]` (0 = pausa,
/// 1–255). El plugin `vibration` las pasa tal cual como `pattern` e `intensities`.
library;

import 'dart:math' as math;

class HapticPattern {
  HapticPattern(List<int> timings, List<int> amplitudes)
    : assert(timings.length == amplitudes.length),
      timings = List.unmodifiable(timings),
      amplitudes = List.unmodifiable(amplitudes);

  final List<int> timings;
  final List<int> amplitudes;

  Duration get duration =>
      Duration(milliseconds: timings.fold(0, (total, t) => total + t));
}

/// Rampa suave de [steps] tramos de [stepMs] entre dos intensidades (curva seno, sin saltos).
HapticPattern _swell(int from, int to, {required int steps, int stepMs = 100}) {
  final amps = List<int>.generate(steps, (i) {
    final t = steps == 1 ? 1.0 : i / (steps - 1);
    final eased = 0.5 - 0.5 * math.cos(math.pi * t);
    return (from + (to - from) * eased).round();
  });
  return HapticPattern(List<int>.filled(steps, stepMs), amps);
}

HapticPattern _concat(List<HapticPattern> parts) => HapticPattern(
  [for (final p in parts) ...p.timings],
  [for (final p in parts) ...p.amplitudes],
);

/// Con control de intensidad (el Samsung A55 lo tiene).
abstract final class AmplitudePatterns {
  /// Ancla: un pulso que sube y baja, una pausa y un eco más débil. Siempre idéntico.
  static final anchor = _concat([
    _swell(25, 110, steps: 4, stepMs: 70),
    _swell(110, 20, steps: 5, stepMs: 80),
    HapticPattern([350], [0]),
    _swell(20, 50, steps: 2, stepMs: 60),
    _swell(50, 10, steps: 3, stepMs: 70),
  ]);

  /// Respiración: un pulso simple y definido en cada extremo del círculo (mínimo → empieza a
  /// inhalar; máximo → empieza a exhalar). Las rampas largas se sentían anticlimáticas tras el
  /// ancla. Misma intensidad máxima que el ancla para que se perciba igual de claro.
  static final inhale = HapticPattern([70], [110]);
  static final exhale = HapticPattern([70], [110]);
}

/// Sin control de intensidad el plugin llama a `createWaveform(timings, repeat)`, que alterna
/// apagado/encendido empezando por apagado: por eso todos empiezan con 0 ms de espera.
abstract final class OnOffPatterns {
  static final anchor = HapticPattern([0, 180, 350, 80], [0, 255, 0, 255]);
  static final inhale = HapticPattern([0, 70], [0, 255]);
  static final exhale = HapticPattern([0, 70], [0, 255]);
}
