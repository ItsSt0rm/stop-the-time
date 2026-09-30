import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

import 'haptic_patterns.dart';

/// Señales no visuales de la secuencia (vibración y sonido).
///
/// Es una interfaz para poder sustituirla en los tests: el hardware real solo se toca en
/// [DeviceCues]. Los tests asignan un doble en `test/flutter_test_config.dart`.
abstract class SensoryCues {
  /// Implementación que usa la app. Se crea al primer uso.
  static SensoryCues instance = DeviceCues();

  /// Carga previa (audio) para que el ancla suene sin retraso al pulsar. Solo con AssetSource:
  /// nunca UrlSource (la app no tiene red).
  Future<void> preload();

  /// Ancla de entrada: vibración y sonido, siempre idénticos.
  void anchor();

  void inhale();
  void exhale();

  /// Corta cualquier vibración en curso (al salir).
  void stop();
}

class DeviceCues implements SensoryCues {
  static const _anchorAsset = 'audio/anchor.wav';

  AudioPlayer? _player;
  bool? _amplitude;
  Future<void>? _loading;

  /// Cambia en cada [stop]; un ancla pendiente de otra "época" ya no se emite.
  int _epoch = 0;

  /// Idempotente: si ya se está cargando, devuelve la misma carga.
  @override
  Future<void> preload() => _loading ??= _load();

  Future<void> _load() async {
    try {
      _amplitude = await Vibration.hasAmplitudeControl();
      final player = AudioPlayer(playerId: 'anchor');
      // Sonido breve: pide foco temporal y deja que otra música baje su volumen en vez de
      // pausarse.
      await player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setSource(AssetSource(_anchorAsset));
      _player = player;
    } catch (e) {
      // Sin sonido o sin vibración la secuencia sigue funcionando: nunca bloquear por esto.
      debugPrint('SensoryCues.preload: $e');
    }
  }

  /// Si se pulsa antes de que termine la carga inicial, espera a ella: así el primer ancla
  /// también suena y usa la vibración con intensidad (y no la de respaldo).
  @override
  void anchor() {
    final epoch = _epoch;
    preload().then((_) {
      if (epoch != _epoch) return; // se salió mientras cargaba
      _vibrate(AmplitudePatterns.anchor, OnOffPatterns.anchor);
      _playAnchor();
    });
  }

  @override
  void inhale() => _vibrate(AmplitudePatterns.inhale, OnOffPatterns.inhale);

  @override
  void exhale() => _vibrate(AmplitudePatterns.exhale, OnOffPatterns.exhale);

  /// Al salir se corta todo: que el ancla no siga sonando en la pantalla de inicio.
  @override
  void stop() {
    _epoch++;
    _guard(Vibration.cancel);
    _guard(() async => _player?.stop());
  }

  Future<void> _playAnchor() => _guard(() async {
    final player = _player;
    if (player == null) return;
    await player.stop(); // vuelve al inicio si sonó antes
    await player.resume();
  });

  void _vibrate(HapticPattern withAmplitude, HapticPattern onOff) {
    final p = (_amplitude ?? false) ? withAmplitude : onOff;
    _guard(
      () => Vibration.vibrate(pattern: p.timings, intensities: p.amplitudes),
    );
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('SensoryCues: $e');
    }
  }
}
