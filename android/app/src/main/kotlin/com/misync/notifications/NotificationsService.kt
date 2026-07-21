package com.misync.notifications

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.content.Intent
import android.os.Bundle
import android.os.Build
import android.app.RemoteInput
import android.app.Notification
import android.util.Log

data class NotificationMeta(
    val key: String,
    val id: Int,
    val `package`: String,
    val app: String,
    val title: String,
    val body: String,
    val category: String,
    val phone: String,
    val replyable: Boolean,
    val kind: String,
    val sbn: StatusBarNotification? = null
)

class NotificationsService : NotificationListenerService() {
    private val TAG = "NotificationsService"
    val activeMetas = java.util.concurrent.ConcurrentHashMap<String, NotificationMeta>()

    companion object {
        const val ACTION_NOTIFICATION_RECEIVED = "com.misync.notifications.NOTIFICATION_RECEIVED"
        const val ACTION_NOTIFICATION_REMOVED = "com.misync.notifications.NOTIFICATION_REMOVED"
        const val EXTRA_PACKAGE = "package"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_ID = "id"
        const val EXTRA_KEY = "key"
        const val EXTRA_APP = "app"
        const val EXTRA_CATEGORY = "category"
        const val EXTRA_PHONE = "phone"
        const val EXTRA_REPLYABLE = "replyable"
        const val EXTRA_KIND = "kind"

        var instance: NotificationsService? = null
            private set
    }

    private lateinit var notificationsManager: NotificationsManager

    override fun onCreate() {
        super.onCreate()
        instance = this
        notificationsManager = NotificationsManager(this)
        Log.d(TAG, "NotificationsService created")
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "NotificationsService connected")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val packageName = sbn.packageName
        val notification = sbn.notification

        // Skip group summaries and ongoing background service notifications (e.g. "Connecting...")
        if ((notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0) {
            Log.d(TAG, "Filtering out group summary notification from $packageName")
            return
        }

        val category = notification.category ?: ""
        val isDialer = isCallPackage(packageName)
        val isCall = isCallNotification(packageName, category)

        if (!isCall && (notification.flags and Notification.FLAG_ONGOING_EVENT) != 0) {
            Log.d(TAG, "Filtering out ongoing background event from $packageName")
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

        // Extract message & sender details from standard Android MessagingStyle
        var hasSenderPerson = false
        val messages = extras.get("android.messages") as? Array<*>
        if (messages != null && messages.isNotEmpty()) {
            val lastMessage = messages.lastOrNull() as? Bundle
            if (lastMessage != null) {
                val text = lastMessage.getCharSequence("text")?.toString()
                if (!text.isNullOrEmpty()) {
                    body = text
                }

                val senderBundle = lastMessage.get("sender_person") as? Bundle
                val senderName = senderBundle?.getCharSequence("name")?.toString()
                    ?: lastMessage.getCharSequence("sender")?.toString()

                if (!senderName.isNullOrEmpty()) {
                    hasSenderPerson = true
                    if (title != senderName) {
                        body = "$senderName: $body"
                    }
                }
            }
        }

        val id = sbn.id
        val normKey = sbn.key.lowercase()

        // Deduplicate identical notification body updates for active notifications
        val existingMeta = activeMetas[normKey]
        if (existingMeta != null && existingMeta.body == body) {
            Log.d(TAG, "Filtering out duplicate notification body update for key=$normKey")
            return
        }

        // Filter out transient Gmail action confirmation notifications
        if (packageName == "com.google.android.gm") {
            val cleanBody = body.lowercase().trim().replace(".", "")
            val cleanTitle = title.lowercase().trim().replace(".", "")
            if (cleanBody == "archived" || cleanTitle == "archived" ||
                cleanBody == "deleted" || cleanTitle == "deleted" ||
                cleanBody == "1 archived" || cleanTitle == "1 archived" ||
                cleanBody == "1 deleted" || cleanTitle == "1 deleted" ||
                cleanBody == "undo" || cleanTitle == "undo" ||
                cleanBody == "marked read" || cleanTitle == "marked read" ||
                cleanBody == "marked unread" || cleanTitle == "marked unread") {
                Log.d(TAG, "Filtering out Gmail transient action confirmation: title=$title, body=$body")
                return
            }
        }

        // Voicemails & Missed Calls Filter
        if (isDialer && category != Notification.CATEGORY_CALL) {
            Log.d(TAG, "Filtering out missed call/voicemail dialer notification from $packageName")
            return
        }

        if (isCall) {
            var hasAnswerAction = false
            val actions = notification.actions
            if (actions != null) {
                for (action in actions) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        if (action.semanticAction == 8) {
                            hasAnswerAction = true
                            break
                        }
                    }
                    val titleText = action.title?.toString()?.lowercase() ?: ""
                    if (titleText.contains("answer") || titleText.contains("accept") || titleText.contains("接听") || titleText.contains("contestar")) {
                        hasAnswerAction = true
                        break
                    }
                }
            }
            if (!hasAnswerAction) {
                Log.d(TAG, "Filtering out non-ringing call notification from $packageName (no answer action)")
                return
            }
        }

