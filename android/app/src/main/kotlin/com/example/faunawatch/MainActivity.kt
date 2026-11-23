package com.example.faunawatch

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val windowSecurityChannel = "faunawatch/window_security"
    private val appInfoChannel = "faunawatch/app_info"
    private val appUpdateChannel = "faunawatch/app_update"

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, appUpdateChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateDir" -> result.success(updateDir().absolutePath)
                    "canInstall" -> result.success(canInstallUpdates())
                    "openInstallSettings" -> {
                        try {
                            startActivity(installSettingsIntent())
                            result.success(null)
                        } catch (error: ActivityNotFoundException) {
                            result.error("unavailable", "No settings screen", null)
                        }
                    }
                    "install" -> {
                        val path = call.argument<String>("path")
                        val file = path?.let { File(it).canonicalFile }
                        // Only files the app downloaded into its updates folder.
                        if (file == null || !file.isFile ||
                            file.parentFile != updateDir().canonicalFile
                        ) {
                            result.error("invalid", "Not a downloaded update", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val uri = FileProvider.getUriForFile(
                                this,
                                "$packageName.updates",
                                file,
                            )
                            val intent = Intent(Intent.ACTION_VIEW)
                                .setDataAndType(uri, "application/vnd.android.package-archive")
                                .addFlags(
                                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                        Intent.FLAG_ACTIVITY_NEW_TASK,
                                )
                            startActivity(intent)
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("unavailable", "Could not open the installer", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Downloaded updates live here; shared by UpdateFileProvider (res/xml/update_paths.xml).
    private fun updateDir(): File = File(cacheDir, "updates").apply { mkdirs() }

    // Android 8+ asks the user once to allow this app to install other apps.
    private fun canInstallUpdates(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()

    private fun installSettingsIntent(): Intent =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            )
        } else {
            Intent(Settings.ACTION_SECURITY_SETTINGS)
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
