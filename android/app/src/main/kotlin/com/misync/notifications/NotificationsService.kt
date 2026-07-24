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
    val metas = java.util.concurrent.ConcurrentHashMap<Int, NotificationMeta>()

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
            metas.clear()
            val activeNotifs = activeNotifications ?: return
            Log.d(TAG, "syncActiveNotifications found ${activeNotifs.size} notifications in Android status bar")
            for (sbn in activeNotifs) {
                processSbn(sbn, broadcast = false)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error syncing active notifications: ", e)
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        processSbn(sbn, broadcast = true)
    }

    private fun processSbn(sbn: StatusBarNotification, broadcast: Boolean = true) {
        val `package` = sbn.packageName
        val notification = sbn.notification
        val category = notification.category ?: ""
        val call = isCall(`package`, category)
        val extras = notification.extras
        val flags = notification.flags
        val app = extractApp(`package`)
        val title = extractTitle(extras)
        val body = extractBody(extras, title, call, app, `package`)
        val key = computeKey(sbn)
        val id = computeId(sbn)

        if (isIgnored(title, body, flags, call, category, extras)) {
            Log.d(TAG, "Filtering out notification for key=$key")
            return
        }

        if (isDuplicate(id, body)) {
            Log.d(TAG, "Filtering out duplicate notification body update for id=$id")
            return
        }

        val phone = extractPhone(sbn, call)
        val secondary = isSecondary(call, category, flags)
        val actions = extractActions(notification)
        val kind = computeKind(call, category, `package`, extras)
        val replyable = computeReplyable(notification, call, category, `package`, extras)
        val timestamp = computeTimestamp(sbn)

        Log.d(
            TAG,
            """
            Notification processed:
              key: $key
              id: $id
              package: $`package` ($app)
              title: $title
              body: $body
              kind: $kind
              secondary: $secondary
              phone: $phone
              replyable: $replyable
              actions: $actions
              timestamp: $timestamp
            """.trimIndent()
        )

        val meta = NotificationMeta(
            key = key,
            id = id,
            `package` = `package`,
            app = app,
            title = title,
            body = body,
            kind = kind,
            secondary = secondary,
            phone = phone,
            replyable = replyable,
            actions = actions,
            timestamp = timestamp,
            sbn = sbn
        )
        metas[id] = meta

        if (broadcast) {
            broadcastReceived(meta)
        }
    }

    private fun extractTitle(extras: Bundle): String {
        return extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
    }

    private fun extractBody(
        extras: Bundle,
        title: String,
        call: Boolean,
        app: String,
        `package`: String
    ): String {
        var body = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
            ?: ""

        val messages = extras.get(Notification.EXTRA_MESSAGES) as? Array<*>
        if (messages != null && messages.isNotEmpty()) {
            val lastMessage = messages.lastOrNull() as? Bundle
            if (lastMessage != null) {
                val text = lastMessage.getCharSequence("text")?.toString()
                if (!text.isNullOrEmpty()) {
                    body = text
                }

                val senderPerson = extractSenderPerson(lastMessage)
                val senderName = senderPerson?.name?.toString()
                    ?: lastMessage.getCharSequence("sender")?.toString()

                if (!senderName.isNullOrEmpty() && title != senderName) {
                    body = "$senderName: $body"
                }
            }
        }

        if (call && (body.isEmpty() || body == title)) {
            body = if (app.isNotEmpty() && !isCallPackage(`package`)) "Incoming $app Call" else "Incoming Call"
        }

        return body
    }

    private fun hasSenderPerson(extras: Bundle): Boolean {
        val messages = extras.get(Notification.EXTRA_MESSAGES) as? Array<*> ?: return false
        val lastMessage = messages.lastOrNull() as? Bundle ?: return false
        val senderPerson = extractSenderPerson(lastMessage)
        val senderName = senderPerson?.name?.toString()
            ?: lastMessage.getCharSequence("sender")?.toString()
        return !senderName.isNullOrEmpty()
    }

    private fun extractSenderPerson(lastMessage: Bundle): android.app.Person? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            lastMessage.getParcelable("sender_person", android.app.Person::class.java)
        } else null
    }

    private fun extractApp(packageName: String): String {
        val pm = packageManager
        return try {
            val appInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            val last = packageName.split(".").lastOrNull() ?: packageName
            last.replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
        }
    }

    private fun isIgnored(
        title: String,
        body: String,
        flags: Int,
        isCall: Boolean,
        category: String,
        extras: Bundle
    ): Boolean {
        val isFgService = (flags and Notification.FLAG_FOREGROUND_SERVICE) != 0
        val isOngoing = (flags and Notification.FLAG_ONGOING_EVENT) != 0
        val isLocalOnly = (flags and Notification.FLAG_LOCAL_ONLY) != 0
        val isGroupSummary = (flags and Notification.FLAG_GROUP_SUMMARY) != 0

        if (isLocalOnly ||
            ((isFgService || isOngoing) && !isCall) ||
            isGroupSummary ||
            (title.isBlank() && body.isBlank())
        ) {
            return true
        }

        // On Android 12+ (API 31+), filter out outgoing (2) or ongoing (3) CallStyle notifications
        if (isCall && category == Notification.CATEGORY_CALL && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (extras.containsKey(Notification.EXTRA_CALL_TYPE)) {
                val callType = extras.getInt(Notification.EXTRA_CALL_TYPE, -1)
                if (callType != Notification.CallStyle.CALL_TYPE_INCOMING) {
                    return true
                }
            }
        }

        return false
    }

    private fun isDuplicate(id: Int, body: String): Boolean {
        val existingMeta = metas[id]
        return existingMeta != null && existingMeta.body == body
    }

    private fun computeKind(
        call: Boolean,
        category: String,
        `package`: String,
        extras: Bundle
    ): String {
        val defaultSmsPkg = android.provider.Telephony.Sms.getDefaultSmsPackage(this)
        val hasMessages = (extras.get(Notification.EXTRA_MESSAGES) as? Array<*>)?.isNotEmpty() == true

        if (category == Notification.CATEGORY_MESSAGE && defaultSmsPkg != `package` && hasMessages && !hasSenderPerson(
                extras
            )
        ) {
            return "standard"
        }

        return when {
            call -> "call"
            category == Notification.CATEGORY_EMAIL -> "email"
            category == Notification.CATEGORY_MESSAGE || (defaultSmsPkg != null && `package` == defaultSmsPkg) -> "text"
            else -> "standard"
        }
    }

    private fun computeReplyable(
        notification: Notification,
        call: Boolean,
        category: String,
        `package`: String,
        extras: Bundle
    ): Boolean {
        val defaultSmsPkg = android.provider.Telephony.Sms.getDefaultSmsPackage(this)
        val hasMessages = (extras.get(Notification.EXTRA_MESSAGES) as? Array<*>)?.isNotEmpty() == true

        if (category == Notification.CATEGORY_MESSAGE && defaultSmsPkg != `package` && hasMessages && !hasSenderPerson(
                extras
            )
        ) {
            return false
        }

        if (call) return true

        val notifActions = notification.actions ?: return false
        for (action in notifActions) {
            val ris = action.remoteInputs ?: continue
            for (ri in ris) {
                if (ri.resultKey != null) return true
            }
        }
        return false
    }

    private fun isSecondary(isCall: Boolean, category: String, flags: Int): Boolean {
        val isFgService = (flags and Notification.FLAG_FOREGROUND_SERVICE) != 0
        val isOngoing = (flags and Notification.FLAG_ONGOING_EVENT) != 0
        return when {
            isCall -> {
                category == Notification.CATEGORY_MISSED_CALL ||
                        category == Notification.CATEGORY_VOICEMAIL
            }

            else -> isFgService || isOngoing
        }
    }

    private fun extractActions(notification: Notification): List<String> {
        val notifActions = notification.actions ?: return emptyList()
        val actionTitles = mutableListOf<String>()
        for (action in notifActions) {
            val actTitle = action.title?.toString() ?: ""
            if (actTitle.isNotEmpty()) {
                actionTitles.add(actTitle)
            }
        }
        return actionTitles
    }

    private fun broadcastReceived(meta: NotificationMeta) {
        val intent = Intent(ACTION_NOTIFICATION_RECEIVED).apply {
            putExtra(EXTRA_PACKAGE, meta.`package`)
            putExtra(EXTRA_TITLE, meta.title)
            putExtra(EXTRA_BODY, meta.body)
            putExtra(EXTRA_ID, meta.id)
            putExtra(EXTRA_KEY, meta.key)
            putExtra(EXTRA_APP, meta.app)
            putExtra(EXTRA_PHONE, meta.phone)
            putExtra(EXTRA_REPLYABLE, meta.replyable)
            putExtra(EXTRA_KIND, meta.kind)
            putExtra(EXTRA_SECONDARY, meta.secondary)
            putExtra(EXTRA_TIMESTAMP, meta.timestamp)
            setPackage(this@NotificationsService.packageName)
        }
        sendBroadcast(intent)
    }

    fun computeKey(sbn: StatusBarNotification): String = sbn.key.lowercase()

    fun computeId(sbn: StatusBarNotification): Int {
        val key = computeKey(sbn)
        return if (sbn.id != 0) sbn.id and 0x7FFFFFFF else key.hashCode() and 0x7FFFFFFF
    }

    fun computeTimestamp(sbn: StatusBarNotification): Long {
        val notification = sbn.notification
        return if (notification.`when` != 0L) notification.`when` else sbn.postTime
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?, rankingMap: RankingMap?, reason: Int) {
        super.onNotificationRemoved(sbn, rankingMap, reason)
        if (sbn == null) return

        val packageName = sbn.packageName
        val key = computeKey(sbn)
        val id = computeId(sbn)
        metas.remove(id)

        Log.d(TAG, "onNotificationRemoved: key=$key, id=$id, reason=$reason")

        val intent = Intent(ACTION_NOTIFICATION_REMOVED).apply {
            putExtra(EXTRA_PACKAGE, packageName)
            putExtra(EXTRA_ID, id)
            putExtra(EXTRA_KEY, key)
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
        return metas[id]
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
            val matchingChatMeta = metas.values.find {
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

        val isCall = isCall(packageName, sbn.notification.category ?: "")
        if (isCall) {
            val phoneNumber = extractPhone(sbn)
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
                        metas.remove(id)
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
                    metas.remove(id)
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
                    metas.remove(id)
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
            val meta = metas[id]
            if (meta != null && (meta.kind == "call" || isCallPackage(meta.`package`))) {
                declineCall(id)
            }
            if (meta != null && meta.sbn != null) {
                cancelNotification(meta.sbn.key)
                metas.remove(id)
                Log.d(TAG, "Notification dismissed successfully for id: $id")
                return true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error dismissing notification: ", e)
        }
        return false
    }

    private fun extractPhone(sbn: StatusBarNotification, call: Boolean = true): String {
        if (!call) return ""
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
                        Log.e(TAG, "Error resolving contact URI in extractPhone: $uriStr", e)
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

    private fun isCall(packageName: String, category: String?): Boolean {
        val cat = category ?: ""
        return cat == Notification.CATEGORY_CALL ||
                cat == Notification.CATEGORY_MISSED_CALL ||
                isCallPackage(packageName)
    }

    fun triggerAction(id: Int, actionKeyword: String): Boolean {
        Log.d(TAG, "triggerAction called for id: $id, keyword: $actionKeyword")
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

    fun open(id: Int): Boolean {
        Log.d(TAG, "open called for id: $id")
        val meta = getMeta(id) ?: return false
        val sbn = meta.sbn ?: return false
        val contentIntent = sbn.notification.contentIntent

        try {
            com.misync.actions.DismissKeyguardActivity.launch(this, targetPendingIntent = contentIntent)
            cancelNotification(sbn.key)
            metas.remove(id)
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error launching notification intent from service", e)
        }
        return false
    }
}
