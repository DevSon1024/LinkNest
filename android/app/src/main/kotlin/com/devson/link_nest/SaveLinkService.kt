package com.devson.link_nest

import android.app.IntentService
import android.content.Intent
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.net.URI


class SaveLinkService : IntentService("SaveLinkService") {

    private val serviceScope = CoroutineScope(Dispatchers.IO)

    override fun onHandleIntent(intent: Intent?) {
        val url = intent?.getStringExtra("url")
        if (url != null) {
            serviceScope.launch {
                saveLinkToDatabase(url)
            }
        }
    }

    private suspend fun saveLinkToDatabase(url: String) {
        try {
            Log.d("SaveLinkService", "Saving link: $url")

            // Create a simple database helper instance
            val dbHelper = DatabaseHelper()

            // Check if link already exists
            if (dbHelper.linkExists(url)) {
                Log.d("SaveLinkService", "Link already exists: $url")
                return
            }

            // Extract domain from URL
            val domain = try {
                URI(url).host?.removePrefix("www.") ?: ""
            } catch (e: Exception) {
                ""
            }

            // Create link model with pending status for background metadata fetching
            val linkModel = LinkModel(
                url = url,
                title = domain.ifEmpty { "Untitled" },
                description = "Loading...",
                imageUrl = "",
                createdAt = DateTime.now(),
                domain = domain,
                tags = emptyList(),
                notes = null,
                status = MetadataStatus.pending
            )

            // Insert link into database
            dbHelper.insertLink(linkModel)

            Log.d("SaveLinkService", "Link saved successfully: $url")

        } catch (e: Exception) {
            Log.e("SaveLinkService", "Error saving link: $url", e)
        }
    }
}