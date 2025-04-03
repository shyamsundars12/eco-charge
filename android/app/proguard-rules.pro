# Preserve ProGuard Keep Annotations
-keep class proguard.annotation.Keep { *; }
-keep class proguard.annotation.KeepClassMembers { *; }
-keep class com.razorpay.** { *; }
-keepattributes *Annotation*
-dontwarn proguard.annotation.**
-dontwarn com.razorpay.**
-dontwarn java.lang.invoke.**
-keep class io.flutter.** { *; }
-keep class com.google.firebase.** { *; }
-keep class androidx.lifecycle.** { *; }
-keep class androidx.** { *; }
-keep class kotlin.** { *; }
-keepattributes *Annotation*
-keep class * { @Keep *; }
-keepclasseswithmembernames class * { @Keep *; }
# Keep Google Play Core classes
-keep class com.google.android.play.** { *; }
-dontwarn com.google.android.play.**
