package com.misync.actions

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
    ) {
        Log.d(TAG, "launchAction: intent=$intentAction, package=$packageName, uri=$uriString, extras=$extras")
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

        val pm = context.packageManager
        val activities = pm.queryIntentActivities(intent, 0)
        if (activities.isNotEmpty()) {
            Log.d(TAG, "Routing intent as Activity")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            DismissKeyguardActivity.launch(context, targetIntent = intent)
        } else {
            Log.d(TAG, "Routing intent as Broadcast")
            context.sendBroadcast(intent)
        }
    }
}
