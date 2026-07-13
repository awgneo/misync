package com.misync.misync.device

import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.service.quicksettings.TileService

class SettingsManager(private val context: Context) {

    fun getDnd(): Boolean {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val filter = notificationManager.currentInterruptionFilter
        return filter == NotificationManager.INTERRUPTION_FILTER_NONE ||
               filter == NotificationManager.INTERRUPTION_FILTER_PRIORITY ||
               filter == NotificationManager.INTERRUPTION_FILTER_ALARMS
    }

    fun setDnd(enabled: Boolean): Boolean {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return if (notificationManager.isNotificationPolicyAccessGranted) {
            val filter = if (enabled) {
                NotificationManager.INTERRUPTION_FILTER_NONE
            } else {
                NotificationManager.INTERRUPTION_FILTER_ALL
            }
            notificationManager.setInterruptionFilter(filter)
            true
        } else {
            false
        }
    }

    fun updateFindWatchTile(enabled: Boolean) {
        val prefs = context.getSharedPreferences("misync_prefs", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("finding_watch", enabled).apply()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            TileService.requestListeningState(
                context,
                ComponentName(context, FindWatchService::class.java)
            )
        }
    }
}
