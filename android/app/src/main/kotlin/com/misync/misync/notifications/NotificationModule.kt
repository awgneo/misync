package com.misync.misync.notifications

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.provider.Settings
import android.util.Log
import com.misync.misync.base.BaseModule
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class NotificationModule(private val context: Context) : BaseModule("notifications") {
    private val TAG = "NotificationModule"

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
                methodChannel?.invokeMethod("notificationReceived", data)
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
                methodChannel?.invokeMethod("notificationRemoved", data)
            }
        }
    }

    override fun onCreate() {
        val filter = IntentFilter().apply {
            addAction(NotificationService.ACTION_NOTIFICATION)
            addAction(NotificationService.ACTION_NOTIFICATION_REMOVED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(notificationReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(notificationReceiver, filter)
        }
    }

    override fun onDestroy() {
        try {
            context.unregisterReceiver(notificationReceiver)
        } catch (e: Exception) {
            // Ignored
        }
    }

    override fun checkPermissions(): Boolean {
        return isNotificationServiceEnabled() &&
               hasRuntimePermission(context, android.Manifest.permission.SEND_SMS) &&
               hasRuntimePermission(context, android.Manifest.permission.READ_CONTACTS)
    }

    override fun requestPermissions(activity: Activity) {
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
    }

    override fun onMethodCall(activity: Activity, method: String, call: MethodCall, result: MethodChannel.Result): Boolean {
        return when (method) {
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
                true
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
                true
            }
            "getAppIcon" -> {
                val packageName = call.argument<String>("packageName") ?: ""
                val size = call.argument<Int>("size") ?: 96
                try {
                    val pm = context.packageManager
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
                true
            }
            "getApps" -> {
                Thread {
                    try {
                        val pm = context.packageManager
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

                        result.success(appList)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }.start()
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
