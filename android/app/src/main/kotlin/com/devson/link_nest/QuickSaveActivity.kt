package com.devson.link_nest

import android.content.Context
import android.content.DialogInterface
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.edit

class QuickSaveActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_quick_save)

        val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)

        val urlTextView: TextView = findViewById(R.id.urlTextView)
        val saveButton: Button = findViewById(R.id.saveButton)

        urlTextView.text = sharedText

        saveButton.setOnClickListener {
            if (sharedText != null) {
                saveLinkToPrefs(sharedText)
                showPostSaveDialog()
            } else {
                finish()
            }
        }
    }

    private fun saveLinkToPrefs(url: String) {
        val sharedPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val key = "flutter.quick_save_urls"

        var existingUrls: MutableSet<String>
        try {
            // This is the correct way to read
            existingUrls = sharedPrefs.getStringSet(key, mutableSetOf())?.toMutableSet() ?: mutableSetOf()
        } catch (e: ClassCastException) {
            // This catches the crash if the old data was a String
            // We clear the bad data and start with a fresh set
            sharedPrefs.edit { remove(key) }
            existingUrls = mutableSetOf()
        }

        existingUrls.add(url)

        sharedPrefs.edit {
            putStringSet(key, existingUrls)
        }
    }

    private fun showPostSaveDialog() {
        val builder = AlertDialog.Builder(this)
        builder.setTitle("Link Saved!")
        builder.setMessage("Would you like to view the saved links now?")

        builder.setPositiveButton("View") { dialog: DialogInterface, _: Int ->
            val intent = Intent(this, MainActivity::class.java).apply {
                putExtra("redirect_to_links", true)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            startActivity(intent)
            dialog.dismiss()
            finish()
        }

        builder.setNegativeButton("Later") { dialog: DialogInterface, _: Int ->
            dialog.dismiss()
            finish()
        }

        val dialog: AlertDialog = builder.create()
        dialog.show()
    }
}