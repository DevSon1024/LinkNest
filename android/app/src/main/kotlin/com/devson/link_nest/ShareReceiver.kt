package com.devson.link_nest

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * A BroadcastReceiver that listens for share intents (ACTION_SEND).
 * When it receives a share intent with plain text, it starts the SaveLinkService
 * to handle saving the link in the background.
 */
class ShareReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Check if the intent is a share intent with plain text
        if (intent.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            // Extract the shared text (URL) from the intent
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)

            // If the shared text is not null or empty, start the SaveLinkService
            if (sharedText != null && sharedText.isNotEmpty()) {
                val serviceIntent = Intent(context, SaveLinkService::class.java).apply {
                    putExtra(Intent.EXTRA_TEXT, sharedText)
                }
                // Start the service to save the link
                context.startService(serviceIntent)
            }
        }
    }
}
