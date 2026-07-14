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
            if (intent?.action == NotificationsService.ACTION_NOTIFICATION) {
                val packageName = intent.getStringExtra(NotificationsService.EXTRA_PACKAGE) ?: ""
                val title = intent.getStringExtra(NotificationsService.EXTRA_TITLE) ?: ""
                val body = intent.getStringExtra(NotificationsService.EXTRA_BODY) ?: ""
                val id = intent.getIntExtra(NotificationsService.EXTRA_ID, 0)
                val key = intent.getStringExtra(NotificationsService.EXTRA_KEY) ?: ""
                val appName = intent.getStringExtra(NotificationsService.EXTRA_APP_NAME) ?: ""
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
                methodChannel?.invokeMethod("notificationReceived", data)
            } else if (intent?.action == NotificationsService.ACTION_NOTIFICATION_REMOVED) {
                val packageName = intent.getStringExtra(NotificationsService.EXTRA_PACKAGE) ?: ""
                val id = intent.getIntExtra(NotificationsService.EXTRA_ID, 0)
                val key = intent.getStringExtra(NotificationsService.EXTRA_KEY) ?: ""
                val category = intent.getStringExtra("category") ?: ""

                val data = mapOf(
                    "package" to packageName,
                    "id" to id,
                    "key" to key,
                    "category" to category
                )
                methodChannel?.invokeMethod("notificationRemoved", data)
            }
        }
    }

    override fun onCreate() {
        val filter = IntentFilter().apply {
            addAction(NotificationsService.ACTION_NOTIFICATION)
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
    }

    override fun onDestroy() {
        try {
            context.unregisterReceiver(notificationReceiver)
        } catch (e: Exception) {
            // Ignored
        }
        try {
            context.unregisterReceiver(dndReceiver)
        } catch (e: Exception) {
            // Ignored
        }
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

    override fun onMethodCall(activity: Activity, method: String, call: MethodCall, result: MethodChannel.Result): Boolean {
        return when (method) {
            "replyToNotification" -> {
                val key = call.argument<String>("key")
                val id = call.argument<Int>("id")
                val message = call.argument<String>("message") ?: ""
                val success = notificationsManager.replyToNotification(key, id, message)
                result.success(success)
                true
            }
            "getDnd" -> {
                result.success(notificationsManager.getDnd())
                true
            }
            "setDnd" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                val success = notificationsManager.setDnd(enabled)
                result.success(success)
                true
            }
            "dismissNotification" -> {
                val key = call.argument<String>("key")
                val id = call.argument<Int>("id")
                val success = notificationsManager.dismissNotification(key, id)
                result.success(success)
                true
            }
            "getAppIcon" -> {
                val packageName = call.argument<String>("packageName") ?: ""
                val size = call.argument<Int>("size") ?: 96
                try {
                    val iconBytes = notificationsManager.getAppIcon(packageName, size)
                    result.success(iconBytes)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to get app icon for $packageName", e)
                    result.error("ERROR", e.message, null)
                }
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
            "sendSms" -> {
                val phoneNumber = call.argument<String>("phoneNumber") ?: ""
                val message = call.argument<String>("message") ?: ""
                val success = notificationsManager.sendSms(phoneNumber, message)
                result.success(success)
                true
            }
            "getDefaultSmsPackage" -> {
                result.success(notificationsManager.getDefaultSmsPackage())
                true
            }
            else -> false
        }
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
