package com.example.calendar_sync

import android.database.ContentObserver
import android.os.Handler
import android.os.Looper
import android.provider.CalendarContract
import android.content.Context
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
    }

    object FlutterEngineHolder {
        var binaryMessenger: io.flutter.plugin.common.BinaryMessenger? = null
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
    }
}
