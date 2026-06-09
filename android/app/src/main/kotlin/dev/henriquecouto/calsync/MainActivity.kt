package dev.henriquecouto.calsync

import android.os.Bundle
import androidx.work.WorkManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        CalendarSyncJobService.schedule(applicationContext)
        WorkManager.getInstance(applicationContext)
            .cancelUniqueWork("observer_registration")
    }
}
