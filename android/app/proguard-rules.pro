# WorkManager Workers — keep class names for deserialization
-keep class dev.henriquecouto.calsync.ObserverRegistrationWorker { *; }
-keep class dev.henriquecouto.calsync.CalendarContentObserver { *; }
-keep class dev.henriquecouto.calsync.MainActivity { *; }

# WorkManager
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**

# NotificationCompat
-keep class androidx.core.app.NotificationCompat { *; }

# device_calendar plugin — Gson serialization, keep field names
-keep class com.builttoroam.devicecalendar.models.** { *; }
-keep class com.builttoroam.devicecalendar.common.** { *; }
-keep class com.builttoroam.devicecalendar.** { *; }

# Keep Gson
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
