package com.misync.misync.media

import android.app.Activity
import android.content.Context
import com.misync.misync.base.BaseModule
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MediaModule(context: Context) : BaseModule("media") {
    private val mediaManager = MediaManager(context)

    override fun checkPermissions(): Boolean {
        return true
    }

    override fun requestPermissions(activity: Activity) {}

    override fun register(channel: MethodChannel) {
        super.register(channel)
        mediaManager.startListening(channel)
    }

    override fun onDestroy() {
        super.onDestroy()
        mediaManager.stopListening()
    }

    override fun onMethodCall(
        activity: Activity,
        method: String,
        call: MethodCall,
        result: MethodChannel.Result
    ): Boolean {
        when (method) {
            "control" -> {
                val key = call.argument<Int>("key")
                val volume = call.argument<Int>("volume")
                val success = mediaManager.controlMedia(key, volume)
                result.success(success)
                return true
            }
        }
        return false
    }
}