        val defaultSmsPkg = android.provider.Telephony.Sms.getDefaultSmsPackage(this)
        val rawKind = when {
            isCall -> "call"
            category == Notification.CATEGORY_EMAIL || packageName == "com.google.android.gm" -> "email"
            category == Notification.CATEGORY_MESSAGE || (defaultSmsPkg != null && packageName == defaultSmsPkg) -> "text"
            else -> "standard"
        }

        var phoneNumber = ""
        if (isCall) {
            phoneNumber = extractPhoneNumber(sbn)
            if (body.isEmpty() || body == title) {
                body = if (appName.isNotEmpty() && appName.lowercase() != "phone") "Incoming $appName Call" else "Incoming Call"
            }
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

        // Standard Android MessagingStyle check: If CATEGORY_MESSAGE has a MessagingStyle payload
        // but no sender person (e.g. automated app notices/updates), treat as standard non-replyable notification.
        val finalKind: String
        val finalReplyable: Boolean
        if (category == Notification.CATEGORY_MESSAGE && defaultSmsPkg != packageName && messages != null && !hasSenderPerson) {
            finalKind = "standard"
            finalReplyable = false
        } else {
            finalKind = rawKind
            finalReplyable = hasRemoteInput
        }

        Log.d(
            TAG,
            "Notification received: $packageName ($appName), title: $title, body: $body, key: $normKey, kind: $finalKind, replyable: $finalReplyable"
        )

        val intent = Intent(ACTION_NOTIFICATION_RECEIVED).apply {
            putExtra(EXTRA_PACKAGE, packageName)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
            putExtra(EXTRA_ID, id)
            putExtra(EXTRA_KEY, normKey)
            putExtra(EXTRA_APP, appName)
            putExtra(EXTRA_CATEGORY, category)
            putExtra(EXTRA_PHONE, phoneNumber)
            putExtra(EXTRA_REPLYABLE, finalReplyable)
            putExtra(EXTRA_KIND, finalKind)
            setPackage(this@NotificationsService.packageName)
        }

        val meta = NotificationMeta(
            key = normKey,
            id = id,
            `package` = packageName,
            app = appName,
            title = title,
            body = body,
            category = category,
            phone = phoneNumber,
            replyable = finalReplyable,
            kind = finalKind,
            sbn = sbn
        )
        activeMetas[normKey] = meta

        sendBroadcast(intent)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
        if (sbn == null) return

        val normKey = sbn.key.lowercase()
        activeMetas.remove(normKey)

        val intent = Intent(ACTION_NOTIFICATION_REMOVED).apply {
            putExtra(EXTRA_PACKAGE, sbn.packageName)
            putExtra(EXTRA_ID, sbn.id)
            putExtra(EXTRA_KEY, normKey)
            putExtra(EXTRA_CATEGORY, sbn.notification.category ?: "")
            setPackage(this@NotificationsService.packageName)
        }
        sendBroadcast(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "NotificationsService destroyed")
    }

