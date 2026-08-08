package com.cotrainr.focuslift

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
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
                        // Start active workout reminder session
                        result.success(true)
                    }
                    "stopFocusSession" -> {
                        result.success(null)
                    }
                    "restoreNormalAccess" -> {
                        // Fail-safe cleanup
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
}
