package com.sbi.kavach

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat

class KavachPackageReceiver : BroadcastReceiver() {

    private val officialPkg = "com.sbi.lotusintouch"
    private val prefsName = "kavach_prefs"
    private val keyPendingThreat = "pending_threat_pkg"
    private val keySimilarity = "pending_threat_sim"

    override fun onReceive(context: Context, intent: Intent) {
        android.util.Log.d("KavachReceiver", "Received intent: ${intent.action}")
        if (intent.action != Intent.ACTION_PACKAGE_ADDED) return
        val pkg = intent.data?.schemeSpecificPart ?: return
        android.util.Log.d("KavachReceiver", "Package added: $pkg")
        if (pkg == context.packageName) return

        val similarity = lcs(pkg.lowercase(), officialPkg.lowercase()).toDouble() /
            maxOf(pkg.length, officialPkg.length)
        android.util.Log.d("KavachReceiver", "Similarity to $officialPkg: $similarity")

        if (similarity > 0.50 && pkg != officialPkg) {
            // 1. Fire a system notification (works even when app is closed)
            showAlert(context, pkg, similarity)

            // 2. Persist to SharedPreferences so Flutter reads it on next resume
            context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                .edit()
                .putString(keyPendingThreat, pkg)
                .putFloat(keySimilarity, similarity.toFloat())
                .apply()

            // 3. Push directly to Flutter if the app is currently foregrounded
            android.util.Log.d("KavachReceiver", "🚨 THREAT DETECTED: $pkg (Sim: $similarity)")
            Handler(Looper.getMainLooper()).post {
                MainActivity.eventSink?.success(
                    mapOf("package_name" to pkg, "similarity" to similarity, "status" to "threat")
                )
            }
        } else {
            // SAFE APP: Just log for debugging, don't bother the user or the dashboard
            android.util.Log.d("KavachReceiver", "✅ SAFE APP (Ignored): $pkg (Sim: $similarity)")
        }
    }

    private fun lcs(a: String, b: String): Int {
        val dp = Array(a.length + 1) { IntArray(b.length + 1) }
        for (i in 1..a.length) {
            for (j in 1..b.length) {
                dp[i][j] = if (a[i - 1] == b[j - 1]) dp[i - 1][j - 1] + 1
                else maxOf(dp[i - 1][j], dp[i][j - 1])
            }
        }
        return dp[a.length][b.length]
    }

    private fun showAlert(context: Context, pkg: String, similarity: Double) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "kavach_threats"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(channelId, "KAVACH Threat Alerts", NotificationManager.IMPORTANCE_HIGH)
                    .also { it.enableVibration(true) }
            )
        }

        // Create an intent to force-open Kavach's MainActivity
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = android.app.PendingIntent.getActivity(
            context, 
            pkg.hashCode(), 
            openIntent, 
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )

        val n = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("🚨 Suspicious App Installed")
            .setContentText("$pkg resembles SBI YONO. Open KAVACH to verify.")
            .setStyle(
                NotificationCompat.BigTextStyle().bigText(
                    "A new app was installed that looks like SBI YONO:\n\n$pkg\n\n" +
                        "Similarity score: ${(similarity * 100).toInt()}%\n" +
                        "Open KAVACH to scan and verify this app."
                )
            )
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setColor(0xFFE05555.toInt())
            .setAutoCancel(false)
            .setContentIntent(pendingIntent)
            .setFullScreenIntent(pendingIntent, true) // Force interrupt the user!
            .build()
        nm.notify(pkg.hashCode(), n)

        // Also try to forcefully start the activity right now (works on some OEMs / if app has permissions)
        try {
            context.startActivity(openIntent)
        } catch (e: Exception) {
            android.util.Log.e("KavachReceiver", "Failed to force start activity", e)
        }
    }
}
