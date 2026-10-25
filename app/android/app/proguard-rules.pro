# ML Kit: ZapWise uses only the Latin text recognizer; the other scripts are optional add-ons
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# TensorFlow Lite: keep the interpreter classes; the GPU delegate is optional
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.gpu.**

# ML Kit and Google Play services look classes up by reflection; R8 must not strip or rename them
# (without these the release build fails with "getClass() on a null object reference" when it reads a photo)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_** { *; }
-keep class com.google.android.gms.internal.mlkit_common.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.firebase.components.** { *; }
-keep class com.google_mlkit_** { *; }
-keep class com.google_mlkit_commons.** { *; }
