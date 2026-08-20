# Health Connect vs. Mi Band 10 Pro (HyperOS) Health Sync Audit Report

## Executive Summary

This report provides a full, deep technical audit of health data synchronization between **Mi Band 10 Pro (HyperOS firmware)**, **Mi Fitness official application (`com.xiaomi.fitness`)**, **Android Health Connect API (SDK 1.1.0+)**, and **MiSync**.

The audit was conducted by:
1. Extracting every record class, mandatory field, unit, metadata rule, de-duplication mechanism, and feature flag from official Android **Health Connect documentation** (`.docs/HEALTHCONNECT.md`).
2. Reverse-engineering **ALL 30 repositories in the Mi Fitness APK source code** (`.apks/mi_fitness_source/sources/com/xiaomi/fitness/repo/`), including both Health Connect sync delegates (`healthconnect/`) and native Xiaomi data processors (`step`, `heartrate`, `spo2`, `sleep`, `stress`, `calorie`, `summary`, `runningIndex`, `vo2max`, `teperature`, `temperaturetrend`, `bloodsugar`, `bloodpressure`, `ecg`, `weight`, `hearing`, `lactatethreshold`, `energy`, `vitality`, `stand`, `strength`, `curse`).
3. Auditing and refactoring **MiSync implementation** (`lib/health/`, `HealthManager.kt`, `HealthModule.kt`).

---

## 1. Health Connect Master Taxonomy & Metadata Protocol

Health Connect standardizes health and fitness data across Android apps into **40+ record types** across 7 primary categories:

### A. Health Connect Record Categories & Capabilities

