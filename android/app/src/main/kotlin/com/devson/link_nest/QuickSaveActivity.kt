package com.devson.link_nest

import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch

class QuickSaveActivity : AppCompatActivity() {

    private lateinit var urlTextView: TextView
    private lateinit var saveButton: Button
    private lateinit var sharedUrl: String

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_quick_save)

        // Make this activity appear as a dialog
        setFinishOnTouchOutside(true)

        initViews()
        handleSharedIntent()
    }

    private fun initViews() {
        urlTextView = findViewById(R.id.urlTextView)
        saveButton = findViewById(R.id.saveButton)

        saveButton.setOnClickListener {
            saveLink()
        }
    }

    private fun handleSharedIntent() {
        val receivedAction = intent.action
        val receivedType = intent.type

        if (receivedAction == Intent.ACTION_SEND && receivedType == "text/plain") {
            sharedUrl = intent.getStringExtra(Intent.EXTRA_TEXT) ?: ""
            if (sharedUrl.isNotEmpty()) {
                displayUrl(sharedUrl)
            } else {
                finish()
            }
        } else {
            finish()
        }
    }

    private fun displayUrl(url: String) {
        // Extract and display the first URL from the shared text
        val urls = extractUrlsFromText(url)
        if (urls.isNotEmpty()) {
            urlTextView.text = urls.first()
            sharedUrl = urls.first()
        } else {
            urlTextView.text = url
        }
    }

    private fun saveLink() {
        lifecycleScope.launch {
            try {
                // Start the background service to save the link
                val serviceIntent = Intent(this@QuickSaveActivity, SaveLinkService::class.java).apply {
                    putExtra("url", sharedUrl)
                }
                startService(serviceIntent)

                Toast.makeText(this@QuickSaveActivity, "Link saved to LinkNest!", Toast.LENGTH_SHORT).show()

                // Optional: Open the main app and navigate to links page
                val mainIntent = Intent(this@QuickSaveActivity, MainActivity::class.java).apply {
                    putExtra("redirect_to_links", true)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                startActivity(mainIntent)

                finish()
            } catch (e: Exception) {
                Toast.makeText(this@QuickSaveActivity, "Error saving link", Toast.LENGTH_SHORT).show()
                finish()
            }
        }
    }

    private fun extractUrlsFromText(text: String): List<String> {
        val urlRegex = Regex(
            """(?:(?:https|http)://|www\.)(?:[-a-zA-Z0-9@:%._+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b)(?:[-a-zA-Z0-9()@:%_+.~#?&//=]*)"""
        )
        return urlRegex.findAll(text).map { it.value }.toList()
    }
}