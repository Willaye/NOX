// Top-level build file for Nox Android App
plugins {
    // AGP 9 ships built-in Kotlin support, so org.jetbrains.kotlin.android is not applied.
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.4.0" apply false
    id("com.google.dagger.hilt.android") version "2.60.1" apply false
    id("com.google.devtools.ksp") version "2.3.12" apply false
}
