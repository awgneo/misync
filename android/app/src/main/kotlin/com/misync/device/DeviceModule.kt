package com.misync.device

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.provider.Settings
import android.util.Log
import com.misync.base.BaseModule
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class DeviceModule(
    private val context: Context
) : BaseModule("device") {
    private val TAG = "DeviceModule"

    private val companionManager = CompanionManager(context)
    private val locationManager = LocationManager(context)
    private val findWatchManager = FindWatchManager(context)
    private val findPhoneManager = FindPhoneManager(context)


    private val stopFindPhoneReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.misync.STOP_FIND_PHONE") {
                findPhoneManager.stop()
                methodChannel?.invokeMethod("stopFindPhone", null)
            }
        }
    }

    private val findWatchReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.misync.FIND_WATCH") {
                val enabled = intent.getBooleanExtra("enabled", false)
                methodChannel?.invokeMethod("findWatchFromTile", enabled)
            }
        }
    }

    override fun onCreate() {
        // Register stop find phone
        val stopFilter = IntentFilter("com.misync.STOP_FIND_PHONE")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(stopFindPhoneReceiver, stopFilter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(stopFindPhoneReceiver, stopFilter)
        }

        // Register find watch
        val watchFilter = IntentFilter("com.misync.FIND_WATCH")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(findWatchReceiver, watchFilter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(findWatchReceiver, watchFilter)
        }
    }

    override fun onDestroy() {
        context.unregisterReceiver(stopFindPhoneReceiver)
        context.unregisterReceiver(findWatchReceiver)
    }

    override fun checkPermissions(): Boolean {
        val backgroundLocationGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            hasRuntimePermission(context, android.Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        } else {
            true
        }
        return companionManager.isDeviceAssociated() &&
                hasRuntimePermission(context, android.Manifest.permission.ACCESS_FINE_LOCATION) &&
                hasRuntimePermission(context, android.Manifest.permission.ACCESS_COARSE_LOCATION) &&
                backgroundLocationGranted
    }

    override fun requestPermissions(activity: Activity) {
        if (!companionManager.isDeviceAssociated()) {
            companionManager.associateDevice(activity)
        }
        val hasFine = hasRuntimePermission(context, android.Manifest.permission.ACCESS_FINE_LOCATION)
        val hasCoarse = hasRuntimePermission(context, android.Manifest.permission.ACCESS_COARSE_LOCATION)

        if (!hasFine || !hasCoarse) {
            val perms = mutableListOf<String>()
            if (!hasFine) perms.add(android.Manifest.permission.ACCESS_FINE_LOCATION)
            if (!hasCoarse) perms.add(android.Manifest.permission.ACCESS_COARSE_LOCATION)
            activity.requestPermissions(perms.toTypedArray(), 102)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            !hasRuntimePermission(context, android.Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        ) {
            activity.requestPermissions(arrayOf(android.Manifest.permission.ACCESS_BACKGROUND_LOCATION), 103)
        }
    }

    override fun onMethodCall(
        activity: Activity,
        method: String,
        call: MethodCall,
        result: MethodChannel.Result
    ): Boolean {
        return when (method) {
            "getDeviceAssociated" -> {
                result.success(companionManager.isDeviceAssociated())
                true
            }

            "requestCompanionAssociation" -> {
                companionManager.associateDevice(activity)
                result.success(null)
                true
            }

            "observeDevicePresence" -> {
                companionManager.observeDevicePresence()
                result.success(null)
                true
            }

            "updateFindWatchState" -> {
                val enabled = call.arguments as? Boolean ?: false
                findWatchManager.updateFindWatchTile(enabled)
                result.success(null)
                true
            }

            "startFindPhone" -> {
                findPhoneManager.start()
                result.success(null)
                true
            }

            "stopFindPhone" -> {
                findPhoneManager.stop()
                result.success(null)
                true
            }

            "getLocation" -> {
                val loc = locationManager.getLocation()
                result.success(loc)
                true
            }

            "startLocationUpdates" -> {
                val success = locationManager.startLocationUpdates { map ->
                    activity.runOnUiThread {
                        methodChannel?.invokeMethod("locationUpdate", map)
                    }
                }
                if (success) {
                    result.success(null)
                } else {
                    throw IllegalStateException("Failed to start location updates")
                }
                true
            }

            "stopLocationUpdates" -> {
                locationManager.stopLocationUpdates()
                result.success(null)
                true
            }

            else -> false
        }
    }

}
