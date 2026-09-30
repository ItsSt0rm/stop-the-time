import 'package:flutter/animation.dart';

import 'sequence.dart';

/// Escala del círculo en reposo y en el punto máximo de la inhalación.
const restScale = 0.6;
const fullScale = 1.0;

const _curve = Curves.easeInOutSine;

/// Escala del círculo para una posición de la secuencia: crece al inhalar, se encoge al exhalar,
/// y queda en reposo fuera de la respiración.
double circleScaleAt(SequencePosition position) {
  final t = _curve.transform(position.segmentProgress);
  return switch (position.segment.breath) {
    Breath.inhale => restScale + (fullScale - restScale) * t,
    Breath.exhale => fullScale - (fullScale - restScale) * t,
    null => restScale,
  };
}
