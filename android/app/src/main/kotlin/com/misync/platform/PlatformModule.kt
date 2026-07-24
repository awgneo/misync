package com.misync.platform

import android.app.Activity
import android.content.Context
import com.misync.base.BaseModule
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class PlatformModule(context: Context) : BaseModule("platform") {
    private val platformManager = PlatformManager(context)

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
            "getApps" -> {
                Thread {
                    try {
                        val appList = platformManager.getApps()
                        result.success(appList)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }.start()
                true
            }

            "getAppIcon" -> {
                val packageName = call.argument<String>("packageName") ?: ""
                val size = call.argument<Int>("size") ?: 96
                val iconBytes = platformManager.getAppIcon(packageName, size)
                result.success(iconBytes)
                true
            }

            else -> false
        }
    }
}
