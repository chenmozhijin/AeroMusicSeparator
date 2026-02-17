package com.example.aero_music_separator

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.IOException

class MainActivity : FlutterActivity() {
    companion object {
        private const val EXPORT_CHANNEL = "aero_music_separator/export"
        private const val EXPORT_REQUEST_CODE = 0xA501
    }

    private var pendingResult: MethodChannel.Result? = null
    private var pendingSourcePath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EXPORT_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "exportFile") {
                    handleExportCall(call, result)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun handleExportCall(call: MethodCall, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("pick_destination", "pick_destination: export is already active", null)
            return
        }
        val sourcePath = call.argument<String>("sourcePath")
        val suggestedName = call.argument<String>("suggestedName")
        val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"

        if (sourcePath.isNullOrBlank() || suggestedName.isNullOrBlank()) {
            result.error("pick_destination", "pick_destination: invalid export arguments", null)
            return
        }

        val sourceFile = File(sourcePath)
        if (!sourceFile.exists() || !sourceFile.canRead()) {
            result.error("ffi_read", "ffi_read: source file is not readable: $sourcePath", null)
            return
        }

        pendingResult = result
        pendingSourcePath = sourcePath
        try {
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = if (mimeType.isBlank()) "application/octet-stream" else mimeType
                putExtra(Intent.EXTRA_TITLE, suggestedName)
            }
            startActivityForResult(intent, EXPORT_REQUEST_CODE)
        } catch (error: Exception) {
            clearPendingState()
            result.error(
                "pick_destination",
                "pick_destination: failed to open export picker: ${error.message}",
                null
            )
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != EXPORT_REQUEST_CODE) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }

        val result = pendingResult
        val sourcePath = pendingSourcePath
        clearPendingState()
        if (result == null || sourcePath.isNullOrBlank()) {
            return
        }

        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }

        val destinationUri = data?.data
        if (destinationUri == null) {
            result.error("pick_destination", "pick_destination: destination uri is null", null)
            return
        }

        try {
            copyFileToUri(sourcePath, destinationUri)
            result.success(destinationUri.toString())
        } catch (error: IOException) {
            val message = error.message ?: "stream copy failed"
            if (message.startsWith("open_output:")) {
                result.error("open_output", message, null)
            } else {
                result.error("stream_copy", "stream_copy: $message", null)
            }
        } catch (error: Exception) {
            result.error("stream_copy", "stream_copy: ${error.message}", null)
        }
    }

    @Throws(IOException::class)
    private fun copyFileToUri(sourcePath: String, destinationUri: Uri) {
        val sourceFile = File(sourcePath)
        FileInputStream(sourceFile).use { input ->
            val output = contentResolver.openOutputStream(destinationUri, "w")
                ?: throw IOException("open_output: unable to open destination output stream")
            output.use { stream ->
                val buffer = ByteArray(256 * 1024)
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) {
                        break
                    }
                    stream.write(buffer, 0, read)
                }
                stream.flush()
            }
        }
    }

    private fun clearPendingState() {
        pendingResult = null
        pendingSourcePath = null
    }
}
