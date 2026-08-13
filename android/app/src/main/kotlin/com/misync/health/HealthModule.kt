package com.misync.health

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import com.misync.base.BaseModule
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
        HealthPermission.getWritePermission(MindfulnessSessionRecord::class),
        HealthPermission.getWritePermission(BodyTemperatureRecord::class),
        HealthPermission.getWritePermission(BloodPressureRecord::class),
        HealthPermission.getWritePermission(HeartRateVariabilityRmssdRecord::class),
        HealthPermission.getWritePermission(RestingHeartRateRecord::class),
        HealthPermission.getWritePermission(RespiratoryRateRecord::class),
        HealthPermission.getWritePermission(Vo2MaxRecord::class),
        HealthPermission.getWritePermission(SkinTemperatureRecord::class),
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
                throw ex
            }
        }
    }

    override fun onMethodCall(activity: Activity, method: String, call: MethodCall, result: MethodChannel.Result): Boolean {
        val clientRecordId = call.argument<String>("clientRecordId")
        return when (method) {
            "writeSteps" -> {
                val start = call.argument<Long>("startTime")!!
                val end = call.argument<Long>("endTime")!!
                val count = call.argument<Int>("count")!!.toLong()
                healthManager.writeSteps(start, end, count, clientRecordId, result)
                true
            }
            "writeHeartRate" -> {
                val time = call.argument<Long>("time")!!
                val bpm = call.argument<Int>("bpm")!!.toLong()
                healthManager.writeHeartRate(time, bpm, clientRecordId, result)
                true
            }
            "writeOxygenSaturation" -> {
                val time = call.argument<Long>("time")!!
                val percentage = call.argument<Double>("percentage")!!
                healthManager.writeOxygenSaturation(time, percentage, clientRecordId, result)
                true
            }
            "writeActiveCalories" -> {
                val start = call.argument<Long>("startTime")!!
                val end = call.argument<Long>("endTime")!!
                val kcal = call.argument<Double>("kcal")!!
                healthManager.writeActiveCaloriesBurned(start, end, kcal, clientRecordId, result)
                true
            }
            "writeDistance" -> {
                val start = call.argument<Long>("startTime")!!
                val end = call.argument<Long>("endTime")!!
                val meters = call.argument<Double>("meters")!!
                healthManager.writeDistance(start, end, meters, clientRecordId, result)
                true
            }
            "writeSleepSession" -> {
                val start = call.argument<Long>("startTime")!!
                val end = call.argument<Long>("endTime")!!
                val stages = call.argument<List<Map<String, Any>>>("stages") ?: emptyList()
                healthManager.writeSleepSession(start, end, stages, clientRecordId, result)
                true
            }
            "writeExerciseSession" -> {
                val start = call.argument<Long>("startTime")!!
                val end = call.argument<Long>("endTime")!!
                val sportType = call.argument<Int>("sportType")!!
                val title = call.argument<String>("title") ?: ""
                val calories = call.argument<Double>("calories")
                val distance = call.argument<Double>("distance")
                val skipCount = call.argument<Int>("skipCount")?.toLong()
                healthManager.writeExerciseSession(start, end, sportType, title, calories, distance, skipCount, clientRecordId, result)
                true
            }
            "writeHeartRateVariabilityRmssd" -> {
                val time = call.argument<Long>("time")!!
                val hrvMillis = call.argument<Double>("hrvMillis")!!
                healthManager.writeHeartRateVariabilityRmssd(time, hrvMillis, clientRecordId, result)
                true
            }
            "writeRestingHeartRate" -> {
                val time = call.argument<Long>("time")!!
                val bpm = call.argument<Int>("bpm")!!.toLong()
                healthManager.writeRestingHeartRate(time, bpm, clientRecordId, result)
                true
            }
            "writeRespiratoryRate" -> {
                val time = call.argument<Long>("time")!!
                val rate = call.argument<Double>("rate")!!
                healthManager.writeRespiratoryRate(time, rate, clientRecordId, result)
                true
            }
            "writeVo2Max" -> {
                val time = call.argument<Long>("time")!!
                val vo2Max = call.argument<Double>("vo2Max")!!
                healthManager.writeVo2Max(time, vo2Max, clientRecordId, result)
                true
            }
            "writeSkinTemperature" -> {
                val start = call.argument<Long>("startTime")!!
                val end = call.argument<Long>("endTime")!!
                val deltas = call.argument<List<Map<String, Any>>>("deltas") ?: emptyList()
                healthManager.writeSkinTemperature(start, end, deltas, clientRecordId, result)
                true
            }
            "getLatestHeightAndWeight" -> {
                healthManager.getLatestHeightAndWeight(result)
                true
            }
            "writeMindfulnessSession" -> {
                val time = call.argument<Long>("time")!!
                val stress = call.argument<Int>("stress")!!
                val sessionType = call.argument<String>("sessionType")
                healthManager.writeMindfulnessSession(time, stress, sessionType, clientRecordId, result)
                true
            }

            "writeBodyTemperature" -> {
                val time = call.argument<Long>("time")!!
                val skinTemp = call.argument<Double>("skinTemp")
                val bodyTemp = call.argument<Double>("bodyTemp")
                healthManager.writeBodyTemperature(time, skinTemp, bodyTemp, clientRecordId, result)
                true
            }
            "writeBloodPressure" -> {
                val time = call.argument<Long>("time")!!
                val systolic = call.argument<Int>("systolic")!!
                val diastolic = call.argument<Int>("diastolic")!!
                healthManager.writeBloodPressure(time, systolic, diastolic, clientRecordId, result)
                true
            }
            else -> false
        }
    }
}

