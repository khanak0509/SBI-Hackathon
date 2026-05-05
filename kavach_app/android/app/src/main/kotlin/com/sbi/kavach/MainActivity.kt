package com.sbi.kavach

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val channel = "kavach/native"
    private val packageEventChannel = "kavach/package_threats"

    companion object {
        var eventSink: EventChannel.EventSink? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Start the persistent foreground service — this keeps our BroadcastReceiver
        // alive even when the user swipes KAVACH away from Recent Apps.
        // On Realme/Oppo/Xiaomi (ColorOS/Realme UI), manifest receivers are killed
        // when an app is force-closed. A ForegroundService is immune to this.
        val serviceIntent = Intent(this, KavachForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }

        // Method channel for imperative calls
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSelfCertHash" -> {
                        try {
                            val hash = getSelfCertHash()
                            result.success(hash)
                        } catch (e: Exception) {
                            result.error("CERT_ERROR", e.message, null)
                        }
                    }
                    "checkPendingThreat" -> {
                        val prefs = getSharedPreferences("kavach_prefs", Context.MODE_PRIVATE)
                        val pkg = prefs.getString("pending_threat_pkg", null)
                        val sim = prefs.getFloat("pending_threat_sim", 0f)
                        if (pkg != null && pkg.isNotEmpty()) {
                            result.success(mapOf("package_name" to pkg, "similarity" to sim.toDouble()))
                        } else {
                            result.success(null)
                        }
                    }
                    "clearPendingThreat" -> {
                        getSharedPreferences("kavach_prefs", Context.MODE_PRIVATE)
                            .edit().remove("pending_threat_pkg").remove("pending_threat_sim").apply()
                        result.success(true)
                    }
                    "openAppSettings" -> {
                        val pkg = call.argument<String>("package") ?: ""
                        val intent = android.content.Intent(
                            android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            android.net.Uri.parse("package:$pkg")
                        )
                        startActivity(intent)
                        result.success(true)
                    }
                    "hasNotificationAccess" -> {
                        val enabledListeners = android.provider.Settings.Secure.getString(
                            contentResolver,
                            "enabled_notification_listeners"
                        )
                        val packageName = packageName
                        val hasAccess = enabledListeners != null && enabledListeners.contains(packageName)
                        result.success(hasAccess)
                    }
                    "openNotificationSettings" -> {
                        val intent = android.content.Intent(
                            android.provider.Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS
                        )
                        startActivity(intent)
                        result.success(true)
                    }
                    "openAppUninstall" -> {
                        val pkg = call.argument<String>("package") ?: ""
                        android.util.Log.d("KavachNative", "Requesting uninstall for: $pkg")
                        if (pkg.isNotEmpty()) {
                            val intent = android.content.Intent(
                                android.content.Intent.ACTION_DELETE,
                                android.net.Uri.fromParts("package", pkg, null)
                            ).apply {
                                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.error("INVALID_PKG", "Package name is empty", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // Event channel so KavachPackageReceiver can push threats to Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, packageEventChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    @Suppress("DEPRECATION")
    private fun getSelfCertHash(): String {
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
        } else {
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
        }
        val cert = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.signingInfo?.apkContentsSigners?.firstOrNull()?.toByteArray()
        } else {
            @Suppress("DEPRECATION")
            info.signatures?.firstOrNull()?.toByteArray()
        } ?: throw Exception("No certificate found")

        return MessageDigest.getInstance("SHA-256")
            .digest(cert)
            .joinToString("") { "%02x".format(it) }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Receiver is now owned by KavachForegroundService, nothing to unregister here
    }
}
