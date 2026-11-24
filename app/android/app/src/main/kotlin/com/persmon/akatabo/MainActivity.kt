package com.persmon.akatabo

import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.biometrics.BiometricManager
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
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
 *
 * "elapsedRealtime" gives the time since the phone started, which changing the date and time
 * cannot move. The waits after wrong PIN tries are timed by it.
 *
 * The "akatabo/permissions" channel backs Settings > Phone permissions: it lists the
 * permissions this build asks for, whether each is granted, and opens the phone's own settings
 * page for one. It changes nothing itself; the person does that in the phone's settings.
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
                    "elapsedRealtime" -> result.success(SystemClock.elapsedRealtime())
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "akatabo/permissions")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requested" -> result.success(requestedPermissions())
                    "open" -> result.success(openSettings(call.arguments as? String ?: "app"))
                    else -> result.notImplemented()
                }
            }
    }

    /** Each permission this build asks for, mapped to whether it is granted now. */
    private fun requestedPermissions(): Map<String, Boolean> {
        val info = packageManager.getPackageInfo(packageName, PackageManager.GET_PERMISSIONS)
        val names = info.requestedPermissions ?: return emptyMap()
        return names
            // The app's own internal permissions are not something the person grants.
            .filterNot { it.startsWith(packageName) }
            .associateWith { checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }
    }

    /** Opens the phone's settings page for [which]. False if no page could be opened. */
    private fun openSettings(which: String): Boolean {
        val intent = when {
            which == "notifications" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O ->
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            // The enrol screen closes at once when a fingerprint or face is already added, or
            // the phone has no sensor, so it is opened only when one could be added now.
            which == "biometrics" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
                getSystemService(BiometricManager::class.java)
                    ?.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_WEAK) ==
                BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED ->
                Intent(Settings.ACTION_BIOMETRIC_ENROLL)
            which == "biometrics" -> Intent(Settings.ACTION_SECURITY_SETTINGS)
            else -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.fromParts("package", packageName, null))
        }
        // Some phones have no page for the exact action; fall back to a broader one.
        val fallback = if (which == "biometrics") {
            Intent(Settings.ACTION_SECURITY_SETTINGS)
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.fromParts("package", packageName, null))
        }
        for (candidate in listOf(intent, fallback)) {
            try {
                startActivity(candidate)
                return true
            } catch (e: Exception) {
                // Try the next one.
            }
        }
        return false
    }
}
