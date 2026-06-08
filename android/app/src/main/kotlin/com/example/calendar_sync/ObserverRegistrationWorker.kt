package com.example.calendar_sync

import android.content.Context
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
        return Result.success()
    }
}
