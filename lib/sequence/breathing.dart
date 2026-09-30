import 'dart:ui' show lerpDouble;

import 'package:flutter/animation.dart';

import 'sequence.dart';

/// Lado de la caja donde se dibuja el círculo; la escala se aplica sobre este tamaño.
const circleBoxSize = 240.0;

/// Escala del botón de inicio: el mismo círculo continúa en la secuencia sin saltos.
const homeScale = 200 / circleBoxSize;

/// Escala del punto tenue al que se contrae el círculo en la entrada.
const dotScale = 0.06;

/// Escala del círculo en reposo y en el punto máximo de la inhalación.
const restScale = 0.6;
const fullScale = 1.0;

const _curve = Curves.easeInOutSine;

/// Escala del círculo para una posición de la secuencia.
/// - Entrada: se contrae desde el botón hasta un punto y se expande al reposo.
/// - Respiración: crece al inhalar, se encoge al exhalar.
/// - Resto: reposo.
double circleScaleAt(SequencePosition position) {
  if (position.step.kind == StepKind.entrada) {
    final p = position.segmentProgress;
    return p < 0.5
        ? lerpDouble(homeScale, dotScale, _curve.transform(p * 2))!
        : lerpDouble(dotScale, restScale, _curve.transform((p - 0.5) * 2))!;
  }
  final t = _curve.transform(position.segmentProgress);
  return switch (position.segment.breath) {
    Breath.inhale => lerpDouble(restScale, fullScale, t)!,
    Breath.exhale => lerpDouble(fullScale, restScale, t)!,
    null => restScale,
  };
}

/// Opacidad de la palabra "Para" dentro del círculo: se desvanece en el primer segundo y cuarto.
double startLabelOpacityAt(SequencePosition position) {
  if (position.step.kind != StepKind.entrada) return 0;
  return (1 - position.segmentProgress / 0.25).clamp(0.0, 1.0);
}
