package com.devson.link_nest

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.Bundle
import android.util.Log

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.devson.link_nest/share"
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

    private fun handleIntent(intent: Intent?) {
        Log.d(TAG, "handleIntent called with action: ${intent?.action}")

        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            Log.d(TAG, "Received shared text: $sharedText")
            if (sharedText != null && sharedText.isNotEmpty()) {
                // Notify Flutter via MethodChannel
                invokeFlutterMethod(sharedText)
            }
        }
    }

    private fun invokeFlutterMethod(sharedText: String) {
        val channel = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL)
        channel.invokeMethod("onSharedData", sharedText)
    }

    private fun getSharedData(): String? {
        return null // No longer needed as we handle directly via MethodChannel
    }
}