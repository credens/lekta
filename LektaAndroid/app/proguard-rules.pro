# Lekta ProGuard rules
-keepattributes Signature
-keepattributes *Annotation*

# Gson
-keep class com.lekta.app.models.** { *; }
-keepclassmembers class com.lekta.app.models.** { *; }
-keep class com.lekta.app.viewmodels.CajaViewModel$CajaSession { *; }

# Retrofit
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
