package com.misync.device

import android.companion.CompanionDeviceService
import android.companion.AssociationInfo
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import org.json.JSONObject

class CompanionService : CompanionDeviceService() {
    private val TAG = "CompanionService"

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "CompanionService created")
    }

    override fun onDeviceAppeared(associationInfo: AssociationInfo) {
        super.onDeviceAppeared(associationInfo)
        Log.d(TAG, "Device appeared: ${associationInfo.deviceMacAddress}")
    }

    override fun onDeviceDisappeared(associationInfo: AssociationInfo) {
        super.onDeviceDisappeared(associationInfo)
        val mac = associationInfo.deviceMacAddress?.toString() ?: ""
        Log.d(TAG, "Device disappeared: $mac")

        val intent = Intent("com.misync.DEVICE_DISAPPEARED").apply {
            setPackage(packageName)
        }
        sendBroadcast(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "CompanionService destroyed")
    }
}
