package dev.henriquecouto.calsync

import android.accounts.AccountManager
import android.content.ContentResolver
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.os.Bundle
import android.provider.CalendarContract
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SoftDeletePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var appContext: Context? = null

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "dev.henriquecouto.calsync/calendar")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        appContext = null
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "softDeleteEvent" -> {
                val raw = call.argument<Number>("eventId")
                val eventId = raw?.toLong()
                if (eventId == null) {
                    result.error("INVALID_ARG", "eventId is required", null)
                    return
                }
                val ctx = appContext ?: run {
                    result.error("NO_CONTEXT", "Plugin not attached", null)
                    return
                }
                try {
                    val eventIdStr = eventId.toString()
                    val uri = buildSyncAdapterUri(ctx, eventIdStr)
                    val values = ContentValues().apply {
                        put(CalendarContract.Events.DELETED, 1)
                        put(CalendarContract.Events.DIRTY, 1)
                    }
                    ctx.contentResolver.update(
                        uri, values,
                        "${CalendarContract.Events._ID} = ?",
                        arrayOf(eventIdStr)
                    )

                    val am = AccountManager.get(ctx)
                    val accounts = am.getAccounts()
                    for (account in accounts) {
                        try {
                            ContentResolver.requestSync(
                                account,
                                CalendarContract.AUTHORITY,
                                Bundle()
                            )
                        } catch (_: Exception) {}
                    }

                    result.success(true)
                } catch (e: Exception) {
                    result.error("DELETE_ERROR", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun buildSyncAdapterUri(ctx: Context, eventIdStr: String): android.net.Uri {
        val calendarId = ctx.contentResolver.query(
            CalendarContract.Events.CONTENT_URI,
            arrayOf(CalendarContract.Events.CALENDAR_ID),
            "${CalendarContract.Events._ID} = ?",
            arrayOf(eventIdStr),
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                cursor.getString(cursor.getColumnIndexOrThrow(CalendarContract.Events.CALENDAR_ID))
            } else null
        } ?: return ContentUris.withAppendedId(
            CalendarContract.Events.CONTENT_URI, eventIdStr.toLong()
        )

        val account = readCalendarAccount(ctx, calendarId)
            ?: return ContentUris.withAppendedId(
                CalendarContract.Events.CONTENT_URI, eventIdStr.toLong()
            )

        return CalendarContract.Events.CONTENT_URI.buildUpon()
            .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
            .appendQueryParameter(CalendarContract.Events.ACCOUNT_NAME, account.first)
            .appendQueryParameter(CalendarContract.Events.ACCOUNT_TYPE, account.second)
            .build()
    }

    private fun readCalendarAccount(
        ctx: Context,
        calendarId: String?
    ): Pair<String, String>? {
        if (calendarId == null) return null
        return ctx.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            arrayOf(
                CalendarContract.Calendars.ACCOUNT_NAME,
                CalendarContract.Calendars.ACCOUNT_TYPE
            ),
            "${CalendarContract.Calendars._ID} = ?",
            arrayOf(calendarId),
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val name = cursor.getString(0)
                val type = cursor.getString(1)
                Pair(name, type)
            } else null
        }
    }
}
