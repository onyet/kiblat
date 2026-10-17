# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Gson / reflection used by some Play / Ads libraries
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Play Billing / in-app purchase
-keep class com.android.vending.billing.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Local notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Home widget
-keep class es.antonborri.home_widget.** { *; }
-keep class id.onyet.app.kiblat.KiblatWidgetProvider { *; }
-keep class id.onyet.app.kiblat.KiblatCountdownWidgetProvider { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelables
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
