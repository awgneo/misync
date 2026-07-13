package com.misync.clock

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import com.misync.base.BaseModule
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class ClockModule(private val context: Context) : BaseModule("clock") {

    private val alarmReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == android.app.AlarmManager.ACTION_NEXT_ALARM_CLOCK_CHANGED) {
                sendNextAlarmUpdate()
            }
        }
    }

    override fun onCreate() {
        val alarmFilter = IntentFilter(android.app.AlarmManager.ACTION_NEXT_ALARM_CLOCK_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(alarmReceiver, alarmFilter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(alarmReceiver, alarmFilter)
        }
    }

    override fun onDestroy() {
        try {
            context.unregisterReceiver(alarmReceiver)
        } catch (e: Exception) {
            // Ignored
        }
    }

    override fun checkPermissions(): Boolean {
        return true
    }

    override fun requestPermissions(activity: Activity) {
        // No-op
    }

    override fun onMethodCall(activity: Activity, method: String, call: MethodCall, result: MethodChannel.Result): Boolean {
        return when (method) {
            "getNextAlarm" -> {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                val nextAlarm = alarmManager.nextAlarmClock
                if (nextAlarm != null) {
                    val calendar = Calendar.getInstance()
                    calendar.timeInMillis = nextAlarm.triggerTime
                    result.success(mapOf(
                        "hour" to calendar.get(Calendar.HOUR_OF_DAY),
                        "minute" to calendar.get(Calendar.MINUTE)
                    ))
                } else {
                    result.success(null)
                }
                true
            }
            else -> false
        }
    }

    private fun sendNextAlarmUpdate() {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        val nextAlarm = alarmManager.nextAlarmClock
        if (nextAlarm != null) {
            val calendar = Calendar.getInstance()
            calendar.timeInMillis = nextAlarm.triggerTime
            val data = mapOf(
                "hour" to calendar.get(Calendar.HOUR_OF_DAY),
                "minute" to calendar.get(Calendar.MINUTE)
            )
            methodChannel?.invokeMethod("nextAlarmChanged", data)
        } else {
            methodChannel?.invokeMethod("nextAlarmChanged", null)
        }
    }
}
