package com.misync.health

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.*
import androidx.health.connect.client.units.*
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class HealthManager(private val context: Context) {
    private val TAG = "HealthManager"
    private val scope = CoroutineScope(Dispatchers.Main)

    val client: HealthConnectClient? by lazy {
        try {
            if (HealthConnectClient.getSdkStatus(context) != HealthConnectClient.SDK_UNAVAILABLE) {
                HealthConnectClient.getOrCreate(context)
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize HealthConnectClient", e)
            null
        }
    }

    fun writeSteps(startTimeMs: Long, endTimeMs: Long, count: Long, result: MethodChannel.Result) {
        val currentClient = client ?: run {
            result.error("CLIENT_NOT_INITIALIZED", "Health Connect client is not initialized", null)
            return
        }

        scope.launch {
            try {
                val record = StepsRecord(
                    startTime = Instant.ofEpochMilli(startTimeMs),
                    startZoneOffset = null,
                    endTime = Instant.ofEpochMilli(endTimeMs),
                    endZoneOffset = null,
                    count = count,
                    metadata = androidx.health.connect.client.records.metadata.Metadata.unknownRecordingMethod()
                )
                withContext(Dispatchers.IO) {
                    currentClient.insertRecords(listOf(record))
                }
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write steps: ", e)
                result.error("WRITE_ERROR", e.message ?: "Failed to write steps", null)
            }
        }
    }

    fun writeHeartRate(timeMs: Long, bpm: Long, result: MethodChannel.Result) {
        val currentClient = client ?: run {
            result.error("CLIENT_NOT_INITIALIZED", "Health Connect client is not initialized", null)
            return
        }

        scope.launch {
            try {
                val record = HeartRateRecord(
                    startTime = Instant.ofEpochMilli(timeMs),
                    startZoneOffset = null,
                    endTime = Instant.ofEpochMilli(timeMs),
                    endZoneOffset = null,
                    samples = listOf(HeartRateRecord.Sample(Instant.ofEpochMilli(timeMs), bpm)),
                    metadata = androidx.health.connect.client.records.metadata.Metadata.unknownRecordingMethod()
                )
                withContext(Dispatchers.IO) {
                    currentClient.insertRecords(listOf(record))
                }
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write heart rate: ", e)
                result.error("WRITE_ERROR", e.message ?: "Failed to write heart rate", null)
            }
        }
    }

    fun writeOxygenSaturation(timeMs: Long, percentage: Double, result: MethodChannel.Result) {
        val currentClient = client ?: run {
            result.error("CLIENT_NOT_INITIALIZED", "Health Connect client is not initialized", null)
            return
        }

        scope.launch {
            try {
                val record = OxygenSaturationRecord(
                    time = Instant.ofEpochMilli(timeMs),
                    zoneOffset = null,
                    percentage = Percentage(percentage),
                    metadata = androidx.health.connect.client.records.metadata.Metadata.unknownRecordingMethod()
                )
                withContext(Dispatchers.IO) {
                    currentClient.insertRecords(listOf(record))
                }
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write oxygen saturation: ", e)
                result.error("WRITE_ERROR", e.message ?: "Failed to write oxygen saturation", null)
            }
        }
    }

    fun writeActiveCaloriesBurned(startTimeMs: Long, endTimeMs: Long, kcal: Double, result: MethodChannel.Result) {
        val currentClient = client ?: run {
            result.error("CLIENT_NOT_INITIALIZED", "Health Connect client is not initialized", null)
            return
        }

        scope.launch {
            try {
                val record = ActiveCaloriesBurnedRecord(
                    startTime = Instant.ofEpochMilli(startTimeMs),
                    startZoneOffset = null,
                    endTime = Instant.ofEpochMilli(endTimeMs),
                    endZoneOffset = null,
                    energy = Energy.kilocalories(kcal),
                    metadata = androidx.health.connect.client.records.metadata.Metadata.unknownRecordingMethod()
                )
                withContext(Dispatchers.IO) {
                    currentClient.insertRecords(listOf(record))
                }
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write active calories: ", e)
                result.error("WRITE_ERROR", e.message ?: "Failed to write active calories", null)
            }
        }
    }

    fun writeDistance(startTimeMs: Long, endTimeMs: Long, meters: Double, result: MethodChannel.Result) {
        val currentClient = client ?: run {
            result.error("CLIENT_NOT_INITIALIZED", "Health Connect client is not initialized", null)
            return
        }

        scope.launch {
            try {
                val record = DistanceRecord(
                    startTime = Instant.ofEpochMilli(startTimeMs),
                    startZoneOffset = null,
                    endTime = Instant.ofEpochMilli(endTimeMs),
                    endZoneOffset = null,
                    distance = Length.meters(meters),
                    metadata = androidx.health.connect.client.records.metadata.Metadata.unknownRecordingMethod()
                )
                withContext(Dispatchers.IO) {
                    currentClient.insertRecords(listOf(record))
                }
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write distance: ", e)
                result.error("WRITE_ERROR", e.message ?: "Failed to write distance", null)
            }
        }
    }

    fun writeSleepSession(
        startTimeMs: Long,
        endTimeMs: Long,
        stagesList: List<Map<String, Any>>,
        result: MethodChannel.Result
    ) {
        val currentClient = client ?: run {
            result.error("CLIENT_NOT_INITIALIZED", "Health Connect client is not initialized", null)
            return
        }

        scope.launch {
            try {
                val stages = if (stagesList.isEmpty()) {
                    listOf(
                        SleepSessionRecord.Stage(
                            startTime = Instant.ofEpochMilli(startTimeMs),
                            endTime = Instant.ofEpochMilli(endTimeMs),
                            stage = SleepSessionRecord.STAGE_TYPE_UNKNOWN
                        )
                    )
                } else {
                    stagesList.map { stageMap ->
                        val start = stageMap["start"] as Long
                        val end = stageMap["end"] as Long
                        val state = stageMap["stage"] as Int
                        val type = when (state) {
                            2 -> SleepSessionRecord.STAGE_TYPE_DEEP
                            3 -> SleepSessionRecord.STAGE_TYPE_LIGHT
                            4 -> SleepSessionRecord.STAGE_TYPE_REM
                            1, 5 -> SleepSessionRecord.STAGE_TYPE_AWAKE
                            else -> SleepSessionRecord.STAGE_TYPE_UNKNOWN
                        }
                        SleepSessionRecord.Stage(
                            startTime = Instant.ofEpochMilli(start),
                            endTime = Instant.ofEpochMilli(end),
                            stage = type
                        )
                    }
                }

                val sleepSession = SleepSessionRecord(
                    startTime = Instant.ofEpochMilli(startTimeMs),
                    startZoneOffset = null,
                    endTime = Instant.ofEpochMilli(endTimeMs),
                    endZoneOffset = null,
                    stages = stages,
                    title = "Sleep",
                    metadata = androidx.health.connect.client.records.metadata.Metadata.unknownRecordingMethod()
                )

                withContext(Dispatchers.IO) {
                    currentClient.insertRecords(listOf(sleepSession))
                }
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write sleep session: ", e)
                result.error("WRITE_ERROR", e.message ?: "Failed to write sleep session", null)
            }
        }
    }

    fun writeExerciseSession(
        startTimeMs: Long,
        endTimeMs: Long,
        sportType: Int,
        title: String,
        calories: Double?,
        distance: Double?,
        skipCount: Long?,
        result: MethodChannel.Result
    ) {
        val currentClient = client ?: run {
            result.error("CLIENT_NOT_INITIALIZED", "Health Connect client is not initialized", null)
            return
        }

        scope.launch {
            try {
                val startInstant = Instant.ofEpochMilli(startTimeMs)
                val endInstant = Instant.ofEpochMilli(endTimeMs)

                val exerciseType = when (sportType) {
                    1 -> ExerciseSessionRecord.EXERCISE_TYPE_RUNNING
                    2 -> ExerciseSessionRecord.EXERCISE_TYPE_WALKING
                    3 -> ExerciseSessionRecord.EXERCISE_TYPE_RUNNING_TREADMILL
                    4 -> ExerciseSessionRecord.EXERCISE_TYPE_WALKING
                    5 -> ExerciseSessionRecord.EXERCISE_TYPE_SKIING
                    6 -> ExerciseSessionRecord.EXERCISE_TYPE_BIKING
                    7 -> ExerciseSessionRecord.EXERCISE_TYPE_BIKING_STATIONARY
                    8 -> ExerciseSessionRecord.EXERCISE_TYPE_OTHER_WORKOUT
                    9 -> ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_POOL
                    10 -> ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_OPEN_WATER
                    11 -> ExerciseSessionRecord.EXERCISE_TYPE_ELLIPTICAL
                    12 -> ExerciseSessionRecord.EXERCISE_TYPE_YOGA
                    13 -> ExerciseSessionRecord.EXERCISE_TYPE_ROWING_MACHINE
                    14 -> ExerciseSessionRecord.EXERCISE_TYPE_HIGH_INTENSITY_INTERVAL_TRAINING // Jump Rope
                    15 -> ExerciseSessionRecord.EXERCISE_TYPE_HIKING
                    16 -> ExerciseSessionRecord.EXERCISE_TYPE_HIGH_INTENSITY_INTERVAL_TRAINING
                    19 -> ExerciseSessionRecord.EXERCISE_TYPE_BASKETBALL
                    20 -> ExerciseSessionRecord.EXERCISE_TYPE_GOLF
                    21 -> ExerciseSessionRecord.EXERCISE_TYPE_SKIING
                    22 -> ExerciseSessionRecord.EXERCISE_TYPE_WALKING
                    24 -> ExerciseSessionRecord.EXERCISE_TYPE_ROCK_CLIMBING
                    25 -> ExerciseSessionRecord.EXERCISE_TYPE_SCUBA_DIVING
                    else -> ExerciseSessionRecord.EXERCISE_TYPE_OTHER_WORKOUT
                }

                val segments = if (sportType == 14 && skipCount != null) {
                    listOf(
                        ExerciseSegment(
                            startTime = startInstant,
                            endTime = endInstant,
                            segmentType = ExerciseSegment.EXERCISE_SEGMENT_TYPE_JUMP_ROPE,
                            repetitions = skipCount.toInt()
                        )
                    )
                } else {
                    emptyList()
                }

                val exerciseSession = ExerciseSessionRecord(
                    startTime = startInstant,
                    startZoneOffset = null,
                    endTime = endInstant,
                    endZoneOffset = null,
                    metadata = androidx.health.connect.client.records.metadata.Metadata.unknownRecordingMethod(),
                    exerciseType = exerciseType,
                    title = title,
                    notes = null,
                    segments = segments,
                    laps = emptyList()
                )

                val list = mutableListOf<Record>(exerciseSession)

                if (calories != null && calories > 0) {
                    list.add(
                        ActiveCaloriesBurnedRecord(
                            startTime = startInstant,
                            startZoneOffset = null,
                            endTime = endInstant,
                            endZoneOffset = null,
                            energy = Energy.kilocalories(calories),
                            metadata = androidx.health.connect.client.records.metadata.Metadata.unknownRecordingMethod()
                        )
                    )
                }

                if (distance != null && distance > 0) {
                    list.add(
                        DistanceRecord(
                            startTime = startInstant,
                            startZoneOffset = null,
                            endTime = endInstant,
                            endZoneOffset = null,
                            distance = Length.meters(distance),
                            metadata = androidx.health.connect.client.records.metadata.Metadata.unknownRecordingMethod()
                        )
                    )
                }

                if (sportType == 14 && skipCount != null && skipCount > 0) {
                    list.add(
                        StepsRecord(
                            startTime = startInstant,
                            startZoneOffset = null,
                            endTime = endInstant,
                            endZoneOffset = null,
                            count = skipCount,
                            metadata = androidx.health.connect.client.records.metadata.Metadata.unknownRecordingMethod()
                        )
                    )
                }

                withContext(Dispatchers.IO) {
                    currentClient.insertRecords(list)
                }
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write workout session: ", e)
                result.error("WRITE_ERROR", e.message ?: "Failed to write workout session", null)
            }
        }
    }

    fun writeMindfulnessSession(timeMs: Long, stress: Int, result: MethodChannel.Result) {
        val currentClient = client ?: run {
            result.error("CLIENT_NOT_INITIALIZED", "Health Connect client is not initialized", null)
            return
        }

        scope.launch {
            try {
                val record = MindfulnessSessionRecord(
                    startTime = Instant.ofEpochMilli(timeMs),
                    startZoneOffset = null,
                    endTime = Instant.ofEpochMilli(timeMs),
                    endZoneOffset = null,
                    title = "Stress Measurement",
                    notes = "Stress Level: $stress",
                    mindfulnessSessionType = MindfulnessSessionRecord.MINDFULNESS_SESSION_TYPE_UNKNOWN,
                    metadata = androidx.health.connect.client.records.metadata.Metadata.unknownRecordingMethod()
                )
                withContext(Dispatchers.IO) {
                    currentClient.insertRecords(listOf(record))
                }
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write mindfulness session: ", e)
                result.error("WRITE_ERROR", e.message ?: "Failed to write mindfulness session", null)
            }
        }
    }

    fun writeBodyTemperature(timeMs: Long, skinTemp: Double?, bodyTemp: Double?, result: MethodChannel.Result) {
        val currentClient = client ?: run {
            result.error("CLIENT_NOT_INITIALIZED", "Health Connect client is not initialized", null)
            return
        }

        val temp = bodyTemp ?: skinTemp ?: run {
            result.error("INVALID_ARGUMENTS", "Body temperature and skin temperature cannot both be null", null)
            return
        }

        scope.launch {
            try {
                val record = BodyTemperatureRecord(
                    time = Instant.ofEpochMilli(timeMs),
                    zoneOffset = null,
                    temperature = Temperature.celsius(temp),
                    metadata = androidx.health.connect.client.records.metadata.Metadata.unknownRecordingMethod()
                )
                withContext(Dispatchers.IO) {
                    currentClient.insertRecords(listOf(record))
                }
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write body temperature: ", e)
                result.error("WRITE_ERROR", e.message ?: "Failed to write body temperature", null)
            }
        }
    }

    fun writeBloodPressure(timeMs: Long, systolic: Int, diastolic: Int, result: MethodChannel.Result) {
        val currentClient = client ?: run {
            result.error("CLIENT_NOT_INITIALIZED", "Health Connect client is not initialized", null)
            return
        }

        scope.launch {
            try {
                val record = BloodPressureRecord(
                    time = Instant.ofEpochMilli(timeMs),
                    zoneOffset = null,
                    systolic = Pressure.millimetersOfMercury(systolic.toDouble()),
                    diastolic = Pressure.millimetersOfMercury(diastolic.toDouble()),
                    metadata = androidx.health.connect.client.records.metadata.Metadata.unknownRecordingMethod()
                )
                withContext(Dispatchers.IO) {
                    currentClient.insertRecords(listOf(record))
                }
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write blood pressure: ", e)
                result.error("WRITE_ERROR", e.message ?: "Failed to write blood pressure", null)
            }
        }
    }

    fun getLatestHeightAndWeight(result: MethodChannel.Result) {
        val currentClient = client ?: run {
            result.error("CLIENT_NOT_INITIALIZED", "Health Connect client is not initialized", null)
            return
        }

        scope.launch {
            try {
                val weightResponse = withContext(Dispatchers.IO) {
                    currentClient.readRecords(
                        ReadRecordsRequest(
                            recordType = WeightRecord::class,
                            timeRangeFilter = TimeRangeFilter.after(Instant.EPOCH)
                        )
                    )
                }
                val heightResponse = withContext(Dispatchers.IO) {
                    currentClient.readRecords(
                        ReadRecordsRequest(
                            recordType = HeightRecord::class,
                            timeRangeFilter = TimeRangeFilter.after(Instant.EPOCH)
                        )
                    )
                }
                val weight = weightResponse.records.maxByOrNull { it.time }?.weight?.inKilograms
                val height = heightResponse.records.maxByOrNull { it.time }?.height?.inMeters
                result.success(
                    mapOf(
                        "weight" to weight,
                        "height" to height
                    )
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed to read height/weight: ", e)
                result.error("READ_ERROR", e.message ?: "Failed to read height/weight", null)
            }
        }
    }
}
