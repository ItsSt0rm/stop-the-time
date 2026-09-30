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

    test('inhale: sin pausas, monótona no decreciente, 1,6 s', () {
      final p = AmplitudePatterns.inhale;
      expect(p.amplitudes, everyElement(greaterThan(0)));
      for (var i = 1; i < p.amplitudes.length; i++) {
        expect(
          p.amplitudes[i],
          greaterThanOrEqualTo(p.amplitudes[i - 1]),
          reason: 'índice $i: ${p.amplitudes}',
        );
      }
      expect(p.amplitudes.last, greaterThan(p.amplitudes.first));
      expect(p.duration, const Duration(milliseconds: 1600));
      expect(p.duration, lessThan(const Duration(seconds: 4)));
    });

    test('exhale: sin pausas, monótona no creciente, 2,4 s', () {
      final p = AmplitudePatterns.exhale;
      expect(p.amplitudes, everyElement(greaterThan(0)));
      for (var i = 1; i < p.amplitudes.length; i++) {
        expect(
          p.amplitudes[i],
          lessThanOrEqualTo(p.amplitudes[i - 1]),
          reason: 'índice $i: ${p.amplitudes}',
        );
      }
      expect(p.amplitudes.last, lessThan(p.amplitudes.first));
      expect(p.duration, const Duration(milliseconds: 2400));
      expect(p.duration, lessThan(const Duration(seconds: 6)));
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

    test('anchor on/off cabe en la entrada (< 5 s)', () {
      expect(
        OnOffPatterns.anchor.duration,
        lessThan(const Duration(seconds: 5)),
      );
    });
  });
}
