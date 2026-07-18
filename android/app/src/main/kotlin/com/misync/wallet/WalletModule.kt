package com.misync.wallet

import android.content.Intent
import android.app.Activity
import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.misync.base.BaseModule
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class WalletModule(private val context: Context) : BaseModule("wallet") {
    private val TAG = "WalletModule"
    private val walletManager = WalletManager(context)
    private var pendingPassUri: String? = null

    companion object {
        private var instance: WalletModule? = null
        fun get(): WalletModule? = instance
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance == this) {
            instance = null
        }
    }

    override fun checkPermissions(): Boolean = true

    override fun requestPermissions(activity: Activity) {}

    fun handleIncomingIntent(uriString: String) {
        Log.d(TAG, "Saving pending pkpass URI: $uriString")
        pendingPassUri = uriString
        // Try to dispatch immediately in case Flutter is already initialized
        handlePkpassUri(uriString)
    }

    private fun forwardToGoogleWallet(uriString: String) {
        try {
            val uri = Uri.parse(uriString)
            val baseIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.apple.pkpass")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            val pm = context.packageManager
            val resolveInfos = pm.queryIntentActivities(baseIntent, 0)
            
            val targetIntents = mutableListOf<Intent>()
            var googleWalletIntent: Intent? = null

            for (info in resolveInfos) {
                val pkgName = info.activityInfo.packageName
                if (pkgName != context.packageName) {
                    val targetIntent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/vnd.apple.pkpass")
                        setClassName(pkgName, info.activityInfo.name)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    targetIntents.add(targetIntent)
                    if (pkgName.contains("wallet", ignoreCase = true) || pkgName.contains("google", ignoreCase = true)) {
                        googleWalletIntent = targetIntent
                    }
                }
            }

            if (googleWalletIntent != null) {
                context.startActivity(googleWalletIntent)
                Log.d(TAG, "Directly launched Google Wallet handler: ${googleWalletIntent.component}")
            } else if (targetIntents.isNotEmpty()) {
                if (targetIntents.size == 1) {
                    context.startActivity(targetIntents[0])
                } else {
                    val firstIntent = targetIntents.removeAt(0)
                    val chooserIntent = Intent.createChooser(firstIntent, "Open Pass with").apply {
                        putExtra(Intent.EXTRA_INITIAL_INTENTS, targetIntents.toTypedArray())
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(chooserIntent)
                }
            } else {
                Log.w(TAG, "No other handlers found for pkpass")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to forward pkpass intent: ", e)
        }
    }

    private fun handlePkpassUri(uriString: String) {
        val parsedUri = Uri.parse(uriString)
        val scheme = parsedUri.scheme
        if (scheme == "http" || scheme == "https") {
            Thread {
                val parsed = walletManager.processPkpassUri(uriString)
                Handler(Looper.getMainLooper()).post {
                    if (parsed != null) {
                        Log.d(TAG, "Successfully parsed pkpass. Dispatching to Flutter: $parsed")
                        methodChannel?.invokeMethod("passIntercepted", parsed)
                        forwardToGoogleWallet(uriString)
                    } else {
                        Log.e(TAG, "Failed to parse pkpass URI: $uriString")
                    }
                }
            }.start()
        } else {
            val parsed = walletManager.processPkpassUri(uriString)
            if (parsed != null) {
                Log.d(TAG, "Successfully parsed pkpass. Dispatching to Flutter: $parsed")
                methodChannel?.invokeMethod("passIntercepted", parsed)
                forwardToGoogleWallet(uriString)
            } else {
                Log.e(TAG, "Failed to parse pkpass URI: $uriString")
            }
        }
    }

    override fun onMethodCall(
        activity: Activity,
        method: String,
        call: MethodCall,
        result: MethodChannel.Result
    ): Boolean {
        return when (method) {
            "getPendingPass" -> {
                val uri = pendingPassUri
                if (uri != null) {
                    pendingPassUri = null
                    val parsedUri = Uri.parse(uri)
                    val scheme = parsedUri.scheme
                    if (scheme == "http" || scheme == "https") {
                        Thread {
                            val parsed = walletManager.processPkpassUri(uri)
                            Handler(Looper.getMainLooper()).post {
                                result.success(parsed)
                            }
                        }.start()
                    } else {
                        val parsed = walletManager.processPkpassUri(uri)
                        result.success(parsed)
                    }
                } else {
                    result.success(null)
                }
                true
            }
            else -> false
        }
    }
}