| Category | Record Class | Record Type | Unit / Primary Metric | Mandatory Fields | Aggregate Supported |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Activity** | `ActiveCaloriesBurnedRecord` | Interval | Energy (kcal / kJ) | `startTime`, `endTime`, `energy`, `metadata` | Total Energy |
| | `ActivityIntensityRecord` | Interval | Intensity Type (Moderate, Vigorous) | `startTime`, `endTime`, `activityIntensityType`, `metadata` | Duration |
| | `CyclingPedalingCadenceRecord` | Series | Cadence (RPM) | `startTime`, `endTime`, `samples`, `metadata` | Avg, Max, Min |
| | `DistanceRecord` | Interval | Length (meters) | `startTime`, `endTime`, `distance`, `metadata` | Total Distance |
| | `ElevationGainedRecord` | Interval | Length (meters) | `startTime`, `endTime`, `elevation`, `metadata` | Total Elevation |
| | `ExerciseSessionRecord` | Interval | Exercise Type, Laps, Segments, Route | `startTime`, `endTime`, `exerciseType`, `metadata` | Total Duration |
| | `FloorsClimbedRecord` | Interval | Double (floors) | `startTime`, `endTime`, `floors`, `metadata` | Total Floors |
| | `PlannedExerciseSessionRecord` | Interval | Planned Block | `endTime`, `exerciseType`, `hasExplicitTime`, `metadata` | N/A |
| | `PowerRecord` | Series | Power (watts) | `startTime`, `endTime`, `samples`, `metadata` | Avg, Max, Min |
| | `SpeedRecord` | Series | Velocity (m/s) | `startTime`, `endTime`, `samples`, `metadata` | Avg, Max, Min |
| | `StepsRecord` | Interval | Long (count) | `startTime`, `endTime`, `count`, `metadata` | Total Steps |
| | `StepsCadenceRecord` | Series | Rate (steps/min) | `startTime`, `endTime`, `samples`, `metadata` | Avg, Max, Min |
| | `TotalCaloriesBurnedRecord` | Interval | Energy (kcal / kJ) | `startTime`, `endTime`, `energy`, `metadata` | Total Energy |
| | `Vo2MaxRecord` | Instantaneous | mL/kg/min | `time`, `vo2MillilitersPerMinuteKilogram`, `measurementMethod`, `metadata` | Latest |
| | `WheelchairPushesRecord` | Interval | Long (count) | `startTime`, `endTime`, `count`, `metadata` | Total Pushes |
| **Body Measurement** | `BasalMetabolicRateRecord` | Instantaneous | Power (watts / kcal/day) | `time`, `basalMetabolicRate`, `metadata` | Total BMR |
| | `BodyFatRecord` | Instantaneous | Percentage (%) | `time`, `percentage`, `metadata` | Avg, Max, Min |
| | `BodyWaterMassRecord` | Instantaneous | Mass (kg) | `time`, `mass`, `metadata` | Latest |
| | `BoneMassRecord` | Instantaneous | Mass (kg) | `time`, `mass`, `metadata` | Latest |
| | `HeightRecord` | Instantaneous | Length (meters) | `time`, `height`, `metadata` | Avg, Max, Min |
| | `LeanBodyMassRecord` | Instantaneous | Mass (kg) | `time`, `mass`, `metadata` | Latest |
| | `WeightRecord` | Instantaneous | Mass (kg) | `time`, `weight`, `metadata` | Avg, Max, Min |
| **Cycle Tracking** | `BasalBodyTemperatureRecord` | Instantaneous | Temperature (°C) | `time`, `temperature`, `measurementLocation`, `metadata` | N/A |
| | `CervicalMucusRecord` | Instantaneous | Enum (appearance/sensation) | `time`, `appearance`, `sensation`, `metadata` | N/A |
| | `IntermenstrualBleedingRecord` | Instantaneous | Instant | `time`, `metadata` | N/A |
| | `MenstruationFlowRecord` | Instantaneous | Enum (flow level) | `time`, `flow`, `metadata` | N/A |
| | `MenstruationPeriodRecord` | Interval | Period Interval | `startTime`, `endTime`, `metadata` | Total Days |
| | `OvulationTestRecord` | Instantaneous | Enum (result) | `time`, `result`, `metadata` | N/A |
| | `SexualActivityRecord` | Instantaneous | Enum (protection used) | `time`, `protectionUsed`, `metadata` | N/A |
| **Nutrition & Hydration**| `HydrationRecord` | Interval | Volume (liters) | `startTime`, `endTime`, `volume`, `metadata` | Total Volume |
| | `NutritionRecord` | Interval | Mass/Energy (macronutrients) | `startTime`, `endTime`, `mealType`, `metadata` | Total Nutrients |
| **Sleep** | `SleepSessionRecord` | Interval | Stages (Deep, Light, REM, Awake) | `startTime`, `endTime`, `stages`, `metadata` | Total Sleep |
| **Vitals** | `BloodGlucoseRecord` | Instantaneous | mmol/L or mg/dL | `time`, `level`, `mealType`, `relationToMeal`, `specimenSource`, `metadata` | Avg, Max, Min |
| | `BloodPressureRecord` | Instantaneous | Pressure (mmHg) | `time`, `systolic`, `diastolic`, `bodyPosition`, `measurementLocation`, `metadata` | Avg, Max, Min |
| | `BodyTemperatureRecord` | Instantaneous | Temperature (°C) | `time`, `temperature`, `measurementLocation`, `metadata` | Avg, Max, Min |
| | `HeartRateRecord` | Series | Heart Rate (BPM) | `startTime`, `endTime`, `samples`, `metadata` | Avg, Max, Min |
| | `HeartRateVariabilityRmssdRecord` | Instantaneous | Time (milliseconds RMSSD) | `time`, `heartRateVariabilityMillis`, `metadata` | Avg, Max, Min |
| | `OxygenSaturationRecord` | Instantaneous | Percentage (SpO2 %) | `time`, `percentage`, `metadata` | Avg, Max, Min |
| | `RespiratoryRateRecord` | Instantaneous | Rate (breaths/min) | `time`, `rate`, `metadata` | Avg, Max, Min |
| | `RestingHeartRateRecord` | Instantaneous | Heart Rate (BPM) | `time`, `beatsPerMinute`, `metadata` | Avg, Max, Min |
| | `SkinTemperatureRecord` | Series | Baseline + Deltas (°C) | `startTime`, `endTime`, `deltas`, `measurementLocation`, `metadata` | Avg, Max, Min |
| **Wellness** | `MindfulnessSessionRecord` | Interval | Session Type (Breathing, Meditation) | `startTime`, `endTime`, `mindfulnessSessionType`, `metadata` | Total Duration |

