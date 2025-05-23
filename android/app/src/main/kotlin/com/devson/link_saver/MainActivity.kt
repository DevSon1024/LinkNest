package com.devson.link_saver

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.Bundle

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.devson.link_saver/share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedData" -> {
                    val sharedData = getSharedData()
                    result.success(sharedData)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (sharedText != null) {
                // Store the shared text for Flutter to retrieve
                getSharedPreferences("shared_data", MODE_PRIVATE)
                    .edit()
                    .putString("shared_text", sharedText)
                    .putLong("shared_time", System.currentTimeMillis())
                    .apply()
            }
        }
    }

    private fun getSharedData(): String? {
        val prefs = getSharedPreferences("shared_data", MODE_PRIVATE)
        val sharedText = prefs.getString("shared_text", null)

        // Clear the shared data after reading
        if (sharedText != null) {
            prefs.edit().remove("shared_text").remove("shared_time").apply()
        }

        return sharedText
    }
}