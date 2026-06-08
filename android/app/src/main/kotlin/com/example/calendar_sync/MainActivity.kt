package com.example.calendar_sync

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        CalendarContentObserver.register(applicationContext)
        flutterEngine?.let { engine ->
            CalendarContentObserver.FlutterEngineHolder.binaryMessenger =
                engine.dartExecutor.binaryMessenger
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        CalendarContentObserver.FlutterEngineHolder.binaryMessenger = null
    }
}
