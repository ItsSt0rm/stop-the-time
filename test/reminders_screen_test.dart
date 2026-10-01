import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:para_el_tiempo/reminders/reminder.dart';
import 'package:para_el_tiempo/screens/reminders_screen.dart';

import 'support/fake_reminders.dart';

late MemoryReminderStore store;
late FakeReminderScheduler scheduler;

Future<void> _pump(
  WidgetTester tester, [
  List<Reminder> initial = const [],
  // Ajuste del sistema "formato de 24 horas". Ver el test omitido con 12 h más abajo.
  bool use24h = true,
]) async {
  // Tamaño de un teléfono (A55 ≈ 1080×2340 px): el selector de hora no cabe en 800×600.
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  store.saved = [...initial];
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24h),
        child: child!,
      ),
      home: RemindersScreen(store: store, scheduler: scheduler),
    ),
  );
  await tester.pumpAndSettle();
}

/// Botón de confirmar del selector de hora en español ("ACEPTAR" o "Aceptar" según la versión).
final _accept = find.byWidgetPredicate(
  (w) => w is Text && w.data?.toLowerCase() == 'aceptar',
);

/// Con el selector de hora abierto: pasa a modo texto, escribe la hora y confirma.
Future<void> _pickTime(WidgetTester tester, int hour, int minute) async {
  await tester.tap(find.byTooltip('Cambiar al modo de introducción de texto'));
  await tester.pumpAndSettle();
  final fields = find.descendant(
    of: find.byType(Dialog),
    matching: find.byType(TextFormField),
  );
  expect(fields, findsNWidgets(2));
  await tester.enterText(fields.at(0), '$hour');
  await tester.enterText(fields.at(1), minute.toString().padLeft(2, '0'));
  await tester.pump();
  await tester.tap(_accept);
  await tester.pumpAndSettle();
}

Reminder _r(int id, {Set<int> days = Reminder.allDays, bool enabled = true}) =>
    Reminder(id: id, hour: 8, minute: 0, weekdays: days, enabled: enabled);

