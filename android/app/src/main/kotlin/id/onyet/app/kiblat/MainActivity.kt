package id.onyet.app.kiblat

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private var pendingAudioResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "id.onyet.app.kiblat/platform"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getLocalTimezone" -> result.success(TimeZone.getDefault().id)
                "pickNotificationSound" -> pickNotificationSound(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun pickNotificationSound(result: MethodChannel.Result) {
        if (pendingAudioResult != null) {
            result.error("picker_active", "An audio picker is already open.", null)
            return
        }

        pendingAudioResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "audio/*"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        try {
            startActivityForResult(intent, REQUEST_AUDIO_PICKER)
        } catch (e: Exception) {
            pendingAudioResult = null
            result.error("picker_unavailable", "No audio picker is available.", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_AUDIO_PICKER) {
            val result = pendingAudioResult
            pendingAudioResult = null

            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                result?.success(null)
                return
            }

            val uri = data.data!!
            try {
                val flags = data.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION
                contentResolver.takePersistableUriPermission(uri, flags)
            } catch (_: Exception) {
                // Some providers do not support persistable grants. The URI may
                // still work while the provider keeps it readable.
            }

            result?.success(
                mapOf(
                    "uri" to uri.toString(),
                    "name" to displayNameFor(uri)
                )
            )
            return
        }

        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun displayNameFor(uri: Uri): String {
        var cursor: Cursor? = null
        return try {
            cursor = contentResolver.query(uri, null, null, null, null)
            val nameIndex = cursor?.getColumnIndex(OpenableColumns.DISPLAY_NAME) ?: -1
            if (cursor != null && cursor.moveToFirst() && nameIndex >= 0) {
                cursor.getString(nameIndex)
            } else {
                uri.lastPathSegment ?: "Custom adzan"
            }
        } catch (_: Exception) {
            uri.lastPathSegment ?: "Custom adzan"
        } finally {
            cursor?.close()
        }
    }

    companion object {
        private const val REQUEST_AUDIO_PICKER = 7001
    }
}
