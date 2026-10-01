package org.modernislamicfoundation.mif_app

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val createCsvRequest = 6401
    private var pendingExport: MethodChannel.Result? = null
    private var csvContent: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mif/finance-export")
            .setMethodCallHandler { call, result ->
                if (call.method != "saveCsv") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingExport != null) {
                    result.error("BUSY", "Finish the current export first.", null)
                    return@setMethodCallHandler
                }
                val filename = call.argument<String>("filename")
                val content = call.argument<String>("content")
                if (filename == null || !Regex("[a-zA-Z0-9_-]+\\.csv").matches(filename) ||
                    content == null || content.length > 5_000_000) {
                    result.error("INVALID_REPORT", "Invalid CSV export.", null)
                    return@setMethodCallHandler
                }
                pendingExport = result
                csvContent = content
                // SAF lets the user choose the destination without storage permissions.
                // https://developer.android.com/training/data-storage/shared/documents-files
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "text/csv"
                    putExtra(Intent.EXTRA_TITLE, filename)
                }
                try {
                    startActivityForResult(intent, createCsvRequest)
                } catch (_: Exception) {
                    pendingExport = null
                    csvContent = null
                    result.error("SAVE_UNAVAILABLE", "The file picker could not open.", null)
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != createCsvRequest) return
        val result = pendingExport ?: return
        val content = csvContent
        val uri = data?.data
        csvContent = null
        if (resultCode != Activity.RESULT_OK || uri == null || content == null) {
            pendingExport = null
            result.success(false)
            return
        }
        Thread {
            try {
                val stream = contentResolver.openOutputStream(uri, "wt")
                    ?: throw IllegalStateException("Destination is not writable")
                stream.use { it.write(content.toByteArray(Charsets.UTF_8)) }
                runOnUiThread { pendingExport = null; result.success(true) }
            } catch (_: Exception) {
                runOnUiThread {
                    pendingExport = null
                    result.error("SAVE_FAILED", "The CSV could not be saved. Check the destination.", null)
                }
            }
        }.start()
    }
}
