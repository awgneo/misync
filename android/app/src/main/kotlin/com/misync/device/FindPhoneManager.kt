package com.misync.device

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.util.Log

class FindPhoneManager(private val context: Context) {
    private val TAG = "FindPhoneManager"
    private var mediaPlayer: MediaPlayer? = null
    private var originalVolume: Int? = null

    fun start() {
        Log.d(TAG, "start: playing loud alert")
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

        if (originalVolume == null) {
            originalVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
        }
        val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
        audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxVolume, 0)

        if (mediaPlayer == null) {
            val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            mediaPlayer = MediaPlayer().apply {
                setDataSource(context, alarmUri)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                isLooping = true
                prepare()
                start()
            }
        }

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "find_phone_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Find Phone Alert",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Plays loud alert when finding phone from watch"
                setBypassDnd(true)
                setSound(null, null)
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val stopIntent = Intent("com.misync.STOP_FIND_PHONE").apply {
            setPackage(context.packageName)
        }
        val stopPendingIntent = PendingIntent.getBroadcast(
            context, 0, stopIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(context, channelId)
        } else {
            @Suppress("DEPRECATION")
            android.app.Notification.Builder(context)
        }
        val notification = builder
            .setSmallIcon(android.R.drawable.ic_menu_search)
            .setContentTitle("Find Phone Alert")
            .setContentText("Your watch is finding this phone")
            .setOngoing(true)
            .setCategory(android.app.Notification.CATEGORY_ALARM)
            .addAction(android.app.Notification.Action.Builder(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Found It",
                stopPendingIntent
            ).build())
            .build()

        notificationManager.notify(1008, notification)
    }

    fun stop() {
        Log.d(TAG, "stop: stopping alarm player")
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping media player", e)
        }
        mediaPlayer = null

        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        originalVolume?.let {
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, it, 0)
            originalVolume = null
        }

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(1008)
    }
}
