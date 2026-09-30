import 'package:flutter/material.dart';

import '../sequence/breathing.dart';
import '../theme.dart';
import 'sequence_screen.dart';

/// Pantalla inicial: un único botón circular que inicia la secuencia.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const startButtonKey = Key('start-button');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
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
        ),
      ),
    );
  }
}
