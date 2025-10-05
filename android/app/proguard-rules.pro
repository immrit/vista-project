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