### B. Health Connect 1.1.0+ Mandatory Metadata Rules
In Health Connect SDK 1.1.0+, `Metadata` construction requires explicit recording method and device attribution:

1. **Recording Method**: Must use factory methods (`Metadata.activelyRecorded()`, `Metadata.autoRecorded()`, `Metadata.manualEntry()`). `Metadata.unknownRecordingMethod()` is fully deprecated and removed from MiSync.
2. **Device Attribution**: Attached `Device(type = Device.TYPE_WATCH, manufacturer = "Xiaomi", model = "Mi Band 10 Pro")` for sensor-captured records.
3. **De-duplication (`clientRecordId`)**: Constructed via `${id.toHexString()}_<type>` for idempotent upsert deduplication when syncing retries occur.

---

## 2. Exhaustive Mi Fitness APK Repository Audit

A complete reverse-engineering audit of **all 30 data repositories** in the Mi Fitness APK (`com.xiaomi.fitness.repo`) reveals the full scope of telemetry produced by Mi Band 10 Pro (HyperOS) and associated ecosystem hardware:

```
com.xiaomi.fitness.repo
├── healthconnect              # Native HC Sync Subsystem
│   ├── StepSyncBiz.java       # Steps -> StepsRecord
│   ├── HrSyncBiz.java         # HR -> HeartRateRecord
│   ├── CalorieSyncBiz.java    # Daily Calories -> ActiveCaloriesBurnedRecord
│   ├── Spo2SyncBiz.java       # SpO2 -> OxygenSaturationRecord
│   ├── SleepSyncBiz.java      # Sleep -> SleepSessionRecord
│   └── SportSyncBiz.java      # Workouts + Route + Speed + Cadence + Elevation
├── bloodsugar                 # BloodGlucoseBiz.java & BloodSugarRepository.java (CGM & Fingerprick)
├── bloodpressure              # BloodPressureBiz.java & BloodPressureRepository.java (BP Cuffs)
├── ecg                        # EcgRepository.java & InterpretedEcgDataSource.java (ECG Waveforms)
├── teperature / temperaturetrend # TemperatureBiz.java (Core Body Temp & Skin Temp Deltas)
├── weight                     # WeightRepository.java & WeightBiz.java (Scale Body Composition)
├── vo2max                     # VO2MaxBiz.java & VO2MaxRepository.java (VO2 Max Estimation)
├── lactatethreshold           # LactateThresholdBiz.java (Lactate Threshold HR & Pace)
├── runningIndex               # RunningIndicatorBiz.java (Running Performance Index & Recovery)
├── hearing                    # HearingBiz.java (Noise / Decibel Exposure)
├── energy / vitality / pai    # EnergyBiz.java (HyperOS Vitality / PAI Score)
├── stand                      # StandBiz.java (Hourly Stand Goals)
├── strength                   # StrengthBiz.java (Resistance Sets, Reps & Weight)
└── curse                      # CurseRepo.java (Menstruation & Cycle Tracking)
```

---

## 3. Master 360-Degree Health Connect Audit & Refactoring Status Matrix

