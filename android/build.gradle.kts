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

// Plugins pinned below compileSdk 36 fail AAR metadata checks (e.g. older lifecycle AARs).
// Prefer withPlugin so we never call afterEvaluate on an already-evaluated project
// (federated file_picker / share_plus can reorder evaluation vs evaluationDependsOn).
subprojects {
    fun bumpLibraryCompileSdk() {
        extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)?.apply {
            if ((compileSdk ?: 0) < 37) {
                compileSdk = 37
            }
        }
    }
    pluginManager.withPlugin("com.android.library") {
        bumpLibraryCompileSdk()
    }
    if (!state.executed) {
        afterEvaluate { bumpLibraryCompileSdk() }
    } else {
        bumpLibraryCompileSdk()
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
