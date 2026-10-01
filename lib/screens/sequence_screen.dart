import 'package:flutter/material.dart';

import '../cues/sensory_cues.dart';
import '../device/screen_awake.dart';
import '../sequence/breathing.dart';
import '../sequence/sequence.dart';
import '../theme.dart';

/// Reproduce la secuencia guiada. Sin reloj, cuenta atrás ni barra de progreso.
class SequenceScreen extends StatefulWidget {
  const SequenceScreen({
    super.key,
    this.sequence = defaultSequence,
    this.cues,
    this.screenAwake,
  });

  final Sequence sequence;

  /// Vibración y sonido; por defecto [SensoryCues.instance].
  final SensoryCues? cues;

  /// Pantalla encendida; por defecto [ScreenAwake.instance].
  final ScreenAwake? screenAwake;

  static const exitButtonKey = Key('exit-button');
  static const circleKey = Key('breathing-circle');

  @override
  State<SequenceScreen> createState() => SequenceScreenState();
}

class SequenceScreenState extends State<SequenceScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;
  late final SensoryCues _cues = widget.cues ?? SensoryCues.instance;
  late final ScreenAwake _screen = widget.screenAwake ?? ScreenAwake.instance;

  /// Último tramo en el que se emitió una señal, para emitir una sola vez por tramo.
  (int, int)? _cuedSegment;

  Sequence get _sequence => widget.sequence;

  Duration get _elapsed => _clock.duration! * _clock.value;

  @override
  void initState() {
    super.initState();
    // Un único reloj interno (nunca visible) marca toda la secuencia.
    _clock = AnimationController(vsync: this, duration: _sequence.total)
      ..addListener(_emitCues)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      })
      ..forward();
    _screen.enable();
    _cues.anchor();
  }

  /// Se ejecuta al salir por cualquier vía (Salir, atrás, fin): la pantalla vuelve a apagarse
  /// según el sistema.
  @override
  void dispose() {
    _screen.disable();
    _cues.stop();
    _clock.dispose();
    super.dispose();
  }

  /// Pulso háptico al empezar cada inhalación y cada exhalación.
  void _emitCues() {
    final position = _sequence.positionAt(_elapsed);
    if (position.finished) return;
    final segment = (position.stepIndex, position.segmentIndex);
    if (segment == _cuedSegment) return;
    _cuedSegment = segment;
    switch (position.segment.breath) {
      case Breath.inhale:
        _cues.inhale();
      case Breath.exhale:
        _cues.exhale();
      case null:
        break;
    }
  }

  void _finish() {
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _clock,
              builder: (context, _) =>
                  _SequenceBody(position: _sequence.positionAt(_elapsed)),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton(
                  key: SequenceScreen.exitButtonKey,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Salir',
                    style: TextStyle(color: AppColors.textDim),
                  ),
                ),
              ),
            ),
          ),
        ],
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
    // El círculo queda centrado en pantalla, igual que el botón de inicio,
    // para que la entrada continúe el mismo círculo sin saltos.
    return LayoutBuilder(
      builder: (context, constraints) {
        final textTop = constraints.maxHeight / 2 + circleBoxSize / 2 + 32;
        return Stack(
          children: [
            Center(
              child: SizedBox.square(
                dimension: circleBoxSize,
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
            ),
            Center(
              child: Opacity(
                opacity: startLabelOpacityAt(position),
                child: const Text('Para', style: startLabelStyle),
              ),
            ),
            Positioned(
              top: textTop,
              left: 32,
              right: 32,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 900),
                // Anclado arriba: durante el fundido conviven frases con distinto número de
                // líneas; centradas (el valor por defecto) se desplazan en vertical.
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, ?current],
                ),
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
        );
      },
    );
  }
}
