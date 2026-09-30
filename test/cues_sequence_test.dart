import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:para_el_tiempo/cues/sensory_cues.dart';
import 'package:para_el_tiempo/main.dart';
import 'package:para_el_tiempo/screens/home_screen.dart';
import 'package:para_el_tiempo/screens/sequence_screen.dart';

import 'support/fake_cues.dart';

const _tick = Duration(milliseconds: 100);

/// Una señal y el tiempo simulado (s) en que apareció en `calls`.
typedef _Cue = (String, double);

/// Avanza [total] en pumps de 100 ms, anotando cuándo cambia `fake.calls`.
/// [start] es el tiempo simulado actual (s); devuelve el nuevo.
Future<double> _record(
  WidgetTester tester,
  FakeCues fake,
  List<_Cue> log,
  Duration total, {
  double start = 0,
}) async {
  var now = start;
  var seen = fake.calls.length;
  var left = total;
  while (left > Duration.zero) {
    await tester.pump(_tick);
    left -= _tick;
    now += _tick.inMicroseconds / 1e6;
    for (; seen < fake.calls.length; seen++) {
      log.add((fake.calls[seen], now));
    }
  }
  return now;
}

/// Home mínima con navegador propio para que "Salir" (pop) tenga a dónde volver.
Future<NavigatorState> _pushWithHome(WidgetTester tester, FakeCues fake) async {
  final key = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(navigatorKey: key, home: const Scaffold()),
  );
  key.currentState!.push(
    MaterialPageRoute<void>(builder: (_) => SequenceScreen(cues: fake)),
  );
  await tester.pump();
  await tester.pump(); // la ruta ya está onstage
  expect(find.byType(SequenceScreen), findsOneWidget);
  return key.currentState!;
}

void main() {
  testWidgets('al montar se llama anchor() una sola vez y primero', (
    tester,
  ) async {
    final fake = FakeCues();
    await tester.pumpWidget(MaterialApp(home: SequenceScreen(cues: fake)));
    expect(fake.calls, ['anchor']);

    // Durante toda la entrada y el apoyo (0–20 s) no se repite ni aparece nada más.
    await _record(tester, fake, [], const Duration(seconds: 19));
    expect(fake.calls, ['anchor']);
  });

  testWidgets(
    '90 s: anchor, luego inhale/exhale alternados 3 veces en su instante, y stop al desmontar',
    (tester) async {
      final fake = FakeCues();
      await tester.pumpWidget(MaterialApp(home: SequenceScreen(cues: fake)));
      expect(fake.calls, ['anchor']);

      final log = <_Cue>[];
      // 90 s + 1 s de margen tras el final (la pantalla es la raíz: no se desmonta sola).
      await _record(tester, fake, log, const Duration(seconds: 91));

      expect(log.map((c) => c.$1), [
        'inhale',
        'exhale',
        'inhale',
        'exhale',
        'inhale',
        'exhale',
      ]);
      const expected = [25.0, 29.0, 35.0, 39.0, 45.0, 49.0];
      for (var i = 0; i < expected.length; i++) {
        expect(
          log[i].$2,
          closeTo(expected[i], 0.2),
          reason: '${log[i].$1} n.º ${i + 1} a los ${log[i].$2} s',
        );
      }
      expect(fake.calls.where((c) => c == 'anchor'), hasLength(1));
      expect(fake.calls, isNot(contains('stop')));

      await tester.pumpWidget(const SizedBox());
      expect(fake.calls.last, 'stop');
      expect(fake.calls.where((c) => c == 'stop'), hasLength(1));
      expect(fake.calls, hasLength(8));
    },
  );

  testWidgets(
    '"Salir" a los 30 s llama a stop() y después no hay más señales',
    (tester) async {
      final fake = FakeCues();
      await _pushWithHome(tester, fake);

      await _record(tester, fake, [], const Duration(seconds: 30));
      expect(fake.calls, ['anchor', 'inhale', 'exhale']);

      await tester.tap(find.byKey(SequenceScreen.exitButtonKey));
      await _record(tester, fake, [], const Duration(seconds: 2));
      expect(find.byType(SequenceScreen), findsNothing);
      expect(fake.calls, ['anchor', 'inhale', 'exhale', 'stop']);

      // Sin reloj huérfano: el tiempo sigue y no se emite nada más.
      await _record(tester, fake, [], const Duration(seconds: 70));
      expect(fake.calls, ['anchor', 'inhale', 'exhale', 'stop']);
    },
  );

  testWidgets(
    'skipStep() de entrada → apoyo → respiración: inhale al llegar el primer tramo, sin duplicados',
    (tester) async {
      final fake = FakeCues();
      await tester.pumpWidget(MaterialApp(home: SequenceScreen(cues: fake)));
      final state = tester.state<SequenceScreenState>(
        find.byType(SequenceScreen),
      );

      await _record(tester, fake, [], const Duration(seconds: 1));
      state.skipStep(); // entrada → apoyo (5 s)
      await tester.pump(_tick);
      state.skipStep(); // apoyo → respiración (20 s, preparación sin fase)
      await tester.pump(_tick);
      expect(fake.calls, ['anchor'], reason: 'la preparación no vibra');

      // La preparación dura 5 s: justo antes aún nada, justo después el inhale.
      final log = <_Cue>[];
      var now = await _record(
        tester,
        fake,
        log,
        const Duration(milliseconds: 4700),
      );
      expect(fake.calls, ['anchor']);
      now = await _record(
        tester,
        fake,
        log,
        const Duration(milliseconds: 600),
        start: now,
      );
      expect(fake.calls, ['anchor', 'inhale']);
      expect(log.single.$2, closeTo(5.0, 0.25));

      // Toda la inhalación (4 s) sin repetir; luego un único exhale.
      await _record(
        tester,
        fake,
        log,
        const Duration(milliseconds: 3500),
        start: now,
      );
      expect(fake.calls, ['anchor', 'inhale']);
      await _record(tester, fake, log, const Duration(milliseconds: 600));
      expect(fake.calls, ['anchor', 'inhale', 'exhale']);
    },
  );

  group('app completa con el doble global', () {
    late FakeCues global;

    setUp(() {
      global = SensoryCues.instance as FakeCues;
      global.calls.clear();
    });

    tearDown(() => global.calls.clear());

    testWidgets('pulsar el botón de inicio emite el ancla', (tester) async {
      await tester.pumpWidget(const ParaElTiempoApp());
      expect(global.calls, isEmpty);

      await tester.tap(find.byKey(HomeScreen.startButtonKey));
      await tester.pump();
      await tester.pump();
      expect(find.byType(SequenceScreen), findsOneWidget);
      expect(global.calls, ['anchor']);
    });
  });
}
