package com.example.faunawatch

import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val windowSecurityChannel = "faunawatch/window_security"
    private val appInfoChannel = "faunawatch/app_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, windowSecurityChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        val secure = call.argument<Boolean>("secure") ?: false
                        if (secure) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, appInfoChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getVersion" -> {
                        try {
                            val info = installedPackageInfo()
                            result.success(
                                mapOf(
                                    "versionName" to info.versionName,
                                    "versionCode" to versionCodeOf(info),
                                ),
                            )
                        } catch (error: PackageManager.NameNotFoundException) {
                            result.error("unavailable", "Version not found", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // The installed app's name and build number from pubspec.yaml's
    // `version: <name>+<build number>`.
    private fun installedPackageInfo(): PackageInfo =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
        } else {
            legacyPackageInfo()
        }

    @Suppress("DEPRECATION")
    private fun legacyPackageInfo(): PackageInfo = packageManager.getPackageInfo(packageName, 0)

    private fun versionCodeOf(info: PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            legacyVersionCode(info)
        }

    @Suppress("DEPRECATION")
    private fun legacyVersionCode(info: PackageInfo): Long = info.versionCode.toLong()
}
