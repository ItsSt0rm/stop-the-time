import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cues/sensory_cues.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Solo vertical: menos cambios en pantalla durante la secuencia.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Sin await: la app se muestra ya; el audio termina de cargar mientras se ve el botón.
  SensoryCues.instance.preload();
  runApp(const ParaElTiempoApp());
}

class ParaElTiempoApp extends StatelessWidget {
  const ParaElTiempoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Para el tiempo',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeScreen(),
    );
  }
}
