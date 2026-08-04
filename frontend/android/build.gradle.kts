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

// tflite_flutter's own android/build.gradle pins Java compileOptions to
// VERSION_11 but doesn't set a matching Kotlin jvmTarget, so Kotlin
// defaults to whatever JDK Gradle itself runs under (21 here) — Gradle
// then fails the whole build with "Inconsistent JVM Target Compatibility
// Between Java and Kotlin Tasks". Fix only this one module: touching
// compileOptions/jvmTarget broadly across all subprojects hits Gradle
// property-finalization errors on other plugins (e.g.
// camera_android_camerax) that manage those properties differently.
// gradle.projectsEvaluated runs once everything is evaluated, avoiding
// the evaluationDependsOn ordering issues afterEvaluate ran into here.
gradle.projectsEvaluated {
    project(":tflite_flutter") {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
