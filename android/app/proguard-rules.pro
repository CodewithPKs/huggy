##############################
# 🧱 Firebase and JSON
##############################
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

-keepclassmembers class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Keep Firebase model classes
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

##############################
# 🧱 Custom app classes (FIXED PACKAGE NAME)
##############################
-keep class com.todo.todo.** { *; }

##############################
# 🧱 Native / JNI methods
##############################
-keepclasseswithmembernames class * {
    native <methods>;
}

##############################
# 🧱 Flutter Engine and Plugins
##############################
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.app.** { *; }
-dontwarn io.flutter.**

##############################
# 🧱 Firebase / Google Services
##############################
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

##############################
# 🧱 Agora RTC SDK (CRITICAL FOR VIDEO CALLS)
##############################
-keep class io.agora.**{*;}
-keep class io.agora.rtc.** { *; }
-keep class io.agora.rtc2.** { *; }
-dontwarn io.agora.**

# Keep Agora native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Agora callback interfaces
-keep interface io.agora.** { *; }

##############################
# 🧱 Speech to Text Plugin
##############################
-keep class org.json.** { *; }
-keep class com.google.android.gms.speech.** { *; }

##############################
# 🧱 Image & File Pickers
##############################
-keep class androidx.core.content.** { *; }
-keep class androidx.documentfile.provider.** { *; }

##############################
# 🧱 Local Auth / Biometric
##############################
-keep class androidx.biometric.** { *; }
-keep class androidx.fragment.app.** { *; }

##############################
# 🧱 Play Core / SplitCompat
##############################
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

##############################
# 🧱 Application / Entry points
##############################
-keep class * extends android.app.Application
-keep class * extends android.app.Service
-keep class * extends android.content.BroadcastReceiver
-keep class * extends android.content.ContentProvider

-keepclassmembers class * {
    public <init>(android.content.Context);
}

##############################
# 🧱 Kotlin Reflection
##############################
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

##############################
# 🧱 AndroidX Core
##############################
-keep class androidx.core.** { *; }
-keep class androidx.lifecycle.** { *; }
-dontwarn androidx.**

##############################
# 🧱 Remove Logging (Optional - saves space)
##############################
# Uncomment to remove all Log calls
# -assumenosideeffects class android.util.Log {
#     public static *** d(...);
#     public static *** v(...);
#     public static *** i(...);
# }