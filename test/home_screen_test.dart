import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:para_el_tiempo/main.dart';
import 'package:para_el_tiempo/screens/home_screen.dart';
import 'package:para_el_tiempo/screens/reminders_screen.dart';
import 'package:para_el_tiempo/screens/sequence_screen.dart';

void main() {
  testWidgets(
    'la pantalla inicial tiene un único botón de inicio y abre la secuencia',
    (tester) async {
      await tester.pumpWidget(const ParaElTiempoApp());

      expect(find.byKey(HomeScreen.startButtonKey), findsOneWidget);
      expect(find.text('Para'), findsOneWidget);
      // Aparte del círculo, solo el acceso discreto a los recordatorios.
      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byKey(HomeScreen.remindersButtonKey), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.tap(find.byKey(HomeScreen.startButtonKey));
      // La secuencia dura 90 s y nunca "settles": avanzamos tiempo concreto
      // (transición de 600 ms + margen).
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SequenceScreen), findsOneWidget);

      await tester.tap(find.byKey(SequenceScreen.exitButtonKey));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SequenceScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  testWidgets('el círculo de inicio sigue centrado en la pantalla', (
    tester,
  ) async {
    await tester.pumpWidget(const ParaElTiempoApp());
    final screen = tester.getRect(find.byType(Scaffold));
    final button = tester.getCenter(find.byKey(HomeScreen.startButtonKey));
    expect(button.dx, closeTo(screen.center.dx, 0.5));
    expect(button.dy, closeTo(screen.center.dy, 0.5));
  });

  testWidgets('el botón de recordatorios está arriba a la derecha', (
    tester,
  ) async {
    await tester.pumpWidget(const ParaElTiempoApp());
    final screen = tester.getRect(find.byType(Scaffold));
    final icon = tester.getRect(find.byKey(HomeScreen.remindersButtonKey));
    expect(icon.right, greaterThan(screen.width - 64));
    expect(icon.top, lessThan(64));
    expect(find.byTooltip('Recordatorios'), findsOneWidget);
    // No se solapa con el círculo.
    final circle = tester.getRect(find.byKey(HomeScreen.startButtonKey));
    expect(icon.overlaps(circle), isFalse);
  });

  testWidgets('el botón de recordatorios abre RemindersScreen y se vuelve', (
    tester,
  ) async {
    await tester.pumpWidget(const ParaElTiempoApp());
    await tester.tap(find.byKey(HomeScreen.remindersButtonKey));
    await tester.pumpAndSettle();
    expect(find.byType(RemindersScreen), findsOneWidget);
    expect(find.text('Recordatorios'), findsOneWidget);

    // Botón/gesto atrás del sistema.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(RemindersScreen), findsNothing);
    expect(find.byKey(HomeScreen.startButtonKey), findsOneWidget);
  });

  testWidgets('en la secuencia no aparece el icono de recordatorios', (
    tester,
  ) async {
    await tester.pumpWidget(const ParaElTiempoApp());
    await tester.tap(find.byKey(HomeScreen.startButtonKey));
    await tester.pump();
    await tester.pump();
    expect(find.byType(SequenceScreen), findsOneWidget);

    for (var second = 0; second < 90; second += 5) {
      expect(
        find.byKey(HomeScreen.remindersButtonKey).hitTestable(),
        findsNothing,
        reason: 'a los $second s',
      );
      expect(
        find.byIcon(Icons.notifications_none_outlined).hitTestable(),
        findsNothing,
        reason: 'a los $second s',
      );
      expect(
        find.descendant(
          of: find.byType(SequenceScreen),
          matching: find.byType(IconButton),
        ),
        findsNothing,
      );
      await tester.pump(const Duration(seconds: 5));
    }
    // Fin de la secuencia y fundido de vuelta (600 ms), en varios frames.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    // Al terminar, el icono vuelve a estar disponible.
    expect(find.byType(SequenceScreen), findsNothing);
    expect(
      find.byKey(HomeScreen.remindersButtonKey).hitTestable(),
      findsOneWidget,
    );
  });
}
