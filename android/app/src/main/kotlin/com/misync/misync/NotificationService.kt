package com.misync.misync

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.content.Intent
import android.os.Bundle
import android.app.RemoteInput
import android.util.Log
import android.content.Context

class NotificationService : NotificationListenerService() {
    private val TAG = "NotificationService"

    companion object {
        const val ACTION_NOTIFICATION = "com.misync.misync.NOTIFICATION_RECEIVED"
        const val EXTRA_PACKAGE = "package"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_ID = "id"
        const val EXTRA_KEY = "key"
        const val EXTRA_APP_NAME = "appName"

        var instance: NotificationService? = null
            private set
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "NotificationService created")
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "NotificationService connected")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val packageName = sbn.packageName
        val notification = sbn.notification
        val extras = notification.extras

        // Get friendly app label
        val pm = packageManager
        val appName = try {
            val appInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            val last = packageName.split(".").lastOrNull() ?: packageName
            last.replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
        }

        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        var body = extras.getCharSequence("android.text")?.toString()
            ?: extras.getCharSequence("android.bigText")?.toString()
            ?: ""

        // Extract message from MessagingStyle if body is empty or generic
        val messages = extras.get("android.messages") as? Array<*>
        if (messages != null && messages.isNotEmpty()) {
            val lastMessage = messages.lastOrNull() as? Bundle
            if (lastMessage != null) {
                val text = lastMessage.getCharSequence("text")?.toString()
                if (!text.isNullOrEmpty()) {
                    body = text
                }

                // If group chat, prepend sender's name if title doesn't already match it
                val senderBundle = lastMessage.get("sender_person") as? Bundle
                val senderName = senderBundle?.getCharSequence("name")?.toString()
                    ?: lastMessage.getCharSequence("sender")?.toString()

                if (!senderName.isNullOrEmpty() && title != senderName) {
                    body = "$senderName: $body"
                }
            }
        }

        val id = sbn.id
        val key = sbn.key

        Log.d(TAG, "Notification received from: $packageName ($appName), title: $title, body: $body")

        val intent = Intent(ACTION_NOTIFICATION).apply {
            putExtra(EXTRA_PACKAGE, packageName)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
            putExtra(EXTRA_ID, id)
            putExtra(EXTRA_KEY, key)
            putExtra(EXTRA_APP_NAME, appName)
            setPackage(this@NotificationService.packageName)
        }
        sendBroadcast(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "NotificationService destroyed")
    }

    // Function to send a quick reply back to the notification sender
    fun reply(key: String, replyText: String): Boolean {
        val activeNotifications = activeNotifications ?: return false
        val sbn = activeNotifications.find { it.key == key } ?: return false
        val actions = sbn.notification.actions ?: return false

        for (action in actions) {
            val remoteInputs = action.remoteInputs ?: continue
            for (remoteInput in remoteInputs) {
                if (remoteInput.resultKey != null) {
                    val intent = Intent().apply {
                        val bundle = Bundle().apply {
                            putCharSequence(remoteInput.resultKey, replyText)
                        }
                        RemoteInput.addResultsToIntent(arrayOf(remoteInput), this, bundle)
                    }
                    try {
                        action.actionIntent.send(this, 0, intent)
                        Log.d(TAG, "Reply sent successfully to notification key: $key")
                        return true
                    } catch (e: Exception) {
                        Log.e(TAG, "Error sending reply to notification: ", e)
                    }
                }
            }
        }
        Log.w(TAG, "No valid reply action found for notification key: $key")
        return false
    }

    fun replyById(id: Int, replyText: String): Boolean {
        val activeNotifications = activeNotifications ?: return false
        val sbn = activeNotifications.find { it.id == id } ?: return false
        return reply(sbn.key, replyText)
    }

    fun dismiss(key: String): Boolean {
        try {
            cancelNotification(key)
            Log.d(TAG, "Notification dismissed successfully for key: $key")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error dismissing notification: ", e)
        }
        return false
    }

    fun dismissById(id: Int): Boolean {
        val activeNotifications = activeNotifications ?: return false
        val sbn = activeNotifications.find { it.id == id } ?: return false
        return dismiss(sbn.key)
    }
}
