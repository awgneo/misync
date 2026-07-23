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
            "kind" to meta.kind,
            "secondary" to meta.secondary,
            "phone" to meta.phone,
            "replyable" to meta.replyable,
            "actions" to meta.actions,
            "timestamp" to meta.timestamp
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
            "kind" to meta.kind,
            "secondary" to meta.secondary,
            "phone" to meta.phone,
            "replyable" to meta.replyable,
            "actions" to meta.actions,
            "timestamp" to meta.timestamp
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
                "kind" to meta.kind,
                "secondary" to meta.secondary,
                "phone" to meta.phone,
                "replyable" to meta.replyable,
                "actions" to meta.actions,
                "timestamp" to meta.timestamp
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
        val service = NotificationsService.instance
            ?: throw IllegalStateException("Notifications listener service is not running")
        val success = service.reply(id, message)
        if (!success) {
            Log.w(TAG, "Reply failed for notification id $id")
        }
        return success
    }

    fun dismissNotification(id: Int): Boolean {
        val service = NotificationsService.instance
            ?: throw IllegalStateException("Notifications listener service is not running")
        return service.dismiss(id)
    }

    fun triggerNotificationAction(id: Int, actionKeyword: String): Boolean {
        val service = NotificationsService.instance
            ?: throw IllegalStateException("Notifications listener service is not running")
        return service.triggerNotificationAction(id, actionKeyword)
    }

    fun openNotificationOnPhone(id: Int): Boolean {
        val service = NotificationsService.instance
            ?: throw IllegalStateException("Notifications listener service is not running")
        return service.openNotificationOnPhone(id)
    }

    fun getApps(): List<Map<String, Any>> {
        val pm = context.packageManager
        val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolveInfos = pm.queryIntentActivities(mainIntent, 0)
        val appsMap = mutableMapOf<String, String>()

        for (ri in resolveInfos) {
            val pkg = ri.activityInfo.packageName
            if (pkg == context.packageName) continue
            val label = ri.loadLabel(pm).toString()
            if (!appsMap.containsKey(pkg)) {
                appsMap[pkg] = label
            }
        }

        return appsMap.entries.map { (pkg, name) ->
            mapOf(
                "package" to pkg,
                "name" to name
            )
        }.sortedBy { (it["name"] as String).lowercase() }
    }

    fun getAppIcon(packageName: String, sizePx: Int = 96): ByteArray? {
        return try {
            val pm = context.packageManager
            val drawable = pm.getApplicationIcon(packageName)
            val bitmap = drawableToBitmap(drawable, sizePx, sizePx)
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        } catch (e: Exception) {
            Log.e(TAG, "Error getting app icon for $packageName", e)
            null
        }
    }

    private fun drawableToBitmap(drawable: Drawable, width: Int, height: Int): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            return Bitmap.createScaledBitmap(drawable.bitmap, width, height, true)
        }
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }
}
