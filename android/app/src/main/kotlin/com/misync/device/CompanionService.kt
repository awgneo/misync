package com.misync.device

import android.companion.CompanionDeviceService
import android.companion.AssociationInfo
import android.content.Context
import android.telephony.SmsManager
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

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val settingsJsonStr = prefs.getString("flutter.misync.device.settings", "") ?: ""

        if (settingsJsonStr.isNotEmpty()) {
            try {
                val settingsJson = JSONObject(settingsJsonStr)
                val trustedNumber = settingsJson.optString("trustedPhoneNumber", "") ?: ""

                if (trustedNumber.isNotEmpty()) {
                    Log.d(TAG, "Triggering 'Phone Left Behind' alert to: $trustedNumber")
                    
                    // 1. Fetch current GPS location
                    val locationManager = LocationManager(this)
                    val loc = locationManager.getLocation()
                    val lat = loc?.get("latitude") as? Double
                    val lon = loc?.get("longitude") as? Double

                    // 2. Format message
                    val msg = if (lat != null && lon != null) {
                        "AWG left their phone behind! Last seen coordinates: https://maps.google.com/?q=$lat,$lon"
                    } else {
                        "AWG left their phone behind! (Unable to acquire GPS lock)"
                    }

                    // 3. Send SMS
                    val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        getSystemService(SmsManager::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        SmsManager.getDefault()
                    }
                    smsManager.sendTextMessage(trustedNumber, null, msg, null, null)
                    Log.d(TAG, "SMS alert sent successfully")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to parse settings JSON or send SMS", e)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "CompanionService destroyed")
    }
}
