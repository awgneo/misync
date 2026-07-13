package com.misync.misync

import android.os.Bundle
import android.util.Log
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.misync.misync.base.BaseModule
import com.misync.misync.device.DeviceModule
import com.misync.misync.health.HealthModule
import com.misync.misync.notifications.NotificationsModule
import com.misync.misync.notifications.NotificationsService
import com.misync.misync.calendar.CalendarModule
import com.misync.misync.clock.ClockModule
import com.misync.misync.media.MediaModule
import com.misync.misync.actions.ActionsModule

class MainActivity : FlutterActivity() {
    private val TAG = "MainActivity"
    private val CHANNEL = "com.misync.misync/channels"

    private var methodChannel: MethodChannel? = null
    private lateinit var modules: List<BaseModule>

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        // Initialize modules
        modules = listOf(
            DeviceModule(this),
            HealthModule(this),
            NotificationsModule(this),
            CalendarModule(this),
            ClockModule(this),
            MediaModule(this),
            ActionsModule(this)
        )

        // Register method channel with all modules
        modules.forEach { it.register(methodChannel!!) }

        methodChannel?.setMethodCallHandler { call, result ->
            val methodCall = call.method
            // Parse namespace: e.g. "health.checkPermissions" -> module = "health", method = "checkPermissions"
            val parts = methodCall.split(".")
            if (parts.size == 2) {
                val moduleName = parts[0]
                val methodName = parts[1]
                val module = modules.find { it.name == moduleName }
                if (module != null) {
                    val handled = module.handleMethodCall(this, methodName, call, result)
                    if (!handled) {
                        result.notImplemented()
                    }
                } else {
                    result.notImplemented()
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Trigger module lifecycle hooks
        modules.forEach { it.onCreate() }

        // Force Android to rebind NotificationListenerService by toggling its component state
        try {
            val componentName = android.content.ComponentName(applicationContext, NotificationsService::class.java)
            val packageManager = applicationContext.packageManager
            packageManager.setComponentEnabledSetting(
                componentName,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
            packageManager.setComponentEnabledSetting(
                componentName,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            Log.d(TAG, "Force reset NotificationsService component enabled setting successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to force reset NotificationsService component: ", e)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        modules.forEach { it.onDestroy() }
    }
}
