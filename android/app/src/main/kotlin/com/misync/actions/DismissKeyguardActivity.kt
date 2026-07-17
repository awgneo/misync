package com.misync.actions

import android.app.Activity
import android.app.ActivityOptions
import android.app.KeyguardManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowManager

class DismissKeyguardActivity : Activity() {
    private val TAG = "DismissKeyguardActivity"
    private var isDismissRequestSent = false

    companion object {
        private const val LAUNCH_TAG = "DismissKeyguardLaunch"

        fun launch(
            context: Context,
            targetIntent: Intent? = null,
            targetPendingIntent: PendingIntent? = null
        ) {
            val km = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            if (km.isKeyguardLocked) {
                Log.d(LAUNCH_TAG, "Device is locked. Starting DismissKeyguardActivity to bypass keyguard.")
                try {
                    val intent = Intent(context, DismissKeyguardActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                        putExtra("target_intent", targetIntent)
                        putExtra("target_pending_intent", targetPendingIntent)
                    }
                    context.startActivity(intent)
                } catch (e: Exception) {
                    Log.e(LAUNCH_TAG, "Failed to start DismissKeyguardActivity, falling back to direct launch", e)
                    directLaunch(context, targetIntent, targetPendingIntent)
                }
            } else {
                Log.d(LAUNCH_TAG, "Device is unlocked. Launching target directly.")
                directLaunch(context, targetIntent, targetPendingIntent)
            }
        }

        private fun directLaunch(
            context: Context,
            targetIntent: Intent?,
            targetPendingIntent: PendingIntent?
        ) {
            try {
                if (targetPendingIntent != null) {
                    if (Build.VERSION.SDK_INT >= 34) {
                        val options = ActivityOptions.makeBasic()
                        options.setPendingIntentBackgroundActivityStartMode(ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED)
                        targetPendingIntent.send(context, 0, null, null, null, null, options.toBundle())
                    } else {
                        targetPendingIntent.send()
                    }
                    Log.d(LAUNCH_TAG, "PendingIntent launched successfully")
                } else if (targetIntent != null) {
                    if (targetIntent.action == "net.dinglisch.android.taskerm.ACTION_TASK") {
                        context.sendBroadcast(targetIntent)
                    } else {
                        context.startActivity(targetIntent)
                    }
                    Log.d(LAUNCH_TAG, "Intent launched successfully")
                }
            } catch (e: Exception) {
                Log.e(LAUNCH_TAG, "Direct launch failed", e)
                // Ultimate broadcast fallback for custom activity intents
                if (targetIntent != null && targetIntent.action != "net.dinglisch.android.taskerm.ACTION_TASK") {
                    try {
                        context.sendBroadcast(targetIntent)
                    } catch (ex: Exception) {
                        Log.e(LAUNCH_TAG, "Broadcast fallback failed", ex)
                    }
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "onCreate called")

        // Turn on screen and show when locked
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume called")

        if (isDismissRequestSent) {
            return
        }

        val targetPendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra("target_pending_intent", PendingIntent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra("target_pending_intent") as? PendingIntent
        }

        val targetIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra("target_intent", Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra("target_intent") as? Intent
        }

        if (targetPendingIntent == null && targetIntent == null) {
            Log.e(TAG, "No launch target (intent or pending intent) specified")
            finish()
            return
        }

        isDismissRequestSent = true
        val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager

        // Post to ensure layout is ready and keyguard request won't be cancelled immediately
        window.decorView.post {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Log.d(TAG, "Requesting keyguard dismiss via requestDismissKeyguard")
                km.requestDismissKeyguard(this, object : KeyguardManager.KeyguardDismissCallback() {
                    override fun onDismissSucceeded() {
                        Log.d(TAG, "Keyguard dismiss succeeded")
                        directLaunch(this@DismissKeyguardActivity, targetIntent, targetPendingIntent)
                        finish()
                    }

                    override fun onDismissCancelled() {
                        Log.d(TAG, "Keyguard dismiss cancelled")
                        finish()
                    }

                    override fun onDismissError() {
                        Log.e(TAG, "Keyguard dismiss error")
                        directLaunch(this@DismissKeyguardActivity, targetIntent, targetPendingIntent)
                        finish()
                    }
                })
            } else {
                @Suppress("DEPRECATION")
                window.addFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD)
                directLaunch(this, targetIntent, targetPendingIntent)
                finish()
            }
        }
    }
}
