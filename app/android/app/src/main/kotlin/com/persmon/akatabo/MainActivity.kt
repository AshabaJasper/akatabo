package com.persmon.akatabo

import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterFragmentActivity is required by local_auth (biometric unlock).
 *
 * The "akatabo/privacy" channel backs the setting "Blank the screen in the app switcher":
 * on Android 13+ it hides the app's thumbnail in recent apps; below that it falls back to
 * FLAG_SECURE, which also blocks screenshots.
 */
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "akatabo/privacy")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setHiddenInRecents" -> {
                        val hidden = call.arguments as? Boolean ?: false
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            setRecentsScreenshotEnabled(!hidden)
                        } else if (hidden) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
