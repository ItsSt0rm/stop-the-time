import 'dart:async';

import 'package:para_el_tiempo/cues/sensory_cues.dart';

import 'support/fake_cues.dart';

/// Se ejecuta antes de cada archivo de test: ningún test toca vibración ni audio reales.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SensoryCues.instance = FakeCues();
  await testMain();
}
