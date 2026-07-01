import org.jetbrains.kotlin.gradle.dsl.JvmTarget

val sanitizedMainResDir = layout.buildDirectory.dir("generated/sanitizedRes/main")
val sanitizeMainRes by tasks.registering(Sync::class) {
    outputs.upToDateWhen { false }
    doFirst {
        delete(sanitizedMainResDir)
    }
    from("src/main/res") {
        include("**/*.xml")
    }
    into(sanitizedMainResDir)
}

plugins {
    id("com.android.application") version "9.2.1"
    id("org.jetbrains.kotlin.plugin.compose") version "2.3.0"
    id("org.jetbrains.kotlin.plugin.serialization") version "2.3.0"
}

android {
    namespace = "com.aipms"
    compileSdk = 35

    val platformBaseUrl = providers.gradleProperty("aipmsPlatformBaseUrl")
        .orElse(providers.environmentVariable("AIPMS_PLATFORM_BASE_URL"))
        .orElse("http://10.0.2.2:8000")
    val collectionBaseUrl = providers.gradleProperty("aipmsCollectionBaseUrl")
        .orElse(providers.environmentVariable("AIPMS_COLLECTION_BASE_URL"))
        .orElse("http://10.0.2.2:8200")
    val releaseStoreFile = providers.gradleProperty("aipmsReleaseStoreFile")
        .orElse(providers.environmentVariable("AIPMS_RELEASE_STORE_FILE"))
    val releaseStorePassword = providers.gradleProperty("aipmsReleaseStorePassword")
        .orElse(providers.environmentVariable("AIPMS_RELEASE_STORE_PASSWORD"))
    val releaseKeyAlias = providers.gradleProperty("aipmsReleaseKeyAlias")
        .orElse(providers.environmentVariable("AIPMS_RELEASE_KEY_ALIAS"))
    val releaseKeyPassword = providers.gradleProperty("aipmsReleaseKeyPassword")
        .orElse(providers.environmentVariable("AIPMS_RELEASE_KEY_PASSWORD"))
    val hasReleaseSigning = releaseStoreFile.isPresent &&
        releaseStorePassword.isPresent &&
        releaseKeyAlias.isPresent &&
        releaseKeyPassword.isPresent

    defaultConfig {
        applicationId = "com.aipms"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"
        buildConfigField("String", "AIPMS_PLATFORM_BASE_URL", "\"${platformBaseUrl.get()}\"")
        buildConfigField("String", "AIPMS_COLLECTION_BASE_URL", "\"${collectionBaseUrl.get()}\"")
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFile.get())
                storePassword = releaseStorePassword.get()
                keyAlias = releaseKeyAlias.get()
                keyPassword = releaseKeyPassword.get()
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        buildConfig = true
        compose = true
    }

    sourceSets {
        getByName("main") {
            res.setSrcDirs(listOf(sanitizedMainResDir))
        }
    }
}

tasks.named("preBuild") {
    dependsOn(sanitizeMainRes)
}

tasks.configureEach {
    if (name.contains("Resources") || name == "preBuild") {
        doFirst {
            delete(
                layout.buildDirectory.asFileTree.matching {
                    include("**/desktop.ini")
                }
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")
    implementation("androidx.activity:activity-compose:1.9.3")

    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.9.0")
    implementation("io.ktor:ktor-client-android:3.5.0")
    implementation("io.ktor:ktor-client-content-negotiation:3.5.0")
    implementation("io.ktor:ktor-serialization-kotlinx-json:3.5.0")
}
