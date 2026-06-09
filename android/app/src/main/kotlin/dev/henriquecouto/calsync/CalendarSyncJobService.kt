package dev.henriquecouto.calsync

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.provider.CalendarContract
import androidx.core.app.NotificationCompat
import dev.fluttercommunity.workmanager.WorkManagerWrapper
import dev.fluttercommunity.workmanager.pigeon.ExistingWorkPolicy
import dev.fluttercommunity.workmanager.pigeon.OneOffTaskRequest
import java.util.concurrent.TimeUnit

class CalendarSyncJobService : JobService() {
    override fun onStartJob(params: JobParameters?): Boolean {
        schedule(applicationContext)

        val request = OneOffTaskRequest(
            uniqueName = "calendar_sync_reactive",
            taskName = "syncTask",
            tag = "calendar_sync_reactive",
            initialDelaySeconds = 5,
            existingWorkPolicy = ExistingWorkPolicy.REPLACE,
        )
        WorkManagerWrapper(applicationContext).enqueueOneOffTask(request)

        Handler(Looper.getMainLooper()).postDelayed({
            showPendingNotification()
        }, 30_000L)

        return false
    }

    override fun onStopJob(params: JobParameters?): Boolean {
        return false
    }

    private fun showPendingNotification() {
        val prefs = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE
        )
        val summary = prefs.getString("flutter.pending_sync_notification", null) ?: return

        val manager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            "calendar_sync",
            "Calendar Sync",
            NotificationManager.IMPORTANCE_DEFAULT,
        )
        manager.createNotificationChannel(channel)

        val notification = NotificationCompat.Builder(applicationContext, "calendar_sync")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Calendar Sync")
            .setContentText(summary)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()

        manager.notify(1, notification)
        prefs.edit().remove("flutter.pending_sync_notification").apply()
    }

    companion object {
        fun schedule(context: Context) {
            val component = ComponentName(
                context.packageName,
                CalendarSyncJobService::class.java.name
            )
            val jobInfo = JobInfo.Builder(1, component)
                .addTriggerContentUri(
                    JobInfo.TriggerContentUri(
                        CalendarContract.Events.CONTENT_URI,
                        JobInfo.TriggerContentUri.FLAG_NOTIFY_FOR_DESCENDANTS
                    )
                )
                .setTriggerContentUpdateDelay(TimeUnit.SECONDS.toMillis(5))
                .build()

            val scheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
            scheduler.schedule(jobInfo)
        }
    }
}
