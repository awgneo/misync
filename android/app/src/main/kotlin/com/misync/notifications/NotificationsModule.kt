package com.misync.notifications

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.app.NotificationManager
import com.misync.base.BaseModule
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

import android.content.pm.PackageManager

class NotificationsModule(private val context: Context) : BaseModule("notifications") {
    private val TAG = "NotificationsModule"
    private val notificationsManager = NotificationsManager(context)

    private val dndReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == android.app.NotificationManager.ACTION_INTERRUPTION_FILTER_CHANGED) {
                sendDndUpdate()
            }
        }
    }

    private val notificationReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == NotificationsService.ACTION_NOTIFICATION_RECEIVED) {
                val `package` = intent.getStringExtra(NotificationsService.EXTRA_PACKAGE) ?: ""
                val title = intent.getStringExtra(NotificationsService.EXTRA_TITLE) ?: ""
                val body = intent.getStringExtra(NotificationsService.EXTRA_BODY) ?: ""
                val id = intent.getIntExtra(NotificationsService.EXTRA_ID, 0)
                val key = intent.getStringExtra(NotificationsService.EXTRA_KEY) ?: ""
                val app = intent.getStringExtra(NotificationsService.EXTRA_APP) ?: ""
                val phone = intent.getStringExtra(NotificationsService.EXTRA_PHONE) ?: ""
                val replyable = intent.getBooleanExtra(NotificationsService.EXTRA_REPLYABLE, false)
                val kind = intent.getStringExtra(NotificationsService.EXTRA_KIND) ?: "standard"
                val secondary = intent.getBooleanExtra(NotificationsService.EXTRA_SECONDARY, false)
                val timestamp = intent.getLongExtra(NotificationsService.EXTRA_TIMESTAMP, System.currentTimeMillis())

                val data = mapOf(
                    "package" to `package`,
                    "title" to title,
                    "body" to body,
                    "id" to id,
                    "key" to key,
                    "app" to app,
                    "phone" to phone,
                    "replyable" to replyable,
                    "kind" to kind,
                    "secondary" to secondary,
                    "timestamp" to timestamp
                )

                methodChannel?.invokeMethod("notificationReceived", data)
            } else if (intent?.action == NotificationsService.ACTION_NOTIFICATION_REMOVED) {
                val `package` = intent.getStringExtra(NotificationsService.EXTRA_PACKAGE) ?: ""
                val id = intent.getIntExtra(NotificationsService.EXTRA_ID, 0)
                val key = intent.getStringExtra(NotificationsService.EXTRA_KEY) ?: ""

                val data = mapOf(
                    "package" to `package`,
                    "id" to id,
                    "key" to key
                )

                methodChannel?.invokeMethod("notificationRemoved", data)
            }
        }
    }

    override fun onCreate() {
        val filter = IntentFilter().apply {
            addAction(NotificationsService.ACTION_NOTIFICATION_RECEIVED)
            addAction(NotificationsService.ACTION_NOTIFICATION_REMOVED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(notificationReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(notificationReceiver, filter)
        }

        val dndFilter = IntentFilter(android.app.NotificationManager.ACTION_INTERRUPTION_FILTER_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(dndReceiver, dndFilter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(dndReceiver, dndFilter)
        }

        // Force Android to rebind NotificationListenerService by toggling its component state
        val componentName = android.content.ComponentName(context, NotificationsService::class.java)
        val packageManager = context.packageManager
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
    }

    override fun onDestroy() {
        context.unregisterReceiver(notificationReceiver)
        context.unregisterReceiver(dndReceiver)
    }

    override fun checkPermissions(): Boolean {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return isNotificationServiceEnabled() &&
                hasRuntimePermission(context, android.Manifest.permission.SEND_SMS) &&
                hasRuntimePermission(context, android.Manifest.permission.READ_CONTACTS) &&
                notificationManager.isNotificationPolicyAccessGranted
    }

    override fun requestPermissions(activity: Activity) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!isNotificationServiceEnabled()) {
            activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
        }
        val perms = mutableListOf<String>()
        if (!hasRuntimePermission(context, android.Manifest.permission.SEND_SMS)) {
            perms.add(android.Manifest.permission.SEND_SMS)
        }
        if (!hasRuntimePermission(context, android.Manifest.permission.READ_CONTACTS)) {
            perms.add(android.Manifest.permission.READ_CONTACTS)
        }
        if (perms.isNotEmpty()) {
            activity.requestPermissions(perms.toTypedArray(), 102)
        }
        if (!notificationManager.isNotificationPolicyAccessGranted) {
            activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
        }
    }

    override fun onMethodCall(
        activity: Activity,
        method: String,
        call: MethodCall,
        result: MethodChannel.Result
    ): Boolean {
        return when (method) {
            "replyToNotification" -> {
                val id = call.argument<Number>("id")?.toInt() ?: (call.argument<String>("key")?.lowercase()?.hashCode()?.and(0x7FFFFFFF) ?: 0)
                val message = call.argument<String>("message") ?: ""
                notificationsManager.replyToNotification(id, message)
                result.success(null)
                true
            }

            "getDnd" -> {
                result.success(notificationsManager.getDnd())
                true
            }

            "setDnd" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                notificationsManager.setDnd(enabled)
                result.success(null)
                true
            }

            "dismissNotification" -> {
                val id = call.argument<Number>("id")?.toInt() ?: (call.argument<String>("key")?.lowercase()?.hashCode()?.and(0x7FFFFFFF) ?: 0)
                notificationsManager.dismissNotification(id)
                result.success(null)
                true
            }

            "triggerNotificationAction" -> {
                val id = call.argument<Number>("id")?.toInt() ?: (call.argument<String>("key")?.lowercase()?.hashCode()?.and(0x7FFFFFFF) ?: 0)
                val action = call.argument<String>("action") ?: ""
                val success = notificationsManager.triggerNotificationAction(id, action)
                result.success(success)
                true
            }

            "openNotificationOnPhone" -> {
                val id = call.argument<Number>("id")?.toInt() ?: (call.argument<String>("key")?.lowercase()?.hashCode()?.and(0x7FFFFFFF) ?: 0)
                val success = notificationsManager.openNotificationOnPhone(id)
                result.success(success)
                true
            }

            "getAppIcon" -> {
                val packageName = call.argument<String>("packageName") ?: ""
                val size = call.argument<Int>("size") ?: 96
                val iconBytes = notificationsManager.getAppIcon(packageName, size)
                result.success(iconBytes)
                true
            }

            "getApps" -> {
                Thread {
                    try {
                        val appList = notificationsManager.getApps()
                        result.success(appList)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }.start()
                true
            }

            "sendText" -> {
                val recipients: List<String> = when (val raw = call.argument<Any>("phoneNumber") ?: call.argument<Any>("recipients") ?: call.argument<Any>("numbers")) {
                    is List<*> -> raw.mapNotNull { it?.toString() }
                    is String -> listOf(raw)
                    else -> emptyList()
                }
                val message = call.argument<String>("message") ?: ""
                val success = notificationsManager.sendText(recipients, message)
                result.success(success)
                true
            }

            "pickContact" -> {
                val currentActivity = activity
                if (currentActivity != null) {
                    pendingContactResult = result
                    val intent = Intent(Intent.ACTION_PICK, android.provider.ContactsContract.CommonDataKinds.Phone.CONTENT_URI)
                    currentActivity.startActivityForResult(intent, REQUEST_CODE_PICK_CONTACT)
                } else {
                    result.success(null)
                }
                true
            }

            "getNotificationMeta" -> {
                val id = call.argument<Number>("id")?.toInt() ?: (call.argument<String>("key")?.lowercase()?.hashCode()?.and(0x7FFFFFFF) ?: 0)
                val metaMap = notificationsManager.getNotificationMeta(id)
                result.success(metaMap)
                true
            }

            "getActiveMetas" -> {
                val metaList = notificationsManager.getAllNotificationMetas()
                result.success(metaList)
                true
            }

            else -> false
        }
    }

    private var activity: Activity? = null
    private var pendingContactResult: MethodChannel.Result? = null

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQUEST_CODE_PICK_CONTACT) {
            val result = pendingContactResult
            pendingContactResult = null
            if (resultCode == Activity.RESULT_OK && data != null && data.data != null) {
                try {
                    val contactUri = data.data!!
                    val projection = arrayOf(
                        android.provider.ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                        android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER
                    )
                    context.contentResolver.query(contactUri, projection, null, null, null)?.use { cursor ->
                        if (cursor.moveToFirst()) {
                            val nameCol = cursor.getColumnIndex(android.provider.ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                            val numCol = cursor.getColumnIndex(android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER)
                            val name = if (nameCol != -1) cursor.getString(nameCol) else ""
                            val number = if (numCol != -1) cursor.getString(numCol) else ""
                            result?.success(mapOf("name" to name, "phone" to number))
                            return true
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error resolving picked contact", e)
                }
            }
            result?.success(null)
            return true
        }
        return false
    }

    companion object {
        const val REQUEST_CODE_PICK_CONTACT = 9001
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val pkgName = context.packageName
        val flat = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
        if (!flat.isNullOrEmpty()) {
            val names = flat.split(":")
            for (name in names) {
                val cn = android.content.ComponentName.unflattenFromString(name)
                if (cn != null && pkgName == cn.packageName) {
                    return true
                }
            }
        }
        return false
    }

    private fun sendDndUpdate() {
        val isDnd = notificationsManager.getDnd()
        methodChannel?.invokeMethod("dndChanged", isDnd)
    }
}
