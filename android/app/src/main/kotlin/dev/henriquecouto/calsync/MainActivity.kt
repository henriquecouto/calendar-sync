package dev.henriquecouto.calsync

import android.os.Bundle
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.android.FlutterActivity
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            CalendarContentObserver.register(applicationContext)
        } catch (_: SecurityException) {}
        CalendarContentObserver.FlutterEngineHolder.appContext = applicationContext
        flutterEngine?.let { engine ->
            CalendarContentObserver.FlutterEngineHolder.binaryMessenger =
                engine.dartExecutor.binaryMessenger
        }
        scheduleObserverRegistration()
    }

    private fun scheduleObserverRegistration() {
        val request = PeriodicWorkRequestBuilder<ObserverRegistrationWorker>(
            15, TimeUnit.MINUTES,
        ).build()

        WorkManager.getInstance(applicationContext)
            .enqueueUniquePeriodicWork(
                "observer_registration",
                ExistingPeriodicWorkPolicy.KEEP,
                request,
            )
    }

    override fun cleanUpFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        CalendarContentObserver.FlutterEngineHolder.binaryMessenger = null
    }
}
