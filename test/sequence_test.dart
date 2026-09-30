import 'package:flutter_test/flutter_test.dart';
import 'package:para_el_tiempo/sequence/breathing.dart';
import 'package:para_el_tiempo/sequence/sequence.dart';

Duration _ms(int ms) => Duration(milliseconds: ms);
Duration _s(num s) => Duration(microseconds: (s * 1000000).round());

void main() {
  const seq = defaultSequence;

  group('temporización', () {
    test('la secuencia dura exactamente 90 s', () {
      expect(seq.total, const Duration(seconds: 90));
    });

    test('los pasos están en el orden esperado', () {
      expect(seq.steps.map((s) => s.kind).toList(), [
        StepKind.entrada,
        StepKind.apoyo,
        StepKind.respiracion,
        StepKind.escaneo,
        StepKind.grounding,
        StepKind.cierre,
      ]);
    });

    test('startOf marca los límites de cada paso', () {
      final starts = [
        for (var i = 0; i < seq.steps.length; i++) seq.startOf(i).inSeconds,
      ];
      expect(starts, [0, 5, 20, 55, 75, 85]);
      expect(seq.startOf(seq.steps.length), seq.total);
    });

    test('duración de cada paso', () {
      expect(seq.steps.map((s) => s.duration.inSeconds).toList(), [
        5,
        15,
        35,
        20,
        10,
        5,
      ]);
    });
  });

  group('positionAt', () {
    StepKind kindAt(Duration d) => seq.positionAt(d).step.kind;

    test('instantes clave', () {
      expect(kindAt(Duration.zero), StepKind.entrada);
      expect(kindAt(_s(2.5)), StepKind.entrada);
      expect(kindAt(_s(10)), StepKind.apoyo);
      expect(kindAt(_s(30)), StepKind.respiracion);
      expect(kindAt(_s(60)), StepKind.escaneo);
      expect(kindAt(_s(80)), StepKind.grounding);
      expect(kindAt(_s(87)), StepKind.cierre);
    });

    test('bordes entre pasos', () {
      expect(kindAt(_ms(4999)), StepKind.entrada);
      expect(kindAt(_s(5)), StepKind.apoyo);
      expect(kindAt(_ms(19999)), StepKind.apoyo);
      expect(kindAt(_s(20)), StepKind.respiracion);
      expect(kindAt(_ms(54999)), StepKind.respiracion);
      expect(kindAt(_s(55)), StepKind.escaneo);
      expect(kindAt(_ms(74999)), StepKind.escaneo);
      expect(kindAt(_s(75)), StepKind.grounding);
      expect(kindAt(_ms(84999)), StepKind.grounding);
      expect(kindAt(_s(85)), StepKind.cierre);
    });

    test('no está terminada justo antes de 90 s', () {
      final p = seq.positionAt(_ms(89999));
      expect(p.finished, isFalse);
      expect(p.step.kind, StepKind.cierre);
    });

    test('a los 90 s y después está terminada', () {
      for (final d in [_s(90), _s(91), _s(1000)]) {
        final p = seq.positionAt(d);
        expect(p.finished, isTrue, reason: '$d');
        expect(p.stepIndex, seq.steps.length - 1);
        expect(p.step.kind, StepKind.cierre);
        expect(p.segmentProgress, 1.0);
      }
    });

    test('valores negativos equivalen al inicio', () {
      final p = seq.positionAt(const Duration(seconds: -3));
      expect(p.finished, isFalse);
      expect(p.stepIndex, 0);
      expect(p.segmentIndex, 0);
      expect(p.segmentElapsed, Duration.zero);
    });

    test('segmentElapsed y segmentProgress dentro de un tramo', () {
      // 27 s = 2 s dentro de la primera inhalación (25–29 s).
      final p = seq.positionAt(_s(27));
      expect(p.segment.breath, Breath.inhale);
      expect(p.segmentElapsed, _s(2));
      expect(p.segmentProgress, closeTo(0.5, 1e-9));
    });
  });

  group('respiración', () {
    final breathing = seq.steps.firstWhere(
      (s) => s.kind == StepKind.respiracion,
    );
    final breaths = breathing.segments.where((s) => s.breath != null).toList();

    test('empieza con una preparación sin fase de respiración', () {
      expect(breathing.segments.first.breath, isNull);
      expect(breathing.segments.first.duration, _s(5));
    });

    test('3 inhalaciones de 4 s y 3 exhalaciones de 6 s', () {
      final inhales = breaths.where((s) => s.breath == Breath.inhale);
      final exhales = breaths.where((s) => s.breath == Breath.exhale);
      expect(inhales, hasLength(3));
      expect(exhales, hasLength(3));
      expect(inhales.every((s) => s.duration == _s(4)), isTrue);
      expect(exhales.every((s) => s.duration == _s(6)), isTrue);
    });

    test('inhalación y exhalación se alternan empezando por inhalar', () {
      expect(breaths.map((s) => s.breath).toList(), [
        Breath.inhale,
        Breath.exhale,
        Breath.inhale,
        Breath.exhale,
        Breath.inhale,
        Breath.exhale,
      ]);
    });
  });

  group('textos', () {
    final texts = [
      for (final step in seq.steps)
        for (final seg in step.segments)
          if (seg.text != null) seg.text!,
    ];

    const banned = [
      'ansiedad',
      'estrés',
      'estres',
      'terapia',
      'terapéut',
      'terapeut',
      'tratamiento',
      'cura',
      'clínic',
      'clinic',
      'médic',
      'medic',
      'síntoma',
      'sintoma',
      'sanar',
    ];

    test('hay textos que revisar', () {
      expect(texts, isNotEmpty);
    });

    test('ningún texto contiene términos médicos o terapéuticos', () {
      for (final t in texts) {
        final lower = t.toLowerCase();
        for (final word in banned) {
          expect(lower.contains(word), isFalse, reason: '"$t" contiene $word');
        }
      }
    });

    test('ningún texto contiene dígitos (sin cuentas atrás)', () {
      for (final t in texts) {
        expect(RegExp(r'\d').hasMatch(t), isFalse, reason: t);
      }
    });
  });

  group('circleScaleAt', () {
    double scaleAt(Duration d) => circleScaleAt(seq.positionAt(d));

    test('reposo fuera de la entrada y la respiración', () {
      for (final s in [5, 10, 19, 22, 24, 56, 70, 80, 88]) {
        expect(scaleAt(_s(s)), restScale, reason: '$s s');
      }
      expect(scaleAt(_s(90)), restScale);
    });

    test('inhalación: de reposo a máximo, monótona creciente', () {
      // Primera inhalación: 25–29 s.
      expect(scaleAt(_s(25)), closeTo(restScale, 1e-6));
      expect(scaleAt(_ms(28999)), closeTo(fullScale, 1e-3));
      var prev = scaleAt(_s(25));
      for (var ms = 25100; ms < 29000; ms += 100) {
        final v = scaleAt(_ms(ms));
        expect(v, greaterThanOrEqualTo(prev), reason: '$ms ms');
        prev = v;
      }
    });

    test('exhalación: de máximo a reposo, monótona decreciente', () {
      // Primera exhalación: 29–35 s.
      expect(scaleAt(_s(29)), closeTo(fullScale, 1e-6));
      expect(scaleAt(_ms(34999)), closeTo(restScale, 1e-3));
      var prev = scaleAt(_s(29));
      for (var ms = 29100; ms < 35000; ms += 100) {
        final v = scaleAt(_ms(ms));
        expect(v, lessThanOrEqualTo(prev), reason: '$ms ms');
        prev = v;
      }
    });

    test('los tres ciclos se comportan igual', () {
      // Inhalaciones empiezan en 25, 35 y 45 s.
      for (final start in [25, 35, 45]) {
        expect(scaleAt(_s(start)), closeTo(restScale, 1e-6));
        expect(scaleAt(_s(start + 2)), closeTo(scaleAt(_s(27)), 1e-9));
        expect(scaleAt(_s(start + 4)), closeTo(fullScale, 1e-6));
      }
    });

    test('tras la entrada la escala siempre está entre reposo y máximo', () {
      for (var ms = 5000; ms <= 90000; ms += 250) {
        final v = scaleAt(_ms(ms));
        expect(v, inInclusiveRange(restScale, fullScale), reason: '$ms ms');
      }
    });
  });

  group('entrada: el círculo del botón se contrae y se expande', () {
    double scaleAt(Duration d) => circleScaleAt(seq.positionAt(d));

    test('constantes coherentes con el botón de inicio', () {
      expect(circleBoxSize * homeScale, closeTo(200, 1e-9));
      expect(dotScale, greaterThan(0));
      expect(dotScale, lessThan(restScale));
    });

    test('t=0 ≈ botón, 2.5 s ≈ punto, 5 s ≈ reposo', () {
      expect(scaleAt(Duration.zero), closeTo(homeScale, 1e-6));
      expect(scaleAt(_ms(2500)), closeTo(dotScale, 1e-6));
      expect(scaleAt(_ms(4999)), closeTo(restScale, 1e-3));
      expect(scaleAt(_s(5)), closeTo(restScale, 1e-9));
    });

    test('el punto de 2.5 s es el mínimo de la entrada', () {
      for (var ms = 0; ms < 5000; ms += 50) {
        expect(scaleAt(_ms(ms)), greaterThanOrEqualTo(dotScale - 1e-9));
      }
    });

    test('decrece en 0–2.5 s y crece en 2.5–5 s', () {
      var prev = scaleAt(Duration.zero);
      for (var ms = 50; ms <= 2500; ms += 50) {
        final v = scaleAt(_ms(ms));
        expect(v, lessThanOrEqualTo(prev), reason: '$ms ms');
        prev = v;
      }
      for (var ms = 2550; ms <= 5000; ms += 50) {
        final v = scaleAt(_ms(ms));
        expect(v, greaterThanOrEqualTo(prev), reason: '$ms ms');
        prev = v;
      }
    });

    test('nunca llega a 0 ni es negativa', () {
      for (var ms = -1000; ms <= 91000; ms += 10) {
        expect(scaleAt(_ms(ms)), greaterThan(0), reason: '$ms ms');
      }
    });
  });

  group('startLabelOpacityAt', () {
    double opacityAt(Duration d) => startLabelOpacityAt(seq.positionAt(d));

    test('visible del todo en t=0', () {
      expect(opacityAt(Duration.zero), 1.0);
    });

    test('se desvanece de forma continua hasta 1.25 s', () {
      expect(opacityAt(_ms(625)), closeTo(0.5, 1e-6));
      var prev = opacityAt(Duration.zero);
      for (var ms = 50; ms <= 1250; ms += 50) {
        final v = opacityAt(_ms(ms));
        expect(v, lessThanOrEqualTo(prev), reason: '$ms ms');
        prev = v;
      }
    });

    test('0 desde 1.25 s hasta el final de la entrada', () {
      for (var ms = 1250; ms < 5000; ms += 50) {
        expect(opacityAt(_ms(ms)), 0.0, reason: '$ms ms');
      }
    });

    test('0 fuera de la entrada', () {
      for (final s in [5, 10, 30, 60, 80, 88, 90, 100]) {
        expect(opacityAt(_s(s)), 0.0, reason: '$s s');
      }
    });

    test('siempre en [0, 1]', () {
      for (var ms = -1000; ms <= 91000; ms += 100) {
        expect(opacityAt(_ms(ms)), inInclusiveRange(0.0, 1.0));
      }
    });
  });
}
