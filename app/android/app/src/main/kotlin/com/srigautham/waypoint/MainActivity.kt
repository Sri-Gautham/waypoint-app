package com.srigautham.waypoint

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth's biometric prompt requires a FragmentActivity, not the
// plain FlutterActivity the template ships with.
class MainActivity : FlutterFragmentActivity()
