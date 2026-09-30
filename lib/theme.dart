import 'package:flutter/material.dart';

/// Paleta de baja estimulación: fondo casi negro, texto gris cálido de bajo contraste.
abstract final class AppColors {
  static const background = Color(0xFF0A0B0D);
  static const circle = Color(0xFF1C2127);
  static const circleEdge = Color(0xFF2C333B);
  static const text = Color(0xFFA7ADB4);
  static const textDim = Color(0xFF5E656D);
}

/// Texto "Para" del botón; se reutiliza en la entrada de la secuencia para que no cambie de aspecto.
const startLabelStyle = TextStyle(
  fontSize: 26,
  letterSpacing: 2,
  fontWeight: FontWeight.w300,
  color: AppColors.text,
);

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: base.colorScheme.copyWith(
      surface: AppColors.background,
      primary: AppColors.text,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
