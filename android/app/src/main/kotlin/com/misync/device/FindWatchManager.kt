package com.misync.device

import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.service.quicksettings.TileService

class FindWatchManager(private val context: Context) {

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
