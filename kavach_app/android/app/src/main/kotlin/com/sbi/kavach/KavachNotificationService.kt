package com.sbi.kavach

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.core.app.NotificationCompat

class KavachNotificationService : NotificationListenerService() {

    private val sbiKeywords = listOf("sbi", "yono", "kyc", "netbanking", "onlinesbi")
    private val legitDomains = setOf("onlinesbi.sbi", "sbi.co.in", "sbicard.com")
    private val urlRegex = Regex("""https?://[^\s"'<>]+""")

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return
        val extras = sbn.notification?.extras ?: return
        val text = extras.getString(Notification.EXTRA_TEXT) ?: ""
        val bigText = extras.getString(Notification.EXTRA_BIG_TEXT) ?: ""
        val fullText = "$text $bigText"

        val urls = urlRegex.findAll(fullText).map { it.value }.toList()
        for (url in urls) {
            if (isSuspicious(url)) {
                showWarning(url, sbn.packageName)
                break
            }
        }
    }

    private fun isSuspicious(url: String): Boolean {
        val lower = url.lowercase()
        val hasSbiKeyword = sbiKeywords.any { lower.contains(it) }
        if (!hasSbiKeyword) return false
        val domain = try {
            java.net.URL(url).host.lowercase().removePrefix("www.")
        } catch (_: Exception) {
            return false
        }
        return domain !in legitDomains
    }

    private fun showWarning(url: String, sourcePackage: String) {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "kavach_warnings"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(
                    channelId,
                    "KAVACH Warnings",
                    NotificationManager.IMPORTANCE_HIGH
                )
            )
        }
        val n = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("⚠️ Suspicious SBI Link Detected")
            .setContentText("A notification contains a suspicious link. Do not tap it.")
            .setStyle(
                NotificationCompat.BigTextStyle().bigText(
                    "Suspicious link in notification from $sourcePackage:\n$url\n\nDo NOT click this link."
                )
            )
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setColor(0xFFE05555.toInt())
            .setAutoCancel(true)
            .build()
        nm.notify(System.currentTimeMillis().toInt(), n)
    }
}
