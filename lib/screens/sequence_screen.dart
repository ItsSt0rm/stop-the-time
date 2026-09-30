import 'package:flutter/material.dart';

import '../sequence/breathing.dart';
import '../sequence/sequence.dart';
import '../theme.dart';

/// Reproduce la secuencia guiada. Sin reloj, cuenta atrás ni barra de progreso.
class SequenceScreen extends StatefulWidget {
  const SequenceScreen({super.key, this.sequence = defaultSequence});

  final Sequence sequence;

  static const exitButtonKey = Key('exit-button');
  static const circleKey = Key('breathing-circle');

  @override
  State<SequenceScreen> createState() => SequenceScreenState();
}

class SequenceScreenState extends State<SequenceScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;

  Sequence get _sequence => widget.sequence;

  Duration get _elapsed => _clock.duration! * _clock.value;

  @override
  void initState() {
    super.initState();
    // Un único reloj interno (nunca visible) marca toda la secuencia.
    _clock = AnimationController(vsync: this, duration: _sequence.total)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      })
      ..forward();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  /// Salta al inicio del siguiente paso (el botón llega en la fase 4).
  void skipStep() {
    final current = _sequence.positionAt(_elapsed).stepIndex;
    if (current + 1 >= _sequence.steps.length) {
      _clock.value = 1;
      return;
    }
    final next = _sequence.startOf(current + 1);
    _clock.forward(from: next.inMicroseconds / _sequence.total.inMicroseconds);
  }

  void _finish() {
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _clock,
              builder: (context, _) {
                final position = _sequence.positionAt(_elapsed);
                final isEntrada = position.step.kind == StepKind.entrada;
                return AnimatedOpacity(
                  // Único oscurecido total: la entrada (0–5 s).
                  opacity: isEntrada ? 0 : 1,
                  duration: const Duration(milliseconds: 1500),
                  child: _SequenceBody(position: position),
                );
              },
            ),
            Positioned(
              right: 8,
              top: 8,
              child: TextButton(
                key: SequenceScreen.exitButtonKey,
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

class _SequenceBody extends StatelessWidget {
  const _SequenceBody({required this.position});

  final SequencePosition position;

  @override
  Widget build(BuildContext context) {
    final text = position.segment.text;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 240,
              child: Center(
                child: Transform.scale(
                  scale: circleScaleAt(position),
                  child: Container(
                    key: SequenceScreen.circleKey,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.circle,
                      border: Border.all(color: AppColors.circleEdge),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              height: 110,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 900),
                child: Text(
                  text ?? '',
                  // La clave por tramo hace que cada frase entre con un fundido suave.
                  key: ValueKey(
                    '${position.stepIndex}-${position.segmentIndex}',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.5,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
