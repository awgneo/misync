package com.misync.misync.media

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.misync.misync.notifications.NotificationsService
import io.flutter.plugin.common.MethodChannel

class MediaManager(private val context: Context) {
    private val TAG = "MediaManager"
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val sessionManager = context.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
    private val handler = Handler(Looper.getMainLooper())

    private var activeSessionsListener: MediaSessionManager.OnActiveSessionsChangedListener? = null
    private val controllersMap = mutableMapOf<MediaController, MediaController.Callback>()
    private var currentController: MediaController? = null

    private var volumeReceiver: BroadcastReceiver? = null
    private var isStarted = false

    fun startListening(channel: MethodChannel) {
        if (isStarted) return
        isStarted = true
        Log.d(TAG, "Starting MediaManager listeners")

        val componentName = ComponentName(context, NotificationsService::class.java)

        activeSessionsListener = MediaSessionManager.OnActiveSessionsChangedListener { controllers ->
            updateControllers(controllers ?: emptyList(), channel)
        }

        try {
            sessionManager.addOnActiveSessionsChangedListener(activeSessionsListener!!, componentName)
            val initialControllers = sessionManager.getActiveSessions(componentName)
            updateControllers(initialControllers, channel)
        } catch (e: Exception) {
            Log.e(TAG, "Error starting active sessions listener: $e")
        }

        volumeReceiver = object : BroadcastReceiver() {
            override fun onReceive(c: Context?, intent: Intent?) {
                if (intent?.action == "android.media.VOLUME_CHANGED_ACTION") {
                    sendMediaUpdate(channel)
                }
            }
        }
        context.registerReceiver(volumeReceiver, IntentFilter("android.media.VOLUME_CHANGED_ACTION"))
    }

    fun stopListening() {
        if (!isStarted) return
        isStarted = false
        Log.d(TAG, "Stopping MediaManager listeners")

        activeSessionsListener?.let {
            sessionManager.removeOnActiveSessionsChangedListener(it)
        }
        activeSessionsListener = null

        controllersMap.forEach { (controller, callback) ->
            controller.unregisterCallback(callback)
        }
        controllersMap.clear()
        currentController = null

        volumeReceiver?.let {
            context.unregisterReceiver(it)
        }
        volumeReceiver = null
    }

    private fun updateControllers(controllers: List<MediaController>, channel: MethodChannel) {
        val toRemove = controllersMap.keys.filter { it !in controllers }
        toRemove.forEach {
            it.unregisterCallback(controllersMap[it]!!)
            controllersMap.remove(it)
        }

        controllers.forEach { controller ->
            if (controller !in controllersMap) {
                val callback = object : MediaController.Callback() {
                    override fun onPlaybackStateChanged(state: PlaybackState?) {
                        evaluateActiveController(controllers, channel)
                    }
                    override fun onMetadataChanged(metadata: MediaMetadata?) {
                        evaluateActiveController(controllers, channel)
                    }
                }
                controller.registerCallback(callback)
                controllersMap[controller] = callback
            }
        }

        evaluateActiveController(controllers, channel)
    }

    private fun evaluateActiveController(controllers: List<MediaController>, channel: MethodChannel) {
        val playing = controllers.firstOrNull { it.playbackState?.state == PlaybackState.STATE_PLAYING }
        val newController = playing ?: controllers.firstOrNull()

        if (newController != currentController) {
            currentController = newController
            Log.d(TAG, "Switched active controller to: ${currentController?.packageName}")
        }
        sendMediaUpdate(channel)
    }

    private fun sendMediaUpdate(channel: MethodChannel) {
        val controller = currentController
        val metadata = controller?.metadata
        val playbackState = controller?.playbackState

        val title = metadata?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: ""
        val artist = metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST) ?: ""
        val duration = metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L
        val position = playbackState?.position ?: 0L

        val state = when (playbackState?.state) {
            PlaybackState.STATE_PLAYING -> 1
            PlaybackState.STATE_PAUSED -> 2
            else -> 0
        }

        val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val curVol = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        val volume = if (maxVol > 0) (curVol * 100 / maxVol) else 0

        handler.post {
            channel.invokeMethod(
                "mediaChanged",
                mapOf(
                    "title" to title,
                    "artist" to artist,
                    "duration" to (duration / 1000).toInt(),
                    "position" to (position / 1000).toInt(),
                    "state" to state,
                    "volume" to volume
                )
            )
        }
    }

    fun controlMedia(key: Int?, volume: Int?): Boolean {
        val controller = currentController ?: return false
        val transport = controller.transportControls
        when (key) {
            0 -> transport.play()
            1 -> transport.pause()
            3 -> transport.skipToPrevious()
            4 -> transport.skipToNext()
            5 -> {
                if (volume != null) {
                    val curVol = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                    val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val curPercentage = if (maxVol > 0) (curVol * 100 / maxVol) else 0
                    if (volume > curPercentage) {
                        audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_RAISE, AudioManager.FLAG_SHOW_UI)
                    } else if (volume < curPercentage) {
                        audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_LOWER, AudioManager.FLAG_SHOW_UI)
                    }
                }
            }
        }
        return true
    }
}
