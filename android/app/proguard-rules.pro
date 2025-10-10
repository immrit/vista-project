# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Audio Waveforms
-keep class com.taurus.audio_waveforms.** { *; }
-keep class com.taurus.audio_waveforms.AudioWaveformsPlugin { *; }
-keep class com.taurus.audio_waveforms.RecorderController { *; }
-keep class com.taurus.audio_waveforms.PlayerController { *; }

# Just Audio
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.just_audio.JustAudioPlugin { *; }
-keep class com.ryanheise.just_audio.AudioPlayer { *; }

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }
-keep class com.baseflow.permissionhandler.PermissionHandlerPlugin { *; }

# Audio Players
-keep class xyz.luan.audioplayers.** { *; }
-keep class xyz.luan.audioplayers.AudioplayersPlugin { *; }

# Path Provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# Keep all native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep all classes with @Keep annotation
-keep @androidx.annotation.Keep class * { *; }

# Keep all classes in your package
-keep class ir.coffevista.vista.** { *; }

# Keep all audio-related classes
-keep class * extends android.media.MediaPlayer { *; }
-keep class * extends android.media.AudioRecord { *; }
-keep class * extends android.media.AudioTrack { *; }

# Keep reflection-based classes
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Keep enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable classes
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ----- Google Play Core / Deferred Components (Flutter embedding references) -----
-keep class com.google.android.play.core.** { *; }
-keep interface com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Keep Flutter deferred components managers
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# AWS SDK ProGuard rules
-keep class software.amazon.awssdk.** { *; }
-keep class software.amazon.awssdk.services.s3.** { *; }
-keep class software.amazon.awssdk.core.** { *; }
-keep class software.amazon.awssdk.auth.** { *; }
-keep class software.amazon.awssdk.regions.** { *; }
-keep class software.amazon.awssdk.http.** { *; }
-keep class software.amazon.awssdk.protocols.** { *; }
-keep class software.amazon.eventstream.** { *; }
-keep class com.amazonaws.** { *; }
-keep class com.amazonaws.services.s3.** { *; }
-keep class com.amazonaws.auth.** { *; }
-keep class com.amazonaws.regions.** { *; }
-keep class com.amazonaws.http.** { *; }
-keep class com.amazonaws.util.** { *; }
-keep class com.amazonaws.internal.** { *; }
-keep class com.amazonaws.metrics.** { *; }
-keep class org.apache.commons.logging.** { *; }
-keep class org.apache.http.** { *; }
-keep class org.joda.time.** { *; }
-keep class com.fasterxml.jackson.** { *; }
-keep class aws.smithy.kotlin.** { *; }
-keep class aws.sdk.kotlin.** { *; }
-keep class aws.sdk.kotlin.services.s3.** { *; }
-keep class aws.sdk.kotlin.core.** { *; }
-keep class aws.sdk.kotlin.auth.** { *; }
-dontwarn software.amazon.awssdk.**
-dontwarn com.amazonaws.**
-dontwarn org.apache.commons.logging.**
-dontwarn org.apache.http.**
-dontwarn org.joda.time.**
-dontwarn com.fasterxml.jackson.**
-dontwarn aws.smithy.kotlin.**
-dontwarn aws.sdk.kotlin.**
-dontwarn aws.sdk.kotlin.services.s3.**

# Flutter Image Compress ProGuard rules
-keep class com.fluttercandies.** { *; }
-keep class top.kikt.** { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class androidx.exifinterface.** { *; }
-keep class android.graphics.** { *; }
-dontwarn com.fluttercandies.**
-dontwarn top.kikt.**
-dontwarn io.flutter.plugins.imagepicker.**
-dontwarn androidx.exifinterface.**
-dontwarn android.graphics.**

# File handling and path operations
-keep class java.io.** { *; }
-keep class java.nio.** { *; }
-keepattributes *FileName*,*FileDescriptor*
