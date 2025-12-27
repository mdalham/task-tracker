###########################################################
# Flutter & Dart
###########################################################
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

###########################################################
# SQFlite & SQLite
###########################################################
-keep class android.database.sqlite.** { *; }
-keep class sqflite.** { *; }

###########################################################
# Hive Database
###########################################################
-keep class *.Adapter { *; }
-keep class **.hive.** { *; }

###########################################################
# Google Mobile Ads SDK
###########################################################
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }

###########################################################
# Firebase & Google Sign-In
###########################################################
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

###########################################################
# Meta / Facebook Audience Network
###########################################################
-keep class com.facebook.** { *; }
-keep interface com.facebook.** { *; }
-dontwarn com.facebook.**

###########################################################
# Unity Ads
###########################################################
-keep class com.unity3d.ads.** { *; }
-keep interface com.unity3d.ads.** { *; }
-dontwarn com.unity3d.ads.**

###########################################################
# Miscellaneous
###########################################################
-dontwarn io.flutter.embedding.**
-dontwarn com.google.ads.**
-dontwarn com.google.android.gms.**
-dontwarn androidx.**
-dontwarn org.jetbrains.**
