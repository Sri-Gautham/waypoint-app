package com.srigautham.waypoint

import android.graphics.BitmapFactory
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges Android's ML Kit text recognition (added as a direct Gradle
 * dependency, not a Flutter plugin, so it can't drag in the iOS CocoaPods
 * that have no arm64 simulator slice) to Dart over a MethodChannel. See
 * lib/services/receipt_scanner_service.dart for the Dart side, which does
 * the amount-parsing — this bridge only returns raw recognized text.
 */
class ReceiptScannerBridge private constructor() {
  companion object {
    private const val CHANNEL_NAME = "com.srigautham.waypoint/receipt_scanner"

    fun register(messenger: BinaryMessenger) {
      val channel = MethodChannel(messenger, CHANNEL_NAME)
      val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
      channel.setMethodCallHandler { call, result ->
        when (call.method) {
          "recognizeText" -> {
            val path = call.argument<String>("path")
            if (path == null) {
              result.error("bad_args", "Missing 'path'.", null)
              return@setMethodCallHandler
            }
            val bitmap = BitmapFactory.decodeFile(path)
            if (bitmap == null) {
              result.error("bad_image", "Couldn't load image at path.", null)
              return@setMethodCallHandler
            }
            // Rotation hardcoded to 0 — doesn't correct for camera EXIF
            // orientation, so a sideways/upside-down photo may just fail
            // to recognize text (handled gracefully: scanTotal() returns
            // null, user types the amount manually) rather than crash.
            val image = InputImage.fromBitmap(bitmap, 0)
            recognizer.process(image)
              .addOnSuccessListener { visionText -> result.success(visionText.text) }
              .addOnFailureListener { e -> result.error("recognition_failed", e.message, null) }
          }
          else -> result.notImplemented()
        }
      }
    }
  }
}
