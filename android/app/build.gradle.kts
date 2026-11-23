import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

// Chiave di firma: su GitHub Actions arriva dai secrets (vedi .github/workflows/android.yml).
// Deve restare sempre la stessa: con una chiave diversa Android rifiuta l'aggiornamento e bisogna disinstallare (dati persi).
val chiave: String? = System.getenv("ALBA_KEYSTORE")

android {
    namespace = "com.svegliatag.alba"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.svegliatag.alba" // definitivo: non cambiarlo mai (cancellerebbe i dati)
        minSdk = 33 // Galaxy S23 e successivi (Android 13+)
        targetSdk = 35
        versionCode = System.getenv("GITHUB_RUN_NUMBER")?.toIntOrNull() ?: 1 // numero della build di GitHub Actions
        versionName = "1.0"
    }

    signingConfigs {
        if (chiave != null) {
            create("alba") {
                storeFile = file(chiave)
                storePassword = System.getenv("ALBA_KEYSTORE_PASSWORD")
                keyAlias = "alba"
                keyPassword = System.getenv("ALBA_KEYSTORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            if (chiave != null) signingConfig = signingConfigs.getByName("alba")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures { compose = true }

    // i suoni si leggono direttamente dall'APK: non vanno compressi
    androidResources { noCompress += "wav" }
}

kotlin {
    compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.12.01"))
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-core")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    testImplementation("junit:junit:4.13.2")
}
