import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:para_el_tiempo/device/screen_awake.dart';
import 'package:para_el_tiempo/main.dart';
import 'package:para_el_tiempo/screens/home_screen.dart';
import 'package:para_el_tiempo/screens/sequence_screen.dart';

import 'support/fake_cues.dart';
import 'support/fake_screen_awake.dart';

/// Avanza [total] en saltos de [step] (varios frames, como en un móvil).
Future<void> _advance(
  WidgetTester tester,
  Duration total, {
  Duration step = const Duration(milliseconds: 500),
}) async {
  var left = total;
  while (left > Duration.zero) {
    final d = left < step ? left : step;
    await tester.pump(d);
    left -= d;
  }
}

/// Tiempo tras un pop para que acabe el fundido de vuelta (600 ms) con margen.
const _afterExit = Duration(seconds: 2);

/// Monta la pantalla de inicio real y abre encima la secuencia con dobles propios.
/// Al volver, el reloj de la secuencia está en ~0 s.
Future<void> _open(
  WidgetTester tester,
  FakeScreenAwake screen,
  FakeCues cues,
) async {
  final key = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(navigatorKey: key, home: const HomeScreen()),
  );
  expect(screen.calls, isEmpty);
  key.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => SequenceScreen(screenAwake: screen, cues: cues),
    ),
  );
  await tester.pump();
  await tester.pump(); // la ruta ya está onstage
  expect(find.byType(SequenceScreen), findsOneWidget);
}

void _expectBackHome(WidgetTester tester) {
  expect(find.byType(SequenceScreen), findsNothing);
  expect(find.byType(HomeScreen), findsOneWidget);
}

void main() {
  late FakeScreenAwake screen;
  late FakeCues cues;

  setUp(() {
    screen = FakeScreenAwake();
    cues = FakeCues();
  });

  group('app completa con el doble global', () {
    late FakeScreenAwake global;

    setUp(() {
      global = ScreenAwake.instance as FakeScreenAwake;
      global.calls.clear();
      global.enabled = false;
    });

    tearDown(() {
      global.calls.clear();
      global.enabled = false;
    });

    testWidgets(
      'en la pantalla de inicio no se mantiene la pantalla encendida',
      (tester) async {
        await tester.pumpWidget(const ParaElTiempoApp());
        await _advance(tester, const Duration(seconds: 5));
        expect(global.calls, isEmpty);
        expect(global.enabled, isFalse);

        // Al pulsar el botón, la secuencia usa el doble global por defecto.
        await tester.tap(find.byKey(HomeScreen.startButtonKey));
        await tester.pump();
        await tester.pump();
        expect(global.calls, ['enable']);
        expect(global.enabled, isTrue);
      },
    );
  });

  testWidgets(
    'al abrir: enable una vez, antes del ancla; encendida los 90 s sin más llamadas',
    (tester) async {
      // Registro común para comprobar el orden enable → anchor.
      final order = <String>[];
      final orderedScreen = _OrderedScreen(screen, order);
      final orderedCues = _OrderedCues(cues, order);
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: key, home: const HomeScreen()),
      );
      key.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              SequenceScreen(screenAwake: orderedScreen, cues: orderedCues),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(order.take(2), ['enable', 'anchor']);
      expect(screen.calls, ['enable']);
      expect(screen.enabled, isTrue);

      for (var second = 0; second < 89; second++) {
        await tester.pump(const Duration(seconds: 1));
        expect(screen.enabled, isTrue, reason: 'a los ${second + 1} s');
        expect(screen.calls, ['enable'], reason: 'a los ${second + 1} s');
      }
      expect(find.byType(SequenceScreen), findsOneWidget);
    },
  );

  testWidgets('al terminar sola (90 s + fundido): disable una vez', (
    tester,
  ) async {
    await _open(tester, screen, cues);
    await _advance(tester, const Duration(seconds: 90));
    await _advance(tester, _afterExit);
    _expectBackHome(tester);
    expect(screen.calls, ['enable', 'disable']);
    expect(screen.enabled, isFalse);
    expect(cues.calls.last, 'stop');

    // Nada más después.
    await _advance(tester, const Duration(seconds: 10));
    expect(screen.calls, ['enable', 'disable']);
  });

  testWidgets('"Salir" a mitad (40 s): disable una vez', (tester) async {
    await _open(tester, screen, cues);
    await _advance(tester, const Duration(seconds: 40));
    expect(screen.calls, ['enable']);

    await tester.tap(find.byKey(SequenceScreen.exitButtonKey));
    await _advance(tester, _afterExit);
    _expectBackHome(tester);
    expect(screen.calls, ['enable', 'disable']);
    expect(screen.enabled, isFalse);

    await _advance(tester, const Duration(seconds: 60));
    expect(screen.calls, ['enable', 'disable']);
  });

  testWidgets(
    'botón atrás de Android a mitad (40 s): vuelve al inicio y disable',
    (tester) async {
      await _open(tester, screen, cues);
      await _advance(tester, const Duration(seconds: 40));

      final handled = await tester.binding.handlePopRoute();
      expect(handled, isTrue);
      await _advance(tester, _afterExit);
      _expectBackHome(tester);
      expect(screen.calls, ['enable', 'disable']);
      expect(screen.enabled, isFalse);
      expect(cues.calls.last, 'stop');
    },
  );

  testWidgets('salir durante la entrada (1 s): disable y stop de las señales', (
    tester,
  ) async {
    await _open(tester, screen, cues);
    await _advance(tester, const Duration(seconds: 1));

    await tester.tap(find.byKey(SequenceScreen.exitButtonKey));
    await _advance(tester, _afterExit);
    _expectBackHome(tester);
    expect(screen.calls, ['enable', 'disable']);
    expect(screen.enabled, isFalse);
    expect(cues.calls, ['anchor', 'stop']);
  });
}

/// Envoltorios que anotan en un registro común para comprobar el orden entre dobles.
class _OrderedScreen implements ScreenAwake {
  _OrderedScreen(this.inner, this.log);
  final FakeScreenAwake inner;
  final List<String> log;

  @override
  void enable() {
    log.add('enable');
    inner.enable();
  }

  @override
  void disable() {
    log.add('disable');
    inner.disable();
  }
}

class _OrderedCues extends FakeCues {
  _OrderedCues(this.inner, this.log);
  final FakeCues inner;
  final List<String> log;

  @override
  void anchor() {
    log.add('anchor');
    inner.anchor();
  }
}
