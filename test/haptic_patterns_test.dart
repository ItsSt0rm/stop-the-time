import 'package:flutter_test/flutter_test.dart';
import 'package:para_el_tiempo/cues/haptic_patterns.dart';

/// Todos los patrones, por nombre, leídos de nuevo en cada llamada.
Map<String, HapticPattern> _all() => {
  'AmplitudePatterns.anchor': AmplitudePatterns.anchor,
  'AmplitudePatterns.inhale': AmplitudePatterns.inhale,
  'AmplitudePatterns.exhale': AmplitudePatterns.exhale,
  'OnOffPatterns.anchor': OnOffPatterns.anchor,
  'OnOffPatterns.inhale': OnOffPatterns.inhale,
  'OnOffPatterns.exhale': OnOffPatterns.exhale,
};

Map<String, HapticPattern> _amplitude() => {
  'anchor': AmplitudePatterns.anchor,
  'inhale': AmplitudePatterns.inhale,
  'exhale': AmplitudePatterns.exhale,
};

Map<String, HapticPattern> _onOff() => {
  'anchor': OnOffPatterns.anchor,
  'inhale': OnOffPatterns.inhale,
  'exhale': OnOffPatterns.exhale,
};

void main() {
  group('todos los patrones (formato createWaveform)', () {
    for (final MapEntry(key: name, value: p) in _all().entries) {
      test('$name: listas de igual longitud, no vacías', () {
        expect(p.timings, isNotEmpty);
        expect(p.timings.length, p.amplitudes.length);
      });

      test('$name: timings >= 0 y amplitudes en 0..255', () {
        expect(p.timings, everyElement(greaterThanOrEqualTo(0)));
        expect(p.amplitudes, everyElement(inInclusiveRange(0, 255)));
        expect(p.duration, greaterThan(Duration.zero));
      });

      test('$name: determinista (dos lecturas iguales)', () {
        final again = _all()[name]!;
        expect(again.timings, p.timings);
        expect(again.amplitudes, p.amplitudes);
        expect(again.duration, p.duration);
      });
    }
  });

  group('AmplitudePatterns (suaves)', () {
    for (final MapEntry(key: name, value: p) in _amplitude().entries) {
      test('$name: cada amplitud es 0 (pausa) o >= 1, y como máximo 120', () {
        for (final a in p.amplitudes) {
          expect(a == 0 || a >= 1, isTrue, reason: 'amplitud $a');
        }
        expect(p.amplitudes.reduce((a, b) => a > b ? a : b), lessThan(121));
      });
    }

    int maxOf(List<int> xs) => xs.reduce((a, b) => a > b ? a : b);

    for (final MapEntry(key: name, value: p) in {
      'inhale': AmplitudePatterns.inhale,
      'exhale': AmplitudePatterns.exhale,
    }.entries) {
      test('$name: un único pulso sin pausas, de 40 a 150 ms', () {
        expect(p.timings, hasLength(1));
        expect(p.amplitudes, everyElement(greaterThan(0)));
        expect(p.duration.inMilliseconds, inInclusiveRange(40, 150));
      });

      test('$name: misma intensidad que el máximo del ancla', () {
        expect(p.amplitudes.single, maxOf(AmplitudePatterns.anchor.amplitudes));
      });
    }

    test('inhale y exhale son idénticos (timings y amplitudes)', () {
      expect(
        AmplitudePatterns.inhale.timings,
        AmplitudePatterns.exhale.timings,
      );
      expect(
        AmplitudePatterns.inhale.amplitudes,
        AmplitudePatterns.exhale.amplitudes,
      );
    });

    test('anchor: contiene una pausa (amplitud 0) y cabe en la entrada', () {
      final p = AmplitudePatterns.anchor;
      final pauses = [
        for (var i = 0; i < p.amplitudes.length; i++)
          if (p.amplitudes[i] == 0) i,
      ];
      expect(pauses, isNotEmpty);
      // La pausa no es el primer ni el último tramo: hay pulso antes y eco después.
      expect(pauses.first, greaterThan(0));
      expect(pauses.last, lessThan(p.amplitudes.length - 1));
      expect(pauses.map((i) => p.timings[i]), contains(350));
      expect(p.duration, lessThan(const Duration(seconds: 5)));
    });
  });

  group('OnOffPatterns (createWaveform sin amplitudes)', () {
    for (final MapEntry(key: name, value: p) in _onOff().entries) {
      test('$name: empieza con 0 ms de espera', () {
        expect(p.timings.first, 0);
      });

      test('$name: amplitudes alternan 0/255 empezando en 0', () {
        for (var i = 0; i < p.amplitudes.length; i++) {
          expect(
            p.amplitudes[i],
            i.isEven ? 0 : 255,
            reason: 'índice $i: ${p.amplitudes}',
          );
        }
        // Termina en un tramo encendido y cada tramo encendido dura algo.
        expect(p.amplitudes.last, 255);
        for (var i = 1; i < p.timings.length; i += 2) {
          expect(p.timings[i], greaterThan(0), reason: 'índice $i');
        }
      });
    }

    for (final MapEntry(key: name, value: p) in {
      'inhale': OnOffPatterns.inhale,
      'exhale': OnOffPatterns.exhale,
    }.entries) {
      test('$name on/off: primer timing 0 y un único tramo encendido', () {
        expect(p.timings.first, 0);
        expect(p.amplitudes.where((a) => a > 0), hasLength(1));
        expect(p.timings, hasLength(2));
        expect(p.timings[1], greaterThan(0));
      });
    }

    test('anchor on/off cabe en la entrada (< 5 s)', () {
      expect(
        OnOffPatterns.anchor.duration,
        lessThan(const Duration(seconds: 5)),
      );
    });
  });
}