| Health Connect Data Type | Supported by Mi Band 10 Pro / Hardware? | Synced by Official Mi Fitness HC? | MiSync Refactoring Status | Details of Implemented Refactoring |
| :--- | :--- | :--- | :--- | :--- |
| **Steps** (`StepsRecord`) | Yes (1-min snapshots + workouts) | Yes | **FULLY SUPPORTED** | Suppresses daily steps during workout windows. Stamped with `toHexString()` deduplication key. |
| **Active Calories** (`ActiveCaloriesBurnedRecord`) | Yes (1-min snapshots + workouts) | Yes | **FULLY SUPPORTED (FIXED)** | **DUPLICATION BUG RESOLVED**: Daily snapshot active calories are now filtered with `isOverlapping` during workout windows to prevent double-counting. |
| **Distance** (`DistanceRecord`) | Yes (1-min snapshots + workouts) | Yes | **FULLY SUPPORTED (FIXED)** | **DUPLICATION BUG RESOLVED**: Daily snapshot distance is now filtered with `isOverlapping` during workout windows. |
| **Exercise Session** (`ExerciseSessionRecord`) | Yes (150+ workout modes) | Yes | **FULLY SUPPORTED** | Mapped for Running, Walking, Biking, Swimming, Jump Rope, Yoga, Hiking, etc. Stamped with `toHexString()` deduplication key. |
| **Heart Rate** (`HeartRateRecord`) | Yes (Continuous 1-min + Workouts + Spot checks) | Yes | **FULLY SUPPORTED** | Written as 1-minute series samples and spot measurements with deduplication key. |
| **Oxygen Saturation** (`OxygenSaturationRecord`) | Yes (Periodic + Spot checks) | Yes | **FULLY SUPPORTED** | Written as percentage instantaneous records with deduplication key. |
| **Sleep Session** (`SleepSessionRecord`) | Yes (Night + Daytime Naps + Sleep Stages) | Yes | **FULLY SUPPORTED (FIXED)** | **NOCTURNAL AWAKE & TRUNCATION BUGS RESOLVED**: Uses authoritative `bedTime`/`wakeupTime` header boundaries. Recovers trailing stages. Implements stage padding and bridges nocturnal wake-up gaps with `STAGE_TYPE_AWAKE`. Enforces Health Connect `[startTimeMs, endTimeMs]` clamping and chronological sorting. Stamped with `toHexString()` deduplication key. |
| **Mindfulness Session** (`MindfulnessSessionRecord`) | Yes (Guided Breathing: Box, Bee, Abdominal + Stress) | No | **FULLY SUPPORTED (NEW)** | **ADDED**: Guided breathing (Relax, Concentrate, Sleep Soundly apps) mapped to `MINDFULNESS_SESSION_TYPE_BREATHING`. Stress logs mapped to `MINDFULNESS_SESSION_TYPE_UNGUIDED`. |
| **Heart Rate Variability** (`HeartRateVariabilityRmssdRecord`) | Yes (Hardware measures RMSSD for stress) | No | **FULLY SUPPORTED (NEW)** | **ADDED**: Stress readings are mapped directly to `HeartRateVariabilityRmssdRecord` (RMSSD ms) in Health Connect. |
| **Resting Heart Rate** (`RestingHeartRateRecord`) | Yes (Watch calculates sleep resting HR) | No | **FULLY SUPPORTED (NEW)** | **ADDED**: `writeRestingHeartRate` implemented in `HealthManager.kt` and `HealthModule.kt`. |
| **Respiratory Rate** (`RespiratoryRateRecord`) | Yes (Watch tracks sleep breathing rate) | No | **FULLY SUPPORTED (NEW)** | **ADDED**: `writeRespiratoryRate` implemented in `HealthManager.kt` and `HealthModule.kt`. |
| **Skin Temperature** (`SkinTemperatureRecord`) | Yes (Mi Band 10 Pro has skin temp sensor) | No | **FULLY SUPPORTED (NEW)** | **ADDED**: `writeSkinTemperature` implemented in `HealthManager.kt` and `HealthModule.kt`. |
| **Body Temperature** (`BodyTemperatureRecord`) | Yes (Spot checks) | No | **FULLY SUPPORTED** | Supported for manual/spot temp readings with deduplication key. |
| **Blood Pressure** (`BloodPressureRecord`) | Yes (Manual / Cuff sync) | No | **FULLY SUPPORTED** | Systolic and Diastolic written cleanly with deduplication key. |
| **VO2 Max** (`Vo2MaxRecord`) | Yes (Calculated post-running workouts) | No | **FULLY SUPPORTED (NEW)** | **ADDED**: `writeVo2Max` implemented with `MEASUREMENT_METHOD_HEART_RATE_RATIO` in `HealthManager.kt`. |
| **Metadata Attribution** (`Metadata`) | Full SDK support | Yes | **FULLY SUPPORTED (FIXED)** | Replaced deprecated `unknownRecordingMethod()` with `Metadata.autoRecorded` / `activelyRecorded`, `Device(type = TYPE_WATCH, manufacturer = "Xiaomi", model = "Mi Band 10 Pro")`, and `toHexString()` clientRecordId. |

---

## 4. Key Architectural Enhancements Accomplished

