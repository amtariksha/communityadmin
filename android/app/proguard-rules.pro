# ── Flutter / Dart ──────────────────────────────────────────────────────
# Keep Flutter engine + platform-channel classes.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── Firebase ────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ── Google Play Services ────────────────────────────────────────────────
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ── Google Play Core (deferred components) ──────────────────────────────
-dontwarn com.google.android.play.core.**

# ── Suppress common warnings ───────────────────────────────────────────
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
