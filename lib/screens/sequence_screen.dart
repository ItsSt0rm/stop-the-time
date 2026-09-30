import 'package:flutter/material.dart';

import '../theme.dart';

/// Marcador de la fase 1. En la fase 2 aquí vivirá la secuencia guiada.
class SequenceScreen extends StatelessWidget {
  const SequenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            const Center(child: Text('Aquí irá la secuencia')),
            Positioned(
              right: 8,
              top: 8,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Salir',
                  style: TextStyle(color: AppColors.textDim),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
