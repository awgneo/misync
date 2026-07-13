package com.misync.misync.actions

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log

class ActionsManager(private val context: Context) {
    private val TAG = "ActionsManager"

    fun launchAction(
        intentAction: String,
        packageName: String?,
        uriString: String?,
        extras: Map<String, String>?
    ): Boolean {
        Log.d(TAG, "launchAction: intent=$intentAction, package=$packageName, uri=$uriString, extras=$extras")
        return try {
            val intent = Intent(intentAction)
            if (packageName != null && packageName.isNotEmpty()) {
                intent.setPackage(packageName)
            }
            if (uriString != null && uriString.isNotEmpty()) {
                intent.data = Uri.parse(uriString)
            }
            extras?.forEach { (key, value) ->
                intent.putExtra(key, value)
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

            if (intentAction == "net.dinglisch.android.taskerm.ACTION_TASK") {
                context.sendBroadcast(intent)
            } else {
                try {
                    context.startActivity(intent)
                } catch (e: Exception) {
                    context.sendBroadcast(intent)
                }
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch action: $intentAction", e)
            false
        }
    }
}
