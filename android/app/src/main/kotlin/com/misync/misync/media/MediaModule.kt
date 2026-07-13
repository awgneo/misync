package com.misync.misync.media

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.misync.misync.base.BaseModule
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MediaModule(private val context: Context) : BaseModule("media") {
    private val mediaManager = MediaManager(context)
    private val TAG = "MediaModule"

    override fun checkPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            ContextCompat.checkSelfPermission(
                context,
                android.Manifest.permission.WRITE_EXTERNAL_STORAGE
            ) == PackageManager.PERMISSION_GRANTED
        }
    }

    override fun requestPermissions(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                intent.data = Uri.parse("package:" + activity.packageName)
                activity.startActivity(intent)
            } catch (e: Exception) {
                try {
                    val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                    activity.startActivity(intent)
                } catch (ex: Exception) {
                    Log.e(TAG, "Failed to launch manage files settings", ex)
                }
            }
        } else {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(android.Manifest.permission.WRITE_EXTERNAL_STORAGE),
                1002
            )
        }
    }

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
