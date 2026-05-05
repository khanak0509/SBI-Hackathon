package com.sbi.kavach

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * KavachForegroundService — the "always-on" guardian.
 *
 * A Foreground Service cannot be killed by Realme/Oppo/Xiaomi battery managers
 * (OplusHansManager, MIUI Phantom Process Killer, etc.) because it has a visible
 * persistent notification. This is how WhatsApp, antivirus apps, and all serious
 * background services survive on Chinese ROM devices.
 *
 * The KavachPackageReceiver is registered DYNAMICALLY inside this service so it
 * remains alive as long as the service is alive — which is always.
 */
class KavachForegroundService : Service() {

    private var packageReceiver: KavachPackageReceiver? = null

    companion object {
        const val CHANNEL_ID = "kavach_guard_channel"
        const val NOTIF_ID = 1001
    }

    override fun onCreate() {
        super.onCreate()
        startForeground(NOTIF_ID, buildPersistentNotification())
        registerPackageReceiver()
        android.util.Log.d("KavachService", "✅ Foreground service started, receiver registered")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // START_STICKY = if the OS kills this service (OOM), restart it automatically
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            packageReceiver?.let { unregisterReceiver(it) }
        } catch (e: Exception) {
            android.util.Log.e("KavachService", "Error unregistering receiver", e)
        }
        android.util.Log.d("KavachService", "❌ Foreground service destroyed")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun registerPackageReceiver() {
        packageReceiver = KavachPackageReceiver()
        val filter = IntentFilter(Intent.ACTION_PACKAGE_ADDED).apply {
            addDataScheme("package")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(packageReceiver, filter, RECEIVER_EXPORTED)
        } else {
            registerReceiver(packageReceiver, filter)
        }
    }

    private fun buildPersistentNotification(): android.app.Notification {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "KAVACH Active Protection",
                NotificationManager.IMPORTANCE_LOW  // LOW = no sound, just persistent
            ).also {
                it.description = "KAVACH is silently monitoring for fake banking apps"
                it.setShowBadge(false)
            }
            nm.createNotificationChannel(channel)
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("🛡️ KAVACH is Active")
            .setContentText("Monitoring for fake SBI apps silently in the background")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)       // Cannot be swiped away
            .setSilent(true)        // No sound, no vibration
            .setShowWhen(false)
            .build()
    }
}
