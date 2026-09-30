import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:para_el_tiempo/main.dart';
import 'package:para_el_tiempo/screens/home_screen.dart';
import 'package:para_el_tiempo/screens/sequence_screen.dart';
import 'package:para_el_tiempo/sequence/sequence.dart';

String _textOf(StepKind kind, [int segment = 0]) => defaultSequence.steps
    .firstWhere((s) => s.kind == kind)
    .segments[segment]
    .text!;

/// Monta la SequenceScreen sola. El reloj interno arranca en este frame,
/// así que a partir de aquí cada `pump(d)` avanza la secuencia `d`.
Future<void> _pumpSequence(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: SequenceScreen()));
}

/// Monta la app completa y abre la secuencia desde el botón de inicio.
/// Al volver, el reloj de la secuencia está en ~0 s.
Future<void> _openFromHome(WidgetTester tester) async {
  await tester.pumpWidget(const ParaElTiempoApp());
  await tester.tap(find.byKey(HomeScreen.startButtonKey));
  // Primer frame: la ruta nueva se monta "offstage" (Hero); en el segundo ya
  // está visible.
  await tester.pump();
  await tester.pump();
  expect(find.byType(SequenceScreen), findsOneWidget);
}

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

/// Tiempo tras un cambio de frase para que acabe el fundido (900 ms).
const _afterSwitch = Duration(seconds: 2);

double _circleWidth(WidgetTester tester) =>
    tester.getRect(find.byKey(SequenceScreen.circleKey)).width;

void main() {
  testWidgets('a los 10 s se ve el texto de apoyo', (tester) async {
    await _pumpSequence(tester);
    await _advance(tester, const Duration(seconds: 10));
    expect(find.text(_textOf(StepKind.apoyo)), findsOneWidget);
  });

  testWidgets('a los 22 s se ve la preparación de la respiración', (
    tester,
  ) async {
    await _pumpSequence(tester);
    await _advance(tester, const Duration(seconds: 22));
    expect(find.text(_textOf(StepKind.respiracion)), findsOneWidget);
    expect(find.text(_textOf(StepKind.apoyo)), findsNothing);
  });

  testWidgets('durante la inhalación el círculo crece', (tester) async {
    await _pumpSequence(tester);
    // En reposo (apoyo) el círculo está a restScale de su caja de 240.
    await _advance(tester, const Duration(seconds: 10));
    final rest = _circleWidth(tester);
    expect(rest, closeTo(240 * 0.6, 0.5));

    // Primera inhalación: 25–29 s.
    await _advance(tester, const Duration(milliseconds: 15500)); // 25.5 s
    expect(find.text('Inhala'), findsOneWidget);
    final early = _circleWidth(tester);
    await _advance(tester, const Duration(seconds: 3)); // 28.5 s
    final late = _circleWidth(tester);
    expect(late, greaterThan(early));
    expect(late, greaterThan(rest));

    // Exhalación: 29–35 s, se encoge.
    await _advance(tester, const Duration(seconds: 2)); // 30.5 s
    final exhaleEarly = _circleWidth(tester);
    await _advance(tester, const Duration(seconds: 4)); // 34.5 s
    expect(find.text('Exhala'), findsOneWidget);
    expect(_circleWidth(tester), lessThan(exhaleEarly));
  });

  testWidgets('tras 90 s la pantalla se cierra y vuelve al inicio', (
    tester,
  ) async {
    await _openFromHome(tester);
    await _advance(tester, const Duration(seconds: 89));
    expect(find.byType(SequenceScreen), findsOneWidget);

    // 90 s + margen para la transición de salida (600 ms).
    await _advance(tester, const Duration(seconds: 3));
    expect(find.byType(SequenceScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byKey(HomeScreen.startButtonKey), findsOneWidget);
  });

  testWidgets('"Salir" vuelve al inicio en mitad de la secuencia', (
    tester,
  ) async {
    await _openFromHome(tester);
    await _advance(tester, const Duration(seconds: 30));

    await tester.tap(find.byKey(SequenceScreen.exitButtonKey));
    await _advance(tester, const Duration(seconds: 1));
    expect(find.byType(SequenceScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);

    // Sin reloj huérfano: pasar más tiempo no provoca nada ni errores.
    await _advance(tester, const Duration(seconds: 70));
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('"Salir" funciona también durante la entrada oscura', (
    tester,
  ) async {
    await _openFromHome(tester);
    await _advance(tester, const Duration(seconds: 2));
    await tester.tap(find.byKey(SequenceScreen.exitButtonKey));
    await _advance(tester, const Duration(seconds: 1));
    expect(find.byType(SequenceScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('tocar "Salir" dos veces seguidas no deja la app vacía', (
    tester,
  ) async {
    await _openFromHome(tester);
    await _advance(tester, const Duration(seconds: 10));
    await tester.tap(find.byKey(SequenceScreen.exitButtonKey));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(
      find.byKey(SequenceScreen.exitButtonKey),
      warnIfMissed: false,
    );
    await _advance(tester, const Duration(seconds: 1));
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('skipStep() avanza al inicio del paso siguiente', (tester) async {
    await _pumpSequence(tester);
    final state = tester.state<SequenceScreenState>(
      find.byType(SequenceScreen),
    );

    // Entrada (1 s) -> apoyo.
    await _advance(tester, const Duration(seconds: 1));
    state.skipStep();
    await _advance(tester, _afterSwitch);
    expect(find.text(_textOf(StepKind.apoyo)), findsOneWidget);

    // Apoyo -> preparación de la respiración (sin esperar a los 20 s).
    state.skipStep();
    await _advance(tester, _afterSwitch);
    expect(find.text(_textOf(StepKind.respiracion)), findsOneWidget);
    expect(find.text(_textOf(StepKind.apoyo)), findsNothing);

    // Respiración -> escaneo (primera zona).
    state.skipStep();
    await _advance(tester, _afterSwitch);
    expect(find.text(_textOf(StepKind.escaneo)), findsOneWidget);

    // Escaneo -> grounding -> cierre.
    state.skipStep();
    await _advance(tester, _afterSwitch);
    expect(find.text(_textOf(StepKind.grounding)), findsOneWidget);
    state.skipStep();
    await _advance(tester, _afterSwitch);
    expect(find.text(_textOf(StepKind.cierre)), findsOneWidget);
  });

  testWidgets('skipStep() en el último paso termina y vuelve al inicio', (
    tester,
  ) async {
    await _openFromHome(tester);
    final state = tester.state<SequenceScreenState>(
      find.byType(SequenceScreen),
    );
    for (var i = 0; i < defaultSequence.steps.length - 1; i++) {
      state.skipStep();
      await _advance(tester, const Duration(seconds: 1));
    }
    expect(find.text(_textOf(StepKind.cierre)), findsOneWidget);
    expect(find.byType(SequenceScreen), findsOneWidget);

    state.skipStep();
    await _advance(tester, const Duration(seconds: 1));
    expect(find.byType(SequenceScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('sin barra de progreso ni texto de reloj en ningún momento', (
    tester,
  ) async {
    final timeLike = RegExp(r'\d+:\d\d|\d+\s?s\b');
    await _pumpSequence(tester);

    for (var second = 0; second < 90; second++) {
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(RefreshProgressIndicator), findsNothing);
      for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
        final text = rich.text.toPlainText();
        expect(
          timeLike.hasMatch(text),
          isFalse,
          reason: 'a los $second s aparece "$text"',
        );
      }
      await tester.pump(const Duration(seconds: 1));
    }
  });
}
