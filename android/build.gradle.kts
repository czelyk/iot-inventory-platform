allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// --- FIX: Define 'flutter' properties for plugins ---
val flutterVersion = mapOf(
    "compileSdkVersion" to 34,
    "minSdkVersion" to 23, // Updated to 23 for Firebase Auth compatibility
    "targetSdkVersion" to 34
)
extra.set("flutter", flutterVersion)

// --- FIX: Force compileSdk for all subprojects ---
subprojects {
    afterEvaluate {
        if ((plugins.hasPlugin("android") || plugins.hasPlugin("com.android.application") || plugins.hasPlugin("com.android.library"))) {
            val android = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            android?.apply {
                if (compileSdkVersion == null || (compileSdkVersion as? String)?.toIntOrNull() != 34) {
                    compileSdkVersion(34)
                }
                defaultConfig {
                    minSdkVersion(23) // Updated to 23
                    targetSdkVersion(34)
                }
            }
        }
        
        if (extensions.findByName("flutter") == null) {
            extensions.add("flutter", flutterVersion)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