void main() {
  setUp(() {
    store = MemoryReminderStore();
    scheduler = FakeReminderScheduler();
  });

  testWidgets('estado vacío: texto de ayuda, botón de añadir y sin avisos', (
    tester,
  ) async {
    scheduler.notificationsGranted = false;
    await _pump(tester);
    expect(find.text('Recordatorios'), findsOneWidget);
    expect(find.textContaining('Elige horas'), findsOneWidget);
    expect(find.byKey(RemindersScreen.addButtonKey), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Permitir'), findsNothing);
    expect(find.text('Conceder'), findsNothing);
  });

  testWidgets('el selector de hora está en español', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(RemindersScreen.addButtonKey));
    await tester.pumpAndSettle();
    // Cabecera del diálogo (en modo texto, "Hora" también es la etiqueta del campo).
    expect(
      find.descendant(of: find.byType(Dialog), matching: find.text('Hora')),
      findsOneWidget,
    );
    expect(_accept, findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('OK'), findsNothing);
  });

  testWidgets('cancelar el selector no crea nada', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(RemindersScreen.addButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(store.saved, isEmpty);
    expect(scheduler.calls, isNot(contains('sync')));
    expect(scheduler.calls, isNot(contains('requestNotifications')));
  });

  testWidgets(
    'añadir: todos los días, activo, guarda y sincroniza; sin pedir permiso si ya está',
    (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(RemindersScreen.addButtonKey));
      await tester.pumpAndSettle();
      await _pickTime(tester, 7, 30);

      final expected = Reminder(
        id: 1,
        hour: 7,
        minute: 30,
        weekdays: Reminder.allDays,
      );
      expect(store.saved, [expected]);
      expect(scheduler.lastSynced, [expected]);
      expect(scheduler.calls, contains('sync'));
      expect(scheduler.calls, isNot(contains('requestNotifications')));
      expect(find.textContaining('Elige horas'), findsNothing);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.textContaining('7:30'), findsOneWidget);
    },
  );

  testWidgets(
    'con el teléfono en formato de 12 h se pueden escribir horas de tarde (22:05)',
    (tester) async {
      await _pump(tester, const [], false);
      await tester.tap(find.byKey(RemindersScreen.addButtonKey));
      await tester.pumpAndSettle();
      await _pickTime(tester, 22, 5);
      expect(store.saved.single.hour, 22);
      expect(store.saved.single.minute, 5);

      // Y una hora de mañana no se convierte en tarde según la hora actual (7 → 7, no 19).
      await tester.tap(find.byKey(RemindersScreen.addButtonKey));
      await tester.pumpAndSettle();
      await _pickTime(tester, 7, 30);
      expect(store.saved.last.hour, 7);
      expect(store.saved.last.minute, 30);
    },
  );

  testWidgets('añadir sin permiso de notificaciones lo pide (antes de sync)', (
    tester,
  ) async {
    scheduler.notificationsGranted = false;
    await _pump(tester);
    await tester.tap(find.byKey(RemindersScreen.addButtonKey));
    await tester.pumpAndSettle();
    await _pickTime(tester, 22, 5);

    final req = scheduler.calls.indexOf('requestNotifications');
    expect(req, isNot(-1));
    expect(req, lessThan(scheduler.calls.indexOf('sync')));
    expect(scheduler.calls.where((c) => c == 'requestNotifications').length, 1);
    expect(store.saved.single.hour, 22);
    expect(store.saved.single.minute, 5);
    // Concedido en el diálogo: no queda aviso.
    expect(find.text('Permitir'), findsNothing);
  });

  testWidgets('si el permiso se deniega, aparece el aviso "Permitir"', (
    tester,
  ) async {
    scheduler
      ..notificationsGranted = false
      ..grantOnRequest = false;
    await _pump(tester);
    await tester.tap(find.byKey(RemindersScreen.addButtonKey));
    await tester.pumpAndSettle();
    await _pickTime(tester, 9, 0);
    expect(store.saved, hasLength(1));
    expect(find.text('Permitir'), findsOneWidget);
  });

  testWidgets('el id nuevo es el máximo + 1', (tester) async {
    await _pump(tester, [_r(4), _r(2)]);
    await tester.tap(find.byKey(RemindersScreen.addButtonKey));
    await tester.pumpAndSettle();
    await _pickTime(tester, 9, 0);
    expect(store.saved.map((r) => r.id), [4, 2, 5]);
  });

  testWidgets('tocar la hora la edita conservando días y estado', (
    tester,
  ) async {
    await _pump(tester, [
      _r(1, days: {1, 5}),
    ]);
    await tester.tap(find.textContaining('8:00'));
    await tester.pumpAndSettle();
    await _pickTime(tester, 21, 45);
    expect(store.saved, [
      Reminder(id: 1, hour: 21, minute: 45, weekdays: {1, 5}),
    ]);
    expect(scheduler.lastSynced, store.saved);
  });

  testWidgets('alternar un día lo quita y lo vuelve a poner', (tester) async {
    await _pump(tester, [_r(1)]);
    await tester.tap(find.text('X'));
    await tester.pumpAndSettle();
    expect(store.saved.single.weekdays, {1, 2, 4, 5, 6, 7});
    expect(scheduler.lastSynced.single.weekdays, {1, 2, 4, 5, 6, 7});

    await tester.tap(find.text('X'));
    await tester.pumpAndSettle();
    expect(store.saved.single.weekdays, Reminder.allDays);
    expect(scheduler.lastSynced.single.weekdays, Reminder.allDays);
  });

  testWidgets('no se puede quitar el último día', (tester) async {
    await _pump(tester, [
      _r(1, days: {7}),
    ]);
    scheduler.calls.clear();
    await tester.tap(find.text('D'));
    await tester.pumpAndSettle();
    expect(store.saved.single.weekdays, {7});
    expect(scheduler.calls, isNot(contains('sync')));
  });

  testWidgets('el Switch desactiva y sincroniza con enabled=false', (
    tester,
  ) async {
    await _pump(tester, [_r(1)]);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(store.saved.single.enabled, isFalse);
    expect(scheduler.lastSynced.single.enabled, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(scheduler.lastSynced.single.enabled, isTrue);
  });

  testWidgets('eliminar quita el recordatorio, guarda y sincroniza', (
    tester,
  ) async {
    await _pump(tester, [
      _r(1),
      _r(2, days: {6}),
    ]);
    await tester.tap(find.byTooltip('Eliminar recordatorio').first);
    await tester.pumpAndSettle();
    expect(store.saved.map((r) => r.id), [2]);
    expect(scheduler.lastSynced.map((r) => r.id), [2]);

    await tester.tap(find.byTooltip('Eliminar recordatorio'));
    await tester.pumpAndSettle();
    expect(store.saved, isEmpty);
    expect(scheduler.lastSynced, isEmpty);
    expect(find.textContaining('Elige horas'), findsOneWidget);
  });

  group('avisos de permisos', () {
    testWidgets('todo concedido: sin avisos', (tester) async {
      await _pump(tester, [_r(1)]);
      expect(find.text('Permitir'), findsNothing);
      expect(find.text('Conceder'), findsNothing);
    });

    testWidgets(
      'sin notificaciones: solo "Permitir"; al pulsarlo pide y resincroniza',
      (tester) async {
        scheduler
          ..notificationsGranted = false
          ..exactGranted = false;
        await _pump(tester, [_r(1)]);
        expect(find.text('Permitir'), findsOneWidget);
        expect(find.text('Conceder'), findsNothing);

        scheduler
          ..calls.clear()
          ..exactGranted = true;
        await tester.tap(find.text('Permitir'));
        await tester.pumpAndSettle();
        expect(scheduler.calls, ['requestNotifications', 'sync']);
        expect(find.text('Permitir'), findsNothing);
      },
    );

    testWidgets('con notificaciones pero sin alarmas exactas: "Conceder"', (
      tester,
    ) async {
      scheduler.exactGranted = false;
      await _pump(tester, [_r(1)]);
      expect(find.text('Permitir'), findsNothing);
      expect(find.text('Conceder'), findsOneWidget);
      await tester.tap(find.text('Conceder'));
      await tester.pumpAndSettle();
      expect(scheduler.calls, contains('requestExactAlarms'));
    });

    testWidgets('sin recordatorios activos no hay avisos', (tester) async {
      scheduler
        ..notificationsGranted = false
        ..exactGranted = false;
      await _pump(tester, [_r(1, enabled: false)]);
      expect(find.text('Permitir'), findsNothing);
      expect(find.text('Conceder'), findsNothing);

      // Al activarlo aparece el aviso.
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Permitir'), findsOneWidget);
    });

    testWidgets('al volver a la app se refrescan permisos y se resincroniza', (
      tester,
    ) async {
      scheduler.exactGranted = false;
      await _pump(tester, [_r(1)]);
      expect(find.text('Conceder'), findsOneWidget);

      // La persona concede el permiso en Ajustes y vuelve.
      scheduler
        ..calls.clear()
        ..exactGranted = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Conceder'), findsNothing);
      expect(scheduler.calls, contains('sync'));
      expect(scheduler.lastSynced, [_r(1)]);
    });
  });
}
