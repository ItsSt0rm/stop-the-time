import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de release: keystore y contraseñas viven fuera del repo, en el home de WSL.
// Ver "Firmar el APK de release" en el README.
val keystorePropsFile = file("${System.getProperty("user.home")}/.keystores/para-el-tiempo.properties")
val keystoreProps = Properties().apply {
    if (keystorePropsFile.exists()) keystorePropsFile.inputStream().use { load(it) }
}

android {
    namespace = "local.paraeltiempo.para_el_tiempo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Requerido por flutter_local_notifications (java.time en Android < 8).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "io.github.itsst0rm.paraeltiempo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Solo las ABI para las que se compila el motor de Flutter (--target-platform android-arm,android-arm64).
    // Dependencias como datastore traen .so para otras ABI; si el APK incluye una ABI sin libflutter.so,
    // Android puede elegirla y la app se cierra al abrir (pasó en v1.1.0 con un teléfono de 32 bits).
    // (ndk.abiFilters no sirve aquí: el plugin de Flutter lo sobrescribe.)
    packaging {
        jniLibs {
            excludes += listOf("lib/x86/**", "lib/x86_64/**")
        }
    }

    signingConfigs {
        if (keystorePropsFile.exists()) {
            create("release") {
                storeFile = file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Nunca se firma un release con la clave de debug.
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

// Sin keystore, el release falla con un mensaje claro en vez de salir sin firmar.
tasks.configureEach {
    if (name == "packageRelease" && !keystorePropsFile.exists()) {
        doFirst {
            throw GradleException("Falta $keystorePropsFile: no se puede firmar el release.")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Misma versión que usa flutter_local_notifications 22.3.1 en su propio build.gradle.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
