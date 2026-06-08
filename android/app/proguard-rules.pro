# WorkManager Workers — keep class names for deserialization
-keep class dev.henriquecouto.calsync.ObserverRegistrationWorker { *; }
-keep class dev.henriquecouto.calsync.CalendarContentObserver { *; }
-keep class dev.henriquecouto.calsync.MainActivity { *; }

# WorkManager
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**

# NotificationCompat
-keep class androidx.core.app.NotificationCompat { *; }
