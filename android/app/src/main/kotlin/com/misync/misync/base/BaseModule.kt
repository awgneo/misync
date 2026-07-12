package com.misync.misync.base

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

abstract class BaseModule(val name: String) {
    protected var methodChannel: MethodChannel? = null

    open fun register(channel: MethodChannel) {
        this.methodChannel = channel
    }

    open fun onCreate() {}
    open fun onDestroy() {}

    abstract fun checkPermissions(): Boolean
    abstract fun requestPermissions(activity: Activity)

    // Returns true if this module handled the call, false otherwise
    abstract fun onMethodCall(activity: Activity, method: String, call: MethodCall, result: MethodChannel.Result): Boolean

    fun handleMethodCall(activity: Activity, method: String, call: MethodCall, result: MethodChannel.Result): Boolean {
        return when (method) {
            "checkPermissions" -> {
                result.success(checkPermissions())
                true
            }
            "requestPermissions" -> {
                requestPermissions(activity)
                result.success(true)
                true
            }
            else -> onMethodCall(activity, method, call, result)
        }
    }

    // Common helper utility to check standard runtime permissions
    protected fun hasRuntimePermission(context: Context, permission: String): Boolean {
        return context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
    }
}
