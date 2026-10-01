package local.paraeltiempo.para_el_tiempo

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Zona horaria IANA del teléfono (p. ej. "America/Bogota") para programar recordatorios.
        // Sustituye al plugin flutter_timezone: una dependencia de terceros menos.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "para_el_tiempo/timezone")
            .setMethodCallHandler { call, result ->
                if (call.method == "localTimezone") {
                    result.success(TimeZone.getDefault().id)
                } else {
                    result.notImplemented()
                }
            }
    }
}
