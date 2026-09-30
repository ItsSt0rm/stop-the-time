import 'package:flutter_test/flutter_test.dart';
import 'package:para_el_tiempo/main.dart';
import 'package:para_el_tiempo/screens/home_screen.dart';
import 'package:para_el_tiempo/screens/sequence_screen.dart';

void main() {
  testWidgets('la pantalla inicial tiene un único botón y abre la secuencia', (
    tester,
  ) async {
    await tester.pumpWidget(const ParaElTiempoApp());

    expect(find.byKey(HomeScreen.startButtonKey), findsOneWidget);
    expect(find.text('Para'), findsOneWidget);

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
  });
}
