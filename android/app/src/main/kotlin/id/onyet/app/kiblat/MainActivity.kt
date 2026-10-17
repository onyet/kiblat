package id.onyet.app.kiblat

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone
import java.security.KeyFactory
import java.security.PublicKey
import java.security.Signature
import java.security.spec.X509EncodedKeySpec
import android.util.Base64
import android.util.Log
import androidx.annotation.NonNull

class MainActivity : FlutterActivity() {
    private var pendingAudioResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d("MainActivity", "Configuring Flutter Engine")

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "id.onyet.app.kiblat/platform"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getLocalTimezone" -> result.success(TimeZone.getDefault().id)
                "pickNotificationSound" -> pickNotificationSound(result)
                "verifySignature" -> {
                    val signedData = call.argument<String>("signedData")
                    val signature = call.argument<String>("signature")
                    val publicKey = call.argument<String>("publicKey")
                    if (signedData == null || signature == null || publicKey == null) {
                        result.error("invalid_arguments", "Arguments cannot be null", null)
                    } else {
                        val isValid = Security.verifyPurchase(publicKey, signedData, signature)
                        result.success(isValid)
                    }
                }
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

object Security {
    private const val TAG = "IABPlayVerification"
    private const val KEY_FACTORY_ALGORITHM = "RSA"
    private const val SIGNATURE_ALGORITHM = "SHA1withRSA"

    fun verifyPurchase(base64PublicKey: String, signedData: String, signature: String): Boolean {
        if (signedData.isEmpty() || base64PublicKey.isEmpty() || signature.isEmpty()) {
            Log.e(TAG, "Purchase verification failed: missing data.")
            return false
        }
        val key = generatePublicKey(base64PublicKey) ?: return false
        return verify(key, signedData, signature)
    }

    private fun generatePublicKey(encodedPublicKey: String): PublicKey? {
        return try {
            val decodedKey = Base64.decode(encodedPublicKey, Base64.DEFAULT)
            val keyFactory = KeyFactory.getInstance(KEY_FACTORY_ALGORITHM)
            keyFactory.generatePublic(X509EncodedKeySpec(decodedKey))
        } catch (e: Exception) {
            Log.e(TAG, "Invalid key specification: $e")
            null
        }
    }

    private fun verify(publicKey: PublicKey, signedData: String, signature: String): Boolean {
        val signatureBytes: ByteArray = try {
            Base64.decode(signature, Base64.DEFAULT)
        } catch (e: IllegalArgumentException) {
            Log.e(TAG, "Base64 decoding failed.")
            return false
        }
        try {
            val signatureAlgorithm = Signature.getInstance(SIGNATURE_ALGORITHM)
            signatureAlgorithm.initVerify(publicKey)
            signatureAlgorithm.update(signedData.toByteArray())
            if (!signatureAlgorithm.verify(signatureBytes)) {
                Log.e(TAG, "Signature verification failed.")
                return false
            }
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Verify exception: $e")
        }
        return false
    }
}
