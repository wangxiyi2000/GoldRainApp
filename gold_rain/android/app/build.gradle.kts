plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.gold_rain"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.gold_rain"
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

    // AGP 8 默认关闭 resValues；产品风味用 resValue 定义 app_name 需要显式开启
    buildFeatures {
        resValues = true
    }

    // 产品风味：
    //   prod = 正式版（applicationId 保持 com.example.gold_rain，数据/签名与历史版本一致）
    //   demo = 演示/调试版（独立包名 com.example.gold_rain.demo，安装后是「另一个 App」，
    //          数据与正式版互不相通；仅应用名不同，其余功能完全一致）
    flavorDimensions += "mode"
    productFlavors {
        create("prod") {
            dimension = "mode"
            applicationId = "com.example.gold_rain"
            resValue("string", "app_name", "搬砖爆金币")
        }
        create("demo") {
            dimension = "mode"
            applicationId = "com.example.gold_rain.demo"
            resValue("string", "app_name", "搬砖爆金币·演示")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
