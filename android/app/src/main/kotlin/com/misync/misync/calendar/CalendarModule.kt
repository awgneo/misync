package com.misync.misync.calendar

import android.app.Activity
import android.content.Context
import com.misync.misync.base.BaseModule
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class CalendarModule(
    private val context: Context
) : BaseModule("calendar") {
    private val calendarManager = CalendarManager(context)

    override fun checkPermissions(): Boolean {
        return hasRuntimePermission(context, android.Manifest.permission.READ_CALENDAR)
    }

    override fun requestPermissions(activity: Activity) {
        if (!hasRuntimePermission(context, android.Manifest.permission.READ_CALENDAR)) {
            activity.requestPermissions(arrayOf(android.Manifest.permission.READ_CALENDAR), 102)
        }
    }

    override fun onMethodCall(activity: Activity, method: String, call: MethodCall, result: MethodChannel.Result): Boolean {
        return when (method) {
            "getCalendars" -> {
                Thread {
                    try {
                        val list = calendarManager.getCalendars()
                        result.success(list)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }.start()
                true
            }
            "getUpcomingEvents" -> {
                val calendarIds = call.argument<List<String>>("calendarIds") ?: emptyList()
                Thread {
                    try {
                        val list = calendarManager.getUpcomingEvents(calendarIds)
                        result.success(list)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }.start()
                true
            }
            else -> false
        }
    }
}
