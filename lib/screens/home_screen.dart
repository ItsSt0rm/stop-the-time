import 'package:flutter/material.dart';

import '../sequence/breathing.dart';
import '../theme.dart';
import 'reminders_screen.dart';
import 'sequence_screen.dart';

/// Pantalla inicial: el botón circular que inicia la secuencia y, arriba a la derecha, el acceso
/// discreto a los recordatorios.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const startButtonKey = Key('start-button');
  static const remindersButtonKey = Key('reminders-button');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Stack: el círculo sigue centrado en pantalla, igual que en la secuencia (continuidad).
      body: Stack(
        children: [
          Center(child: _startButton(context)),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: IconButton(
                  key: remindersButtonKey,
                  tooltip: 'Recordatorios',
                  icon: const Icon(
                    Icons.notifications_none_outlined,
                    color: AppColors.textDim,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RemindersScreen(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _startButton(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Iniciar la secuencia',
      child: GestureDetector(
        key: startButtonKey,
        onTap: () => Navigator.of(context).push(
          PageRouteBuilder<void>(
            pageBuilder: (_, _, _) => const SequenceScreen(),
            // Entrada instantánea: la secuencia empieza con este mismo círculo en el mismo
            // lugar, así que no hay corte visible. Al volver, fundido suave.
            transitionDuration: Duration.zero,
            reverseTransitionDuration: const Duration(milliseconds: 600),
            transitionsBuilder: (_, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        child: Container(
          width: circleBoxSize * homeScale,
          height: circleBoxSize * homeScale,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.circle,
            border: Border.all(color: AppColors.circleEdge),
          ),
          child: const Text('Para', style: startLabelStyle),
        ),
      ),
    );
  }
}
