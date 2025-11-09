##############################
# 🧱 Firebase and JSON
##############################
-keepattributes Signature
-keepattributes *Annotation*

-keepclassmembers class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

##############################
# 🧱 Custom app classes
##############################
-keep class com.example.dual_access_app.** { *; }

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

##############################
# 🧱 Firebase / Google Services
##############################
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

##############################
# 🧱 Play Core / SplitCompat
##############################
# Keep all Play Core classes but avoid SplitInstall duplicates
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.common.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }


##############################
# 🧱 Application / Entry points
##############################
-keep class * extends android.app.Application
-keepclassmembers class * {
    public <init>(android.content.Context);
}