    fun getMeta(key: String): NotificationMeta? {
        if (key.isNotEmpty()) {
            val meta = activeMetas[key.lowercase()]
            if (meta != null) return meta
        }
        return activeMetas.values.lastOrNull { it.replyable || it.kind == "text" || it.kind == "call" }
            ?: activeMetas.values.lastOrNull()
    }

    // Function to send a quick reply back to the notification sender
    fun reply(key: String, replyText: String): Boolean {
        val meta = getMeta(key)
        if (meta == null || meta.sbn == null) {
            Log.w(TAG, "Cannot reply: no active replyable notification found for key: $key")
            return false
        }
        val sbn = meta.sbn
        val notification = sbn.notification
        val category = notification.category ?: ""
        val packageName = sbn.packageName

        // 1. Try RemoteInput on target notification or matching active chat notification from same app
        var targetAction: Notification.Action? = null
        var targetRemoteInput: RemoteInput? = null

        val actions = notification.actions
        if (actions != null) {
            for (action in actions) {
                val ris = action.remoteInputs ?: continue
                for (ri in ris) {
                    if (ri.resultKey != null) {
                        targetAction = action
                        targetRemoteInput = ri
                        break
                    }
                }
                if (targetAction != null) break
            }
        }

        // If target notification (e.g. Signal Call card) has no RemoteInput, search activeMetas for a chat card from same app
        if (targetAction == null) {
            val matchingChatMeta = activeMetas.values.find {
                it.`package` == packageName && it.sbn != null && it.replyable && it.kind != "call"
            }
            if (matchingChatMeta != null && matchingChatMeta.sbn != null) {
                val chatActions = matchingChatMeta.sbn.notification.actions
                if (chatActions != null) {
                    for (action in chatActions) {
                        val ris = action.remoteInputs ?: continue
                        for (ri in ris) {
                            if (ri.resultKey != null) {
                                targetAction = action
                                targetRemoteInput = ri
                                break
                            }
                        }
                        if (targetAction != null) break
                    }
                }
            }
        }

        // Execute RemoteInput if found
        if (targetAction != null && targetRemoteInput != null) {
            val intent = Intent().apply {
                val bundle = Bundle().apply {
                    putCharSequence(targetRemoteInput.resultKey, replyText)
                }
                RemoteInput.addResultsToIntent(arrayOf(targetRemoteInput), this, bundle)
            }
            try {
                targetAction.actionIntent.send(this, 0, intent)
                declineCall(meta.key)
                Log.d(TAG, "Reply sent successfully via RemoteInput for key: ${meta.key}")
                return true
            } catch (e: Exception) {
                Log.e(TAG, "Error sending RemoteInput reply: ", e)
            }
        }

        // 2. Fallback to SMS text for cellular calls with no RemoteInput action
        val isCall = isCallNotification(packageName, category)
        if (isCall) {
            val phoneNumber = extractPhoneNumber(sbn)
            if (phoneNumber.isNotEmpty()) {
                declineCall(meta.key)
                return notificationsManager.sendText(listOf(phoneNumber), replyText)
            }
        }

        Log.w(TAG, "No valid reply action found for notification key: ${meta.key}")
        return false
    }

    fun replyById(id: Int, replyText: String): Boolean {
        val meta = activeMetas.values.find { it.id == id } ?: return false
        return reply(meta.key, replyText)
    }