> [!WARNING]
> **Active Calorie & Distance Duplication RESOLVED**:
> In `lib/health/module.dart`, `_syncSnapshotsFile()` now checks `isOverlapping` against active workout time ranges (`exerciseRanges`). Daily active calories and daily distance falling inside workout windows are explicitly suppressed, eliminating double-counting in Health Connect.

> [!IMPORTANT]
> **Nocturnal Wake-Up & Sleep Duration Continuity RESOLVED**:
> Reverse-engineering of `SleepSyncBiz.java`, `SleepAggregateUtils.java`, and `DayNightSleepConverter.java` revealed that nocturnal awakenings (e.g. getting out of bed for a pet, water, or restroom) generated split stage sequences that were previously truncated in Health Connect:
> 1. **Header-First Session Boundaries**: `Sleep.startTime` and `Sleep.endTime` now prioritize the watch's official `bedTime` and `wakeupTime` headers, ensuring the overall session reflects the true night span (Time in Bed) regardless of intermediate waking breaks.
> 2. **Trailing Stage Recovery**: `_parseNightSleep` and `_parseDaytimeSleep` now capture the final sleep stage from the last transition timestamp up to `wakeupTime`, eliminating the dropped tail stage bug.
> 3. **Automatic Stage Padding & Intermediate Wake-Gap Bridging**: `formattedStages` automatically pads sleep onset/wake-up buffers with `STAGE_TYPE_AWAKE` and bridges intermediate waking gaps with explicit `STAGE_TYPE_AWAKE` records.
> 4. **Strict Health Connect Range Clamping & Chronological Sorting**: `HealthManager.kt` clamps all stages strictly within `[startTimeMs, endTimeMs]`, discards malformed non-positive intervals, and sorts stages chronologically to satisfy Health Connect SDK constraints.

> [!IMPORTANT]
> **Metadata & Native De-duplication (`clientRecordId`) INSTALLED**:
> 1. **`clientRecordId` added**: Every record now passes a deterministic `clientRecordId` constructed from `${id.toHexString()}_<type>`. If a sync attempt retries, Health Connect natively updates existing records instead of inserting duplicates.
> 2. **Device attribution added**: All records are attributed to `Device(type = Device.TYPE_WATCH, manufacturer = "Xiaomi", model = "Mi Band 10 Pro")`.

> [!TIP]
> **Expanded Beyond Official Mi Fitness Health Connect Sync**:
> MiSync now syncs **MindfulnessSessionRecord** (Guided Breathing & Stress logs), **HeartRateVariabilityRmssdRecord** (from HRV stress logs), **RestingHeartRateRecord** (from sleep), **RespiratoryRateRecord** (from sleep breathing), **Vo2MaxRecord** (from running summaries with `MEASUREMENT_METHOD_HEART_RATE_RATIO`), and **SkinTemperatureRecord** (from wrist temp deltas).

---

## 5. Summary of Refactored Files

- **`android/app/src/main/kotlin/com/misync/health/HealthManager.kt`**: Upgraded `Metadata` to `autoRecorded`/`activelyRecorded` with `Device(TYPE_WATCH)` and `clientRecordId`. Added write methods for Mindfulness Sessions, HRV, Resting HR, Sleep Respiratory Rate, VO2 Max (`MEASUREMENT_METHOD_HEART_RATE_RATIO`), and Skin Temp. Implemented sleep stage boundary clamping, chronological sorting, and fallback handling to `STAGE_TYPE_SLEEPING`.
- **`android/app/src/main/kotlin/com/misync/health/HealthModule.kt`**: Added Health Connect write permissions and registered MethodChannel handlers.
- **`lib/health/parsers/types/sleep.dart`**: Prioritized `bedTime` and `wakeupTime` for session boundaries. Implemented `formattedStages` continuous stage padding and intermediate awake gap bridging.
- **`lib/health/parsers/sleep.dart`**: Implemented trailing stage capture after while-loops in `_parseNightSleep` and `_parseDaytimeSleep`.
- **`lib/health/parsers/id.dart`**: Provides clean `toHexString()` identifier method.
- **`lib/health/module.dart`**: Implemented `isOverlapping` filtering for active calories and distance in daily snapshots. Passed deterministic `toHexString()` clientRecordId keys across all sync calls. Added Mindfulness and HRV sync for stress logs.
- **`android/app/src/main/AndroidManifest.xml`**: Declared all 18 Health Connect `<uses-permission>` permissions to enforce runtime security compliance.

