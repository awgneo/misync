package com.misync.notifications

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsManager
import android.util.Log
import android.app.NotificationManager
import java.io.ByteArrayOutputStream

class NotificationsManager(private val context: Context) {
    private val TAG = "NotificationsManager"

    fun sendText(recipients: List<String>, message: String): Boolean {
        var success = false
        val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            context.getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }

        for (recipient in recipients) {
            val number = recipient.trim()
            if (number.isNotEmpty()) {
                try {
                    smsManager.sendTextMessage(number, null, message, null, null)
                    Log.d(TAG, "SMS text sent to $number successfully")
                    success = true
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to send SMS to $number", e)
                }
            }
        }
        return success
    }

    fun getNotificationMeta(id: Int): Map<String, Any>? {
        val service = NotificationsService.instance ?: return null
        val meta = service.getMeta(id) ?: return null
        return mapOf(
            "key" to meta.key,
            "id" to meta.id,
            "package" to meta.`package`,
            "app" to meta.app,
            "title" to meta.title,
            "body" to meta.body,
            "category" to meta.category,
            "phone" to meta.phone,
            "replyable" to meta.replyable,
            "kind" to meta.kind,
            "actions" to meta.actions,
            "hasArchive" to meta.hasArchive,
            "hasDelete" to meta.hasDelete,
            "semanticActions" to meta.semanticActions,
            "isClearable" to meta.isClearable
        )
    }

    fun getNotificationMeta(key: String): Map<String, Any>? {
        val service = NotificationsService.instance ?: return null
        val meta = service.getMeta(key) ?: return null
        return mapOf(
            "key" to meta.key,
            "id" to meta.id,
            "package" to meta.`package`,
            "app" to meta.app,
            "title" to meta.title,
            "body" to meta.body,
            "category" to meta.category,
            "phone" to meta.phone,
            "replyable" to meta.replyable,
            "kind" to meta.kind,
            "actions" to meta.actions,
            "hasArchive" to meta.hasArchive,
            "hasDelete" to meta.hasDelete,
            "semanticActions" to meta.semanticActions,
            "isClearable" to meta.isClearable
        )
    }

    fun getAllNotificationMetas(): List<Map<String, Any>> {
        val service = NotificationsService.instance ?: return emptyList()
        service.syncActiveNotifications()
        return service.activeMetas.values.map { meta ->
            mapOf(
                "key" to meta.key,
                "id" to meta.id,
                "package" to meta.`package`,
                "app" to meta.app,
                "title" to meta.title,
                "body" to meta.body,
                "category" to meta.category,
                "phone" to meta.phone,
                "replyable" to meta.replyable,
                "kind" to meta.kind,
                "actions" to meta.actions,
                "hasArchive" to meta.hasArchive,
                "hasDelete" to meta.hasDelete,
                "semanticActions" to meta.semanticActions,
                "isClearable" to meta.isClearable
            )
        }
    }

    fun getDnd(): Boolean {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val filter = notificationManager.currentInterruptionFilter
        return filter == NotificationManager.INTERRUPTION_FILTER_NONE ||
                filter == NotificationManager.INTERRUPTION_FILTER_PRIORITY ||
                filter == NotificationManager.INTERRUPTION_FILTER_ALARMS
    }

    fun setDnd(enabled: Boolean): Boolean {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!notificationManager.isNotificationPolicyAccessGranted) {
            throw SecurityException("Notification policy access not granted")
        }
        val filter = if (enabled) {
            NotificationManager.INTERRUPTION_FILTER_PRIORITY
        } else {
            NotificationManager.INTERRUPTION_FILTER_ALL
        }
        notificationManager.setInterruptionFilter(filter)
        return true
    }

    fun replyToNotification(id: Int, message: String): Boolean {
        val service = NotificationsService.instance ?: throw IllegalStateException("Notifications listener service is not running")
        val success = service.reply(id, message)
        if (!success) {
            Log.w("NotificationsManager", "Cannot reply: id not found for id=$id")
            throw IllegalArgumentException("Notification not found or reply failed for id=$id")
        }
        return true
    }

    fun dismissNotification(id: Int): Boolean {
        val service = NotificationsService.instance ?: return false
        return service.dismiss(id)
    }

    fun triggerNotificationAction(id: Int, action: String): Boolean {
        val service = NotificationsService.instance ?: throw IllegalStateException("Notifications listener service is not running")
        return service.triggerNotificationAction(id, action)
    }

    fun openNotificationOnPhone(id: Int): Boolean {
        val service = NotificationsService.instance ?: throw IllegalStateException("Notifications listener service is not running")
        return service.openNotificationOnPhone(id)
    }


    fun getAppIcon(packageName: String, size: Int): ByteArray {
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
        return byteBuffer.array()
    }

    fun getApps(): List<Map<String, Any>> {
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
        return appList
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
