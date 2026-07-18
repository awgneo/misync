package com.misync

import android.os.Bundle
import android.util.Log
import android.content.pm.PackageManager
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.misync.MainActivity
import com.misync.base.BaseModule
import com.misync.device.DeviceModule
import com.misync.health.HealthModule
import com.misync.notifications.NotificationsModule
import com.misync.notifications.NotificationsService
import com.misync.calendar.CalendarModule
import com.misync.clock.ClockModule
import com.misync.media.MediaModule
import com.misync.actions.ActionsModule
import com.misync.finance.FinanceModule
import com.misync.wallet.WalletModule

class MainActivity : FlutterActivity() {
    private val TAG = "MainActivity"
    private val CHANNEL = "com.misync/channels"

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
            ActionsModule(this),
            FinanceModule(this),
            WalletModule(this)
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
        modules.forEach {
            try {
                it.onCreate()
            } catch (e: Exception) {
                Log.e(TAG, "Error in onCreate for module ${it.name}: ", e)
            }
        }

        intent?.let {
            dispatchIntent(it)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        dispatchIntent(intent)
    }

    private fun dispatchIntent(intent: Intent) {
        for (module in modules) {
            try {
                if (module.onIntent(intent)) {
                    Log.d(TAG, "Intent consumed by module: ${module.name}")
                    intent.data = null
                    break
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error routing intent to module ${module.name}: ", e)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        modules.forEach {
            try {
                it.onDestroy()
            } catch (e: Exception) {
                Log.e(TAG, "Error in onDestroy for module ${it.name}: ", e)
            }
        }
    }
}
