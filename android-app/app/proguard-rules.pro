# Retrofit
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.nox.app.data.model.** { *; }
-keep class retrofit2.** { *; }
-keepclasseswithmembers class * { @retrofit2.http.* <methods>; }

# Gson
-keep class com.google.gson.** { *; }
-keepattributes EnclosingMethod

# Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
