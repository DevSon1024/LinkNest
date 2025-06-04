package com.devson.link_saver

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import androidx.core.content.edit
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class BackgroundShareService : Service() {
    private val channel = "com.devson.link_saver/share"
    private val tag = "BackgroundShareService"
    private lateinit var flutterEngine: FlutterEngine

    override fun onCreate() {
        super.onCreate()
        Log.d(tag, "BackgroundShareService created")
        flutterEngine = FlutterEngine(this)
        flutterEngine.dartExecutor.binaryMessenger.let { messenger ->
            MethodChannel(messenger, channel).setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveSharedLink" -> {
                        val url = call.argument<String>("url")
                        Log.d(tag, "Received URL to save: $url")
                        if (url != null) {
                            saveSharedLink(url)
                            result.success(true)
                        } else {
                            result.error("NO_URL", "No URL provided", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(tag, "onStartCommand called with action: ${intent?.action}")

        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            Log.d(tag, "Received shared text: $sharedText")

            if (sharedText != null && sharedText.isNotEmpty()) {
                saveSharedLink(sharedText)
            }
        }

        return START_NOT_STICKY
    }

    private fun saveSharedLink(url: String) {
        val prefs = getSharedPreferences("shared_data", MODE_PRIVATE)
        val currentTime = System.currentTimeMillis()
        val lastSharedText = prefs.getString("shared_text", null)
        val lastSharedTime = prefs.getLong("shared_time", 0)

        if (lastSharedText != url || (currentTime - lastSharedTime) > 2000) {
            Log.d(tag, "Storing new shared link: $url")
            prefs.edit {
                putString("shared_text", url)
                putLong("shared_time", currentTime)
                putBoolean("has_new_data", true)
            }

            // Send notification
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
                .invokeMethod("saveSharedLink", mapOf("url" to url))
        } else {
            Log.d(tag, "Duplicate shared link ignored: $url")
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        flutterEngine.destroy()
        Log.d(tag, "BackgroundShareService destroyed")
    }
}