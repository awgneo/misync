package com.misync.device

import android.companion.CompanionDeviceService
import android.companion.AssociationInfo
import android.util.Log

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
        Log.d(TAG, "Device disappeared: ${associationInfo.deviceMacAddress}")
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "CompanionService destroyed")
    }
}
