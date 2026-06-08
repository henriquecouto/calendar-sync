package com.example.calendar_sync

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import androidx.core.app.NotificationCompat
import androidx.work.Worker
import androidx.work.WorkerParameters

class ObserverRegistrationWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {

    override fun doWork(): Result {
        try {
            CalendarContentObserver.register(applicationContext)
        } catch (_: SecurityException) {}

        showPendingNotification()

        return Result.success()
    }

    private fun showPendingNotification() {
        val prefs = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE
        )
        val summary = prefs.getString("flutter.pending_sync_notification", null) ?: return

        val manager = applicationContext.getSystemService(
            Context.NOTIFICATION_SERVICE
        ) as NotificationManager

        val channel = NotificationChannel(
            "calendar_sync",
            "Calendar Sync",
            NotificationManager.IMPORTANCE_DEFAULT,
        )
        manager.createNotificationChannel(channel)

        val notification = NotificationCompat.Builder(applicationContext, "calendar_sync")
            .setSmallIcon(android.R.drawable.ic_popup_sync)
            .setContentTitle("Calendar Sync")
            .setContentText(summary)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()

        manager.notify(1, notification)

        prefs.edit().remove("flutter.pending_sync_notification").apply()
    }
}