    fun declineCall(key: String): Boolean {
        Log.d(TAG, "declineCall called for key: $key")
        val meta = getMeta(key) ?: return false
        val sbn = meta.sbn ?: return false
        val actions = sbn.notification.actions ?: return false

        // 1. Check for Android P+ SEMANTIC_ACTION_CALL_DECLINE (2)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            for (action in actions) {
                if (action.semanticAction == 2 /* SEMANTIC_ACTION_CALL_DECLINE */) {
                    try {
                        action.actionIntent.send()
                        Log.d(TAG, "Successfully triggered semantic DECLINE action (2) for key: ${meta.key}")
                        cancelNotification(sbn.key)
                        activeMetas.remove(meta.key)
                        return true
                    } catch (e: Exception) {
                        Log.e(TAG, "Error triggering semantic decline action for key: ${meta.key}", e)
                    }
                }
            }
        }

        // 2. Keyword fallback matching
        val keywords = listOf("decline", "hang", "reject", "挂断", "拒", "拒绝", "dismiss", "ignore")
        for (action in actions) {
            val title = action.title?.toString()?.lowercase() ?: continue
            if (keywords.any { title.contains(it) }) {
                try {
                    action.actionIntent.send()
                    Log.d(TAG, "Successfully triggered decline action '${action.title}' for key: ${meta.key}")
                    cancelNotification(sbn.key)
                    activeMetas.remove(meta.key)
                    return true
                } catch (e: Exception) {
                    Log.e(TAG, "Error triggering decline action for key: ${meta.key}", e)
                }
            }
        }

        // 3. Fallback for cellular telecom calls
        if (isCallPackage(sbn.packageName) || meta.kind == "call") {
            try {
                val telecomManager = getSystemService(android.content.Context.TELECOM_SERVICE) as? android.telecom.TelecomManager
                if (telecomManager != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    telecomManager.endCall()
                    Log.d(TAG, "Ended call via TelecomManager.endCall()")
                    cancelNotification(sbn.key)
                    activeMetas.remove(meta.key)
                    return true
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error ending call via TelecomManager", e)
            }
        }

        return false
    }

    fun declineCallById(id: Int): Boolean {
        val meta = activeMetas.values.find { it.id == id } ?: return false
        return declineCall(meta.key)
    }

    fun dismiss(key: String): Boolean {
        Log.d(TAG, "dismiss called for key: $key")
        try {
            val meta = getMeta(key)
            if (meta != null && (meta.kind == "call" || isCallPackage(meta.`package`))) {
                declineCall(meta.key)
            }
            if (meta != null && meta.sbn != null) {
                cancelNotification(meta.sbn.key)
                activeMetas.remove(meta.key)
                Log.d(TAG, "Notification dismissed successfully for key: ${meta.key}")
                return true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error dismissing notification: ", e)
        }
        return false
    }

    fun dismissById(id: Int): Boolean {
        val meta = activeMetas.values.find { it.id == id } ?: return false
        return dismiss(meta.key)
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

    fun triggerNotificationAction(key: String, actionKeyword: String): Boolean {
        Log.d(TAG, "triggerNotificationAction called for key: $key, keyword: $actionKeyword")
        val meta = getMeta(key) ?: return false
        val sbn = meta.sbn ?: return false
        val actions = sbn.notification.actions ?: return false

        val targetSemanticAction = when (actionKeyword.lowercase()) {
            "archive" -> 5
            "delete" -> 4
            else -> -1
        }

        if (targetSemanticAction != -1) {
            for (action in actions) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    if (action.semanticAction == targetSemanticAction) {
                        try {
                            action.actionIntent.send()
                            Log.d(TAG, "Triggered semantic action $targetSemanticAction for key: ${meta.key}")
                            return true
                        } catch (e: Exception) {
                            Log.e(TAG, "Error triggering semantic action $targetSemanticAction", e)
                        }
                    }
                }
            }
        }

        for (action in actions) {
            val title = action.title?.toString()?.lowercase() ?: continue
            if (title.contains(actionKeyword.lowercase())) {
                try {
                    action.actionIntent.send()
                    Log.d(TAG, "Triggered keyword action '${action.title}' for key: ${meta.key}")
                    return true
                } catch (e: Exception) {
                    Log.e(TAG, "Error triggering keyword action '${action.title}'", e)
                }
            }
        }

        Log.w(TAG, "No action matching keyword '$actionKeyword' found for key: ${meta.key}")
        return false
    }

    fun openNotificationOnPhone(key: String): Boolean {
        Log.d(TAG, "openNotificationOnPhone called for key: $key")
        val meta = getMeta(key) ?: return false
        val sbn = meta.sbn ?: return false
        val contentIntent = sbn.notification.contentIntent

        try {
            com.misync.actions.DismissKeyguardActivity.launch(this, targetPendingIntent = contentIntent)
            cancelNotification(sbn.key)
            activeMetas.remove(meta.key)
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error launching notification intent from service", e)
        }
        return false
    }
}
