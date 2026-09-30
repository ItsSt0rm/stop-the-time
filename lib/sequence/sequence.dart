/// Definición de la secuencia como datos puros (sin Flutter), para poder testear la temporización.
library;

enum StepKind { entrada, apoyo, respiracion, escaneo, grounding, cierre }

enum Breath { inhale, exhale }

/// Tramo mínimo de la secuencia: una duración con un texto opcional y, en la respiración, su fase.
class Segment {
  const Segment(this.duration, {this.text, this.breath});

  final Duration duration;
  final String? text;
  final Breath? breath;
}

class SequenceStep {
  const SequenceStep(this.kind, this.segments);

  final StepKind kind;
  final List<Segment> segments;

  Duration get duration =>
      segments.fold(Duration.zero, (total, s) => total + s.duration);
}

/// Dónde está la secuencia en un instante dado.
class SequencePosition {
  const SequencePosition({
    required this.stepIndex,
    required this.segmentIndex,
    required this.segmentElapsed,
    required this.step,
    required this.finished,
  });

  final int stepIndex;
  final int segmentIndex;
  final Duration segmentElapsed;
  final SequenceStep step;
  final bool finished;

  Segment get segment => step.segments[segmentIndex];

  /// Progreso 0..1 dentro del tramo actual.
  double get segmentProgress {
    final total = segment.duration.inMicroseconds;
    if (total == 0) return 1;
    return (segmentElapsed.inMicroseconds / total).clamp(0.0, 1.0);
  }
}

class Sequence {
  const Sequence(this.steps);

  final List<SequenceStep> steps;

  Duration get total =>
      steps.fold(Duration.zero, (total, s) => total + s.duration);

  Duration startOf(int stepIndex) => steps
      .take(stepIndex)
      .fold(Duration.zero, (total, s) => total + s.duration);

  SequencePosition positionAt(Duration elapsed) {
    var remaining = elapsed < Duration.zero ? Duration.zero : elapsed;
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      for (var j = 0; j < step.segments.length; j++) {
        final d = step.segments[j].duration;
        if (remaining < d) {
          return SequencePosition(
            stepIndex: i,
            segmentIndex: j,
            segmentElapsed: remaining,
            step: step,
            finished: false,
          );
        }
        remaining -= d;
      }
    }
    final last = steps.last;
    return SequencePosition(
      stepIndex: steps.length - 1,
      segmentIndex: last.segments.length - 1,
      segmentElapsed: last.segments.last.duration,
      step: last,
      finished: true,
    );
  }
}

const _inhale = Segment(
  Duration(seconds: 4),
  text: 'Inhala',
  breath: Breath.inhale,
);
const _exhale = Segment(
  Duration(seconds: 6),
  text: 'Exhala',
  breath: Breath.exhale,
);

/// Secuencia de ~90 s. Diseño propio, no un protocolo validado.
const defaultSequence = Sequence([
  // 0–5 s: pantalla oscura; el ancla (vibración + sonido) se añade en la fase 3.
  SequenceStep(StepKind.entrada, [Segment(Duration(seconds: 5))]),
  // 5–20 s
  SequenceStep(StepKind.apoyo, [
    Segment(
      Duration(seconds: 15),
      text:
          'Siente el peso de tu cuerpo\ny la presión de tus pies en el suelo.',
    ),
  ]),
  // 20–55 s: 5 s de preparación + 3 ciclos de 4 s / 6 s.
  SequenceStep(StepKind.respiracion, [
    Segment(
      Duration(seconds: 5),
      text: 'Sigue el círculo:\ncrece al inhalar, se encoge al exhalar.',
    ),
    _inhale,
    _exhale,
    _inhale,
    _exhale,
    _inhale,
    _exhale,
  ]),
  // 55–75 s: una zona cada 5 s, sin corregir.
  SequenceStep(StepKind.escaneo, [
    Segment(
      Duration(seconds: 5),
      text: 'Nota tu mandíbula.\nSin cambiar nada.',
    ),
    Segment(Duration(seconds: 5), text: 'Nota tus hombros,\ntal como están.'),
    Segment(Duration(seconds: 5), text: 'Nota tus manos.'),
    Segment(Duration(seconds: 5), text: 'Nota tu abdomen.'),
  ]),
  // 75–85 s
  SequenceStep(StepKind.grounding, [
    Segment(
      Duration(seconds: 10),
      text: 'Nombra un sonido,\nalgo que ves\ny algo que tocas.',
    ),
  ]),
  // 85–90 s
  SequenceStep(StepKind.cierre, [
    Segment(
      Duration(seconds: 5),
      text: 'Reanuda con una intención:\n¿qué haces ahora?',
    ),
  ]),
]);
