package com.misync.misync

import android.app.Activity
import android.companion.AssociationRequest
import android.companion.CompanionDeviceManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.IntentSender
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val TAG = "MainActivity"
    private val CHANNEL = "com.misync.misync/channels"
    private val REQUEST_ASSOCIATE_DEVICE = 1001

    private var methodChannel: MethodChannel? = null

    // BroadcastReceiver to receive notifications from NotificationService
    private val notificationReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == NotificationService.ACTION_NOTIFICATION) {
                val packageName = intent.getStringExtra(NotificationService.EXTRA_PACKAGE) ?: ""
                val title = intent.getStringExtra(NotificationService.EXTRA_TITLE) ?: ""
                val body = intent.getStringExtra(NotificationService.EXTRA_BODY) ?: ""
                val id = intent.getIntExtra(NotificationService.EXTRA_ID, 0)
                val key = intent.getStringExtra(NotificationService.EXTRA_KEY) ?: ""
                val appName = intent.getStringExtra(NotificationService.EXTRA_APP_NAME) ?: ""
 
                 val data = mapOf(
                     "package" to packageName,
                     "title" to title,
                     "body" to body,
                     "id" to id,
                     "key" to key,
                     "appName" to appName
                 )
                runOnUiThread {
                    methodChannel?.invokeMethod("onNotificationReceived", data)
                }
            }
        }
    }

    private val alarmReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == android.app.AlarmManager.ACTION_NEXT_ALARM_CLOCK_CHANGED) {
                sendNextAlarmUpdate()
            }
        }
    }

    private fun sendNextAlarmUpdate() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        val nextAlarm = alarmManager.nextAlarmClock
        if (nextAlarm != null) {
            val calendar = java.util.Calendar.getInstance()
            calendar.timeInMillis = nextAlarm.triggerTime
            val data = mapOf(
                "hour" to calendar.get(java.util.Calendar.HOUR_OF_DAY),
                "minute" to calendar.get(java.util.Calendar.MINUTE)
            )
            runOnUiThread {
                methodChannel?.invokeMethod("onNextAlarmChanged", data)
            }
        } else {
            runOnUiThread {
                methodChannel?.invokeMethod("onNextAlarmChanged", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkNotificationPermission" -> {
                    result.success(isNotificationServiceEnabled())
                }
                "requestNotificationPermission" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(true)
                }
                "checkCompanionAssociation" -> {
                    result.success(isDeviceAssociated())
                }
                "requestCompanionAssociation" -> {
                    associateDevice()
                    result.success(true)
                }
                "startPresenceObservation" -> {
                    startPresenceObservation()
                    result.success(true)
                }
                "replyToNotification" -> {
                    val key = call.argument<String>("key")
                    val id = call.argument<Int>("id")
                    val message = call.argument<String>("message") ?: ""
                    val success = if (key != null && key.isNotEmpty()) {
                        NotificationService.instance?.reply(key, message) ?: false
                    } else if (id != null) {
                        NotificationService.instance?.replyById(id, message) ?: false
                    } else {
                        false
                    }
                    result.success(success)
                }
                "dismissNotification" -> {
                    val key = call.argument<String>("key")
                    val id = call.argument<Int>("id")
                    val success = if (key != null && key.isNotEmpty()) {
                        NotificationService.instance?.dismiss(key) ?: false
                    } else if (id != null) {
                        NotificationService.instance?.dismissById(id) ?: false
                    } else {
                        false
                    }
                    result.success(success)
                }
                "launchAction" -> {
                    val intentAction = call.argument<String>("intent") ?: ""
                    val packageName = call.argument<String>("package")
                    val extras = call.argument<Map<String, String>>("extras")
                    Log.d(TAG, "launchAction: intent=$intentAction, package=$packageName, extras=$extras")
                    try {
                        val intent = Intent(intentAction)
                        if (packageName != null && packageName.isNotEmpty()) {
                            intent.setPackage(packageName)
                        }
                        extras?.forEach { (key, value) ->
                            intent.putExtra(key, value)
                        }
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

                        if (intentAction == "net.dinglisch.android.taskerm.ACTION_TASK") {
                            sendBroadcast(intent)
                        } else {
                            try {
                                startActivity(intent)
                            } catch (e: Exception) {
                                sendBroadcast(intent)
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to launch action: $intentAction", e)
                        result.success(false)
                    }
                }
                "getDefaultSmsPackage" -> {
                    val defaultSmsPackage = android.provider.Telephony.Sms.getDefaultSmsPackage(this)
                    result.success(defaultSmsPackage)
                }
                "getNextAlarm" -> {
                    val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                    val nextAlarm = alarmManager.nextAlarmClock
                    if (nextAlarm != null) {
                        val calendar = java.util.Calendar.getInstance()
                        calendar.timeInMillis = nextAlarm.triggerTime
                        result.success(mapOf(
                            "hour" to calendar.get(java.util.Calendar.HOUR_OF_DAY),
                            "minute" to calendar.get(java.util.Calendar.MINUTE)
                        ))
                    } else {
                        result.success(null)
                    }
                }
                "getInstalledApps" -> {
                    Thread {
                        try {
                            val pm = packageManager
                            val apps = pm.getInstalledPackages(PackageManager.GET_META_DATA)
                            val appList = mutableListOf<Map<String, Any>>()
                            for (pkg in apps) {
                                val launchIntent = pm.getLaunchIntentForPackage(pkg.packageName)
                                if (launchIntent != null && pkg.applicationInfo != null) {
                                    val appInfo = pkg.applicationInfo!!
                                    val appName = appInfo.loadLabel(pm).toString()
                                    val packageName = pkg.packageName
                                    val iconDrawable = appInfo.loadIcon(pm)
                                    val iconBytes = drawableToByteArray(iconDrawable)

                                    val map = mutableMapOf<String, Any>()
                                    map["packageName"] = packageName
                                    map["appName"] = appName
                                    if (iconBytes != null) {
                                        map["iconBytes"] = iconBytes
                                    }
                                    appList.add(map)
                                }
                            }
                            appList.sortBy { (it["appName"] as String).lowercase() }

                            runOnUiThread {
                                result.success(appList)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("ERROR", e.message, null)
                            }
                        }
                    }.start()
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Force Android to rebind NotificationListenerService by toggling its component state
        try {
            val componentName = android.content.ComponentName(applicationContext, NotificationService::class.java)
            val packageManager = applicationContext.packageManager
            packageManager.setComponentEnabledSetting(
                componentName,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
            packageManager.setComponentEnabledSetting(
                componentName,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            Log.d(TAG, "Force reset NotificationService component enabled setting successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to force reset NotificationService component: ", e)
        }

        // Register receiver for notification events
        val filter = IntentFilter(NotificationService.ACTION_NOTIFICATION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(notificationReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(notificationReceiver, filter)
        }

        // Register receiver for next alarm clock changes
        val alarmFilter = IntentFilter(android.app.AlarmManager.ACTION_NEXT_ALARM_CLOCK_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(alarmReceiver, alarmFilter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(alarmReceiver, alarmFilter)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(notificationReceiver)
        } catch (e: Exception) {}
        try {
            unregisterReceiver(alarmReceiver)
        } catch (e: Exception) {}
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val pkgName = packageName
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        if (!TextUtils.isEmpty(flat)) {
            val names = flat.split(":")
            for (name in names) {
                val cn = android.content.ComponentName.unflattenFromString(name)
                if (cn != null && TextUtils.equals(pkgName, cn.packageName)) {
                    return true
                }
            }
        }
        return false
    }

    private fun isDeviceAssociated(): Boolean {
        val deviceManager = getSystemService(Context.COMPANION_DEVICE_SERVICE) as CompanionDeviceManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            deviceManager.myAssociations.isNotEmpty()
        } else {
            @Suppress("DEPRECATION")
            deviceManager.associations.isNotEmpty()
        }
    }

    private fun associateDevice() {
        val deviceManager = getSystemService(Context.COMPANION_DEVICE_SERVICE) as CompanionDeviceManager
        val request = AssociationRequest.Builder()
            .setSingleDevice(true)
            .setDeviceProfile(AssociationRequest.DEVICE_PROFILE_WATCH)
            .build()

        Log.d(TAG, "Requesting Companion device association...")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            deviceManager.associate(request, mainExecutor, object : CompanionDeviceManager.Callback() {
                override fun onAssociationPending(intentSender: IntentSender) {
                    try {
                        startIntentSenderForResult(intentSender, REQUEST_ASSOCIATE_DEVICE, null, 0, 0, 0)
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
                        startIntentSenderForResult(chooserLauncher, REQUEST_ASSOCIATE_DEVICE, null, 0, 0, 0)
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

    private fun startPresenceObservation() {
        val deviceManager = getSystemService(Context.COMPANION_DEVICE_SERVICE) as CompanionDeviceManager
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
        } else {
            @Suppress("DEPRECATION")
            val associations = deviceManager.associations
            for (mac in associations) {
                try {
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

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_ASSOCIATE_DEVICE && resultCode == Activity.RESULT_OK) {
            Log.d(TAG, "Device associated successfully!")
            startPresenceObservation()
            // Notify Flutter that association is done
            methodChannel?.invokeMethod("onCompanionAssociationComplete", true)
        }
    }

    private fun drawableToByteArray(drawable: Drawable): ByteArray? {
        try {
            val bitmap = when (drawable) {
                is BitmapDrawable -> drawable.bitmap
                else -> {
                    val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 96
                    val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 96
                    val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(bmp)
                    drawable.setBounds(0, 0, canvas.width, canvas.height)
                    drawable.draw(canvas)
                    bmp
                }
            }
            val scaledBitmap = Bitmap.createScaledBitmap(bitmap, 96, 96, true)
            val stream = ByteArrayOutputStream()
            scaledBitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            return stream.toByteArray()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to convert drawable to byte array", e)
            return null
        }
    }
}
