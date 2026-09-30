import 'package:flutter/material.dart';

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
                transitionsBuilder: (_, animation, _, child) =>
                    FadeTransition(opacity: animation, child: child),
                transitionDuration: const Duration(milliseconds: 600),
              ),
            ),
            child: Container(
              width: 200,
              height: 200,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.circle,
                border: Border.all(color: AppColors.circleEdge),
              ),
              child: const Text(
                'Para',
                style: TextStyle(
                  fontSize: 26,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
