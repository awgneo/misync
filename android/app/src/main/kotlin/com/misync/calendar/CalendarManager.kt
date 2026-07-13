package com.misync.calendar

import android.content.Context
import android.util.Log

class CalendarManager(private val context: Context) {
    private val TAG = "CalendarManager"

    fun getCalendars(): List<Map<String, Any>> {
        val uri = android.provider.CalendarContract.Calendars.CONTENT_URI
        val projection = arrayOf(
            android.provider.CalendarContract.Calendars._ID,
            android.provider.CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            android.provider.CalendarContract.Calendars.ACCOUNT_NAME,
            android.provider.CalendarContract.Calendars.CALENDAR_COLOR
        )
        val list = mutableListOf<Map<String, Any>>()
        try {
            val cursor = context.contentResolver.query(uri, projection, null, null, null)
            cursor?.use { c ->
                val idIndex = c.getColumnIndex(android.provider.CalendarContract.Calendars._ID)
                val nameIndex = c.getColumnIndex(android.provider.CalendarContract.Calendars.CALENDAR_DISPLAY_NAME)
                val accountIndex = c.getColumnIndex(android.provider.CalendarContract.Calendars.ACCOUNT_NAME)
                val colorIndex = c.getColumnIndex(android.provider.CalendarContract.Calendars.CALENDAR_COLOR)
                while (c.moveToNext()) {
                    val id = c.getLong(idIndex).toString()
                    val name = c.getString(nameIndex) ?: ""
                    val account = c.getString(accountIndex) ?: ""
                    val color = c.getInt(colorIndex)
                    list.add(mapOf(
                        "id" to id,
                        "name" to name,
                        "account" to account,
                        "color" to color
                    ))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to query calendars: ", e)
        }
        return list
    }

    fun getUpcomingEvents(calendarIds: List<String>): List<Map<String, Any>> {
        if (calendarIds.isEmpty()) return emptyList()

        val begin = System.currentTimeMillis()
        val end = begin + 7L * 24L * 60L * 60L * 1000L

        val builder = android.provider.CalendarContract.Instances.CONTENT_URI.buildUpon()
        android.content.ContentUris.appendId(builder, begin)
        android.content.ContentUris.appendId(builder, end)
        val uri = builder.build()

        val projection = arrayOf(
            android.provider.CalendarContract.Instances.TITLE,
            android.provider.CalendarContract.Instances.DESCRIPTION,
            android.provider.CalendarContract.Instances.EVENT_LOCATION,
            android.provider.CalendarContract.Instances.BEGIN,
            android.provider.CalendarContract.Instances.END,
            android.provider.CalendarContract.Instances.ALL_DAY,
            android.provider.CalendarContract.Instances.EVENT_ID
        )

        val selection = StringBuilder()
        val selectionArgs = mutableListOf<String>()
        selection.append(android.provider.CalendarContract.Instances.CALENDAR_ID + " IN (")
        for (i in calendarIds.indices) {
            if (i > 0) selection.append(",")
            selection.append("?")
            selectionArgs.add(calendarIds[i])
        }
        selection.append(")")

        val eventList = mutableListOf<Map<String, Any>>()
        try {
            val cursor = context.contentResolver.query(
                uri,
                projection,
                selection.toString(),
                selectionArgs.toTypedArray(),
                android.provider.CalendarContract.Instances.BEGIN + " ASC"
            )

            cursor?.use { c ->
                val titleIdx = c.getColumnIndex(android.provider.CalendarContract.Instances.TITLE)
                val descIdx = c.getColumnIndex(android.provider.CalendarContract.Instances.DESCRIPTION)
                val locIdx = c.getColumnIndex(android.provider.CalendarContract.Instances.EVENT_LOCATION)
                val beginIdx = c.getColumnIndex(android.provider.CalendarContract.Instances.BEGIN)
                val endIdx = c.getColumnIndex(android.provider.CalendarContract.Instances.END)
                val allDayIdx = c.getColumnIndex(android.provider.CalendarContract.Instances.ALL_DAY)
                val eventIdIdx = c.getColumnIndex(android.provider.CalendarContract.Instances.EVENT_ID)

                var count = 0
                while (c.moveToNext() && count < 500) {
                    val title = c.getString(titleIdx) ?: ""
                    val description = c.getString(descIdx) ?: ""
                    val location = c.getString(locIdx) ?: ""
                    val startMs = c.getLong(beginIdx)
                    val endMs = c.getLong(endIdx)
                    val allDay = c.getInt(allDayIdx) == 1
                    val eventId = c.getLong(eventIdIdx)
                    val notifyMinutes = getReminderMinutes(eventId)

                    eventList.add(mapOf(
                        "title" to title,
                        "description" to description,
                        "location" to location,
                        "start" to startMs,
                        "end" to endMs,
                        "allDay" to allDay,
                        "notifyMinutesBefore" to notifyMinutes
                    ))
                    count++
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to query upcoming events: ", e)
        }
        return eventList
    }

    private fun getReminderMinutes(eventId: Long): Int {
        val uri = android.provider.CalendarContract.Reminders.CONTENT_URI
        val projection = arrayOf(android.provider.CalendarContract.Reminders.MINUTES)
        val selection = "${android.provider.CalendarContract.Reminders.EVENT_ID} = ?"
        val selectionArgs = arrayOf(eventId.toString())
        var minutes = 0
        try {
            val cursor = context.contentResolver.query(uri, projection, selection, selectionArgs, null)
            cursor?.use { c ->
                if (c.moveToFirst()) {
                    minutes = c.getInt(c.getColumnIndexOrThrow(android.provider.CalendarContract.Reminders.MINUTES))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to query reminder minutes for event $eventId", e)
        }
        return minutes
    }
}
