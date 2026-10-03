# Proguard / R8 rules for Musify

# Flutter Wrapper & Play Store Deferred Components
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn com.google.android.play.core.**

# Just Audio
-keep class com.ryanheise.just_audio.** { *; }
-dontwarn com.ryanheise.just_audio.**

# Audio Service
-keep class com.ryanheise.audioservice.** { *; }
-dontwarn com.ryanheise.audioservice.**

# Android Audio Effects (Equalizer, LoudnessEnhancer)
-keep class android.media.audiofx.** { *; }

# ExoPlayer / Media3
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**
-keep class androidx.media.** { *; }
-dontwarn androidx.media.**

# SQLite / Drift
-keep class org.sqlite.** { *; }
-dontwarn org.sqlite.**
-keep class io.requery.android.database.sqlite.** { *; }
-dontwarn io.requery.android.database.sqlite.**

# Awesome Notifications
-keep class me.carda.awesome_notifications.** { *; }
-dontwarn me.carda.awesome_notifications.**

# General library annotations
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn com.google.errorprone.annotations.**
