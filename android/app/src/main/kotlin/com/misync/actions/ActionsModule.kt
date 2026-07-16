package com.misync.actions

import android.app.Activity
import android.content.Context
import com.misync.base.BaseModule
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class ActionsModule(context: Context) : BaseModule("actions") {
    private val actionsManager = ActionsManager(context)

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
            "launchAction" -> {
                val intentAction = call.argument<String>("intent") ?: ""
                val packageName = call.argument<String>("package")
                val uriString = call.argument<String>("uri")
                val extras = call.argument<Map<String, String>>("extras")
                actionsManager.launchAction(intentAction, packageName, uriString, extras)
                result.success(null)
                true
            }
            else -> false
        }
    }
}
