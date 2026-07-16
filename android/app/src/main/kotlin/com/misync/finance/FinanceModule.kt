package com.misync.finance

import android.app.Activity
import android.content.Context
import com.misync.base.BaseModule
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class FinanceModule(private val context: Context) : BaseModule("finance") {
    private val investmentsManager = InvestmentsManager(context)

    override fun checkPermissions(): Boolean {
        return true
    }

    override fun requestPermissions(activity: Activity) {}

    override fun onMethodCall(
        activity: Activity,
        method: String,
        call: MethodCall,
        result: MethodChannel.Result
    ): Boolean {
        return when (method) {
            "updateInvestmentsWidget" -> {
                investmentsManager.updateWidget()
                result.success(null)
                true
            }
            else -> false
        }
    }
}
