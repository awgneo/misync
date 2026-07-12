package com.misync.misync.device

import android.content.Context
import android.content.Intent
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log

class FindWatchService : TileService() {
    private val TAG = "FindWatchService"

    override fun onStartListening() {
        super.onStartListening()
        updateTileState()
    }

    override fun onClick() {
        super.onClick()
        val prefs = getSharedPreferences("misync_prefs", Context.MODE_PRIVATE)
        val currentFinding = prefs.getBoolean("finding_watch", false)
        val newFinding = !currentFinding

        Log.d(TAG, "Tile clicked: toggling finding state to $newFinding")

        // Save state immediately
        prefs.edit().putBoolean("finding_watch", newFinding).apply()

        // Send local broadcast to MainActivity to invoke MethodChannel
        val intent = Intent("com.misync.misync.FIND_WATCH").apply {
            putExtra("enabled", newFinding)
            setPackage(packageName)
        }
        sendBroadcast(intent)

        updateTileState()
    }

    private fun updateTileState() {
        val tile = qsTile ?: return
        val prefs = getSharedPreferences("misync_prefs", Context.MODE_PRIVATE)
        val finding = prefs.getBoolean("finding_watch", false)

        if (finding) {
            tile.state = Tile.STATE_ACTIVE
            tile.label = "Finding Watch"
        } else {
            tile.state = Tile.STATE_INACTIVE
            tile.label = "Find Watch"
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            tile.subtitle = ""
        }
        tile.updateTile()
    }
}
