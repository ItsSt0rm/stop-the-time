import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'cues/sensory_cues.dart';
import 'reminders/reminder_scheduler.dart';
import 'reminders/reminder_store.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Solo vertical: menos cambios en pantalla durante la secuencia.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Sin await: la app se muestra ya; el audio termina de cargar mientras se ve el botón.
  SensoryCues.instance.preload();
  _resyncReminders();
  runApp(const ParaElTiempoApp());
}

/// En cada arranque se reprograman los recordatorios guardados: corrige cambios de zona horaria
/// o del permiso de alarmas exactas hechos fuera de la app.
Future<void> _resyncReminders() async {
  try {
    final reminders = await ReminderStore.instance.load();
    if (reminders.isEmpty) return;
    await ReminderScheduler.instance.sync(reminders);
  } catch (e) {
    debugPrint('Recordatorios: $e');
  }
}

class ParaElTiempoApp extends StatelessWidget {
  const ParaElTiempoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Para el tiempo',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // Español para los textos del sistema (selector de hora, botones de diálogo…).
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const HomeScreen(),
    );
  }
}
