# Proguard rules for Attendance App (ATS)

# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Mobile Scanner
-keep class dev.steenbakker.mobile_scanner.** { *; }
-dontwarn dev.steenbakker.mobile_scanner.**

# Google ML Kit Barcode Scanning
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.libraries.barhopper.** { *; }
-keep class com.google.photos.** { *; }

# Keep all ComponentRegistrar classes with empty constructors for ML Kit DI / Reflection
-keep class * implements com.google.firebase.components.ComponentRegistrar {
    public <init>();
    public *;
}
-keep class * implements com.google.android.gms.common.internal.** {
    public <init>();
    public *;
}
-keep class com.google.mlkit.common.internal.** {
    public <init>();
    public *;
}
-keep class com.google.mlkit.vision.barcode.internal.** {
    public <init>();
    public *;
}
-keep class com.google.mlkit.vision.common.internal.** {
    public <init>();
    public *;
}

# AndroidX Camera / CameraX
-keep class androidx.camera.** { *; }
-keep interface androidx.camera.** { *; }
-dontwarn androidx.camera.**

# AndroidX Biometrics & Security
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# Enums
-keepclassmembers class * extends java.lang.Enum {
    <fields>;
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
