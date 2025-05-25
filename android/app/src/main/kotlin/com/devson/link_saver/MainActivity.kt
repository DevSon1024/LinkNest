package com.devson.link_saver

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.Bundle
import android.util.Log

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.devson.link_saver/share"
    private val TAG = "MainActivity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedData" -> {
                    val sharedData = getSharedData()
                    Log.d(TAG, "Flutter requested shared data: $sharedData")
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
        Log.d(TAG, "onCreate called")
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        Log.d(TAG, "onNewIntent called")
        handleIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume called")
        // Re-check intent when app resumes
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        Log.d(TAG, "handleIntent called with action: ${intent?.action}")

        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            Log.d(TAG, "Received shared text: $sharedText")

            if (sharedText != null && sharedText.isNotEmpty()) {
                // Store the shared text with a unique timestamp to avoid conflicts
                val currentTime = System.currentTimeMillis()
                val prefs = getSharedPreferences("shared_data", MODE_PRIVATE)

                // Check if this is a duplicate by comparing with recent entries
                val lastSharedText = prefs.getString("shared_text", null)
                val lastSharedTime = prefs.getLong("shared_time", 0)

                // Only store if it's different text or enough time has passed (2 seconds)
                if (lastSharedText != sharedText || (currentTime - lastSharedTime) > 2000) {
                    Log.d(TAG, "Storing new shared text: $sharedText")
                    prefs.edit()
                        .putString("shared_text", sharedText)
                        .putLong("shared_time", currentTime)
                        .putBoolean("has_new_data", true)
                        .apply()
                } else {
                    Log.d(TAG, "Duplicate shared text ignored")
                }
            }
        }
    }

    private fun getSharedData(): String? {
        val prefs = getSharedPreferences("shared_data", MODE_PRIVATE)
        val hasNewData = prefs.getBoolean("has_new_data", false)

        if (!hasNewData) {
            return null
        }

        val sharedText = prefs.getString("shared_text", null)
        Log.d(TAG, "Returning shared data: $sharedText")

        // Mark as read but don't clear immediately
        // This allows Flutter to get the data multiple times if needed
        prefs.edit()
            .putBoolean("has_new_data", false)
            .apply()

        return sharedText
    }
}