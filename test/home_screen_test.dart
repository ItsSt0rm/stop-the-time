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
    await tester.pumpAndSettle();
    expect(find.byType(SequenceScreen), findsOneWidget);

    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
