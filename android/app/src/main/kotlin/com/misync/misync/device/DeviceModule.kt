package com.misync.misync.device

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.provider.Settings
import android.util.Log
import com.misync.misync.base.BaseModule
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class DeviceModule(
    private val context: Context
) : BaseModule("device") {
    private val TAG = "DeviceModule"

    private val companionManager = CompanionManager(context)
    private val locationManager = LocationManager(context)
    private val settingsManager = SettingsManager(context)
    private val findPhoneManager = FindPhoneManager(context)

    private val dndReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == android.app.NotificationManager.ACTION_INTERRUPTION_FILTER_CHANGED) {
                sendDndUpdate()
            }
        }
    }

    private val stopFindPhoneReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.misync.misync.STOP_FIND_PHONE") {
                findPhoneManager.stop()
                methodChannel?.invokeMethod("stopFindPhone", null)
            }
        }
    }

    private val findWatchReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.misync.misync.FIND_WATCH") {
                val enabled = intent.getBooleanExtra("enabled", false)
                methodChannel?.invokeMethod("findWatchFromTile", enabled)
            }
        }
    }

    override fun onCreate() {
        // Register dnd changes
        val dndFilter = IntentFilter(android.app.NotificationManager.ACTION_INTERRUPTION_FILTER_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(dndReceiver, dndFilter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(dndReceiver, dndFilter)
        }

        // Register stop find phone
        val stopFilter = IntentFilter("com.misync.misync.STOP_FIND_PHONE")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(stopFindPhoneReceiver, stopFilter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(stopFindPhoneReceiver, stopFilter)
        }

        // Register find watch
        val watchFilter = IntentFilter("com.misync.misync.FIND_WATCH")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(findWatchReceiver, watchFilter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(findWatchReceiver, watchFilter)
        }
    }

    override fun onDestroy() {
        try {
            context.unregisterReceiver(dndReceiver)
        } catch (e: Exception) {}
        try {
            context.unregisterReceiver(stopFindPhoneReceiver)
        } catch (e: Exception) {}
        try {
            context.unregisterReceiver(findWatchReceiver)
        } catch (e: Exception) {}
    }

    override fun checkPermissions(): Boolean {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        val backgroundLocationGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            hasRuntimePermission(context, android.Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        } else {
            true
        }
        return companionManager.isDeviceAssociated() &&
               hasRuntimePermission(context, android.Manifest.permission.ACCESS_FINE_LOCATION) &&
               hasRuntimePermission(context, android.Manifest.permission.ACCESS_COARSE_LOCATION) &&
               backgroundLocationGranted &&
               notificationManager.isNotificationPolicyAccessGranted
    }

    override fun requestPermissions(activity: Activity) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
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
                   !hasRuntimePermission(context, android.Manifest.permission.ACCESS_BACKGROUND_LOCATION)) {
            activity.requestPermissions(arrayOf(android.Manifest.permission.ACCESS_BACKGROUND_LOCATION), 103)
        }
        
        if (!notificationManager.isNotificationPolicyAccessGranted) {
            activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
        }
    }

    override fun onMethodCall(activity: Activity, method: String, call: MethodCall, result: MethodChannel.Result): Boolean {
        return when (method) {
            "getDeviceAssociated" -> {
                result.success(companionManager.isDeviceAssociated())
                true
            }
            "requestCompanionAssociation" -> {
                companionManager.associateDevice(activity)
                result.success(true)
                true
            }
            "observeDevicePresence" -> {
                companionManager.observeDevicePresence()
                result.success(true)
                true
            }
            "updateFindWatchState" -> {
                val enabled = call.arguments as? Boolean ?: false
                settingsManager.updateFindWatchTile(enabled)
                result.success(true)
                true
            }
            "startFindPhone" -> {
                findPhoneManager.start()
                result.success(true)
                true
            }
            "stopFindPhone" -> {
                findPhoneManager.stop()
                result.success(true)
                true
            }
            "getDnd" -> {
                result.success(settingsManager.getDnd())
                true
            }
            "setDnd" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                val success = settingsManager.setDnd(enabled)
                result.success(success)
                true
            }
            "getLocation" -> {
                val loc = locationManager.getLocation()
                result.success(loc)
                true
            }
            else -> false
        }
    }

    private fun sendDndUpdate() {
        val isDnd = settingsManager.getDnd()
        methodChannel?.invokeMethod("dndChanged", isDnd)
    }
}
