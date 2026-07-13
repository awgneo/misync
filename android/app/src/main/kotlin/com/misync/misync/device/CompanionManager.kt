package com.misync.misync.device

import android.app.Activity
import android.companion.AssociationRequest
import android.companion.CompanionDeviceManager
import android.content.Context
import android.content.IntentSender
import android.os.Build
import android.util.Log

class CompanionManager(private val context: Context) {
    private val TAG = "CompanionManager"

    fun isDeviceAssociated(): Boolean {
        val deviceManager = context.getSystemService(Context.COMPANION_DEVICE_SERVICE) as CompanionDeviceManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            deviceManager.myAssociations.isNotEmpty()
        } else {
            @Suppress("DEPRECATION")
            deviceManager.associations.isNotEmpty()
        }
    }

    fun associateDevice(activity: Activity) {
        val deviceManager = context.getSystemService(Context.COMPANION_DEVICE_SERVICE) as CompanionDeviceManager
        val request = AssociationRequest.Builder()
            .setSingleDevice(true)
            .setDeviceProfile(AssociationRequest.DEVICE_PROFILE_WATCH)
            .build()

        Log.d(TAG, "Requesting Companion device association...")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            deviceManager.associate(request, activity.mainExecutor, object : CompanionDeviceManager.Callback() {
                override fun onAssociationPending(intentSender: IntentSender) {
                    try {
                        activity.startIntentSenderForResult(intentSender, 1001, null, 0, 0, 0)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to start association chooser", e)
                    }
                }

                override fun onFailure(error: CharSequence?) {
                    Log.e(TAG, "Association request failed: $error")
                }
            })
        } else {
            @Suppress("DEPRECATION")
            deviceManager.associate(request, object : CompanionDeviceManager.Callback() {
                override fun onDeviceFound(chooserLauncher: IntentSender) {
                    try {
                        activity.startIntentSenderForResult(chooserLauncher, 1001, null, 0, 0, 0)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to start association chooser", e)
                    }
                }

                override fun onFailure(error: CharSequence?) {
                    Log.e(TAG, "Association request failed: $error")
                }
            }, null)
        }
    }

    fun observeDevicePresence() {
        val deviceManager = context.getSystemService(Context.COMPANION_DEVICE_SERVICE) as CompanionDeviceManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val associations = deviceManager.myAssociations
            for (assoc in associations) {
                try {
                    val mac = assoc.deviceMacAddress?.toString()
                    if (mac != null) {
                        Log.d(TAG, "Starting presence observation for: $mac")
                        deviceManager.startObservingDevicePresence(mac)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start presence observation", e)
                }
            }
        }
    }
}
