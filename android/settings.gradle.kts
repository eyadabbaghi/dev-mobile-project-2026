try {
    val processEnvClass = Class.forName("java.lang.ProcessEnvironment")
    val theEnvironmentField = processEnvClass.getDeclaredField("theEnvironment")
    theEnvironmentField.isAccessible = true
    @Suppress("UNCHECKED_CAST")
    val env = theEnvironmentField.get(null) as MutableMap<String, String>
    env.remove("ANDROID_PREFS_ROOT")

    val theCaseInsensitiveEnvironmentField = processEnvClass.getDeclaredField("theCaseInsensitiveEnvironment")
    theCaseInsensitiveEnvironmentField.isAccessible = true
    @Suppress("UNCHECKED_CAST")
    val caseInsensitiveEnv = theCaseInsensitiveEnvironmentField.get(null) as MutableMap<String, String>
    caseInsensitiveEnv.remove("ANDROID_PREFS_ROOT")
} catch (e: Throwable) {
    // ignore
}

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
