package com.srigautham.waypoint

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// local_auth's biometric prompt requires a FragmentActivity, not the
// plain FlutterActivity the template ships with.
class MainActivity : FlutterFragmentActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    ReceiptScannerBridge.register(flutterEngine.dartExecutor.binaryMessenger)
  }
}
