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
import android.media.MediaPlayer
import android.media.AudioManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.service.quicksettings.TileService
import android.location.Geocoder
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val TAG = "MainActivity"
    private val CHANNEL = "com.misync.misync/channels"
    private val REQUEST_ASSOCIATE_DEVICE = 1001

    private var methodChannel: MethodChannel? = null
    private var mediaPlayer: MediaPlayer? = null
    private var originalVolume: Int? = null
    private var findWatchReceiver: BroadcastReceiver? = null
    private var stopFindPhoneReceiver: BroadcastReceiver? = null

    private val notificationReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == NotificationService.ACTION_NOTIFICATION) {
                val packageName = intent.getStringExtra(NotificationService.EXTRA_PACKAGE) ?: ""
                val title = intent.getStringExtra(NotificationService.EXTRA_TITLE) ?: ""
                val body = intent.getStringExtra(NotificationService.EXTRA_BODY) ?: ""
                val id = intent.getIntExtra(NotificationService.EXTRA_ID, 0)
                val key = intent.getStringExtra(NotificationService.EXTRA_KEY) ?: ""
                val appName = intent.getStringExtra(NotificationService.EXTRA_APP_NAME) ?: ""
                val category = intent.getStringExtra("category") ?: ""
                val phoneNumber = intent.getStringExtra("phoneNumber") ?: ""
 
                 val data = mapOf(
                     "package" to packageName,
                     "title" to title,
                     "body" to body,
                     "id" to id,
                     "key" to key,
                     "appName" to appName,
                     "category" to category,
                     "phoneNumber" to phoneNumber
                 )
                runOnUiThread {
                    methodChannel?.invokeMethod("notificationReceived", data)
                }
            } else if (intent?.action == NotificationService.ACTION_NOTIFICATION_REMOVED) {
                val packageName = intent.getStringExtra(NotificationService.EXTRA_PACKAGE) ?: ""
                val id = intent.getIntExtra(NotificationService.EXTRA_ID, 0)
                val key = intent.getStringExtra(NotificationService.EXTRA_KEY) ?: ""
                val category = intent.getStringExtra("category") ?: ""

                val data = mapOf(
                    "package" to packageName,
                    "id" to id,
                    "key" to key,
                    "category" to category
                )
                runOnUiThread {
                    methodChannel?.invokeMethod("notificationRemoved", data)
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

    private val dndReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == android.app.NotificationManager.ACTION_INTERRUPTION_FILTER_CHANGED) {
                sendDndUpdate()
            }
        }
    }

    private fun sendDndUpdate() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        val filter = notificationManager.currentInterruptionFilter
        val isDnd = filter == android.app.NotificationManager.INTERRUPTION_FILTER_NONE ||
                    filter == android.app.NotificationManager.INTERRUPTION_FILTER_PRIORITY ||
                    filter == android.app.NotificationManager.INTERRUPTION_FILTER_ALARMS
        runOnUiThread {
            methodChannel?.invokeMethod("dndChanged", isDnd)
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
                methodChannel?.invokeMethod("nextAlarmChanged", data)
            }
        } else {
            runOnUiThread {
                methodChannel?.invokeMethod("nextAlarmChanged", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermissions" -> {
                    val permissions = call.argument<List<String>>("permissions") ?: emptyList()
                    val missing = mutableListOf<String>()
                    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                    for (perm in permissions) {
                        when (perm) {
                            "notification" -> if (!isNotificationServiceEnabled()) missing.add("notification")
                              "sms" -> if (checkSelfPermission(android.Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) missing.add("sms")
                              "contacts" -> if (checkSelfPermission(android.Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) missing.add("contacts")
                              "companion" -> if (!getDeviceAssociated()) missing.add("companion")
                              "dnd" -> if (!notificationManager.isNotificationPolicyAccessGranted) missing.add("dnd")
                              "calendar" -> if (checkSelfPermission(android.Manifest.permission.READ_CALENDAR) != PackageManager.PERMISSION_GRANTED) missing.add("calendar")
                              "location" -> if (checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
                                               checkSelfPermission(android.Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) missing.add("location")
                        }
                    }
                    result.success(missing)
                }
                "requestPermissions" -> {
                    val permissions = call.argument<List<String>>("permissions") ?: emptyList()
                    val runtimePerms = mutableListOf<String>()
                    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                    for (perm in permissions) {
                        when (perm) {
                            "notification" -> if (!isNotificationServiceEnabled()) {
                                startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                            }
                            "sms" -> if (checkSelfPermission(android.Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
                                runtimePerms.add(android.Manifest.permission.SEND_SMS)
                            }
                            "contacts" -> if (checkSelfPermission(android.Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
                                runtimePerms.add(android.Manifest.permission.READ_CONTACTS)
                            }
                            "companion" -> if (!getDeviceAssociated()) {
                                associateDevice()
                            }
                            "dnd" -> if (!notificationManager.isNotificationPolicyAccessGranted) {
                                startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
                            }
                            "calendar" -> if (checkSelfPermission(android.Manifest.permission.READ_CALENDAR) != PackageManager.PERMISSION_GRANTED) {
                                runtimePerms.add(android.Manifest.permission.READ_CALENDAR)
                            }
                            "location" -> {
                                if (checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                                    runtimePerms.add(android.Manifest.permission.ACCESS_FINE_LOCATION)
                                }
                                if (checkSelfPermission(android.Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                                    runtimePerms.add(android.Manifest.permission.ACCESS_COARSE_LOCATION)
                                }
                            }
                        }
                    }
                    if (runtimePerms.isNotEmpty()) {
                        requestPermissions(runtimePerms.toTypedArray(), 102)
                    }
                    result.success(true)
                }
                "getDnd" -> {
                    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                    val filter = notificationManager.currentInterruptionFilter
                    val isDnd = filter == android.app.NotificationManager.INTERRUPTION_FILTER_NONE ||
                                filter == android.app.NotificationManager.INTERRUPTION_FILTER_PRIORITY ||
                                filter == android.app.NotificationManager.INTERRUPTION_FILTER_ALARMS
                    result.success(isDnd)
                }
                "setDnd" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
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
                }
                "getDeviceAssociated" -> {
                    result.success(getDeviceAssociated())
                }
                "requestCompanionAssociation" -> {
                    associateDevice()
                    result.success(true)
                }
                "observeDevicePresence" -> {
                    observeDevicePresence()
                    result.success(true)
                }
                "replyToNotification" -> {
                    val key = call.argument<String>("key")
                    val id = call.argument<Int>("id")
                    val message = call.argument<String>("message") ?: ""
                    val success = if (key != null && key.isNotEmpty()) {
                        val repSuccess = NotificationService.instance?.reply(key, message) ?: false
                        NotificationService.instance?.declineCall(key)
                        repSuccess
                    } else if (id != null) {
                        val repSuccess = NotificationService.instance?.replyById(id, message) ?: false
                        NotificationService.instance?.declineCallById(id)
                        repSuccess
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
                "getAppIcon" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val size = call.argument<Int>("size") ?: 96
                    try {
                        val pm = packageManager
                        val drawable = if (packageName == "com.google.android.dialer" || packageName == "phone_call_icon") {
                            val intent = Intent(Intent.ACTION_DIAL)
                            val resolveInfo = pm.resolveActivity(intent, 0)
                            if (resolveInfo != null) {
                                resolveInfo.activityInfo.loadIcon(pm)
                            } else {
                                pm.getApplicationIcon(packageName)
                            }
                        } else {
                            pm.getApplicationIcon(packageName)
                        }

                        val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else size
                        val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else size
                        val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                        val canvas = Canvas(bmp)
                        drawable.setBounds(0, 0, canvas.width, canvas.height)
                        drawable.draw(canvas)

                        val scaledBmp = Bitmap.createScaledBitmap(bmp, size, size, true)
                        val byteBuffer = java.nio.ByteBuffer.allocate(scaledBmp.byteCount)
                        scaledBmp.copyPixelsToBuffer(byteBuffer)
                        result.success(byteBuffer.array())
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to get app icon for $packageName", e)
                        result.error("ERROR", e.message, null)
                    }
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
                "sendSms" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")
                    val message = call.argument<String>("message") ?: ""
                    val success = if (phoneNumber != null && phoneNumber.isNotEmpty()) {
                        try {
                            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                getSystemService(android.telephony.SmsManager::class.java)
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
                "getApps" -> {
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
                "getCalendars" -> {
                    Thread {
                        try {
                            val uri = android.provider.CalendarContract.Calendars.CONTENT_URI
                            val projection = arrayOf(
                                android.provider.CalendarContract.Calendars._ID,
                                android.provider.CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
                                android.provider.CalendarContract.Calendars.ACCOUNT_NAME,
                                android.provider.CalendarContract.Calendars.CALENDAR_COLOR
                            )
                            val cursor = contentResolver.query(uri, projection, null, null, null)
                            val list = mutableListOf<Map<String, Any>>()
                            cursor?.use { c ->
                                val idIndex = c.getColumnIndex(android.provider.CalendarContract.Calendars._ID)
                                val nameIndex = c.getColumnIndex(android.provider.CalendarContract.Calendars.CALENDAR_DISPLAY_NAME)
                                val accountIndex = c.getColumnIndex(android.provider.CalendarContract.Calendars.ACCOUNT_NAME)
                                val colorIndex = c.getColumnIndex(android.provider.CalendarContract.Calendars.CALENDAR_COLOR)
                                while (c.moveToNext()) {
                                    val id = c.getLong(idIndex).toString()
                                    val name = c.getString(nameIndex) ?: ""
                                    val account = c.getString(accountIndex) ?: ""
                                    val color = c.getInt(colorIndex)
                                    list.add(mapOf(
                                        "id" to id,
                                        "name" to name,
                                        "account" to account,
                                        "color" to color
                                    ))
                                }
                            }
                            runOnUiThread {
                                result.success(list)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("ERROR", e.message, null)
                            }
                        }
                    }.start()
                }
                "getUpcomingEvents" -> {
                    val calendarIds = call.argument<List<String>>("calendarIds") ?: emptyList()
                    Thread {
                        try {
                            if (calendarIds.isEmpty()) {
                                runOnUiThread { result.success(emptyList<Map<String, Any>>()) }
                                return@Thread
                            }

                            val begin = System.currentTimeMillis()
                            val end = begin + 7L * 24L * 60L * 60L * 1000L

                            val builder = android.provider.CalendarContract.Instances.CONTENT_URI.buildUpon()
                            android.content.ContentUris.appendId(builder, begin)
                            android.content.ContentUris.appendId(builder, end)
                            val uri = builder.build()

                            val projection = arrayOf(
                                android.provider.CalendarContract.Instances.TITLE,
                                android.provider.CalendarContract.Instances.DESCRIPTION,
                                android.provider.CalendarContract.Instances.EVENT_LOCATION,
                                android.provider.CalendarContract.Instances.BEGIN,
                                android.provider.CalendarContract.Instances.END,
                                android.provider.CalendarContract.Instances.ALL_DAY,
                                android.provider.CalendarContract.Instances.EVENT_ID
                            )

                            val selection = StringBuilder()
                            val selectionArgs = mutableListOf<String>()
                            selection.append(android.provider.CalendarContract.Instances.CALENDAR_ID + " IN (")
                            for (i in calendarIds.indices) {
                                if (i > 0) selection.append(",")
                                selection.append("?")
                                selectionArgs.add(calendarIds[i])
                            }
                            selection.append(")")

                            val cursor = contentResolver.query(
                                uri,
                                projection,
                                selection.toString(),
                                selectionArgs.toTypedArray(),
                                android.provider.CalendarContract.Instances.BEGIN + " ASC"
                            )

                            val eventList = mutableListOf<Map<String, Any>>()
                            cursor?.use { c ->
                                val titleIdx = c.getColumnIndex(android.provider.CalendarContract.Instances.TITLE)
                                val descIdx = c.getColumnIndex(android.provider.CalendarContract.Instances.DESCRIPTION)
                                val locIdx = c.getColumnIndex(android.provider.CalendarContract.Instances.EVENT_LOCATION)
                                val beginIdx = c.getColumnIndex(android.provider.CalendarContract.Instances.BEGIN)
                                val endIdx = c.getColumnIndex(android.provider.CalendarContract.Instances.END)
                                val allDayIdx = c.getColumnIndex(android.provider.CalendarContract.Instances.ALL_DAY)
                                val eventIdIdx = c.getColumnIndex(android.provider.CalendarContract.Instances.EVENT_ID)

                                var count = 0
                                while (c.moveToNext() && count < 500) {
                                    val title = c.getString(titleIdx) ?: ""
                                    val description = c.getString(descIdx) ?: ""
                                    val location = c.getString(locIdx) ?: ""
                                    val startMs = c.getLong(beginIdx)
                                    val endMs = c.getLong(endIdx)
                                    val allDay = c.getInt(allDayIdx) == 1
                                    val eventId = c.getLong(eventIdIdx)
                                    val notifyMinutes = getReminderMinutes(eventId)

                                    eventList.add(mapOf(
                                        "title" to title,
                                        "description" to description,
                                        "location" to location,
                                        "start" to startMs,
                                        "end" to endMs,
                                        "allDay" to allDay,
                                        "notifyMinutesBefore" to notifyMinutes
                                    ))
                                    count++
                                }
                            }
                            runOnUiThread {
                                result.success(eventList)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("ERROR", e.message, null)
                            }
                        }
                    }.start()
                }
                "startFindPhone" -> {
                    startFindPhone()
                    result.success(true)
                }
                "stopFindPhone" -> {
                    stopFindPhone()
                    result.success(true)
                }
                "updateFindWatchState" -> {
                    val enabled = call.arguments as? Boolean ?: false
                    updateFindWatchState(enabled)
                    result.success(true)
                }
                "getLocation" -> {
                    val loc = getLocation()
                    result.success(loc)
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
        val filter = IntentFilter().apply {
            addAction(NotificationService.ACTION_NOTIFICATION)
            addAction(NotificationService.ACTION_NOTIFICATION_REMOVED)
        }
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

        // Register receiver for DND changes
        val dndFilter = IntentFilter(android.app.NotificationManager.ACTION_INTERRUPTION_FILTER_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(dndReceiver, dndFilter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(dndReceiver, dndFilter)
        }

        // Register local broadcast receiver to stop Find Phone
        stopFindPhoneReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == "com.misync.misync.STOP_FIND_PHONE") {
                    stopFindPhone()
                    runOnUiThread {
                        methodChannel?.invokeMethod("stopFindPhone", null)
                    }
                }
            }
        }
        val stopFilter = IntentFilter("com.misync.misync.STOP_FIND_PHONE")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(stopFindPhoneReceiver, stopFilter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(stopFindPhoneReceiver, stopFilter)
        }

        // Register local broadcast receiver for Find Watch requests from TileService
        findWatchReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == "com.misync.misync.FIND_WATCH") {
                    val enabled = intent.getBooleanExtra("enabled", false)
                    runOnUiThread {
                        methodChannel?.invokeMethod("findWatchFromTile", enabled)
                    }
                }
            }
        }
        val watchFilter = IntentFilter("com.misync.misync.FIND_WATCH")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(findWatchReceiver, watchFilter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(findWatchReceiver, watchFilter)
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
        try {
            unregisterReceiver(dndReceiver)
        } catch (e: Exception) {}
        try {
            unregisterReceiver(stopFindPhoneReceiver)
        } catch (e: Exception) {}
        try {
            unregisterReceiver(findWatchReceiver)
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

    private fun getDeviceAssociated(): Boolean {
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

    private fun observeDevicePresence() {
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
            observeDevicePresence()
            // Notify Flutter that association is done
            methodChannel?.invokeMethod("deviceAssociated", true)
        }
    }

    private fun getReminderMinutes(eventId: Long): Int {
        val uri = android.provider.CalendarContract.Reminders.CONTENT_URI
        val projection = arrayOf(android.provider.CalendarContract.Reminders.MINUTES)
        val selection = "${android.provider.CalendarContract.Reminders.EVENT_ID} = ?"
        val selectionArgs = arrayOf(eventId.toString())
        var minutes = 0
        try {
            val cursor = contentResolver.query(uri, projection, selection, selectionArgs, null)
            cursor?.use { c ->
                if (c.moveToFirst()) {
                    minutes = c.getInt(c.getColumnIndexOrThrow(android.provider.CalendarContract.Reminders.MINUTES))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to query reminder minutes for event $eventId", e)
        }
        return minutes
    }

    private fun startFindPhone() {
        Log.d(TAG, "startFindPhone: playing loud alert")
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (originalVolume == null) {
            originalVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
        }
        val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
        audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxVolume, 0)

        if (mediaPlayer == null) {
            val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            mediaPlayer = MediaPlayer().apply {
                setDataSource(applicationContext, alarmUri)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                isLooping = true
                prepare()
                start()
            }
        }

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "find_phone_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Find Phone Alert",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Plays loud alert when finding phone from watch"
                setBypassDnd(true)
                setSound(null, null)
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val stopIntent = Intent("com.misync.misync.STOP_FIND_PHONE").apply {
            setPackage(packageName)
        }
        val stopPendingIntent = PendingIntent.getBroadcast(
            this, 0, stopIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(this, channelId)
        } else {
            @Suppress("DEPRECATION")
            android.app.Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(android.R.drawable.ic_menu_search)
            .setContentTitle("Find Phone Alert")
            .setContentText("Your watch is finding this phone")
            .setOngoing(true)
            .setCategory(android.app.Notification.CATEGORY_ALARM)
            .addAction(android.app.Notification.Action.Builder(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Found It",
                stopPendingIntent
            ).build())
            .build()

        notificationManager.notify(1008, notification)
    }

    private fun stopFindPhone() {
        Log.d(TAG, "stopFindPhone: stopping alarm player")
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping media player", e)
        }
        mediaPlayer = null

        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        originalVolume?.let {
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, it, 0)
            originalVolume = null
        }

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(1008)
    }

    private fun updateFindWatchState(enabled: Boolean) {
        val prefs = getSharedPreferences("misync_prefs", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("finding_watch", enabled).apply()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            TileService.requestListeningState(
                this,
                android.content.ComponentName(this, FindWatchTileService::class.java)
            )
        }
    }

    private fun getLocation(): Map<String, Any>? {
        Log.d(TAG, "getLocation: querying LocationManager")
        val locationManager = getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
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
                val geocoder = Geocoder(this, Locale.getDefault())
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