---

## 6. Technical Audit Notes & Integration Clarifications

> [!NOTE]
> **Nocturnal Wake-Up Handling & DayNightSleepConverter Mechanics**:
> 1. In official Mi Fitness (`DayNightSleepConverter.java`), when a user wakes up during the night:
>    - Awake intervals $\le 10$ minutes are maintained inline within the active sleep segment.
>    - Awake intervals $> 10$ minutes generate a split segment boundary, but `mergeTwoSleepInNeed()` merges segments back together if total combined sleep $\ge 180$ minutes and the intervening break is marked as `AWAKE` (`state = 5`).
> 2. In MiSync, by using authoritative `bedTime`/`wakeupTime` headers and encoding intermediate waking gaps as `STAGE_TYPE_AWAKE`, Health Connect accurately computes:
>    $$\text{Time in Bed} = \text{wakeupTime} - \text{bedTime}$$
>    $$\text{Total Sleep Duration} = \sum (\text{DEEP} + \text{LIGHT} + \text{REM})$$
>    $$\text{Awake Duration} = \sum \text{AWAKE}$$
>    This matches the watch's display and eliminates shortened/fragmented sessions in Google Health Connect.

> [!NOTE]
> **Health Connect Manifest Permissions**:
> In Android Health Connect SDK (SDK 34+), runtime permission checks verify both Health Connect granted status and `AndroidManifest.xml` `<uses-permission>` tags. All 18 Health Connect data types (including `WRITE_HEART_RATE_VARIABILITY`, `WRITE_RESTING_HEART_RATE`, `WRITE_RESPIRATORY_RATE`, `WRITE_VO2_MAX`, `WRITE_SKIN_TEMPERATURE`) are declared in `AndroidManifest.xml` to prevent `SecurityException` runtime errors.

> [!NOTE]
> **Google Health / Fitbit "Sleep Score" Policy**:
> 1. `SleepSessionRecord` in Health Connect intentionally lacks a `SleepScore` API field because sleep scores are manufacturer-proprietary algorithms.
> 2. The Google Health (Fitbit) Android app restricts its "Sleep Score" tab to 1st-party Fitbit and Pixel Watch hardware.
> 3. For third-party apps like MiSync, Google Health displays full sleep sessions, sleep stage charts (Deep, Light, REM, Awake), and efficiency under **"Total Duration"** and **"Main Sleep"**.

> [!NOTE]
> **Mindfulness, Guided Breathing & Stress Apps**:
> 1. **Relax, Concentrate & Sleep Soundly Apps**: Watch-initiated guided breathing sessions (Box breathing, Bee breathing, Abdominal breathing) are logged to Health Connect as `MindfulnessSessionRecord` (`mindfulnessSessionType = MINDFULNESS_SESSION_TYPE_BREATHING`) alongside `HeartRateRecord` and `HeartRateVariabilityRmssdRecord`.
> 2. **Passive Stress Logs**: Continuous stress logs are written to Health Connect as `MindfulnessSessionRecord` (`mindfulnessSessionType = MINDFULNESS_SESSION_TYPE_UNGUIDED`) and `HeartRateVariabilityRmssdRecord`.

> [!NOTE]
> **Daytime Naps ("Take a Nap") vs. Main Sleep**:
> Decompiled APK logic (`DayNightSleepConverter.java`) splits sleep into Main Sleep (nighttime) and Naps (daytime sessions $\ge 20$ min). MiSync parses all sleep segments regardless of time of day and writes them to Health Connect as valid `SleepSessionRecord` instances.

> [!NOTE]
> **Xiaomi Vitality Score (PAI Successor)**:
> HyperOS calculates a 7-day rolling 0–100 **Vitality Score** based on heart rate exertion over time. Health Connect does not store 0–100 proprietary scores, but stores the underlying exertion via `ActivityIntensityRecord` (Moderate vs. Vigorous exertion minutes) and `HeartRateRecord`.


