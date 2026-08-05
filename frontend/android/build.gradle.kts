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
subprojects {
    project.evaluationDependsOn(":app")
}

// tflite_flutter's own build.gradle sets its Java compileOptions to 11 but
// leaves Kotlin unset, so Kotlin defaults to the build's JDK (17) and
// assembleRelease fails with "Inconsistent JVM Target Compatibility" between
// compileReleaseJavaWithJavac (11) and compileReleaseKotlin (17).
//
// Scoped to just that plugin, and only touching the Kotlin side: every other
// module already builds fine on its own, and forcing compileOptions
// (Java source/targetCompatibility) here throws "sourceCompatibility has
// been finalized" for modules whose AGP config already locked that property.
subprojects {
    if (project.name != "tflite_flutter") return@subprojects
    plugins.withId("org.jetbrains.kotlin.android") {
        tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
