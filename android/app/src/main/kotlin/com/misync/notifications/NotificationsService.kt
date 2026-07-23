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
    val kind: String,        // "call", "text", "email", "standard"
    val secondary: Boolean,  // false = primary event (ringing call, new text/email), true = secondary notice (missed call, voicemail, archived, undo)
    val phone: String,
    val replyable: Boolean,
    val actions: List<String> = emptyList(),
    val timestamp: Long = 0L,
    val sbn: StatusBarNotification? = null
)

class NotificationsService : NotificationListenerService() {
    private val TAG = "NotificationsService"
    val activeMetas = java.util.concurrent.ConcurrentHashMap<Int, NotificationMeta>()

    companion object {
        const val ACTION_NOTIFICATION_RECEIVED = "com.misync.notifications.NOTIFICATION_RECEIVED"
        const val ACTION_NOTIFICATION_REMOVED = "com.misync.notifications.NOTIFICATION_REMOVED"
        const val EXTRA_PACKAGE = "package"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_ID = "id"
        const val EXTRA_KEY = "key"
        const val EXTRA_APP = "app"
        const val EXTRA_PHONE = "phone"
        const val EXTRA_REPLYABLE = "replyable"
        const val EXTRA_KIND = "kind"
        const val EXTRA_SECONDARY = "secondary"
        const val EXTRA_TIMESTAMP = "timestamp"

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

    fun syncActiveNotifications() {
        try {
            activeMetas.clear()
            val activeNotifs = activeNotifications ?: return
            Log.d(TAG, "syncActiveNotifications found ${activeNotifs.size} notifications in Android status bar")
            for (sbn in activeNotifs) {
                processSbn(sbn, emitBroadcast = false)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error syncing active notifications: ", e)
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        processSbn(sbn, emitBroadcast = true)
    }

    private fun processSbn(sbn: StatusBarNotification, emitBroadcast: Boolean = true) {
        val packageName = sbn.packageName
        val notification = sbn.notification
        val category = notification.category ?: ""
        val isCall = isCallNotification(packageName, category)

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

        // Filter out local-only, foreground/ongoing service (except incoming/active calls), group summary, and empty notifications
        val flags = notification.flags
        val isFgService = (flags and Notification.FLAG_FOREGROUND_SERVICE) != 0
        val isOngoing = (flags and Notification.FLAG_ONGOING_EVENT) != 0

        if ((flags and Notification.FLAG_LOCAL_ONLY) != 0 ||
            ((isFgService || isOngoing) && !isCall) ||
            (flags and Notification.FLAG_GROUP_SUMMARY) != 0 ||
            (title.isBlank() && body.isBlank())
        ) {
            Log.d(
                TAG,
                "Filtering out notification for key=${sbn.key} (isFgService=$isFgService, isOngoing=$isOngoing, isCall=$isCall)"
            )
            return
        }

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

        val lowerBody = body.lowercase().trim()
        val lowerTitle = title.lowercase().trim()

        val normKey = sbn.key.lowercase()
        val id = computeNotificationId(sbn)

        // Deduplicate identical notification body updates for active notifications
        val existingMeta = activeMetas[id]
        if (existingMeta != null && existingMeta.body == body) {
            Log.d(TAG, "Filtering out duplicate notification body update for id=$id")
            return
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
                body =
                    if (appName.isNotEmpty() && appName.lowercase() != "phone") "Incoming $appName Call" else "Incoming Call"
            }
        }

        val isSecondary: Boolean = when {
            isCall -> {
                category == Notification.CATEGORY_MISSED_CALL ||
                        lowerBody.contains("missed call") ||
                        lowerBody.contains("voicemail") ||
                        lowerTitle.contains("missed call")
            }
            else -> {
                isFgService || isOngoing || lowerBody.contains("archived") || lowerBody.contains("undo") || lowerBody.contains("sent")
            }
        }

        var hasRemoteInput = isCall
        val actionTitles = mutableListOf<String>()

        val notifActions = notification.actions
        if (notifActions != null) {
            for (action in notifActions) {
                val actTitle = action.title?.toString() ?: ""
                if (actTitle.isNotEmpty()) {
                    actionTitles.add(actTitle)
                }
                val ris = action.remoteInputs
                if (ris != null) {
                    for (ri in ris) {
                        if (ri.resultKey != null) {
                            hasRemoteInput = true
                        }
                    }
                }
            }
        }

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
            "Notification processed: $packageName ($appName), title: $title, body: $body, key: $normKey, kind: $finalKind, secondary: $isSecondary, replyable: $finalReplyable"
        )

        val timestamp = if (notification.`when` != 0L) notification.`when` else sbn.postTime

        val meta = NotificationMeta(
            key = normKey,
            id = id,
            `package` = packageName,
            app = appName,
            title = title,
            body = body,
            kind = finalKind,
            secondary = isSecondary,
            phone = phoneNumber,
            replyable = finalReplyable,
            actions = actionTitles,
            timestamp = timestamp,
            sbn = sbn
        )
        activeMetas[id] = meta

        if (emitBroadcast) {
            val intent = Intent(ACTION_NOTIFICATION_RECEIVED).apply {
                putExtra(EXTRA_PACKAGE, packageName)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
                putExtra(EXTRA_ID, id)
                putExtra(EXTRA_KEY, normKey)
                putExtra(EXTRA_APP, appName)
                putExtra(EXTRA_PHONE, phoneNumber)
                putExtra(EXTRA_REPLYABLE, finalReplyable)
                putExtra(EXTRA_KIND, finalKind)
                putExtra(EXTRA_SECONDARY, isSecondary)
                putExtra(EXTRA_TIMESTAMP, timestamp)
                setPackage(this@NotificationsService.packageName)
            }
            sendBroadcast(intent)
        }
    }

    fun computeNotificationId(sbn: StatusBarNotification): Int {
        val normKey = sbn.key.lowercase()
        return if (sbn.id != 0) sbn.id and 0x7FFFFFFF else normKey.hashCode() and 0x7FFFFFFF
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?, rankingMap: RankingMap?, reason: Int) {
        super.onNotificationRemoved(sbn, rankingMap, reason)
        if (sbn == null) return

        val packageName = sbn.packageName
        val normKey = sbn.key.lowercase()
        val id = computeNotificationId(sbn)
        activeMetas.remove(id)

        Log.d(TAG, "onNotificationRemoved: key=$normKey, id=$id, reason=$reason")

        val intent = Intent(ACTION_NOTIFICATION_REMOVED).apply {
            putExtra(EXTRA_PACKAGE, packageName)
            putExtra(EXTRA_ID, id)
            putExtra(EXTRA_KEY, normKey)
            putExtra("reason", reason)
            setPackage(this@NotificationsService.packageName)
        }
        sendBroadcast(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "NotificationsService destroyed")
    }

    fun getMeta(id: Int): NotificationMeta? {
        if (id == 0) return null
        return activeMetas[id]
    }

    fun getMeta(key: String): NotificationMeta? {
        if (key.isEmpty()) return null
        val id = key.lowercase().hashCode() and 0x7FFFFFFF
        return activeMetas[id]
    }

    fun reply(id: Int, replyText: String): Boolean {
        val meta = getMeta(id)
        if (meta == null || meta.sbn == null) {
            Log.w(TAG, "Cannot reply: no active replyable notification found for id: $id")
            return false
        }
        val sbn = meta.sbn
        val packageName = sbn.packageName

        var targetAction: Notification.Action? = null
        var targetRemoteInput: RemoteInput? = null

        val actions = sbn.notification.actions
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

        if (targetAction != null && targetRemoteInput != null) {
            val intent = Intent().apply {
                val bundle = Bundle().apply {
                    putCharSequence(targetRemoteInput.resultKey, replyText)
                }
                RemoteInput.addResultsToIntent(arrayOf(targetRemoteInput), this, bundle)
            }
            try {
                targetAction.actionIntent.send(this, 0, intent)
                if (meta.kind == "call") {
                    declineCall(id)
                }
                Log.d(TAG, "Reply sent successfully via RemoteInput for id: $id")
                return true
            } catch (e: Exception) {
                Log.e(TAG, "Error sending RemoteInput reply: ", e)
            }
        }

        val isCall = isCallNotification(packageName, sbn.notification.category ?: "")
        if (isCall) {
            val phoneNumber = extractPhoneNumber(sbn)
            if (phoneNumber.isNotEmpty()) {
                declineCall(id)
                return notificationsManager.sendText(listOf(phoneNumber), replyText)
            }
        }

        Log.w(TAG, "No valid reply action found for notification id: $id")
        return false
    }

    fun declineCall(id: Int): Boolean {
        Log.d(TAG, "declineCall called for id: $id")
        val meta = getMeta(id) ?: return false
        val sbn = meta.sbn ?: return false
        val actions = sbn.notification.actions ?: return false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            for (action in actions) {
                if (action.semanticAction == 2 /* SEMANTIC_ACTION_CALL_DECLINE */) {
                    try {
                        action.actionIntent.send()
                        Log.d(TAG, "Successfully triggered semantic DECLINE action (2) for id: $id")
                        cancelNotification(sbn.key)
                        activeMetas.remove(id)
                        return true
                    } catch (e: Exception) {
                        Log.e(TAG, "Error triggering semantic decline action for id: $id", e)
                    }
                }
            }
        }

        val keywords = listOf("decline", "hang", "reject", "挂断", "拒", "拒绝", "dismiss", "ignore")
        for (action in actions) {
            val title = action.title?.toString()?.lowercase() ?: continue
            if (keywords.any { title.contains(it) }) {
                try {
                    action.actionIntent.send()
                    Log.d(TAG, "Successfully triggered decline action '${action.title}' for id: $id")
                    cancelNotification(sbn.key)
                    activeMetas.remove(id)
                    return true
                } catch (e: Exception) {
                    Log.e(TAG, "Error triggering decline action for id: $id", e)
                }
            }
        }

        if (isCallPackage(sbn.packageName) || meta.kind == "call") {
            try {
                val telecomManager =
                    getSystemService(android.content.Context.TELECOM_SERVICE) as? android.telecom.TelecomManager
                if (telecomManager != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    telecomManager.endCall()
                    Log.d(TAG, "Ended call via TelecomManager.endCall()")
                    cancelNotification(sbn.key)
                    activeMetas.remove(id)
                    return true
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error ending call via TelecomManager", e)
            }
        }

        return false
    }

    fun dismiss(id: Int): Boolean {
        Log.d(TAG, "dismiss called for id: $id")
        if (id == 0) {
            Log.w(TAG, "dismiss ignored: id is 0")
            return false
        }
        try {
            val meta = activeMetas[id]
            if (meta != null && (meta.kind == "call" || isCallPackage(meta.`package`))) {
                declineCall(id)
            }
            if (meta != null && meta.sbn != null) {
                cancelNotification(meta.sbn.key)
                activeMetas.remove(id)
                Log.d(TAG, "Notification dismissed successfully for id: $id")
                return true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error dismissing notification: ", e)
        }
        return false
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
        if (phoneNumber.isNotEmpty()) {
            try {
                phoneNumber = java.net.URLDecoder.decode(phoneNumber, "UTF-8")
            } catch (e: Exception) {
                phoneNumber = phoneNumber.replace("%2B", "+").replace("%2b", "+")
            }
        }
        return phoneNumber
    }

    private fun isCallPackage(packageName: String): Boolean {
        val pkg = packageName.lowercase()
        return pkg.contains("dialer") ||
                pkg.contains("telecom") ||
                pkg.contains("phone") ||
                pkg.contains("incallui")
    }

    private fun isCallNotification(packageName: String, category: String?): Boolean {
        val cat = category ?: ""
        return cat == Notification.CATEGORY_CALL ||
                cat == Notification.CATEGORY_MISSED_CALL ||
                isCallPackage(packageName)
    }

    fun triggerNotificationAction(id: Int, actionKeyword: String): Boolean {
        Log.d(TAG, "triggerNotificationAction called for id: $id, keyword: $actionKeyword")
        val meta = getMeta(id) ?: return false
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
                            Log.d(TAG, "Triggered semantic action $targetSemanticAction for id: $id")
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
                    Log.d(TAG, "Triggered keyword action '${action.title}' for id: $id")
                    return true
                } catch (e: Exception) {
                    Log.e(TAG, "Error triggering keyword action '${action.title}'", e)
                }
            }
        }

        Log.w(TAG, "No action matching keyword '$actionKeyword' found for id: $id")
        return false
    }

    fun openNotificationOnPhone(id: Int): Boolean {
        Log.d(TAG, "openNotificationOnPhone called for id: $id")
        val meta = getMeta(id) ?: return false
        val sbn = meta.sbn ?: return false
        val contentIntent = sbn.notification.contentIntent

        try {
            com.misync.actions.DismissKeyguardActivity.launch(this, targetPendingIntent = contentIntent)
            cancelNotification(sbn.key)
            activeMetas.remove(id)
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error launching notification intent from service", e)
        }
        return false
    }
}
