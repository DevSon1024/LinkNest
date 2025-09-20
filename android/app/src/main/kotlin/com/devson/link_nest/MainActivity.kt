package com.devson.link_nest

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.Bundle
import android.util.Log

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.devson.link_nest/share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { _, _ -> }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val channel = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL)

        // Handle the redirect from the "View" button in the Quick Save dialog
        if (intent?.getBooleanExtra("redirect_to_links", false) == true) {
            channel.invokeMethod("navigateToLinksPage", null)
            intent.removeExtra("redirect_to_links") // Consume the extra
        }
        // Handle a regular share intent
        else if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (sharedText != null) {
                channel.invokeMethod("handleSharedLink", sharedText)
            }
        }
    }
}