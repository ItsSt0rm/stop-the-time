import 'dart:async';

import 'package:para_el_tiempo/cues/sensory_cues.dart';
import 'package:para_el_tiempo/device/screen_awake.dart';

import 'support/fake_cues.dart';
import 'support/fake_screen_awake.dart';

/// Se ejecuta antes de cada archivo de test: ningún test toca vibración, audio ni la pantalla
/// reales.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SensoryCues.instance = FakeCues();
  ScreenAwake.instance = FakeScreenAwake();
  await testMain();
}
