package com.misync.wallet

import android.app.Activity
import android.content.Context
import android.content.Intent
import com.misync.base.BaseModule
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class WalletModule(private val context: Context) : BaseModule("wallet") {
    private val walletManager = WalletManager(context)

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

    override fun onIntent(intent: Intent): Boolean {
        return walletManager.handleIntent(intent, methodChannel)
    }

    override fun onMethodCall(
        activity: Activity,
        method: String,
        call: MethodCall,
        result: MethodChannel.Result
    ): Boolean {
        return when (method) {
            "getPendingPass" -> {
                walletManager.consumePendingPass(result)
                true
            }
            else -> false
        }
    }
}
