package com.example.calendar_sync

import android.app.NotificationChannel
import android.app.NotificationManager
import android.database.ContentObserver
import android.os.Handler
import android.os.Looper
import android.provider.CalendarContract
import android.content.Context
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel

class CalendarContentObserver(
    context: Context,
    handler: Handler,
) : ContentObserver(handler) {

    override fun onChange(selfChange: Boolean) {
        FlutterEngineHolder.binaryMessenger?.let {
            MethodChannel(
                it,
                "com.example.calendar_sync/calendar_observer",
            ).invokeMethod("onCalendarChanged", null)
        }
        Handler(Looper.getMainLooper()).postDelayed({
            showPendingNotification()
        }, 10_000L)
    }

    object FlutterEngineHolder {
        var binaryMessenger: io.flutter.plugin.common.BinaryMessenger? = null
        var appContext: Context? = null
    }

    companion object {
        fun register(context: Context) {
            val observer = CalendarContentObserver(
                context,
                Handler(Looper.getMainLooper()),
            )
            context.contentResolver.registerContentObserver(
                CalendarContract.Events.CONTENT_URI,
                true,
                observer,
            )
        }

        fun showPendingNotification() {
            val ctx = FlutterEngineHolder.appContext ?: return
            val prefs = ctx.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE
            )
            val summary = prefs.getString("flutter.pending_sync_notification", null) ?: return

            val manager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                "calendar_sync",
                "Calendar Sync",
                NotificationManager.IMPORTANCE_DEFAULT,
            )
            manager.createNotificationChannel(channel)

            val notification = NotificationCompat.Builder(ctx, "calendar_sync")
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
}
