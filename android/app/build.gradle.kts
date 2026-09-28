plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")

    // START: FlutterFire Configuration
    id("com.google.gms.google-services") // Google Services Plugin app-level
    // END: FlutterFire Configuration
}

android {
    namespace = "com.example.smart_kuhlschrank"
    compileSdk = 34
    // ndkVersion = "27.0.12077973" // Kaldırıldı, Flutter yönetsin

    compileOptions {
        // Enable core library desugaring
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.smart_kuhlschrank"
        minSdkVersion(23) // Firebase Auth gereksinimi nedeniyle 23 yapıldı
        targetSdkVersion(34)
        versionCode = 1
        versionName = "1.0"
        multiDexEnabled = true // Büyük projeler için gerekli olabilir
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // Firebase BoM ve gerekli kütüphaneler
    implementation(platform("com.google.firebase:firebase-bom:34.7.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
}
