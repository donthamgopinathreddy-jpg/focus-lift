package com.cotrainr.focuslift

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val FOCUS_CONTROL_CHANNEL = "com.cotrainr.focuslift/focus_control"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOCUS_CONTROL_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAuthorizationStatus" -> {
                        val isGranted = checkUsageAccessGranted()
                        if (isGranted) {
                            result.success("authorized")
                        } else {
                            result.success("notDetermined")
                        }
                    }
                    "requestAuthorization" -> {
                        try {
                            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "launchPhoneApp" -> {
                        try {
                            val dialIntent = Intent(Intent.ACTION_DIAL).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(dialIntent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "launchCameraApp" -> {
                        try {
                            val cameraIntent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(cameraIntent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "launchMusicApp" -> {
                        val pkg = call.argument<String?>("packageName")
                        var launched = false
                        if (!pkg.isNullOrEmpty()) {
                            try {
                                val launchIntent = packageManager.getLaunchIntentForPackage(pkg)?.apply {
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                if (launchIntent != null) {
                                    startActivity(launchIntent)
                                    launched = true
                                }
                            } catch (e: Exception) {
                                launched = false
                            }
                        }
                        if (!launched) {
                            try {
                                val musicIntent = Intent(MediaStore.INTENT_ACTION_MUSIC_PLAYER).apply {
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(musicIntent)
                                launched = true
                            } catch (e: Exception) {
                                launched = false
                            }
                        }
                        result.success(launched)
                    }
                    "discoverInstalledMusicApps" -> {
                        val musicApps = getMusicApplications()
                        result.success(musicApps)
                    }
                    "getLauncherApps" -> {
                        val apps = getLauncherApplications()
                        result.success(apps)
                    }
                    "openAppPicker" -> {
                        result.success(null)
                    }
                    "updateSelectedDistractions" -> {
                        result.success(null)
                    }
                    "startFocusSession" -> {
                        result.success(true)
                    }
                    "stopFocusSession" -> {
                        result.success(null)
                    }
                    "restoreNormalAccess" -> {
                        result.success(null)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    private fun checkUsageAccessGranted(): Boolean {
        return try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    packageName
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    packageName
                )
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            false
        }
    }

    private fun getLauncherApplications(): List<Map<String, String>> {
        val appList = mutableListOf<Map<String, String>>()
        try {
            val pm = packageManager
            val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
                addCategory(Intent.CATEGORY_LAUNCHER)
            }
            val resolvedActivities = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.queryIntentActivities(mainIntent, PackageManager.ResolveInfoFlags.of(0L))
            } else {
                pm.queryIntentActivities(mainIntent, 0)
            }

            for (resolveInfo in resolvedActivities) {
                val pkgName = resolveInfo.activityInfo.packageName
                if (pkgName != packageName) {
                    val appLabel = resolveInfo.loadLabel(pm).toString()
                    appList.add(mapOf("appName" to appLabel, "packageName" to pkgName))
                }
            }
        } catch (e: Exception) {
            // Graceful fallback
        }
        return appList.sortedBy { it["appName"]?.lowercase() ?: "" }
    }

    private fun getMusicApplications(): List<Map<String, String>> {
        val appList = mutableListOf<Map<String, String>>()
        val knownMusicKeywords = listOf("music", "spotify", "audio", "podcast", "radio", "sound", "yt music", "deezer", "tidal", "tunein", "pandora")
        try {
            val pm = packageManager
            val allLauncher = getLauncherApplications()
            for (app in allLauncher) {
                val name = app["appName"]?.lowercase() ?: ""
                val pkg = app["packageName"]?.lowercase() ?: ""
                if (knownMusicKeywords.any { name.contains(it) || pkg.contains(it) }) {
                    appList.add(app)
                }
            }
        } catch (e: Exception) {
            // Graceful fallback
        }
        return appList
    }
}
