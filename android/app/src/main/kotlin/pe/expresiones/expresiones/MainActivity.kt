package pe.expresiones.expresiones

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.math.max
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(
            messenger,
            "pe.expresiones.expresiones/avatar",
            StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue(),
        ).setMethodCallHandler { call, result ->
            if (call.method != "optimize") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val path = requireNotNull(call.argument<String>("path"))
                result.success(encodeAvatar(File(path)))
            } catch (_: Exception) {
                result.error("invalid_image", "No se pudo convertir la imagen.", null)
            }
        }
    }

    private fun encodeAvatar(file: File): ByteArray {
        val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            ImageDecoder.decodeBitmap(ImageDecoder.createSource(file)) { decoder, info, _ ->
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                val (width, height) = avatarSize(info.size.width, info.size.height)
                decoder.setTargetSize(width, height)
            }
        } else {
            // The image picker has already resized and oriented the source photo.
            val original = requireNotNull(BitmapFactory.decodeFile(file.path))
            val (width, height) = avatarSize(original.width, original.height)
            Bitmap.createScaledBitmap(original, width, height, true).also { resized ->
                if (resized !== original) original.recycle()
            }
        }
        try {
            @Suppress("DEPRECATION")
            val format = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                Bitmap.CompressFormat.WEBP_LOSSY
            } else {
                Bitmap.CompressFormat.WEBP
            }
            return ByteArrayOutputStream().use { output ->
                check(bitmap.compress(format, 84, output))
                output.toByteArray()
            }
        } finally {
            bitmap.recycle()
        }
    }

    private fun avatarSize(width: Int, height: Int): Pair<Int, Int> {
        val scale = minOf(1.0, 512.0 / max(width, height))
        return (width * scale).roundToInt().coerceAtLeast(1) to
            (height * scale).roundToInt().coerceAtLeast(1)
    }
}
