package com.misync.notifications

import android.service.notification.NotificationListenerService
import android.telephony.SmsManager
import android.service.notification.StatusBarNotification
import android.content.Intent
import android.os.Bundle
import android.os.Build
import android.app.RemoteInput
import android.app.Notification
import android.util.Log

class NotificationsService : NotificationListenerService() {
    private val TAG = "NotificationsService"

    companion object {
        const val ACTION_NOTIFICATION_RECEIVED = "com.misync.action.NOTIFICATION_RECEIVED"
        const val ACTION_NOTIFICATION_REMOVED = "com.misync.action.NOTIFICATION_REMOVED"
        const val EXTRA_PACKAGE = "package"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_ID = "id"
        const val EXTRA_KEY = "key"
        const val EXTRA_APP = "app"
        const val EXTRA_CATEGORY = "category"
        const val EXTRA_PHONE = "phone"
        const val EXTRA_REPLYABLE = "replyable"

        var instance: NotificationsService? = null
            private set
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "NotificationsService created")
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "NotificationsService connected")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val packageName = sbn.packageName
        val notification = sbn.notification

        // Skip group summaries (generic grouped message container notifications)
        if ((notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0) {
            Log.d(TAG, "Filtering out group summary notification from $packageName")
            return
        }

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
        val category = notification.category ?: ""

        val isCall = isCallNotification(packageName, category)

        var phoneNumber = ""
        if (isCall) {
            phoneNumber = extractPhoneNumber(sbn)
        }

        var hasRemoteInput = isCall
        if (!hasRemoteInput) {
            val actions = notification.actions
            if (actions != null) {
                for (action in actions) {
                    val ris = action.remoteInputs
                    if (ris != null) {
                        for (ri in ris) {
                            if (ri.resultKey != null) {
                                hasRemoteInput = true
                                break
                            }
                        }
                    }
                    if (hasRemoteInput) break
                }
            }
        }

        Log.d(
            TAG,
            "Notification received from: $packageName ($appName), title: $title, body: $body, category: $category, phoneNumber: $phoneNumber, hasRemoteInput: $hasRemoteInput"
        )

        val intent = Intent(ACTION_NOTIFICATION_RECEIVED).apply {
            putExtra(EXTRA_PACKAGE, packageName)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
            putExtra(EXTRA_ID, id)
            putExtra(EXTRA_KEY, key)
            putExtra(EXTRA_APP, appName)
            putExtra(EXTRA_CATEGORY, category)
            putExtra(EXTRA_PHONE, phoneNumber)
            putExtra(EXTRA_REPLYABLE, hasRemoteInput)
            setPackage(this@NotificationsService.packageName)
        }
        sendBroadcast(intent)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName
        val id = sbn.id
        val key = sbn.key
        val category = sbn.notification.category ?: ""

        val intent = Intent(ACTION_NOTIFICATION_REMOVED).apply {
            putExtra(EXTRA_PACKAGE, packageName)
            putExtra(EXTRA_ID, id)
            putExtra(EXTRA_KEY, key)
            putExtra(EXTRA_CATEGORY, category)
            setPackage(this@NotificationsService.packageName)
        }
        sendBroadcast(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "NotificationsService destroyed")
    }

    // Function to send a quick reply back to the notification sender
    fun reply(key: String, replyText: String): Boolean {
        val activeNotifications = activeNotifications ?: return false
        val sbn = activeNotifications.find { it.key == key } ?: return false
        val notification = sbn.notification
        val category = notification.category ?: ""
        val packageName = sbn.packageName

        val isCall = isCallNotification(packageName, category)

        if (isCall) {
            val phoneNumber = extractPhoneNumber(sbn)
            if (phoneNumber.isNotEmpty()) {
                // 1. Decline the call first
                declineCall(key)

                // 2. Send SMS
                try {
                    val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        this.getSystemService(SmsManager::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        SmsManager.getDefault()
                    }
                    smsManager.sendTextMessage(phoneNumber, null, replyText, null, null)
                    Log.d(TAG, "SMS call quick reply sent to $phoneNumber successfully")
                    return true
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to send SMS call reply to $phoneNumber", e)
                }
            } else {
                Log.w(TAG, "Cannot send SMS reply: Phone number is empty")
            }
            return false
        }

        val actions = notification.actions ?: return false
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

    fun declineCall(key: String): Boolean {
        Log.d(TAG, "declineCall called for key: $key")
        val activeNotifications = activeNotifications ?: return false

        // Try exact match first
        var sbn = activeNotifications.find { it.key == key }

        // Fallback: search for any active call notification ONLY if the target key is call-related
        if (sbn == null) {
            val parts = key.split("|")
            val isCallKey = if (parts.size >= 2) {
                isCallPackage(parts[1])
            } else {
                true // Default to true if key format is not standard
            }

            if (isCallKey) {
                Log.d(TAG, "Exact notification not found for key: $key. Searching active notifications for call...")
                sbn = activeNotifications.find { s ->
                    isCallNotification(s.packageName, s.notification.category)
                }
            } else {
                Log.d(TAG, "Exact notification not found for non-call key: $key. Skipping call-decline fallback.")
            }
        }

        if (sbn == null) {
            Log.w(TAG, "No call notification found to decline")
            return false
        }

        val actions = sbn.notification.actions
        if (actions == null) {
            Log.w(TAG, "No actions found for notification: ${sbn.key}")
            return false
        }

        Log.d(TAG, "Found actions for call notification ${sbn.key}: ${actions.map { it.title?.toString() }}")

        val keywords = listOf("decline", "hang", "reject", "挂断", "拒", "拒绝", "dismiss", "ignore")
        for (action in actions) {
            val title = action.title?.toString()?.lowercase() ?: continue
            if (keywords.any { title.contains(it) }) {
                try {
                    action.actionIntent.send()
                    Log.d(TAG, "Successfully triggered decline action: ${action.title} for key: ${sbn.key}")
                    return true
                } catch (e: Exception) {
                    Log.e(TAG, "Error triggering decline action for key: ${sbn.key}", e)
                }
            }
        }
        return false
    }

    fun declineCallById(id: Int): Boolean {
        val activeNotifications = activeNotifications ?: return false
        val sbn = activeNotifications.find { it.id == id } ?: return false
        return declineCall(sbn.key)
    }

    fun dismiss(key: String): Boolean {
        Log.d(TAG, "dismiss called for key: $key")
        try {
            if (declineCall(key)) {
                return true
            }

            val active = activeNotifications ?: emptyArray()
            Log.d(TAG, "Active notification keys (${active.size}): ${active.map { it.key }}")

            // Try exact match first in active list
            var targetKey = key
            val exactMatch = active.find { it.key == key }

            if (exactMatch == null) {
                // Fallback: Parse package name and ID/tag from key
                // Key format is typically: userId|packageName|id|tag|uid
                val parts = key.split("|")
                if (parts.size >= 3) {
                    val pkg = parts[1]
                    val idStr = parts[2]
                    val id = idStr.toIntOrNull()
                    if (id != null) {
                        // Find by package name and ID
                        val fallbackMatch = active.find { it.packageName == pkg && it.id == id }
                        if (fallbackMatch != null) {
                            Log.d(TAG, "Exact key not found, found fallback match by package and ID: ${fallbackMatch.key}")
                            targetKey = fallbackMatch.key
                        }
                    }
                }
            }

            cancelNotification(targetKey)
            Log.d(TAG, "Notification dismissed successfully for key: $targetKey")
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

    private fun extractPhoneNumber(sbn: StatusBarNotification): String {
        val notification = sbn.notification
        val extras = notification.extras
        var phoneNumber = extras.getString("android.phoneNumber") ?: ""
        if (phoneNumber.isEmpty()) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val person = extras.getParcelable<android.app.Person>("android.callPerson")
                val uriStr = person?.uri?.toString() ?: ""
                if (uriStr.startsWith("tel:")) {
                    phoneNumber = uriStr.substring(4)
                } else if (uriStr.startsWith("content://com.android.contacts/")) {
                    try {
                        val contactUri = android.net.Uri.parse(uriStr)
                        val cursor = contentResolver.query(contactUri, null, null, null, null)
                        if (cursor != null) {
                            if (cursor.moveToFirst()) {
                                val idCol = cursor.getColumnIndex(android.provider.ContactsContract.Contacts._ID)
                                if (idCol != -1) {
                                    val contactId = cursor.getString(idCol)
                                    val phones = contentResolver.query(
                                        android.provider.ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                                        arrayOf(android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER),
                                        android.provider.ContactsContract.CommonDataKinds.Phone.CONTACT_ID + " = ?",
                                        arrayOf(contactId), null
                                    )
                                    if (phones != null) {
                                        if (phones.moveToFirst()) {
                                            phoneNumber = phones.getString(0)
                                        }
                                        phones.close()
                                    }
                                }
                            }
                            cursor.close()
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error resolving contact URI in extractPhoneNumber: $uriStr", e)
                    }
                }
            }
        }
        if (phoneNumber.isEmpty() && extras.getCharSequence("android.title") != null) {
            val title = extras.getCharSequence("android.title").toString()
            if (title.matches(Regex("^[+]?[0-9\\s\\-()]{7,20}$"))) {
                phoneNumber = title.replace("\\s".toRegex(), "")
            }
        }
        return phoneNumber
    }

    private fun isCallPackage(packageName: String): Boolean {
        val pkg = packageName.lowercase()
        return pkg.contains("dialer") ||
               pkg.contains("telecom") ||
               pkg.contains("phone") ||
               pkg.contains("call")
    }

    private fun isCallNotification(packageName: String, category: String?): Boolean {
        return (category ?: "") == Notification.CATEGORY_CALL || isCallPackage(packageName)
    }
}
