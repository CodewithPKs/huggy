# Firebase
-keepattributes Signature
-keepattributes *Annotation*

# JSON serialization
-keepclassmembers class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Preserve custom classes
-keep class com.example.dual_access_app.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Flutter classes
-keep class io.flutter.** { *; }
-keep class com.google.firebase.** { *; }
# Keep Flutter and Play Core classes if R8 is shrinking them accidentally
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-keep class com.google.android.play.core.** { *; }
