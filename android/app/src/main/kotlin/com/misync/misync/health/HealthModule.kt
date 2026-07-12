package com.misync.misync.health

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import com.misync.misync.base.BaseModule
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class HealthModule(
    private val context: Context
) : BaseModule("health") {
    private val TAG = "HealthModule"
    private val healthManager = HealthManager(context)

    private val requiredPermissions = setOf(
        HealthPermission.getWritePermission(StepsRecord::class),
        HealthPermission.getWritePermission(HeartRateRecord::class),
        HealthPermission.getWritePermission(SleepSessionRecord::class),
        HealthPermission.getWritePermission(OxygenSaturationRecord::class),
        HealthPermission.getWritePermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getWritePermission(TotalCaloriesBurnedRecord::class),
        HealthPermission.getWritePermission(DistanceRecord::class),
        HealthPermission.getWritePermission(ExerciseSessionRecord::class),
        HealthPermission.getReadPermission(HeightRecord::class),
        HealthPermission.getReadPermission(WeightRecord::class)
    )

    override fun checkPermissions(): Boolean {
        val currentClient = healthManager.client ?: return false
        return kotlinx.coroutines.runBlocking {
            try {
                val granted = currentClient.permissionController.getGrantedPermissions()
                granted.containsAll(requiredPermissions)
            } catch (e: Exception) {
                false
            }
        }
    }

    override fun requestPermissions(activity: Activity) {
        val context = activity.applicationContext
        Log.d(TAG, "launching Health Connect settings")
        try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                Intent("android.health.connect.action.MANAGE_HEALTH_PERMISSIONS").apply {
                    putExtra(Intent.EXTRA_PACKAGE_NAME, context.packageName)
                }
            } else {
                Intent("androidx.health.connect.client.ACTION_HEALTH_CONNECT_SETTINGS").apply {
                    putExtra(Intent.EXTRA_PACKAGE_NAME, context.packageName)
                }
            }
            activity.startActivity(intent)
        } catch (e: Exception) {
            try {
                val intent = Intent("androidx.health.ACTION_HEALTH_CONNECT_SETTINGS")
                activity.startActivity(intent)
            } catch (ex: Exception) {
                Log.e(TAG, "Failed to launch Health Connect settings: ", ex)
            }
        }
    }

    override fun onMethodCall(activity: Activity, method: String, call: MethodCall, result: MethodChannel.Result): Boolean {
        return when (method) {
            "writeSteps" -> {
                val start = call.argument<Long>("startTime")!!
                val end = call.argument<Long>("endTime")!!
                val count = call.argument<Int>("count")!!.toLong()
                healthManager.writeSteps(start, end, count, result)
                true
            }
            "writeHeartRate" -> {
                val time = call.argument<Long>("time")!!
                val bpm = call.argument<Int>("bpm")!!.toLong()
                healthManager.writeHeartRate(time, bpm, result)
                true
            }
            "writeOxygenSaturation" -> {
                val time = call.argument<Long>("time")!!
                val percentage = call.argument<Double>("percentage")!!
                healthManager.writeOxygenSaturation(time, percentage, result)
                true
            }
            "writeActiveCalories" -> {
                val start = call.argument<Long>("startTime")!!
                val end = call.argument<Long>("endTime")!!
                val kcal = call.argument<Double>("kcal")!!
                healthManager.writeActiveCaloriesBurned(start, end, kcal, result)
                true
            }
            "writeDistance" -> {
                val start = call.argument<Long>("startTime")!!
                val end = call.argument<Long>("endTime")!!
                val meters = call.argument<Double>("meters")!!
                healthManager.writeDistance(start, end, meters, result)
                true
            }
            "writeSleepSession" -> {
                val start = call.argument<Long>("startTime")!!
                val end = call.argument<Long>("endTime")!!
                val stages = call.argument<List<Map<String, Any>>>("stages") ?: emptyList()
                healthManager.writeSleepSession(start, end, stages, result)
                true
            }
            "writeWorkoutSession" -> {
                val start = call.argument<Long>("startTime")!!
                val end = call.argument<Long>("endTime")!!
                val sportType = call.argument<Int>("sportType")!!
                val title = call.argument<String>("title") ?: ""
                val calories = call.argument<Double>("calories")
                val distance = call.argument<Double>("distance")
                val skipCount = call.argument<Int>("skipCount")?.toLong()
                healthManager.writeWorkoutSession(start, end, sportType, title, calories, distance, skipCount, result)
                true
            }
            "getLatestHeightAndWeight" -> {
                healthManager.getLatestHeightAndWeight(result)
                true
            }
            else -> false
        }
    }
}
