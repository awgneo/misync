package com.misync.misync.device

import android.app.Activity
import android.companion.AssociationRequest
import android.companion.CompanionDeviceManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.IntentSender
import android.content.pm.PackageManager
import android.location.Geocoder
import android.os.Build
import android.provider.Settings
import android.service.quicksettings.TileService
import android.util.Log
import com.misync.misync.base.BaseModule
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class DeviceModule(
    private val context: Context
) : BaseModule("device") {
    private val TAG = "DeviceModule"
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
        return isDeviceAssociated() &&
               hasRuntimePermission(context, android.Manifest.permission.ACCESS_FINE_LOCATION) &&
               hasRuntimePermission(context, android.Manifest.permission.ACCESS_COARSE_LOCATION) &&
               notificationManager.isNotificationPolicyAccessGranted
    }

    override fun requestPermissions(activity: Activity) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        if (!isDeviceAssociated()) {
            associateDevice(activity)
        }
        val perms = mutableListOf<String>()
        if (!hasRuntimePermission(context, android.Manifest.permission.ACCESS_FINE_LOCATION)) {
            perms.add(android.Manifest.permission.ACCESS_FINE_LOCATION)
        }
        if (!hasRuntimePermission(context, android.Manifest.permission.ACCESS_COARSE_LOCATION)) {
            perms.add(android.Manifest.permission.ACCESS_COARSE_LOCATION)
        }
        if (perms.isNotEmpty()) {
            activity.requestPermissions(perms.toTypedArray(), 102)
        }
        if (!notificationManager.isNotificationPolicyAccessGranted) {
            activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
        }
    }

    override fun onMethodCall(activity: Activity, method: String, call: MethodCall, result: MethodChannel.Result): Boolean {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        return when (method) {
            "getDeviceAssociated" -> {
                result.success(isDeviceAssociated())
                true
            }
            "requestCompanionAssociation" -> {
                associateDevice(activity)
                result.success(true)
                true
            }
            "observeDevicePresence" -> {
                observeDevicePresence()
                result.success(true)
                true
            }
            "updateFindWatchState" -> {
                val enabled = call.arguments as? Boolean ?: false
                val prefs = context.getSharedPreferences("misync_prefs", Context.MODE_PRIVATE)
                prefs.edit().putBoolean("finding_watch", enabled).apply()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    TileService.requestListeningState(
                        context,
                        android.content.ComponentName(context, FindWatchService::class.java)
                    )
                }
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
                val filter = notificationManager.currentInterruptionFilter
                val isDnd = filter == android.app.NotificationManager.INTERRUPTION_FILTER_NONE ||
                            filter == android.app.NotificationManager.INTERRUPTION_FILTER_PRIORITY ||
                            filter == android.app.NotificationManager.INTERRUPTION_FILTER_ALARMS
                result.success(isDnd)
                true
            }
            "setDnd" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                if (notificationManager.isNotificationPolicyAccessGranted) {
                    val filter = if (enabled) {
                        android.app.NotificationManager.INTERRUPTION_FILTER_NONE
                    } else {
                        android.app.NotificationManager.INTERRUPTION_FILTER_ALL
                    }
                    notificationManager.setInterruptionFilter(filter)
                    result.success(true)
                } else {
                    result.success(false)
                }
                true
            }
            "launchAction" -> {
                val intentAction = call.argument<String>("intent") ?: ""
                val packageName = call.argument<String>("package")
                val uriString = call.argument<String>("uri")
                val extras = call.argument<Map<String, String>>("extras")
                Log.d(TAG, "launchAction: intent=$intentAction, package=$packageName, uri=$uriString, extras=$extras")
                try {
                    val intent = Intent(intentAction)
                    if (packageName != null && packageName.isNotEmpty()) {
                        intent.setPackage(packageName)
                    }
                    if (uriString != null && uriString.isNotEmpty()) {
                        intent.data = android.net.Uri.parse(uriString)
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
                    result.success(true)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to launch action: $intentAction", e)
                    result.success(false)
                }
                true
            }
            "sendSms" -> {
                val phoneNumber = call.argument<String>("phoneNumber")
                val message = call.argument<String>("message") ?: ""
                val success = if (phoneNumber != null && phoneNumber.isNotEmpty()) {
                    try {
                        val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            context.getSystemService(android.telephony.SmsManager::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            android.telephony.SmsManager.getDefault()
                        }
                        smsManager.sendTextMessage(phoneNumber, null, message, null, null)
                        Log.d(TAG, "SMS sent to $phoneNumber successfully")
                        true
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to send SMS to $phoneNumber", e)
                        false
                    }
                } else {
                    false
                }
                result.success(success)
                true
            }
            "getDefaultSmsPackage" -> {
                val defaultSmsPackage = android.provider.Telephony.Sms.getDefaultSmsPackage(context)
                result.success(defaultSmsPackage)
                true
            }
            "getLocation" -> {
                val loc = getLocation()
                result.success(loc)
                true
            }
            else -> false
        }
    }

    private fun isDeviceAssociated(): Boolean {
        val deviceManager = context.getSystemService(Context.COMPANION_DEVICE_SERVICE) as CompanionDeviceManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            deviceManager.myAssociations.isNotEmpty()
        } else {
            @Suppress("DEPRECATION")
            deviceManager.associations.isNotEmpty()
        }
    }

    private fun associateDevice(activity: Activity) {
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

    private fun observeDevicePresence() {
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

    private fun getLocation(): Map<String, Any>? {
        Log.d(TAG, "getLocation: querying LocationManager")
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
        val providers = locationManager.getProviders(true)
        var bestLocation: android.location.Location? = null
        for (provider in providers) {
            try {
                val loc = locationManager.getLastKnownLocation(provider) ?: continue
                if (bestLocation == null || loc.accuracy < bestLocation.accuracy) {
                    bestLocation = loc
                }
            } catch (e: SecurityException) {
                Log.e(TAG, "Location permission not granted for provider $provider", e)
            }
        }
        if (bestLocation != null) {
            var cityName = "Current Location"
            try {
                val geocoder = Geocoder(context, Locale.getDefault())
                val addresses = geocoder.getFromLocation(bestLocation.latitude, bestLocation.longitude, 1)
                if (!addresses.isNullOrEmpty()) {
                    val address = addresses[0]
                    cityName = address.locality ?: address.subAdminArea ?: address.adminArea ?: "Current Location"
                }
            } catch (e: Exception) {
                Log.e(TAG, "Geocoder failed to get city name", e)
            }
            Log.d(TAG, "getLocation: found lat=${bestLocation.latitude}, lon=${bestLocation.longitude}, city=$cityName")
            return mapOf(
                "latitude" to bestLocation.latitude,
                "longitude" to bestLocation.longitude,
                "cityName" to cityName
            )
        }
        Log.w(TAG, "getLocation: no last known location found")
        return null
    }

    private fun sendDndUpdate() {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        val filter = notificationManager.currentInterruptionFilter
        val isDnd = filter == android.app.NotificationManager.INTERRUPTION_FILTER_NONE ||
                filter == android.app.NotificationManager.INTERRUPTION_FILTER_PRIORITY ||
                filter == android.app.NotificationManager.INTERRUPTION_FILTER_ALARMS
        methodChannel?.invokeMethod("dndChanged", isDnd)
    }
}
