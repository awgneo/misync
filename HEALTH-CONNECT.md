Health Connect requires a mobile device running **Android 9 (API 28)** or higher
with **Google Play services** installed.

Health Connect is exclusive to Android and Google Play. Users can access Health
Connect in two ways, depending on their Android version:

- **On Android 14 and higher,** Health Connect is part of the Android system and is accessible in **Settings**.
- **On Android 13 and lower,** Health Connect is a publicly available app on the Google Play Store.

| **Note:** Health Connect is not supported on devices with work profiles. While users might be able to grant permissions in the work profile, the Health Connect APIs won't be usable, and no data will be written because the work profile is never considered to be in the foreground. Consider this limitation when developing for Google Workspace users.

## Android 14 framework

Health Connect is packaged with Android 14 as part of the Android system, which
means you cannot uninstall it from a device.

### Entry points

On Android 14, users access Health Connect app permissions and data in the
following ways:

- Go to **Settings \> Security \& Privacy \> Privacy \> Health Connect**.
- Go to **Settings \> Security \& Privacy \> Privacy \> Privacy dashboard \>
  (see other permissions) \> Health Connect**.
- Go to **Settings \> Security \& Privacy \> Privacy \> Permission manager \>
  Health Connect**.

## Android 13 APK

The Health Connect app was launched on the Google Play Store on
November 11, 2022.

Once third-party developers [integrate](https://developer.android.com/health-and-fitness/guides/health-connect/develop/get-started) their apps and
[declare access](https://developer.android.com/health-and-fitness/guides/health-connect/publish/declare-access) to the Health Connect APIs and data types, their apps
can read, write, and share approved data types from the user's on-device store.

Check out the [migration guide](https://developer.android.com/health-and-fitness/guides/health-connect/migrate/migrate-from-android-13-to-14) for guidance on how data is migrated
between the APK and the framework model once users make the switch from
Android 13 to Android 14.

When new features are added to Health Connect, users may not always update their
version of Health Connect. The Feature Availability API is a way to check if a
feature in Health Connect is available on your user's device and decide what
action to take.

## Get started

The Feature Availability API shares the same dependency as the Health Connect
SDK. To get started, verify that at least version `1.1.0-alpha08` is in your
`build.gradle` file:

    dependencies {
      implementation("androidx.health.connect:connect-client:1.1.0-alpha08")
    }

## Feature flags

The feature flags available for Health Connect are listed in the following
table. Functionality behind a feature flag won't be available for use if the
user's device doesn't support the feature.

<br />

| Feature flag | Data type | Related guides |
|---|---|---|
| `FEATURE_ACTIVITY_INTENSITY` | Activity intensity | [Workouts](https://developer.android.com/health-and-fitness/health-connect/experiences/workouts) |
| `FEATURE_EXTENDED_DEVICE_TYPES` | Extended device types | [Metadata requirements](https://developer.android.com/health-and-fitness/health-connect/metadata#device-type) |
| `FEATURE_MATCHMAKING` | Matchmaking |   |
| `FEATURE_PERSONAL_HEALTH_RECORD` | Medical records | [Medical Records data format](https://developer.android.com/health-and-fitness/health-connect/medical-records/data-format) [Write medical data](https://developer.android.com/health-and-fitness/health-connect/medical-records/write-data) [Read medical data](https://developer.android.com/health-and-fitness/health-connect/medical-records/read-data) |
| `FEATURE_MINDFULNESS_SESSION` | Mindfulness | [Track mindfulness](https://developer.android.com/health-and-fitness/health-connect/features/mindfulness) |
| `FEATURE_PLANNED_EXERCISE` | Planned exercise | [Workouts](https://developer.android.com/health-and-fitness/health-connect/experiences/workouts) [Training plans](https://developer.android.com/health-and-fitness/health-connect/features/training-plans) |
| `FEATURE_READ_HEALTH_DATA_IN_BACKGROUND` | Read data in background | [Background read example](https://developer.android.com/health-and-fitness/health-connect/read-data#background-read-example) |
| `FEATURE_READ_HEALTH_DATA_HISTORY` | Read historical data | [Read data older than 30 days](https://developer.android.com/health-and-fitness/health-connect/read-data#read-older-data) |
| `FEATURE_SKIN_TEMPERATURE` | Skin temperature | [Vitals](https://developer.android.com/health-and-fitness/health-connect/experiences/vitals) [Measure skin temperature](https://developer.android.com/health-and-fitness/health-connect/features/skin-temperature) |
[*Table: Health Connect feature availability flags*]

<br />

## Perform the check

The main function to check for feature availability is `getFeatureStatus()`.
This returns integer constants `FEATURE_STATUS_AVAILABLE` or
`FEATURE_STATUS_UNAVAILABLE`:
To determine whether a user's device supports Read Health Data in Background on Health Connect, check the availability of `FEATURE_READ_HEALTH_DATA_IN_BACKGROUND` on the client:

<br />

    if (healthConnectClient
         .features
         .getFeatureStatus(
           HealthConnectFeatures.FEATURE_READ_HEALTH_DATA_IN_BACKGROUND
         ) == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE) {

      // Feature is available
    } else {
      // Feature isn't available
    }

For a list of all available feature flags, see the [`HealthConnectFeatures`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectFeatures)
reference page.

## Handle lack of feature availability

If a feature isn't available on a user's device, an update may enable it. You
may consider directing the user to update Health Connect if they don't have
the latest supported version on their device. However, users using the APK
(on Android 13 and lower) can't use the system module features that are only
available on devices running Android 14 or higher.

For extended device types, if [`FEATURE_EXTENDED_DEVICE_TYPES`](https://developer.android.com/health-and-fitness/guides/health-connect/develop/metadata#device-type) isn't
available on the user's device, those values are treated as
`Device.TYPE_UNKNOWN`. Provide a sensible fallback in your write and UI logic.

Data types in Health Connect are stored in objects that are subclasses of
[`Record`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/Record).

For each data type, there are associated fields that are either generic such as
`time` and `zoneOffset`, or specific such as `title`, `count`, and `percentage`.
Some fields use basic types---such as long, double, or string---while others use
complex types like enumerations and classes like [`Instant`](https://developer.android.com/reference/java/time/Instant) and
[`ZoneOffset`](https://developer.android.com/reference/java/time/ZoneOffset). The attributes of these fields can be required or
optional. Some attributes are read-only, and some attributes are clamped to a
specific range of values.

For the full list of available data types and their fields, refer to the classes
in [Jetpack](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/package-summary#classes).

## Metadata attributes

Data in the Health Connect API also includes [metadata](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/metadata/Metadata) attributes
described in the following list:

- **Health Connect ID:** Each point of data is assigned with a unique identifier (UID) upon creation. This is useful for standard read and write operations. See [Health Connect ID](https://developer.android.com/health-and-fitness/health-connect/data-format#health-connect-id) for more details.
- **Last modified time:** This marks the timestamp the last instance a record has an update. It's automatically generated on the first creation of the record or on every update.
- **Data origin:** Health Connect stores information about the app where the data came from. It contains the package name of that origin, which is automatically added upon creation.
- **Device:** Health Connect stores information about the device where the data came from. It contains the manufacturer and model of that device, which you manually supply the value.
- **Client ID:** Health Connect provides Client IDs so that client apps can refer to data using their own IDs, which helps with conflict resolution and makes syncing easier. This is supplied to the record manually.
- **Client record version:** Along with the Client ID, Health Connect provides versioning to help tracking changes during data syncing. This is supplied to the record manually.
- **Recording method:** Health Connect lets you understand how data is recorded. These methods include apps recording data passively (automatically), and users recording data actively or manually.

## Health Connect ID

Health Connect assigns unique identifiers (UIDs) to newly inserted data objects,
which identify data objects and distinguish them from others. Health Connect IDs
are useful in read or write requests. Health Connect IDs aren't identical to
Client IDs. A client app assigns Client IDs, while Health Connect exclusively
assigns Health Connect IDs.

**Keep in mind** of the following notes when working with Health Connect IDs:

- Sessions have a single Health Connect ID, but data within sessions have their own Health Connect IDs.
- Health Connect IDs aren't tied or related to timestamps.
- Some use cases might require storing a specific Health Connect ID during a workflow. For example, a specific ID is required to retrieve and show to a user the data entry that they just logged.

## Time in Health Connect

All data written to Health Connect must specify the zone offset information.
Specifying the zone offset enables apps to read the data to represent it in
civil time. Civil time is the time that is local and relevant to the user,
but not necessarily in Coordinated Universal Time (UTC).

In rare circumstances, the zone offset might not be available. When this occurs
in Android 14 (API Level 34), Health Connect sets the zone offset based on the
system default time zone of the device. In Android 13 and lower versions
(API Level 33 and lower), it's possible to write to Health Connect without
specifying any zone offset information, which must be avoided whenever possible.

### Time and zone setting

Specifying zone offset information while writing data provides time zone
information when reading data in Health Connect. However, it may fail to do so
in certain situations, such as when the zone offset isn't provided. Your app
needs to be prepared to deal with both kinds of data, in a way that makes sense
for your specific circumstances.

> This guide is compatible with Health Connect version [1.1.0-alpha12](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0-alpha12).

This guide covers the process of writing or updating data in Health Connect.

> [!TIP]
> **Tip:** For more guidance on how to write data, take a look at the [Android Developer video for reading and writing data](https://www.youtube.com/watch?v=NAx7Gv_Hk7E) in Health Connect.

## Handle zero values

Some data types like steps, distance, or calories might have a value of `0`.
Only write zero values when it reflects true inactivity while the user was
wearing the device. Don't write zero values if the device wasn't worn, data is
missing, or the battery died. In such cases, omit the record to avoid misleading
data.

## Set up data structure

Before writing data, we need to set up the records first. For more than 50 data
types, each have their respective structures.
See the [Jetpack reference](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/package-summary#classes) for more details about the data
types available.

### Basic records

The [Steps](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/StepsRecord) data type in Health Connect captures the number of steps a
user has taken between readings. Step counts represent a common measurement
across health, fitness, and wellness platforms.

The following example shows how to set steps count data:


```kotlin
val zoneOffset = ZoneOffset.systemDefault().rules.getOffset(startTime)
val stepsRecord = StepsRecord(
    count = 120,
    startTime = startTime,
    endTime = endTime,
    startZoneOffset = zoneOffset,
    endZoneOffset = zoneOffset,
    metadata = Metadata.autoRecorded(
        device = Device(type = Device.TYPE_WATCH)
    )
)
healthConnectClient.insertRecords(listOf(stepsRecord))
```

<br />

> [!NOTE]
> **Note:** Only write a zero value if the device was worn and no activity occurred. Don't write data if the device was off-body or the data is incomplete. For best practices on handling time zones, see the [Time zone handling](https://developer.android.com/health-and-fitness/health-connect/write-data#time-zone-handling) section.

### Records with units of measurement

Health Connect can store values along with their units of measurement to provide
accuracy. One example is the [Nutrition](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord) data type that is vast and
comprehensive. It includes a wide variety of optional nutrient fields ranging
from total carbohydrates to vitamins. Each data point represents the nutrients
that were potentially consumed as part of a meal or food item.

In this data type, all of the nutrients are represented in units of
[Mass](https://developer.android.com/reference/kotlin/androidx/health/connect/client/units/Mass), while `energy` is represented in a unit of [Energy](https://developer.android.com/reference/kotlin/androidx/health/connect/client/units/Energy).

The following example shows how to set nutrition data for a user who has
eaten a banana:


```kotlin
val endTime = Instant.now()
val startTime = endTime.minus(Duration.ofMinutes(1))

val banana = NutritionRecord(
    name = "banana",
    energy = 105.0.kilocalories,
    dietaryFiber = 3.1.grams,
    potassium = 0.422.grams,
    totalCarbohydrate = 27.0.grams,
    totalFat = 0.4.grams,
    saturatedFat = 0.1.grams,
    sodium = 0.001.grams,
    sugar = 14.0.grams,
    vitaminB6 = 0.0005.grams,
    vitaminC = 0.0103.grams,
    startTime = startTime,
    endTime = endTime,
    startZoneOffset = ZoneOffset.UTC,
    endZoneOffset = ZoneOffset.UTC,
    metadata = Metadata.activelyRecorded(
        device = Device(type = Device.TYPE_PHONE)
    )
)
```

<br />

### Records with series data

Health Connect can store a list of series data. One example is the
[Heart Rate](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord) data type that captures a series of heartbeat samples
detected between readings.

In this data type, the parameter `samples` is represented by a list of
[Heart Rate samples](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord.Sample). Each sample contains a `beatsPerMinute`
value and a `time` value.

The following example shows how to set heart rate series data:


```kotlin
val endTime = Instant.now()
val startTime = endTime.minus(Duration.ofMinutes(5))

val heartRateRecord = HeartRateRecord(
    startTime = startTime,
    startZoneOffset = ZoneOffset.UTC,
    endTime = endTime,
    endZoneOffset = ZoneOffset.UTC,
    // records 10 arbitrary data, to replace with actual data
    samples = List(10) { index ->
        HeartRateRecord.Sample(
            time = startTime + Duration.ofSeconds(index.toLong()),
            beatsPerMinute = 100 + index.toLong(),
        )
    },
    metadata = Metadata.activelyRecorded(
        device = Device(type = Device.TYPE_WATCH)
    ))
```

<br />

## Request permissions from the user

After creating a client instance, your app needs to request permissions from
the user. Users must be allowed to grant or deny permissions at any time.

To do so, create a set of permissions for the required data types.
Make sure that the permissions in the set are declared in your Android
manifest first.


```kotlin
val permissions =
    setOf(
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getWritePermission(HeartRateRecord::class),
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getWritePermission(StepsRecord::class)
    )
```
Use [`getGrantedPermissions`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/PermissionController#getGrantedPermissions()) to see if your app already has the required permissions granted. If not, use [`createRequestPermissionResultContract`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/PermissionController#createRequestPermissionResultContract(kotlin.String)) to request those permissions. This displays the Health Connect permissions screen.

```kotlin
val permissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getWritePermission(StepsRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getWritePermission(HeartRateRecord::class)
    )

val requestPermissionsLauncher = rememberLauncherForActivityResult(
    contract = PermissionController.createRequestPermissionResultContract()
) { grantedPermissions ->
    if (grantedPermissions.containsAll(permissions)) {
        coroutineScope.launch { snackbarHostState.showSnackbar("Permissions granted!") }
    } else {
        coroutineScope.launch { snackbarHostState.showSnackbar("Permissions denied.") }
    }
}
```
Because users can grant or revoke permissions at any time, your app needs to check for permissions every time before using them and handle scenarios where permission is lost.

<br />

## Write data

One of the common workflows in Health Connect is writing data. To add records,
use [`insertRecords`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#insertRecords(kotlin.collections.List)).

The following example shows how to write data inserting step counts:


```kotlin
val zoneOffset = ZoneOffset.systemDefault().rules.getOffset(startTime)
val stepsRecord = StepsRecord(
    count = 120,
    startTime = startTime,
    endTime = endTime,
    startZoneOffset = zoneOffset,
    endZoneOffset = zoneOffset,
    metadata = Metadata.autoRecorded(
        device = Device(type = Device.TYPE_WATCH)
    )
)
healthConnectClient.insertRecords(listOf(stepsRecord))
```

<br />

## Update data

If you need to change one or more records, especially when you need to
[sync](https://developer.android.com/guide/health-and-fitness/health-connect/develop/sync-data) your app datastore with data from Health Connect, you can update
your data. There are two ways to update existing data which depends on the
identifier used to find records.

### Metadata

It is worth examining the `Metadata` class first as this is necessary when
updating data. On creation, each [`Record`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/Record) in Health Connect has a
[`metadata`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/metadata/Metadata) field. The following properties are relevant to
synchronization:

| Properties | Description |
|---|---|
| `id` | Every `Record` in Health Connect has a unique `id` value. **Health Connect automatically populates this** **when inserting a new record.** |
| `lastModifiedTime` | Every `Record` also keeps track of the last time the record was modified. **Health Connect automatically populates this.** |
| `clientRecordId` | Each `Record` can have a unique ID associated with it to serve as reference in your app datastore. **Your app supplies this value.** |
| `clientRecordVersion` | Where a record has `clientRecordId`, the `clientRecordVersion` can be used to allow data to stay in sync with the version in your app datastore. **Your app supplies this value.** |

### Update after reading by time range

To update data, prepare the needed records first. Perform any changes to the
records if necessary. Then, call [`updateRecords`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#updateRecords(kotlin.collections.List)) to make
the changes.

The following example shows how to update data. For this purpose, each record
has its zone offset values adjusted into PST.


```kotlin
suspend fun updateSteps(
    healthConnectClient: HealthConnectClient,
    prevRecordStartTime: Instant,
    prevRecordEndTime: Instant
) {
    try {
        val request = healthConnectClient.readRecords(
            ReadRecordsRequest(
                recordType = StepsRecord::class, timeRangeFilter = TimeRangeFilter.between(
                    prevRecordStartTime,
                    prevRecordEndTime
                )
            )
        )

        val newStepsRecords = arrayListOf<StepsRecord>()
        for (record in request.records) {
            // Adjusted both offset values to reflect changes
            val sr = StepsRecord(
                count = record.count,
                startTime = record.startTime,
                startZoneOffset = record.startTime.atZone(ZoneId.of("PST")).offset,
                endTime = record.endTime,
                endZoneOffset = record.endTime.atZone(ZoneId.of("PST")).offset,
                metadata = record.metadata
            )
            newStepsRecords.add(sr)
        }

        healthConnectClient.updateRecords(newStepsRecords)
    } catch (e: Exception) {
        // Run error handling here
    }
}
```

<br />

### Upsert through Client Record ID

If you are using the optional Client Record ID and Client Record Version values,
we recommend using [`insertRecords`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#insertRecords(kotlin.collections.List)) instead of `updateRecords`.

The `insertRecords` function has the ability to upsert data.
If the data exists in Health Connect based on the given set of
Client Record IDs, it gets overwritten. Otherwise, it is written as new data.
This scenario is useful whenever you need to [sync](https://developer.android.com/guide/health-and-fitness/health-connect/develop/sync-data) data from
your app datastore to Health Connect.

The following example shows how to perform an upsert on data pulled from
the app datastore:


```kotlin
 fun pullStepsFromDatastore(startTime: Instant, endTime: Instant) : ArrayList<StepsRecord> {
    val appStepsRecords = arrayListOf<StepsRecord>()
    // Pull data from app datastore
    // ...
    // Make changes to data if necessary
    // ...
    // Store data in appStepsRecords
    // ...
    var sr = StepsRecord(
        metadata = Metadata.activelyRecorded(
            clientRecordId = "Your client record ID",
            clientRecordVersion = 0L,
            device = Device(type = Device.TYPE_WATCH)
        ),
        startTime = startTime,
        startZoneOffset = startTime.atZone(ZoneId.of("PST")).offset,
        endTime = endTime,
        endZoneOffset = endTime.atZone(ZoneId.of("PST")).offset,
        count = 120
    )
    appStepsRecords.add(sr)
    // ...
    return appStepsRecords
}

suspend fun upsertSteps(
    healthConnectClient: HealthConnectClient,
    newStepsRecords: ArrayList<StepsRecord>
) {
    try {
        healthConnectClient.insertRecords(newStepsRecords)
    } catch (e: Exception) {
        // Run error handling here
    }
}
```

<br />

After that, you can call these functions in your main thread.


```kotlin
upsertSteps(healthConnectClient, pullStepsFromDatastore(
    startTime = startTime,
    endTime = endTime
))
```

<br />

#### Value check in Client Record Version

If your process of upserting data includes the Client Record Version, Health
Connect performs comparison checks in the [`clientRecordVersion`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/metadata/Metadata#clientRecordVersion())
values. If the version from the inserted data is higher than the
version from the existing data, the upsert happens. Otherwise, the process
ignores the change and the value remains the same.

To include versioning in your data, you need to supply
`Metadata.clientRecordVersion` with a `Long` value based on your versioning
logic.


```kotlin
val endTime = Instant.now()
val startTime = endTime.minus(Duration.ofMinutes(15))

val stepsRecord = StepsRecord(
    count = 100L,
    startTime = startTime,
    startZoneOffset = ZoneOffset.UTC,
    endTime = endTime,
    endZoneOffset = ZoneOffset.UTC,
    metadata = Metadata.activelyRecorded(
        clientRecordId = "Your supplied record ID",
        clientRecordVersion = 0L, // Your supplied record version
        device = Device(type = Device.TYPE_WATCH)
    )
)
```

<br />

Upserts don't automatically increment `version` whenever there are changes,
preventing any unexpected instances of overwriting data. With that, you have to
manually supply it with a higher value.

## General guidance

Your app should write all supported first-party data. Optionally, you can
choose to have your app write data obtained from third-party sources. However,
if your app has read data from Health Connect, that data shouldn't be
written back into Health Connect.

When writing data that has been imported or derived from another source, you
are expected to correctly attribute its origin and source device metadata.
To do this, you must supply the following metadata for each written record:

- **`recordingMethod`** : For automatically or manually recorded data, we expect the recording method to be updated to reflect the type of activity that has been recorded:
  - `RECORDING_METHOD_AUTOMATICALLY_RECORDED`: If the data was automatically recorded, for example, a fitness band automatically detected the user went for a run.
  - `RECORDING_METHOD_ACTIVELY_RECORDED`: If the user started a new activity, such as biking on their wearable.
  - `RECORDING_METHOD_MANUAL_ENTRY`: If the user entered the data manually.
- **`device.type`** : You are required to specify a device type from one of the supported `Device` types.
- **`device.manufacturer`**: The device's manufacturer, for example, "Fitbit".
- **`device.model`**: The device's model, for example, "Charge 3".

Setting metadata correctly is crucial for data transparency and helps
users understand where their health information comes from. For complete
details, refer to the Health Connect metadata guide.

If data in your app has been imported from another app, then the responsibility
falls onto the other app to write its own data to Health Connect.

It's also a good idea to implement logic that handles write exceptions such as
data being outside of bounds, or an internal system error. You can apply your
backoff and retry strategies on a job scheduling mechanism. If writing to
Health Connect is ultimately unsuccessful, make sure that your app can move past
that point of export. Don't forget to log and report errors to aid diagnosis.

When tracking data, there are a couple of suggestions you can
follow depending on the way your app writes data.

### Time zone handling

When writing time-based records, avoid setting offsets to **zoneOffset.UTC**
by default because this can lead to inaccurate timestamps when users are in
other zones. Instead, calculate the offset based on the device's actual
location. You can retrieve the device's time zone using
`ZoneId.systemDefault()`.


```kotlin
val endTime = Instant.now()
val startTime = endTime.minus(Duration.ofDays(1))
val stepsRecords = mutableListOf<StepsRecord>()
var sampleTime = startTime
val minutesBetweenSamples = 15L
while (sampleTime < endTime) {
    // Get the default ZoneId then convert it to an offset
    val zoneOffset = ZoneOffset.systemDefault().rules.getOffset(sampleTime)
    stepsRecords += StepsRecord(
        startTime = sampleTime.minus(Duration.ofMinutes(minutesBetweenSamples)),
        startZoneOffset = zoneOffset,
        endTime = sampleTime,
        endZoneOffset = zoneOffset,
        count = Random.nextLong(1, 100),
        metadata = Metadata.activelyRecorded(device = Device(type = Device.TYPE_WATCH)),
    )
    sampleTime = sampleTime.plus(Duration.ofMinutes(minutesBetweenSamples))
}
healthConnectClient.insertRecords(
    stepsRecords
)
```

<br />

See the [documentation for `ZoneId`](https://developer.android.com/reference/kotlin/java/time/ZoneId) for more details.

### Write frequency and granularity

When writing data to Health Connect, use appropriate resolution. Using the
appropriate resolution helps reduce storage load, while still maintaining
consistent and accurate data. Data resolution encompasses two things:

- **Frequency of writes** : How often your application write any new data into Health Connect.
  - Write data as frequently as possible when new data is available, while being mindful of device performance.
  - To avoid negatively impacting battery life and other performance aspects, the maximum interval between writes should be 15 minutes.
- **Granularity of written data** : How often the data was sampled.
  - For example, write heart rate samples every 5 seconds.
  - Not every data type requires the same sample rate. There is little benefit to updating step count data every second, as opposed to a less frequent cadence such as every 60 seconds.
  - Higher sample rates may give users a more detailed and granular look at their health and fitness data. Sample rate frequencies should strike a balance between detail and performance.

> [!NOTE]
> **Note:** If your app relies on data from devices that sync less frequently than 15 minutes, adjust your writes to match the device's sync interval. This avoid empty writes to Health Connect.

### Additional guidelines

Follow these guidelines when writing data:

- On every sync, only write new data and updated data that was modified since the last sync.
- Chunk requests to at most 1000 records per write request.
- Restrict tasks to run only when the device is idle and is not low on battery.
- For background tasks, use [WorkManager](https://developer.android.com/topic/libraries/architecture/workmanager) to schedule periodic tasks, with a maximum time period of 15 minutes.

The following code uses WorkManager to schedule periodic background tasks, with
a maximum time period of 15 minutes, and a flex interval of 5 minutes. This
configuration is set using the
[`PeriodicWorkRequest.Builder`](https://developer.android.com/reference/kotlin/androidx/work/PeriodicWorkRequest.Builder#Builder(java.lang.Class,kotlin.Long,java.util.concurrent.TimeUnit,kotlin.Long,java.util.concurrent.TimeUnit)) class.

    val constraints = Constraints.Builder()
        .requiresBatteryNotLow()
        .requiresDeviceIdle(true)
        .build()

    val writeDataWork = PeriodicWorkRequestBuilder<WriteDataToHealthConnectWorker>(
            15,
            TimeUnit.MINUTES,
            5,
            TimeUnit.MINUTES
        )
        .setConstraints(constraints)
        .build()

### Active tracking

This includes apps that perform event-based tracking such as exercise and sleep,
or manual user input such as nutrition. These records are created when the app
is in the foreground, or in rare events where it is used a few times in a day.

Verify that your app doesn't keep Health Connect running for the entire
duration of the event.

Data must be written to Health Connect in one of two ways:

- Sync data to Health Connect after the event is complete. For example, sync data when the user ends a tracked exercise session.
- Schedule a one-off task using [`WorkManager`](https://developer.android.com/topic/libraries/architecture/workmanager) to sync data later.

## Best practices for granularity and frequency of writes

When writing data to Health Connect, use appropriate resolution. Using the
appropriate resolution helps reduce storage load, while still maintaining
consistent and accurate data. Data resolution encompasses 2 things:

1. **Frequency of writes**: how often your application pushes any new data into
   Health Connect. Write data as frequently as possible when new data is
   available, while being mindful of device performance. To avoid negatively
   impacting battery life and other performance aspects, the maximum interval
   between writes should be 15 minutes.

2. **Granularity of written data**: how often the data that is pushed in was
   sampled. For example, write heart rate samples every 5s. Not every data type
   requires the same sample rate. There is little benefit to updating step count
   data every second, as opposed to a less frequent cadence such as every 60
   seconds. However, higher sample rates may give users a more detailed and
   granular look at their health and fitness data. Sample rate frequencies
   should strike a balance between detail and performance.

### Structure records for series data

For data types that use a series of samples, such as `HeartRateRecord`, it's
important to structure your records correctly. Instead of creating a single,
day-long record that is constantly updated, you should create multiple smaller
records, each representing a specific time interval.

For example, for heart rate data, you should create a new `HeartRateRecord` for
each minute. Each record would have a start time and end time spanning that
minute, and would contain all the heart rate samples captured during that
minute.

During regular syncs with Health Connect (for example, every 15 minutes), your
app should write all the one-minute records that have been created since the
previous sync. This keeps records at a manageable size and improves the
performance of querying and processing data.

The following example shows how to create a `HeartRateRecord` for a single
minute, containing multiple samples:


```kotlin
val startTime = Instant.now().truncatedTo(ChronoUnit.MINUTES)
val endTime = startTime.plus(Duration.ofMinutes(1))

val heartRateRecord = HeartRateRecord(
    startTime = startTime,
    startZoneOffset = ZoneOffset.UTC,
    endTime = endTime,
    endZoneOffset = ZoneOffset.UTC,
    // Create a new record every minute, containing a list of samples.
    samples = listOf(
        HeartRateRecord.Sample(
            time = startTime + Duration.ofSeconds(15),
            beatsPerMinute = 80,
        ),
        HeartRateRecord.Sample(
            time = startTime + Duration.ofSeconds(30),
            beatsPerMinute = 82,
        ),
        HeartRateRecord.Sample(
            time = startTime + Duration.ofSeconds(45),
            beatsPerMinute = 85,
        )
    ),
    metadata = Metadata.activelyRecorded(
        device = Device(type = Device.TYPE_WATCH)
    ))
```

<br />

### Write data monitored throughout the day

For data collected on an ongoing basis, like steps, your application should
write to Health Connect as frequently as possible when new data is available.
To avoid negatively impacting battery life and other performance aspects, the
maximum interval between writes should be 15 minutes.

|---|---|---|---|
| **Data type** | **Unit** | **Expected** | **Example** |
| Steps | steps | Every 1 minute | 23:14 - 23:15 - 5 steps 23:16 - 23:17 - 22 steps 23:17 - 23:18 - 8 steps |
| StepsCadence | steps/min | Every 1 minute | 23:14 - 23:15 - 5 spm 23:16 - 23:17 - 22 spm 23:17 - 23:18 - 8 spm |
| Wheelchair pushes | pushes | Every 1 minute | 23:14 - 23:15 - 5 pushes 23:16 - 23:17 - 22 pushes 23:17 - 23:18 - 8 pushes |
| ActiveCaloriesBurned | Calories | Every 15 minutes | 23:15 - 23:30 - 2 Calories 23:30 - 23:45 - 25 Calories 23:45 - 00:00 - 5 Calories |
| TotalCaloriesBurned | Calories | Every 15 minutes | 23:15 - 23:30 - 16 Calories 23:30 - 23:45 - 16 Calories 23:45 - 00:00 - 16 Calories |
| Distance | km/min | Every 1 minute | 23:14-23:15 - 0.008 km 23:16 - 23:16 - 0.021 km 23:17 - 23:18 - 0.012 km |
| ElevationGained | m | Every 1 minute | 20:36 - 20:37 - 3.048m 20:39 - 20:40 - 3.048m 23:23 - 23:24 - 9.144m |
| FloorsClimbed | floors | Every 1 minute | 23:14 - 23:15 - 5 floors 23:16 - 23:16 - 22 floors 23:17 - 23:18 - 8 floors |
| HeartRate | bpm | 4 times a minute | 6:11:15am - 55 bpm 6:11:30am - 56 bpm 6:11:45 am - 56 bpm 6:12:00 am - 55 bpm |
| HeartRateVariabilityRmssd | ms | Every 1 minute | 6:11am - 23 ms |
| RespiratoryRate | breaths/minute | Every 1 minute | 23:14 - 23:15 - 60 breaths/minute 23:16 - 23:16 - 62 breaths/minute 23:17 - 23:18 - 64 breaths/minute |
| OxygenSaturation | % | Every 1 hour | 6:11 - 95.208% |
[*Table 1: Guidance for writing data*]

> [!NOTE]
> **Note:** As of version 1.1.0-rc01, **RecordingMethod** and **DeviceType** are mandatory requirements when writing data.

Data should be written to Health Connect at the end of the workout or sleep
session. For active tracking, such as exercise and sleep, or manual user input
like nutrition, these records are created when the app is in the foreground, or
in rare events where it is used a few times in a day.

Verify that your app doesn't keep Health Connect running for the entire duration
of the event.

Data must be written to Health Connect in one of two ways:

- Sync data to Health Connect after the event is complete. For example, sync data when the user ends a tracked exercise session.
- Schedule a one-off task using [WorkManager](https://developer.android.com/topic/libraries/architecture/workmanager) to sync data later.

#### Exercise and sleep sessions

At minimum, your application should follow the guidance in the **Expected**
column in Table 2. Where possible, follow the guidance in the
**Best** column.

The following table shows how to write data during an exercise:

|---|---|---|---|---|
| **Data type** | **Unit** | **Expected** | **Best** | **Example** |
| Steps | steps | Every 1 minute | Every 1 second | 23:14-23:15 - 5 steps 23:16 - 23:17 - 22 steps 23:17 - 23:18 - 8 steps |
| StepsCadence | steps/min | Every 1 minute | Every 1 second | 23:14-23:15 - 35 spm 23:16 - 23:17 - 37 spm 23:17 - 23:18 - 40 spm |
| Wheelchair pushes | pushes | Every 1 minute | Every 1 second | 23:14-23:15 - 5 pushes 23:16 - 23:17 - 22 pushes 23:17 - 23:18 - 8 pushes |
| CyclingPedalingCadence | rpm | Every 1 minute | Every 1 second | 23:14-23:15 - 65 rpm 23:16 - 23:17 - 70 rpm 23:17 - 23:18 - 68 rpm |
| Power | watts | Every 1 minute | Every 1 second | 23:14-23:15 - 250 watts 23:16 - 23:17 - 255 watts 23:17 - 23:18 - 245 watts |
| Speed | km/min | Every 1 minute | Every 1 second | 23:14-23:15 - 0.3 km/min 23:16 - 23:17 - 0.4 km/min 23:17 - 23:18 -0.4 km/min |
| Distance | km/m | Every 1 minute | Every 1 second | 23:14-23:15 - 0.008 km 23:16 - 23:16 - 0.021 km 23:17 - 23:18 - 0.012 km |
| ActiveCaloriesBurned | Calories | Every 1 minute | Every 1 second | 23:14-23:15 - 20 Calories 23:16 - 23:17 - 20 Calories 23:17 - 23:18 - 25 Calories |
| TotalCaloriesBurned | Calories | Every 1 minute | Every 1 second | 23:14-23:15 - 36 Calories 23:16 - 23:17 - 36 Calories 23:17 - 23:18 - 41 Calories |
| ElevationGained | m | Every 1 minute | Every 1 second | 20:36 - 20:37 - 3.048m 20:39 - 20:40 - 3.048m 23:23 - 23:24 - 9.144m |
| ExerciseRoutes | lat/lng/alt | Every 3-5 seconds | Every 1 second |   |
| HeartRate | bpm | 4 times a minute | Every 1 second | 23:14-23:15 - 150 bpm |
[*Table 2: Guidance for writing data during an exercise session*]

Table 3 shows how to write data during or after a sleep session:

|---|---|---|---|
| **Data type** | **Unit** | **Expected samples** | **Example** |
| Sleep Staging | stage | Granular period of time per sleep stage | 23:46 - 23:50 - awake 23:50 - 23:56 - light sleep 23:56 - 00:16 - deep sleep |
| RestingHeartRate | bpm | Single daily value (expected first thing in the morning) | 6:11am - 60 bpm |
| OxygenSaturation | % | Single daily value (expected first thing in the morning) | 6:11 - 95.208% |
[*Table 3: Guidance for writing data during or after a sleep session*]

#### Multi-sport events

This approach uses existing data types and structures, and it verifies
compatibility with current Health Connect implementations and data readers.
This is a common approach taken by fitness platforms.

> [!NOTE]
> **Note:** Health Connect doesn't automatically calculate the total duration of a multi-sport event. Data readers must calculate this by using the start time of the first activity and the end time of the last activity.

Additionally, individual sessions such as swimming, biking, and running aren't
inherently linked within Health Connect, and data readers must infer the
relationship between these sessions based on their time proximity.
Transitions between segments, such as from swimming to biking, aren't explicitly
represented.

The following example shows how to write data for a triathlon:


```kotlin
val swimStartTime = Instant.parse("2024-08-22T08:00:00Z")
val swimEndTime = Instant.parse("2024-08-22T08:30:00Z")
val bikeStartTime = Instant.parse("2024-08-22T08:40:00Z")
val bikeEndTime = Instant.parse("2024-08-22T09:40:00Z")
val runStartTime = Instant.parse("2024-08-22T09:50:00Z")
val runEndTime = Instant.parse("2024-08-22T10:20:00Z")

val swimSession = ExerciseSessionRecord(
    startTime = swimStartTime,
    endTime = swimEndTime,
    exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_OPEN_WATER,
    metadata = Metadata.activelyRecorded(
        device = Device(type = Device.TYPE_WATCH)
    ),
    startZoneOffset = null,
    endZoneOffset = null,
)

val bikeSession = ExerciseSessionRecord(
    startTime = bikeStartTime,
    endTime = bikeEndTime,
    exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_BIKING,
    metadata = Metadata.activelyRecorded(
        device = Device(type = Device.TYPE_WATCH)
    ),
    startZoneOffset = null,
    endZoneOffset = null,
)

val runSession = ExerciseSessionRecord(
    startTime = runStartTime,
    endTime = runEndTime,
    exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_RUNNING,
    metadata = Metadata.activelyRecorded(
        device = Device(type = Device.TYPE_WATCH)
    ),
    startZoneOffset = null,
    endZoneOffset = null,
)

healthConnectClient.insertRecords(listOf(swimSession, bikeSession, runSession))
```

<br />

## Handle exceptions

Health Connect throws standard exceptions for CRUD operations when an issue is
encountered. Your app should catch and handle each of these exceptions as
appropriate.

Each method on `HealthConnectClient` lists the exceptions that can be thrown.
In general, your app should handle the following exceptions:


<br />

<br />

<br />

<br />

<br />

<br />

<br />

<br />

<br />

<br />

| **Exception** | **Description** | **Recommended best practice** |
|---|---|---|
| `IllegalStateException` | One of the following scenarios has occurred: <br /> - The Health Connect service isn't available. - The request isn't a valid construction. For example, an aggregate request in periodic buckets where an `Instant` object is used for the `timeRangeFilter`. <br /> | Handle possible issues with the inputs first before doing a request. Preferably, assign values to variables or use them as parameters within a custom function instead of using them directly in your requests so that you can apply error handling strategies. |
| `IOException` | There are issues encountered upon reading and writing data from disk. | To avoid this issue, here are some suggestions: <br /> - Back up any user input. - Be able to handle any issues that occur during bulk write operations. For example, make sure the process moves past the issue and carry out the remaining operations. - Apply retries and backoff strategies to handle request issues. <br /> |
| `RemoteException` | Errors have occurred within, or in communicating with, the underlying service to which the SDK connects. For example, your app is trying to delete a record with a given `uid`. However, the exception is thrown after the app finds out upon checking in the underlying service that the record doesn't exist. | To avoid this issue, here are some suggestions: <br /> - Perform regular syncs between your app's datastore and Health Connect. - Apply retries and backoff strategies to handle request issues. <br /> |
| `SecurityException` | There are issues encountered when the requests require permissions that aren't granted. | To avoid this, make sure that you've [declared use of Health Connect data types](https://developer.android.com/guide/health-and-fitness/health-connect/develop/frequently-asked-questions#declare-access) for your published app. Also, you must declare Health Connect permissions [in the manifest file](https://developer.android.com/guide/health-and-fitness/health-connect/develop/get-started#step-3) and [in your activity](https://developer.android.com/guide/health-and-fitness/health-connect/develop/get-started#step-4). <br /> <br /> |
[*Table 1: Health Connect exceptions and recommended best practices*]

<br />

The following example shows you how to read raw data as part of the common
workflow.

> [!TIP]
> **Tip:** For further guidance on reading raw data, take a look at the [Android
> Developer video for reading and writing data](https://www.youtube.com/watch?v=NAx7Gv_Hk7E&t=122) in Health Connect.

## Read data

Health Connect allows apps to read data from the datastore when the app is
in the foreground and background:

- **Foreground reads**: You can normally read data from Health Connect when
  your app is in the foreground. In these cases, you may consider using a
  foreground service to run this operation in case the user or system places your
  app in the background during a read operation.

- **Background reads** : By requesting an extra permission from the user, you
  can read data after the user or system places your app in the background.
  See the complete [background read example](https://developer.android.com/health-and-fitness/guides/health-connect/develop/read-data#background-read-example).

The Steps data type in Health Connect captures the number of steps a user has
taken between readings. Step counts represent a common measurement across
health, fitness, and wellness platforms. Health Connect lets you read and write
step count data.

To read records, create a [`ReadRecordsRequest`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/request/ReadRecordsRequest) and supply
it when you call [`readRecords`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#readRecords(androidx.health.connect.client.request.ReadRecordsRequest)).

> [!NOTE]
> **Note:** For cumulative types like `StepsRecord`, use `aggregate()` instead of `readRecords()` to avoid double counting from multiple sources and improve accuracy. See [Read aggregated
> data](https://developer.android.com/reference/kotlin/androidx/health/connect/client/aggregate/package-summary) for more information.

The following example shows how to read step count data for a user within a
certain time. For an extended example with [`SensorManager`](https://developer.android.com/reference/android/hardware/SensorManager),
see the [step count](https://developer.android.com/health-and-fitness/guides/basic-fitness-app/read-step-count-data) data guide.


```kotlin
val response = healthConnectClient.readRecords(
    ReadRecordsRequest(
        HeartRateRecord::class,
        timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
    )
)
response.records.forEach { record ->
    /* Process records */
}
```

<br />

You can also read your data in an aggregated manner using
[`aggregate`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/aggregate/package-summary).


```kotlin
suspend fun readStepsAggregate(startTime: Instant, endTime: Instant): Long {
    val response = healthConnectClient.aggregate(
        AggregateRequest(
            metrics = setOf(StepsRecord.COUNT_TOTAL),
            timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
        )
    )
    return response[StepsRecord.COUNT_TOTAL] ?: 0L
}
```

<br />

> [!NOTE]
> **Note:** If you're interested in obtaining calculated data such as averages and totals, it is recommended to use [aggregation](https://developer.android.com/health-and-fitness/guides/health-connect/develop/aggregate-data). You can set [smaller time slices](https://developer.android.com/health-and-fitness/guides/health-connect/develop/aggregate-data#buckets) whenever you aggregate. The aggregation API also contains logic to handle duplicate records, and lessens the chances of rate limiting.

## Read mobile steps

> [!WARNING]
> **Warning:** Starting with the Health Connect update in June 2026, on-device steps are attributed to a device-specific **Synthetic Package Name (SPN)** instead of the generic `"android"` package name. See [Attribution change for on-device steps](https://developer.android.com/health-and-fitness/health-connect/read-data#attribution-change) for details.

With Android 14 (API level 34) and SDK Extension version 20 or higher,
Health Connect provides on-device step counting. If any app has been granted
the `READ_STEPS` permission, Health Connect starts capturing steps from the
Android-powered device, and users see steps data automatically added to
Health Connect **Steps** entries.

To check if on-device step counting is available, verify that the device is
running Android 14 (API level 34) and has at least SDK extension version 20:

    val isStepTrackingAvailable =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE &&
            SdkExtensions.getExtensionVersion(Build.VERSION_CODES.UPSIDE_DOWN_CAKE) >= 20

If your app reads aggregated step counts using
[`aggregate`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/aggregate/package-summary) and doesn't filter by `DataOrigin`, on-device
steps are automatically included in the total, and no changes are required for
the June 2026 update.

### Attribution change for on-device steps

Starting with the June 2026 update, steps tracked natively by Health
Connect are attributed to a **Synthetic Package Name (SPN)** , such as
`com.android.healthconnect.phone.jd5bdd37e1a8d3667a05d0abebfc4a89e`.

Previously, built-in steps were attributed to the package name `android`.
Historical step data recorded before June 2026 retains the `android` package
name.

SPNs are device-specific and scoped on a per-application basis to protect
user privacy:

- **Stable:** The SPN for the current device is stable for your application.
- **Application-Scoped:** Different applications on the same device see different SPNs for on-device step data.

#### Query for on-device steps

Because SPNs are scoped and device-specific, you **must not** hardcode SPN
values. Instead, use the `getCurrentDeviceDataSource()` API to retrieve the
SPN for the current device.

While on-device step counting requires SDK extension version 20 or higher,
the `getCurrentDeviceDataSource()` API is available on Android 14 (API level
34) with SDK extension version 11 or higher.

The `getCurrentDeviceDataSource()` API is not yet available in the Health
Connect Jetpack library. The following examples use the Android framework API
instead:

    import android.content.Context
    import android.health.connect.HealthConnectManager

    val healthConnectManager = context.getSystemService(HealthConnectManager::class.java)
    val deviceDataSource = healthConnectManager?.getCurrentDeviceDataSource()
    val currentDeviceSpn = deviceDataSource?.deviceDataOrigin?.packageName

If your app needs to read on-device steps, or if it displays step data
broken down by source application or device, you must query for records
where the `DataOrigin` is `android` **or** matches the device's SPN. If
your app shows attribution for step data, use [`metadata.device`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/metadata/Device)
to identify the source device for individual records. For on-device steps
identified by an SPN in aggregated data, you can use device metadata such as
`model` or `manufacturer` from `DeviceDataSource` for attribution, or use a
generic label like "Your phone" for on-device steps.

The following example shows how to read aggregated on-device step count data
by filtering for both `android` and the current device SPN:

    import android.content.Context
    import android.health.connect.HealthConnectManager
    import android.os.Build
    import android.os.ext.SdkExtensions
    import androidx.health.connect.client.HealthConnectClient
    import androidx.health.connect.client.records.StepsRecord
    import androidx.health.connect.client.records.metadata.DataOrigin
    import androidx.health.connect.client.request.AggregateRequest
    import androidx.health.connect.client.time.TimeRangeFilter
    import java.time.Instant

    suspend fun readDeviceStepsByTimeRange(
        healthConnectClient: HealthConnectClient,
        context: Context,
        startTime: Instant,
        endTime: Instant
    ) {
        // 1. Check if SDK Extension 11+ is available for getCurrentDeviceDataSource()
        val isDataSourceApiAvailable = Build.VERSION.SDK_INT >= Build.VERSION_CODES.U &&
                SdkExtensions.getExtensionVersion(Build.VERSION_CODES.U) >= 11

        try {
            val healthConnectManager = context.getSystemService(HealthConnectManager::class.java)

            // 2. Safely fetch the package name only if API is available and data exists
            val currentDeviceSpn = if (isDataSourceApiAvailable) {
                healthConnectManager?.getCurrentDeviceDataSource()?.deviceDataOrigin?.packageName
            } else {
                null
            }

            val dataOriginFilters = mutableSetOf(DataOrigin("android"))

            // 3. Explicit null-safety check using .let
            currentDeviceSpn?.let {
                dataOriginFilters.add(DataOrigin(it))
            }

            val response = healthConnectClient.aggregate(
                AggregateRequest(
                    metrics = setOf(StepsRecord.COUNT_TOTAL),
                    timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
                    dataOriginFilter = dataOriginFilters
                )
            )

            val stepCount = response[StepsRecord.COUNT_TOTAL]

        } catch (e: Exception) {
            // Now this catch block only handles actual runtime exceptions, 
            // rather than Errors from missing methods.
        }
    }

> [!NOTE]
> **Note:** If your app has significant users on Android 13 and lower, we recommend also maintaining or adding an integration with the local [Recording API](https://developer.android.com/health-and-fitness/recording-api).

### On-Device Step Counting

- **Sensor Usage** : Health Connect utilizes the [`TYPE_STEP_COUNTER`](https://developer.android.com/reference/android/hardware/Sensor#TYPE_STEP_COUNTER) sensor from `SensorManager`. This sensor is optimized for low power consumption, making it ideal for continuous background step tracking.
- **Data Granularity**: To conserve battery life, step data is typically batched and written to the Health Connect database no more frequently than once per minute.
- **Attribution** : Steps recorded by this feature before June 2026 are attributed to the `android` package name in the [`DataOrigin`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/metadata/DataOrigin). After this date, they are attributed to a device-specific SPN. See [Attribution change for on-device steps](https://developer.android.com/health-and-fitness/health-connect/read-data#attribution-change).
- **Activation** : The on-device step counting mechanism is active only when at least one application on the device has been granted the `READ_STEPS` permission within Health Connect.

## Background read example

To read data in the background, declare the following permission in your
manifest file:

    <application>
      <uses-permission android:name="android.permission.health.READ_HEALTH_DATA_IN_BACKGROUND" />
    ...
    </application>

The following example shows how to read step count data in the background for a
user within a certain time by using [`WorkManager`](https://developer.android.com/reference/kotlin/androidx/work/WorkManager):


```kotlin
class ScheduleWorker(appContext: Context, workerParams: WorkerParameters) :
    CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        val healthConnectClient = HealthConnectClient.getOrCreate(applicationContext)
        // Perform background read logic here
        return Result.success()
    }
}
```

```kotlin
fun enqueueBackgroundReadWorker(context: Context, healthConnectClient: HealthConnectClient) {
    if (healthConnectClient
            .features
            .getFeatureStatus(
                HealthConnectFeatures.FEATURE_READ_HEALTH_DATA_IN_BACKGROUND
            ) == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE
    ) {

        val periodicWorkRequest = PeriodicWorkRequestBuilder<ScheduleWorker>(1, TimeUnit.HOURS)
            .build()

        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            "read_health_connect",
            ExistingPeriodicWorkPolicy.KEEP,
            periodicWorkRequest
        )
    }
}
```

<br />

> [!NOTE]
> **Note:** If the user doesn't grant all of the permissions that are required for background reads, your app should still run, and it should perform as many tasks as it can with the permissions that the user granted.

The [`ReadRecordsRequest`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/request/package-summary#ReadRecordsRequest(androidx.health.connect.client.time.TimeRangeFilter,kotlin.collections.Set,kotlin.Boolean,kotlin.Int,kotlin.String)) parameter has a default `pageSize` value of 1000.
If the number of records in a single `readResponse` exceeds the
`pageSize` of the request, you need to iterate
over all pages of the response to retrieve all records by using `pageToken`.
However, be careful to avoid rate-limiting concerns.

## pageToken read example

It is recommended to use `pageToken` for reading records to retrieve all
available data from the requested time period.

The following example shows how to read all records until all page tokens have
been exhausted:


```kotlin
val type = HeartRateRecord::class
val endTime = Instant.now()
val startTime = endTime.minus(Duration.ofDays(7))

try {
    var pageToken: String? = null
    do {
        val readResponse =
            healthConnectClient.readRecords(
                ReadRecordsRequest(
                    recordType = type,
                    timeRangeFilter = TimeRangeFilter.between(
                        startTime,
                        endTime
                    ),
                    pageToken = pageToken
                )
            )
        val records = readResponse.records
        // Do something with records
        pageToken = readResponse.pageToken
    } while (pageToken != null)
} catch (quotaError: IllegalStateException) {
    // Backoff
}
```
For information about best practices when reading large datasets, refer to [Plan to avoid rate limiting](https://developer.android.com/health-and-fitness/guides/health-connect/plan/rate-limiting).

<br />

## Read previously written data

If an app has written records to Health Connect before, it is possible for that
app to read historical data. This is applicable for scenarios in which
the app needs to resync with Health Connect after the user has reinstalled it.

Some read restrictions apply:

- For Android 14 and higher

  - No historical limit on an app reading its own data.
  - 30-day limit on an app reading other data.
- For Android 13 and lower

  - 30-day limit on app reading any data.

The restrictions can be removed by requesting a [Read permission](https://developer.android.com/health-and-fitness/guides/health-connect/develop/read-data#read-older-data).

To read historical data, you need to indicate the package name as a
[`DataOrigin`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/metadata/DataOrigin) object in the `dataOriginFilter` parameter of your
[`ReadRecordsRequest`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/request/ReadRecordsRequest).

The following example shows how to indicate a package name when reading
heart rate records:


```kotlin
try {
    val response =  healthConnectClient.readRecords(
        ReadRecordsRequest(
            recordType = HeartRateRecord::class,
            timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
            dataOriginFilter = setOf(DataOrigin("com.my.package.name"))
        )
    )
    for (record in response.records) {
        // Process each record
    }
} catch (e: Exception) {
    // Run error handling here
}
```

<br />

## Read data older than 30 days

By default, all applications can read data from Health Connect for up to 30 days
prior to when any permission was first granted.

If you need to extend read permissions beyond any of the
[default restrictions](https://developer.android.com/health-and-fitness/guides/health-connect/develop/read-data#read-previously-written-data), request the
[`PERMISSION_READ_HEALTH_DATA_HISTORY`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/permission/HealthPermission#PERMISSION_READ_HEALTH_DATA_HISTORY()).
Otherwise, without this permission, an attempt to read records older than
30 days results in an error.

### Permissions history for a deleted app

If a user deletes your app, all permissions, including the history permission,
are revoked. If the user reinstalls your app and grants permission again,
the same [default restrictions](https://developer.android.com/health-and-fitness/guides/health-connect/develop/read-data#read-previously-written-data) apply, and your
app can read data from Health Connect for up to 30 days prior to that new date.

For example, suppose
the user deletes your app on May 10, 2023 and then reinstalls
the app on May 15, 2023, and grants read permissions. The earliest date
your app can now read data from by default
is **April 15, 2023**.

## Handle exceptions

Health Connect throws standard exceptions for CRUD operations when an issue is
encountered. Your app should catch and handle each of these exceptions as
appropriate.

Each method on `HealthConnectClient` lists the exceptions that can be thrown.
In general, your app should handle the following exceptions:


<br />

<br />

<br />

<br />

<br />

<br />

<br />

<br />

<br />

<br />

| **Exception** | **Description** | **Recommended best practice** |
|---|---|---|
| `IllegalStateException` | One of the following scenarios has occurred: <br /> - The Health Connect service isn't available. - The request isn't a valid construction. For example, an aggregate request in periodic buckets where an `Instant` object is used for the `timeRangeFilter`. <br /> | Handle possible issues with the inputs first before doing a request. Preferably, assign values to variables or use them as parameters within a custom function instead of using them directly in your requests so that you can apply error handling strategies. |
| `IOException` | There are issues encountered upon reading and writing data from disk. | To avoid this issue, here are some suggestions: <br /> - Back up any user input. - Be able to handle any issues that occur during bulk write operations. For example, make sure the process moves past the issue and carry out the remaining operations. - Apply retries and backoff strategies to handle request issues. <br /> |
| `RemoteException` | Errors have occurred within, or in communicating with, the underlying service to which the SDK connects. For example, your app is trying to delete a record with a given `uid`. However, the exception is thrown after the app finds out upon checking in the underlying service that the record doesn't exist. | To avoid this issue, here are some suggestions: <br /> - Perform regular syncs between your app's datastore and Health Connect. - Apply retries and backoff strategies to handle request issues. <br /> |
| `SecurityException` | There are issues encountered when the requests require permissions that aren't granted. | To avoid this, make sure that you've [declared use of Health Connect data types](https://developer.android.com/guide/health-and-fitness/health-connect/develop/frequently-asked-questions#declare-access) for your published app. Also, you must declare Health Connect permissions [in the manifest file](https://developer.android.com/guide/health-and-fitness/health-connect/develop/get-started#step-3) and [in your activity](https://developer.android.com/guide/health-and-fitness/health-connect/develop/get-started#step-4). <br /> <br /> |
[*Table 1: Health Connect exceptions and recommended best practices*]

<br />

Aggregating data in Health Connect includes basic aggregations or aggregating
data into buckets. The following workflows show you how to do both.

> [!TIP]
> **Tip:** For further guidance on aggregating data, take a look at the [Android
> Developer video for reading and writing data](https://www.youtube.com/watch?v=NAx7Gv_Hk7E&t=149) in Health Connect.

## Basic aggregation

To use basic aggregation on your data, use the [`aggregate`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#aggregate(androidx.health.connect.client.request.AggregateRequest)) function
on your [`HealthConnectClient`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient) object. It accepts an
[`AggregateRequest`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/request/AggregateRequest) object where you add the metric types
and the time range as its parameters. How basic aggregates are called depends on
the metric types used.

### Cumulative aggregation

Cumulative aggregation computes the total value.

The following example shows you how to aggregate data for a data type:


```kotlin
suspend fun readDistanceAggregate(startTime: Instant, endTime: Instant): Number {
    val response = healthConnectClient.aggregate(
        AggregateRequest(
            metrics = setOf(DistanceRecord.DISTANCE_TOTAL),
            timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
        )
    )
    return response[DistanceRecord.DISTANCE_TOTAL]?.inMeters ?: 0L
}
```

<br />

### Filter by data origin

You can also filter aggregate data by its origin. For example, only including
data written by a specific app.

The following example shows how to use `dataOriginFilter` and
[`AggregateRequest`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/request/AggregateRequest) to aggregate steps from a specific app:


```kotlin
suspend fun aggregateStepsFromSpecificApp(
    healthConnectClient: HealthConnectClient,
    startTime: Instant,
    endTime: Instant,
    appPackageName: String
) {
    try {
        val response = healthConnectClient.aggregate(
            AggregateRequest(
                metrics = setOf(StepsRecord.COUNT_TOTAL),
                timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
                dataOriginFilter = setOf(DataOrigin(appPackageName))
            )
        )
        // The result may be null if no data is available in the time range
        val totalSteps = response[StepsRecord.COUNT_TOTAL] ?: 0L
    } catch (e: Exception) {
        // Run error handling here
    }
}
```

<br />

### Statistical aggregation

Statistical aggregation computes the minimum, maximum, or average values of
records with samples.

The following example shows how to use statistical aggregation:


```kotlin
suspend fun readHeartRateAggregate(startTime: Instant, endTime: Instant): Pair<Long, Long> {
    val response = healthConnectClient.aggregate(
        AggregateRequest(
            metrics = setOf(HeartRateRecord.BPM_MAX, HeartRateRecord.BPM_MIN),
            timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
        )
    )
    val minimumHeartRate = response[HeartRateRecord.BPM_MIN] ?: 0L
    val maximumHeartRate = response[HeartRateRecord.BPM_MAX] ?: 0L

    return maximumHeartRate to minimumHeartRate
}
```

<br />

## Buckets

Health Connect can also let you aggregate data into *buckets* . The two types of
buckets you can use include **duration** and **period**.

Once called, they return a list of buckets. Note that the list can be sparse, so
a bucket is not included in the list if it doesn't contain any data.

### Duration

In this case, aggregated data is split into buckets within a fixed length of
time, such as a minute or an hour. To aggregate data into buckets, use
[`aggregateGroupByDuration`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#aggregateGroupByDuration(androidx.health.connect.client.request.AggregateGroupByDurationRequest)). It accepts an
[`AggregateGroupByDurationRequest`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/request/AggregateGroupByDurationRequest) object where you add the
metric types, the time range, and the [`Duration`](https://developer.android.com/reference/java/time/Duration) as parameters.
You can use pairs of [`Instant`](https://developer.android.com/reference/java/time/Instant) or
[`LocalDateTime`](https://developer.android.com/reference/java/time/LocalDateTime) objects for `startTime` and `endTime` in
`TimeRangeFilter`.

The following shows an example of aggregating steps into minute-long buckets:


```kotlin
suspend fun aggregateStepsIntoMinutes(
    healthConnectClient: HealthConnectClient,
    startTime: LocalDateTime,
    endTime: LocalDateTime
) {
    try {
        val response =
            healthConnectClient.aggregateGroupByDuration(
                AggregateGroupByDurationRequest(
                    metrics = setOf(StepsRecord.COUNT_TOTAL),
                    timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
                    timeRangeSlicer = Duration.ofMinutes(1L)
                )
            )
        for (durationResult in response) {
            // The result may be null if no data is available in the time range
            val totalSteps = durationResult.result[StepsRecord.COUNT_TOTAL] ?: 0L
        }
    } catch (e: Exception) {
        // Run error handling here
    }
}
```

<br />

### Period

In this case, aggregated data is split into buckets within a date-based amount
of time, such as a week or a month. To aggregate data into buckets, use
[`aggregateGroupByPeriod`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#aggregateGroupByPeriod(androidx.health.connect.client.request.AggregateGroupByPeriodRequest)). It accepts an
[`AggregateGroupByPeriodRequest`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/request/AggregateGroupByPeriodRequest) object where you add the
metric types, the time range, and the [`Period`](https://developer.android.com/reference/java/time/Period) as parameters.

The following shows an example of aggregating steps into monthly buckets:


```kotlin
suspend fun aggregateStepsIntoMonths(
    healthConnectClient: HealthConnectClient,
    startTime: LocalDateTime,
    endTime: LocalDateTime
) {
    try {
        val response =
            healthConnectClient.aggregateGroupByPeriod(
                AggregateGroupByPeriodRequest(
                    metrics = setOf(StepsRecord.COUNT_TOTAL),
                    timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
                    timeRangeSlicer = Period.ofMonths(1)
                )
            )
        for (monthlyResult in response) {
            // The result may be null if no data is available in the time range
            val totalSteps = monthlyResult.result[StepsRecord.COUNT_TOTAL] ?: 0L
        }
    } catch (e: Exception) {
        // Run error handling here
    }
}
```

<br />

> [!NOTE]
> **Note:** When running bucket aggregates per period, make sure that the start and end times set are not using the [`Instant`](https://developer.android.com/reference/java/time/Instant) class. Otherwise, the app returns an `IllegalStateException`.

## Read restrictions

By default, all applications can read data from Health Connect for up to 30 days
prior to when any permission was first granted.

If you need to extend read permissions beyond any of the
[default restrictions](https://developer.android.com/health-and-fitness/guides/health-connect/develop/read-data#read-previously-written-data), request the
[`PERMISSION_READ_HEALTH_DATA_HISTORY`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/permission/HealthPermission#PERMISSION_READ_HEALTH_DATA_HISTORY()).
Otherwise, without this permission, an attempt to read records older than
30 days results in an error.

### Permissions history for a deleted app

If a user deletes your app, all permissions, including the history permission,
are revoked. If the user reinstalls your app and grants permission again,
the same [default restrictions](https://developer.android.com/health-and-fitness/guides/health-connect/develop/read-data#read-previously-written-data) apply, and your
app can read data from Health Connect for up to 30 days prior to that new date.

For example, suppose
the user deletes your app on May 10, 2023 and then reinstalls
the app on May 15, 2023, and grants read permissions. The earliest date
your app can now read data from by default
is **April 15, 2023**.

## Aggregate data affected by user-selected apps priorities

End users can set priority for the Sleep and Activity apps that they have
integrated with Health Connect. Only end users can alter these priority
lists. When you perform an aggregate read, the Aggregate API accounts for
any duplicate data and keeps only the data from the app with the highest
priority. Duplicate data could exist if the user has multiple apps writing
the same kind of data---such as the number of steps taken or the distance
covered---at the same time.
![Figure showing Reorder app priorities](https://developer.android.com/static/health-and-fitness/health-connect/images/reorder_apps_priorities.svg) **Figure 1**: Reorder app priorities

![Figure showing reorder app priorities](https://developer.android.com/static/health-and-fitness/health-connect/images/reorder_apps_priorities.svg)

For information on how end users can prioritize their apps,
see [Manage Health Connect data](https://support.google.com/android/answer/12990553).

The user can add or remove apps as well as change their priorities. A user might
want to remove an app that is writing duplicate data so that the data totals on
the Health Connect screen are identical to the app they have
given the highest priority. The data totals are updated in real time.

Even though the Aggregate API calculates Activity and Sleep apps' data by
deduping data according to how the user has
set priorities, you can still build your
own logic to calculate the data separately for each app writing that data.

Only the Activity and Sleep data types are deduped by Health Connect, and
the data totals shown are the values after the dedupe has been performed
by the Aggregate API. These totals show the most recent full day where
data exists for steps and distance. For other types of data, the
aggregated results combine all data of the type in Health Connect from all
apps which wrote the data.

## Background reads

You can request that your application run in the background and read data from
Health Connect. If you request the
[Background Read](https://developer.android.com/health-and-fitness/guides/health-connect/develop/read-data#background-read-example)
permission, your user can grant your app access to read data in the background.

## Supported aggregate data types by record

This table lists all the supported aggregate data types by Health Connect
record.

<br />

| Record | Aggregate data type |
|---|---|
| [`ActiveCaloriesBurnedRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ActiveCaloriesBurnedRecord) | [`ACTIVE_CALORIES_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ActiveCaloriesBurnedRecord#ACTIVE_CALORIES_TOTAL()) |
| [`ActivityIntensityRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ActivityIntensityRecord) | [`DURATION_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ActivityIntensityRecord#DURATION_TOTAL()), [`INTENSITY_MINUTES_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ActivityIntensityRecord#INTENSITY_MINUTES_TOTAL()), [`MODERATE_DURATION_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ActivityIntensityRecord#MODERATE_DURATION_TOTAL()), [`VIGOROUS_DURATION_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ActivityIntensityRecord#VIGOROUS_DURATION_TOTAL()) |
| [`BasalMetabolicRateRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/BasalMetabolicRateRecord) | [`BASAL_CALORIES_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/BasalMetabolicRateRecord#BASAL_CALORIES_TOTAL()) |
| [`BloodPressureRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/BloodPressureRecord) | [`DIASTOLIC_AVG`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/BloodPressureRecord#DIASTOLIC_AVG()), [`DIASTOLIC_MAX`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/BloodPressureRecord#DIASTOLIC_MAX()), [`DIASTOLIC_MIN`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/BloodPressureRecord#DIASTOLIC_MIN()), [`SYSTOLIC_AVG`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/BloodPressureRecord#SYSTOLIC_AVG()), [`SYSTOLIC_MAX`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/BloodPressureRecord#SYSTOLIC_MAX()), [`SYSTOLIC_MIN`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/BloodPressureRecord#SYSTOLIC_MIN()) |
| [`CyclingPedalingCadenceRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/CyclingPedalingCadenceRecord) | [`RPM_AVG`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/CyclingPedalingCadenceRecord#RPM_AVG()), [`RPM_MAX`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/CyclingPedalingCadenceRecord#RPM_MAX()), [`RPM_MIN`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/CyclingPedalingCadenceRecord#RPM_MIN()) |
| [`DistanceRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/DistanceRecord) | [`DISTANCE_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/DistanceRecord#DISTANCE_TOTAL()) |
| [`ElevationGainedRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ElevationGainedRecord) | [`ELEVATION_GAINED_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ElevationGainedRecord#ELEVATION_GAINED_TOTAL()) |
| [`ExerciseSessionRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord) | [`EXERCISE_DURATION_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_DURATION_TOTAL()) |
| [`FloorsClimbedRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/FloorsClimbedRecord) | [`FLOORS_CLIMBED_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/FloorsClimbedRecord#FLOORS_CLIMBED_TOTAL()) |
| [`HeartRateRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord) | [`BPM_AVG`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord#BPM_AVG()), [`BPM_MAX`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord#BPM_MAX()), [`BPM_MIN`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord#BPM_MIN()), [`MEASUREMENTS_COUNT`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord#MEASUREMENTS_COUNT()) |
| [`HeightRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeightRecord) | [`HEIGHT_AVG`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeightRecord#HEIGHT_AVG()), [`HEIGHT_MAX`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeightRecord#HEIGHT_MAX()), [`HEIGHT_MIN`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeightRecord#HEIGHT_MIN()) |
| [`HydrationRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HydrationRecord) | [`VOLUME_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HydrationRecord#VOLUME_TOTAL()) |
| [`MindfulnessSessionRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/MindfulnessSessionRecord) | [`MINDFULNESS_DURATION_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/MindfulnessSessionRecord#MINDFULNESS_DURATION_TOTAL()) |
| [`NutritionRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord) | [`BIOTIN_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#BIOTIN_TOTAL()), [`CAFFEINE_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#CAFFEINE_TOTAL()), [`CALCIUM_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#CALCIUM_TOTAL()), [`CHLORIDE_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#CHLORIDE_TOTAL()), [`CHOLESTEROL_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#CHOLESTEROL_TOTAL()), [`CHROMIUM_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#CHROMIUM_TOTAL()), [`COPPER_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#COPPER_TOTAL()), [`DIETARY_FIBER_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#DIETARY_FIBER_TOTAL()), [`ENERGY_FROM_FAT_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#ENERGY_FROM_FAT_TOTAL()), [`ENERGY_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#ENERGY_TOTAL()), [`FOLATE_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#FOLATE_TOTAL()), [`FOLIC_ACID_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#FOLIC_ACID_TOTAL()), [`IODINE_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#IODINE_TOTAL()), [`IRON_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#IRON_TOTAL()), [`MAGNESIUM_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#MAGNESIUM_TOTAL()), [`MANGANESE_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#MANGANESE_TOTAL()), [`MOLYBDENUM_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#MOLYBDENUM_TOTAL()), [`MONOUNSATURATED_FAT_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#MONOUNSATURATED_FAT_TOTAL()), [`NIACIN_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#NIACIN_TOTAL()), [`PANTOTHENIC_ACID_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#PANTOTHENIC_ACID_TOTAL()), [`PHOSPHORUS_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#PHOSPHORUS_TOTAL()), [`POLYUNSATURATED_FAT_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#POLYUNSATURATED_FAT_TOTAL()), [`POTASSIUM_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#POTASSIUM_TOTAL()), [`PROTEIN_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#PROTEIN_TOTAL()), [`RIBOFLAVIN_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#RIBOFLAVIN_TOTAL()), [`SATURATED_FAT_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#SATURATED_FAT_TOTAL()), [`SELENIUM_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#SELENIUM_TOTAL()), [`SODIUM_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#SODIUM_TOTAL()), [`SUGAR_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#SUGAR_TOTAL()), [`THIAMIN_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#THIAMIN_TOTAL()), [`TOTAL_CARBOHYDRATE_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#TOTAL_CARBOHYDRATE_TOTAL()), [`TOTAL_FAT_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#TOTAL_FAT_TOTAL()), [`TRANS_FAT_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#TRANS_FAT_TOTAL()), [`UNSATURATED_FAT_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#UNSATURATED_FAT_TOTAL()), [`VITAMIN_A_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#VITAMIN_A_TOTAL()), [`VITAMIN_B12_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#VITAMIN_B12_TOTAL()), [`VITAMIN_B6_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#VITAMIN_B6_TOTAL()), [`VITAMIN_C_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#VITAMIN_C_TOTAL()), [`VITAMIN_D_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#VITAMIN_D_TOTAL()), [`VITAMIN_E_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#VITAMIN_E_TOTAL()), [`VITAMIN_K_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#VITAMIN_K_TOTAL()), [`ZINC_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/NutritionRecord#ZINC_TOTAL()) |
| [`PowerRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/PowerRecord) | [`POWER_AVG`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/PowerRecord#POWER_AVG()), [`POWER_MAX`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/PowerRecord#POWER_MAX()), [`POWER_MIN`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/PowerRecord#POWER_MIN()) |
| [`RestingHeartRateRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/RestingHeartRateRecord) | [`BPM_AVG`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/RestingHeartRateRecord#BPM_AVG()), [`BPM_MAX`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/RestingHeartRateRecord#BPM_MAX()), [`BPM_MIN`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/RestingHeartRateRecord#BPM_MIN()) |
| [`SkinTemperatureRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/SkinTemperatureRecord) | [`TEMPERATURE_DELTA_AVG`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/SkinTemperatureRecord#TEMPERATURE_DELTA_AVG()), [`TEMPERATURE_DELTA_MAX`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/SkinTemperatureRecord#TEMPERATURE_DELTA_MAX()), [`TEMPERATURE_DELTA_MIN`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/SkinTemperatureRecord#TEMPERATURE_DELTA_MIN()) |
| [`SleepSessionRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/SleepSessionRecord) | [`SLEEP_DURATION_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/SleepSessionRecord#SLEEP_DURATION_TOTAL()) |
| [`SpeedRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/SpeedRecord) | [`SPEED_AVG`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/SpeedRecord#SPEED_AVG()), [`SPEED_MAX`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/SpeedRecord#SPEED_MAX()), [`SPEED_MIN`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/SpeedRecord#SPEED_MIN()) |
| [`StepsRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/StepsRecord) | [`COUNT_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/StepsRecord#COUNT_TOTAL()) |
| [`StepsCadenceRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/StepsCadenceRecord) | [`RATE_AVG`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/StepsCadenceRecord#RATE_AVG()), [`RATE_MAX`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/StepsCadenceRecord#RATE_MAX()), [`RATE_MIN`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/StepsCadenceRecord#RATE_MIN()) |
| [`TotalCaloriesBurnedRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/TotalCaloriesBurnedRecord) | [`ENERGY_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/TotalCaloriesBurnedRecord#ENERGY_TOTAL()) |
| [`WeightRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/WeightRecord) | [`WEIGHT_AVG`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/WeightRecord#WEIGHT_AVG()), [`WEIGHT_MAX`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/WeightRecord#WEIGHT_MAX()), [`WEIGHT_MIN`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/WeightRecord#WEIGHT_MIN()) |
| [`WheelchairPushesRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/WheelchairPushesRecord) | [`COUNT_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/WheelchairPushesRecord#COUNT_TOTAL()) |
[*Table: Supported aggregate data types by record*]

<br />

Deleting data is a key part of the CRUD operations in Health Connect. This guide
shows you how you can delete records in two ways.

> [!TIP]
> **Tip:** For further guidance on deleting data, take a look at the [Android Developer video for reading and writing data](https://www.youtube.com/watch?v=NAx7Gv_Hk7E&t=299) in Health Connect.

## Delete using Record IDs

You can delete records using a list of unique identifiers such as the Record ID
and your app's Client Record ID. Use [`deleteRecords`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#deleteRecords(kotlin.reflect.KClass,kotlin.collections.List,kotlin.collections.List)), and
supply it with two lists of `Strings`, one for the Record IDs and one for the
Client IDs. If you only have one of the IDs available, you can set `emptyList()`
on the other list.

The following code example shows how to delete Steps data using its IDs:


```kotlin
try {
    healthConnectClient.deleteRecords(
        recordType = StepsRecord::class,
        recordIdsList = idList,
        clientRecordIdsList = emptyList<String>()
    )
} catch (e: Exception) {
    // Run error handling here
}
```

<br />

## Delete using a time range

You can also delete data using a time range as your filter.
Use [`deleteRecords`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#deleteRecords(kotlin.reflect.KClass,androidx.health.connect.client.time.TimeRangeFilter)), and supply it with a
[`TimeRangeFilter`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/time/TimeRangeFilter) object that takes
a start and end timestamp values.

The following code example shows how to delete Steps data of a specific time:


```kotlin
try {
    healthConnectClient.deleteRecords(
        StepsRecord::class,
        timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
    )
} catch (e: Exception) {
    // Run error handling here
}
```

<br />

> This guide is compatible with Health Connect version [1.1.0-alpha12](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0-alpha12).

Most apps that integrate with Health Connect have their own datastore that
serves as the source of truth. Health Connect provides ways to keep your app
in sync.

Depending on your app's architecture, the sync process might involve some or
all of the following actions:

- Feed new or updated data from your app's datastore to Health Connect.
- Pull data changes from Health Connect into your app's datastore.
- Delete data from Health Connect when it's deleted in your app's datastore.

In each case, make sure that the syncing process keeps both Health Connect and
your app's datastore aligned.

## Feed data to Health Connect

The first part of the syncing process is to feed data from your app's datastore
to the Health Connect datastore.

### Prepare your data

Usually, records in your app's datastore have the following details:

- A unique key, such as a `UUID`.
- A version or timestamp.

When syncing data to Health Connect, identify and feed only the data that has
been inserted, updated, or deleted since the last sync.

### Write data to Health Connect

To feed data into Health Connect, carry out the following steps:

1. Obtain a list of new, updated, or deleted entries from your app's datastore.
2. For each entry, create a `Record` object appropriate for that data type. For example, create a `WeightRecord` object for data related to weight.
3. Specify a `Metadata` object with each `Record`. This includes
   `clientRecordId`, which is an ID from your app's datastore that you can use
   to uniquely identify the record. You can use your existing unique key for
   this. If your data is versioned, also provide a
   `clientRecordVersion` that aligns with the versioning used in your data.
   If it's not versioned, you can use the `Long` value
   of the current timestamp as an alternative.


   ```kotlin
   val recordVersion = 0L
   // Specify as needed
   // The clientRecordId is an ID that you choose for your record. This
   // is often the same ID you use in your app's datastore.
   val clientRecordId = "<your-record-id>"

   val record = WeightRecord(
       metadata = Metadata.activelyRecorded(
           clientRecordId = clientRecordId,
           clientRecordVersion = recordVersion,
           device = Device(type = Device.TYPE_SCALE)
       ),
       weight = Mass.kilograms(62.0),
       time = Instant.now(),
       zoneOffset = ZoneOffset.UTC,
   )
   healthConnectClient.insertRecords(listOf(record))
   ```

   <br />

4. [Upsert](https://developer.android.com/guide/health-and-fitness/health-connect/develop/write-data#upsert-through-client-id) data to Health Connect using
   [`insertRecords`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#insertRecords(kotlin.collections.List)). Upserting data means that any existing
   data in Health Connect gets overwritten as long as the `clientRecordId`
   values exist in the Health Connect datastore, and the `clientRecordVersion`
   is higher than the existing value. Otherwise, the upserted data is written
   as new data.


   ```kotlin
   healthConnectClient.insertRecords(arrayListOf(record))
   ```

   <br />

To learn about the practical considerations for feeding data, check out the best
practices for [Write data](https://developer.android.com/guide/health-and-fitness/health-connect/plan/best-practices#write-data).

### Store Health Connect IDs

If your app also reads data from Health Connect, store the Health Connect `id`
for records after you upsert them. You need this `id` to process deletions when
you pull data changes from Health Connect.

The [`insertRecords`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#insertRecords(kotlin.collections.List)) function returns a
[`InsertRecordsResponse`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/response/InsertRecordsResponse) that contains the list of `id` values.
Use the response to get the Record IDs and store them.


```kotlin
val response = healthConnectClient.insertRecords(listOf(record))
for (recordId in response.recordIdsList) {
    // Store recordId to your app's datastore
}
```

<br />

> [!NOTE]
> **Note:** If your app needs to read data from Health Connect, you must store the `id`. This is necessary to correctly process deletion changelogs, as `DeletionChange` notifications only provide the record `id`.

## Pull data from Health Connect

The second part of the syncing process is to pull for any data changes from
Health Connect to your app's datastore. The data changes can include updates and
deletions.

### Get a Changes token

To get a list of changes to pull from Health Connect, your app needs to keep
track of *Changes* tokens. You can use them when requesting *Changes* to
return both a list of data changes, and a new *Changes* token to be used next
time.

To obtain a *Changes* token, call [`getChangesToken`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#getChangesToken(androidx.health.connect.client.request.ChangesTokenRequest)) and
supply the required data types.


```kotlin
val changesToken = healthConnectClient.getChangesToken(
    ChangesTokenRequest(recordTypes = setOf(WeightRecord::class))
)
```

<br />

> [!NOTE]
> **Note:** We recommend getting separate tokens per data type instead of getting them in bulk to avoid having an `Exception` in case one of the permissions is revoked.

### Check for data changes

Now that you've obtained a *Changes* token, use it to get all *Changes* .
We recommend creating a loop to get through all the *Changes* where it checks
if there are available data changes. Here are the following steps:

1. Call [`getChanges`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#getChanges(kotlin.String)) using the token to obtain a list of *Changes*.
2. Check each change whether its type of change is an [`UpsertionChange`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/changes/UpsertionChange) or a [`DeletionChange`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/changes/DeletionChange), and perform the necessary operations.
   - For `UpsertionChange`, only take changes that didn't come from the calling app to make sure you're not re-importing data.
3. Assign the next *Changes* token as your new token.
4. Repeat Steps 1-3 until there are no *Changes* left.
5. Store the next token and reserve it for a future import.


```kotlin
suspend fun processChanges(context: Context, token: String): String {
    var nextChangesToken = token
    do {
        val response = healthConnectClient.getChanges(nextChangesToken)
        response.changes.forEach { change ->
            when (change) {
                is UpsertionChange ->
                    if (change.record.metadata.dataOrigin.packageName != context.packageName) {
                        processUpsertionChange(change)
                    }
                is DeletionChange -> processDeletionChange(change)
            }
        }
        nextChangesToken = response.nextChangesToken
    } while (response.hasMore)
    // Return and store the changes token for use next time.
    return nextChangesToken
}
```

<br />

To learn about the practical considerations for pulling data, check out the best
practices for [Sync data](https://developer.android.com/guide/health-and-fitness/health-connect/plan/best-practices#sync-data).

### Process data changes

Reflect the changes to your app's datastore. For `UpsertionChange`, use the `id`
and the `lastModifiedTime` from its `metadata` to [upsert](https://developer.android.com/guide/health-and-fitness/health-connect/develop/write-data#upsert-through-client-id) the record.
For `DeletionChange`, use the `id` provided to [delete](https://developer.android.com/guide/health-and-fitness/health-connect/develop/delete-data) the record.
This requires that you have stored the record `id` as mentioned in
[Store Health Connect IDs](https://developer.android.com/health-and-fitness/health-connect/sync-data#store-ids).

> [!NOTE]
> **Note:** [`DeletionChange`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/changes/DeletionChange) only contains the `id` of the deleted record, and not the record type, due to privacy. With that, you can either specify only 1 data type for each call of `getChanges`, or make sure that you've stored this information separately beforehand.

## Delete data from Health Connect

When a user deletes their own data from your app, make sure that the data is
also [removed](https://developer.android.com/guide/health-and-fitness/health-connect/develop/delete-data) from Health Connect. Use [`deleteRecords`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#deleteRecords(kotlin.reflect.KClass,kotlin.collections.List,kotlin.collections.List))
to do this. This takes a record type and list of `id` and `clientRecordId`
values, which makes it convenient to batch multiple data for deletion. An
alternative [`deleteRecords`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#deleteRecords(kotlin.reflect.KClass,androidx.health.connect.client.time.TimeRangeFilter)) that takes in a `timeRangeFilter`
is also available.

## Low-latency synchronization from wearables

To sync data from a wearable fitness device to Health Connect with low latency,
use [`CompanionDeviceService`](https://developer.android.com/reference/android/companion/CompanionDeviceService). This approach works for
devices that support BLE GATT Notifications or Indications and
target Android 8.0 (API level 26) or higher. `CompanionDeviceService` allows
your app to receive data from wearables and write it to Health Connect, even
when the app isn't already running. For more details on BLE best practices, see
[Bluetooth Low Energy overview](https://developer.android.com/develop/connectivity/bluetooth/ble/background#stay-connected).

### Associate the device

First, your app must guide the user through a one-time process to associate
the wearable with your app using
[`CompanionDeviceManager`](https://developer.android.com/reference/android/companion/CompanionDeviceManager). This grants your app the
necessary permissions to interact with the device. For more information,
see [Companion device pairing](https://developer.android.com/develop/connectivity/bluetooth/companion-device-pairing).

### Declare the service in the Manifest

Next, declare `CompanionDeviceService` in your app's manifest file. Add the
following to your `AndroidManifest.xml`:

    <manifest ...>
       <application ...>
           <service
               android:name=".MyWearableService"
               android:exported="true"
               android:permission="android.permission.BIND_COMPANION_DEVICE_SERVICE">
               <intent-filter>
                   <action android:name="android.companion.CompanionDeviceService" />
               </intent-filter>
           </service>
       </application>
    </manifest>

### Create CompanionDeviceService

Finally, create a class that extends `CompanionDeviceService`. This service
handles the connection to the wearable device and receives data through BLE
GATT callbacks. When new data is received, it's immediately written to Health
Connect.


```kotlin
private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
private var healthConnectClient: HealthConnectClient? = null
private var bluetoothGatt: BluetoothGatt? = null

override fun onDeviceAppeared(address: String) {
    super.onDeviceAppeared(address)
    healthConnectClient = HealthConnectClient.getOrCreate(this)

    serviceScope.launch {
        val granted = healthConnectClient?.permissionController?.getGrantedPermissions()

        // 1. Check permissions ONCE when the device connects
        if (granted?.contains(HealthPermission.getWritePermission(HeartRateRecord::class)) ?: false) {
            // This is where you'd actually start the Bluetooth connection
            // bluetoothGatt = gattCallback.connect(...)
        }

        // 2. Do your initial database read
        readExerciseSessionAndRoute()
    }
}

private val gattCallback = object : BluetoothGattCallback() {
    override fun onCharacteristicChanged(
        gatt: BluetoothGatt,
        characteristic: BluetoothGattCharacteristic,
        value: ByteArray
    ) {
        super.onCharacteristicChanged(gatt, characteristic, value)

        // 3. ONLY process the incoming data here
        val rawData = value

        serviceScope.launch {
            // parseWearableData(rawData)
            // insertExerciseRoute() or writeToHealthConnect()
        }
    }
}
```

<br />

## Best practices for syncing data

The following factors affect the syncing process.

### Token expiration

Since an unused *Changes* token expires within 30 days, you must use a sync
strategy that avoids losing information in such a case. Your strategy could
include the following approaches:

- Search your app datastore for the most recently consumed record that also has an `id` from Health Connect.
- Request records from Health Connect that begin with a specific timestamp, and then insert or update them in your app's datastore.
- Request a Changes token to reserve it for the next time it's needed.

#### Recommended Changes management strategies

In case your app is getting invalid or expired *Changes* tokens, we
recommend the following management strategies depending on its application in
your logic:

- **Read and dedupe all data** . This is the most ideal strategy.
  - Store the timestamp of the last time they read data from Health Connect.
  - On token expiry, re-read all data from the most recent timestamp or for the last 30 days. Then, dedupe it against the previously read data using identifiers.
  - Ideally, implement Client IDs since they are required for data updates.
- **Only read data since the last read timestamp** . This results in some data discrepancies around the time of Changes token expiry, but the time period is shorter that could take a few hours to a couple of days.
  - Store the timestamp of the last time they read data from Health Connect.
  - On token expiry, read all data from this timestamp onwards.
- **Delete then read data for the last 30 days** . This aligns more closely with what happens on the first integration.
  - Delete all data read by the app from Health Connect for the last 30 days.
  - Once deleted, read all of this data again.
- **Read data for last 30 days without deduping** . This is the least ideal strategy, and results in having duplicate data displayed to users.
  - Delete all data read by the app from Health Connect for the last 30 days.
  - Allow duplicate entries.

### Data type Changes tokens

If your app consumes more than one data type independently, use separate Changes
Tokens for each data type. Only use a list of multiple data types with the
Changes Sync API if these data types are either consumed together or not at all.

### Foreground reads

Apps can only read data from Health Connect while they are in the foreground.
When syncing data from Health Connect, access to Health Connect may be
interrupted at any point. For example, your app must handle interruptions
midway through a sync when reading a large amount of data from Health Connect,
and continue the next time the app is opened.

### Background reads

You can request that your application run in the background and read data from
Health Connect. If you request the
[`Background Read`](https://developer.android.com/health-and-fitness/guides/health-connect/develop/read-data#background-read-example) permission, your user can grant your app
access to read data in the background.

### Import timings

As your app can't get notified of new data, check for new data at two points:

- Each time your app becomes active in the foreground. In this case, use lifecycle events.
- Periodically, while your app remains in the foreground. Notify users when new data is available, allowing them to update their screen to reflect the changes.

> This guide is compatible with Health Connect version [1.1.0-alpha12](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0-alpha12) and
> later.

There are changes to metadata in Health Connect for
developers who upgrade to release 1.1.0-alpha12 or later.

> [!WARNING]
> **Warning:** Updating Jetpack versions without implementing these changes will break your Health Connect integration.

## Library information

The [Google Maven Android gradle plugin](https://developer.android.com/build/dependencies#google-maven) artifact ID
identifies the Health Connect library to which you will need to upgrade.
Add this Health Connect SDK dependency to your module-level
`build.gradle` file:

    dependencies {
      implementation "androidx.health.connect:connect-client:1.1.0-alpha12"
    }

## Metadata changes

Two metadata changes have been introduced to the **Health Connect Jetpack SDK**
as of version 1.1.0-alpha12 to help verify that additional useful metadata
exists in the ecosystem. If `metadata` is not included in your
`Record` constructor, you might see a **Constructor internal** error.

### Specify the recording method

You must specify metadata details whenever
a `Record()` type object is instantiated.

When writing data to **Health Connect** , you must specify one of four recording
methods by using one of the corresponding [factory methods](https://developer.android.com/health-and-fitness/health-connect/metadata#metadata-methods)
to instantiate `Metadata`:

| Recording method | Description |
|---|---|
| `RECORDING_METHOD_UNKNOWN` | The recording method cannot be verified. |
| `RECORDING_METHOD_MANUAL_ENTRY` | The user entered the data. |
| `RECORDING_METHOD_AUTOMATICALLY_RECORDED` | A device or sensor recorded the data. |
| `RECORDING_METHOD_ACTIVELY_RECORDED` | The user initiated the start or end of the recording session on a device. |

For example:


```kotlin
 StepsRecord(
    startTime = Instant.ofEpochMilli(1234L),
    startZoneOffset = null,
    endTime = Instant.ofEpochMilli(1236L),
    endZoneOffset = null,
    metadata = Metadata.activelyRecorded(device = Device(type = Device.TYPE_WATCH)),
    count = 10
)
```

<br />

### Device type

You must specify a device type for all
automatically and actively recorded data. For more details, see the
[`Device` class in the Jetpack documentation](https://cs.android.com/androidx/platform/frameworks/support/+/androidx-main:health/connect/connect-client/src/main/java/androidx/health/connect/client/records/metadata/Device.kt). Current device
types include:

| Device type | Description |
|---|---|
| `TYPE_UNKNOWN` | The device type is unknown. |
| `TYPE_WATCH` | The device type is a watch. |
| `TYPE_PHONE` | The device type is a phone. |
| `TYPE_SCALE` | The device type is a scale. |
| `TYPE_RING` | The device type is a ring. |
| `TYPE_HEAD_MOUNTED` | The device type is a head-mounted device. |
| `TYPE_FITNESS_BAND` | The device type is a fitness band. |
| `TYPE_CHEST_STRAP` | The device type is a chest strap. |
| `TYPE_SMART_DISPLAY` | The device type is a smart display. |

Some `Device.type` values are only available on later versions of Health
Connect. When the extended device types feature isn't available, these types
are treated as `Device.TYPE_UNKNOWN`.

| Extended device types | Description |
|---|---|
| `TYPE_CONSUMER_MEDICAL_DEVICE` | The device type is medical device. |
| `TYPE_GLASSES` | The device type is a pair of smart glasses or eyewear. |
| `TYPE_HEARABLE` | The device type is a hearable device. |
| `TYPE_FITNESS_MACHINE` | The device type is a stationary machine. |
| `TYPE_FITNESS_EQUIPMENT` | The device type is a fitness equipment. |
| `TYPE_PORTABLE_COMPUTER` | The device type is a portable computer. |
| `TYPE_METER` | The device type is a measurement meter. |

To determine whether a user's device supports Extended Device Types on Health Connect, check the availability of `FEATURE_EXTENDED_DEVICE_TYPES` on the client:

<br />

    if (healthConnectClient
         .features
         .getFeatureStatus(
           HealthConnectFeatures.FEATURE_EXTENDED_DEVICE_TYPES
         ) == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE) {

      // Feature is available
    } else {
      // Feature isn't available
    }

See [Check for feature availability](https://developer.android.com/health-and-fitness/guides/health-connect/develop/feature-availability) to learn more.

> [!NOTE]
> **Note:** If known, provide the \`manufacturer\` and \`model\` of the device in addition to device type. Doing so helps with attribution in reader applications, so users can understand which device or application recorded their data.

For example:


```kotlin
 val WATCH_DEVICE = Device(
    manufacturer = "Google",
    model = "Pixel Watch",
    type = Device.TYPE_WATCH
)

// Phone
 val PHONE_DEVICE = Device(
    manufacturer = "Google",
    model = "Pixel 8",
    type = Device.TYPE_PHONE
)

// Ring
 val RING_DEVICE = Device(
    manufacturer = "Oura",
    model = "Ring Gen3",
    type = Device.TYPE_RING
)

// Scale
 val SCALE_DEVICE = Device(
    manufacturer = "Withings",
    model = "Body Comp",
    type = Device.TYPE_SCALE
)
```

<br />

### Snippets updated

Health Connect guides have been updated wherever new snippets are needed
to adhere to the new metadata requirements. For some examples, refer to the
[Write Data](https://developer.android.com/health-and-fitness/guides/health-connect/develop/write-data) page.

### New metadata methods

Metadata can no longer be directly instantiated, so use one of the
factory methods to get a new instance of metadata. The factory methods verify
that device information is provided when a device or sensor was used to
record the data. For manually entered data, providing device information
remains optional.
Each function has three signature variants:

- `activelyRecorded`

  - `fun activelyRecorded(device: Device): Metadata.`
  - `fun activelyRecorded(clientRecordId: String, clientRecordVersion: Long = 0, device: Device): Metadata`
  - `fun activelyRecordedWithId(id: String, device: Device): Metadata`
- `autoRecorded`

  - `fun autoRecorded(device: Device): Metadata`
  - `fun autoRecorded(clientRecordId: String, clientRecordVersion: Long = 0, device: Device): Metadata`
  - `fun autoRecordedWithId(id: String, device: Device): Metadata`
- `manualEntry`

  - `fun manualEntry(device: Device? = null): Metadata`
  - `fun manualEntry(clientRecordId: String, clientRecordVersion: Long = 0, device: Device? = null): Metadata`
  - `fun manualEntryWithId(id: String, device: Device? = null): Metadata`
- `unknownRecordingMethod`

  - `fun unknownRecordingMethod(device: Device? = null): Metadata`
  - `fun unknownRecordingMethod(clientRecordId: String, clientRecordVersion: Long = 0, device: Device? = null): Metadata`
  - `fun unknownRecordingMethodWithId(id: String, device: Device? = null): Metadata`

For more information, see the [Android Open Source Project](https://cs.android.com/androidx/platform/frameworks/support/+/androidx-main:health/connect/connect-client/src/main/java/androidx/health/connect/client/records/metadata/Metadata.kt).

### Testing data

Use the [Testing Library](https://developer.android.com/health-and-fitness/guides/health-connect/test/unit-tests) and
[`MetadataTestHelper`](https://cs.android.com/androidx/platform/frameworks/support/+/androidx-main:health/connect/connect-testing/src/main/java/androidx/health/connect/client/testing/MetadataTestHelper.kt) to mock expected metadata
values:

    private val TEST_METADATA =
        Metadata.unknownRecordingMethod(
            clientRecordId = "clientId",
            clientRecordVersion = 1L,
            device = Device(type = Device.TYPE_UNKNOWN),
        ).populatedWithTestValues(id = "test")

This simulates the behavior of the Health Connect implementation,
which automatically populates these values during record insertion.

For the testing library, you need to add this Health Connect SDK dependency to
your module-level `build.gradle` file:

    dependencies {
      testImplementation "androidx.health.connect:connect-testing:1.0.0-alpha02"
    }

## Upgrade the library

The main steps you need to perform are:

1. Upgrade your library to 1.1.0-alpha12.

2. When building the library, compilation errors will be thrown where
   new metadata is needed. To resolve these errors and complete migration,
   verify you make the following changes:

   - It is mandatory to specify a recording method when constructing a `Record`. This is done by using one of the factory methods provided in `Metadata`, such as `Metadata.manualEntry()` or `Metadata.activelyRecorded(device = Device(...))`.
   - For data recorded by a device, it is mandatory to specify a device type, such as `Device.TYPE_WATCH` or `Device.TYPE_PHONE`.
3. If your app writes extended device types, gate them behind
   `FEATURE_EXTENTED_DEVICE_TYPES` to avoid unexpected `TYPE_UNKNOWN` on devices
   where the feature isn't available.

To maintain optimal system stability and performance, Health Connect imposes
rate limits on client connections to the Health Connect API.

This guide outlines the limits imposed on read and write API operations in
Health Connect, and how to avoid rate limiting through efficient app design.

## API limits

Limits are placed on both foreground and background API operations as **fixed
request rate quotas**.

Rate and memory limits are variable based on the type of operation your app is
performing, and whether that operation occurs in the foreground or background.

### Read and changelog limits

For read and changelog limits, Health Connect imposes two limits on the number
of API calls available to your app:

- A periodic limit on the number of API calls your app can make to the API.
- A daily limit on the number of API calls your app can make.

### Insert, update and delete limits

Health Connect places four distinct limits on insertion, update and deletion
operations:

- A periodic limit on the number of calls your app can make to the API.
- A daily limit on the number of calls your app can make to the API.
- A memory limit for bulk insertions.
- A memory limit for single record insertions.

## Best practices

We recommend that apps interact with the Health Connect API in a way that
minimizes battery use, maintains optimal system health and promotes efficient
data management across all CRUD operations.

Here are some best practice guidelines to adhere to.

### Background API calls

Battery usage for background operations reduces the user experience and raises
questions regarding [data privacy](https://developer.android.com/guide/health-and-fitness/health-connect/develop/read-data#foreground-restriction).

As such, background rate limiting is stricter than foreground rate limiting.
It's therefore important to limit the amount of API calls your app carries out
in the background.

### Exception handling

If your app experiences an exception when writing data to Health Connect, we
recommend retrying from where the exception occurred.

Don't delete all the data in question and retry the entire write request.
This approach eats into your insert quota, reduces performance, and has a
negative impact on battery life.

### Changelog handling

To minimize the risk of your app being rate limited, you should utilize
[changelog handling](https://developer.android.com/guide/health-and-fitness/health-connect/develop/sync-data#pull-data) to synchronize your database with data from Health
Connect, rather than over-relying on raw read requests.

> This guide is compatible with Health Connect version [1.1.0-alpha12](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0-alpha12).

Health Connect provides a *skin temperature* data type to measure peripheral
body temperature. This measurement is a particularly useful signal for detecting
sleep quality, reproductive health, and the potential onset of illness.

## Check Health Connect availability

Before attempting to use Health Connect, your app should verify that Health Connect is available
on the user's device. Health Connect might not be pre-installed on all devices or could be disabled.
You can check for availability using the `https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#getSdkStatus(android.content.Context,kotlin.String)`
method.

#### How to check for Health Connect availability

```kotlin
fun checkHealthConnectAvailability(context: Context) {
    val providerPackageName = "com.google.android.apps.healthdata" // Or get from HealthConnectClient.DEFAULT_PROVIDER_PACKAGE_NAME
    val availabilityStatus = HealthConnectClient.getSdkStatus(context, providerPackageName)

    if (availabilityStatus == HealthConnectClient.SDK_UNAVAILABLE) {
      // Health Connect is not available. Guide the user to install/enable it.
      // For example, show a dialog.
      return // early return as there is no viable integration
    }
    if (availabilityStatus == HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED) {
      // Health Connect is available but requires an update.
      // Optionally redirect to package installer to find a provider, for example:
      val uriString = "market://details?id=$providerPackageName&url=healthconnect%3A%2F%2Fonboarding"
      context.startActivity(
        Intent(Intent.ACTION_VIEW).apply {
          setPackage("com.android.vending")
          data = Uri.parse(uriString)
          putExtra("overlay", true)
          putExtra("callerId", context.packageName)
        }
      )
      return
    }
    // Health Connect is available, obtain a HealthConnectClient instance
    val healthConnectClient = HealthConnectClient.getOrCreate(context)
    // Issue operations with healthConnectClient
}
```

Depending on the status returned by `getSdkStatus()`, you can guide the user
to install or update Health Connect from the Google Play Store if necessary.

## Feature availability

To determine whether a user's device supports skin temperature on Health Connect, check the availability of `FEATURE_SKIN_TEMPERATURE` on the client:

<br />

    if (healthConnectClient
         .features
         .getFeatureStatus(
           HealthConnectFeatures.FEATURE_SKIN_TEMPERATURE
         ) == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE) {

      // Feature is available
    } else {
      // Feature isn't available
    }

See [Check for feature availability](https://developer.android.com/health-and-fitness/guides/health-connect/develop/feature-availability) to learn more.

> [!NOTE]
> **Note:** The skin temperature data type isn't meant to measure core body temperature. If your app requires this measurement, use classes such as [`BodyTemperatureRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/BodyTemperatureRecord) and [`BasalBodyTemperatureRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/BasalBodyTemperatureRecord).

## Required permissions

Access to skin temperature is protected by the following permissions:

- `android.permission.health.READ_SKIN_TEMPERATURE`
- `android.permission.health.WRITE_SKIN_TEMPERATURE`

To add skin temperature capability to your app, start by requesting
permissions for the `SkinTemperature` data type.

Here's the permission you need to declare to be able to write
skin temperature:

    <application>
      <uses-permission
    android:name="android.permission.health.WRITE_SKIN_TEMPERATURE" />
    ...
    </application>

To read skin temperature, you need to request the following permissions:

    <application>
      <uses-permission
    android:name="android.permission.health.READ_SKIN_TEMPERATURE" />
    ...
    </application>

### Request permissions from the user

After creating a client instance, your app needs to request permissions from
the user. Users must be allowed to grant or deny permissions at any time.

To do so, create a set of permissions for the required data types.
Make sure that the permissions in the set are declared in your Android
manifest first.


```kotlin
val permissions =
    setOf(
        HealthPermission.getReadPermission(SkinTemperatureRecord::class),
        HealthPermission.getWritePermission(SkinTemperatureRecord::class)
    )
```
Use [`getGrantedPermissions`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/PermissionController#getGrantedPermissions()) to see if your app already has the required permissions granted. If not, use [`createRequestPermissionResultContract`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/PermissionController#createRequestPermissionResultContract(kotlin.String)) to request those permissions. This displays the Health Connect permissions screen.

```kotlin
val permissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getWritePermission(StepsRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getWritePermission(HeartRateRecord::class)
    )

val requestPermissionsLauncher = rememberLauncherForActivityResult(
    contract = PermissionController.createRequestPermissionResultContract()
) { grantedPermissions ->
    if (grantedPermissions.containsAll(permissions)) {
        coroutineScope.launch { snackbarHostState.showSnackbar("Permissions granted!") }
    } else {
        coroutineScope.launch { snackbarHostState.showSnackbar("Permissions denied.") }
    }
}
```
Because users can grant or revoke permissions at any time, your app needs to check for permissions every time before using them and handle scenarios where permission is lost.

<br />

## Information included in a skin temperature record

Skin temperature measurements are organized into *records*. Each record consists
of the following information:

- **Baseline temperature**, in degrees Celsius or degrees Fahrenheit. This is an optional value that is most useful for visualization in your app's UI.
- A **list of deltas** in skin temperature, each showing the change in skin temperature since the last measurement. If the baseline temperature is provided, these deltas should use the same temperature units.
- The **location** on the user's body where the measurement was taken: finger, toe, or wrist.

## Supported aggregations

<br />

The following aggregate values are available for
`SkinTemperatureRecord`:

- [`TEMPERATURE_DELTA_AVG`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/SkinTemperatureRecord#TEMPERATURE_DELTA_AVG())
- [`TEMPERATURE_DELTA_MAX`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/SkinTemperatureRecord#TEMPERATURE_DELTA_MAX())
- [`TEMPERATURE_DELTA_MIN`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/SkinTemperatureRecord#TEMPERATURE_DELTA_MIN())

<br />

## Example usage

The following code snippets show how to read and write skin temperature
measurements.

### Read skin temperature record

The following code snippet demonstrates how to read a skin temperature
measurements using the Jetpack library:

    suspend fun readSkinTemperatures() {
        // Error handling, permission check, and feature availability check
        // aren't included.

        // Record includes measurements during the past hour.
        val recordEndTime = Instant.now()
        val recordStartTime = recordEndTime.minusSeconds(60 * 60)

        val response = healthConnectClient.readRecords(
            ReadRecordsRequest<SkinTemperatureRecord>(
                timeRangeFilter = TimeRangeFilter.between(
                    recordStartTime, recordEndTime
                )
            )
        )

        for (skinTemperatureRecord in response.records) {
            // Process each skin temperature record here.
        }
    }

### Write a skin temperature record

The following code snippet shows how to write skin temperature
measurements using the Jetpack library:


    suspend fun writeSkinTemperatures(): InsertRecordsResponse {
        // Error handling, permission check, and feature availability check
        // aren't included.

        // Record includes measurements during the past hour.
        val recordEndTime: ZonedDateTime = now()
        val recordStartTime: ZonedDateTime = recordEndTime.minusHours(1)

        healthConnectClient.insertRecords(
            // For this example, there's only one skin temperature record.
            listOf(
                SkinTemperatureRecord(
                    baseline = Temperature.celsius(37.0),
                    startTime = recordStartTime.toInstant(),
                    startZoneOffset = recordStartTime.offset,
                    endTime = recordEndTime.toInstant(),
                    endZoneOffset = recordEndTime.offset,
                    deltas = listOf(
                        SkinTemperatureRecord.Delta(
                            recordEndTime.minusMinutes(50).toInstant(), celsius(0.5)
                        ), SkinTemperatureRecord.Delta(
                            recordEndTime.minusMinutes(30).toInstant(), celsius(-0.7)
                        )
                    ),
                    measurementLocation = SkinTemperatureRecord.MEASUREMENT_LOCATION_FINGER,
                    metadata = Metadata.autoRecorded(
                        device = Device(type = Device.TYPE_RING)
                    ),
                )
            )
        )
    }

> This guide is compatible with Health Connect version [1.1.0-alpha12](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0-alpha12).

Exercise routes allow users to track a GPS route for associated exercise
activities and share maps of their workouts with other apps.

## Check Health Connect availability

Before attempting to use Health Connect, your app should verify that Health Connect is available
on the user's device. Health Connect might not be pre-installed on all devices or could be disabled.
You can check for availability using the `https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#getSdkStatus(android.content.Context,kotlin.String)`
method.

#### How to check for Health Connect availability

```kotlin
fun checkHealthConnectAvailability(context: Context) {
    val providerPackageName = "com.google.android.apps.healthdata" // Or get from HealthConnectClient.DEFAULT_PROVIDER_PACKAGE_NAME
    val availabilityStatus = HealthConnectClient.getSdkStatus(context, providerPackageName)

    if (availabilityStatus == HealthConnectClient.SDK_UNAVAILABLE) {
      // Health Connect is not available. Guide the user to install/enable it.
      // For example, show a dialog.
      return // early return as there is no viable integration
    }
    if (availabilityStatus == HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED) {
      // Health Connect is available but requires an update.
      // Optionally redirect to package installer to find a provider, for example:
      val uriString = "market://details?id=$providerPackageName&url=healthconnect%3A%2F%2Fonboarding"
      context.startActivity(
        Intent(Intent.ACTION_VIEW).apply {
          setPackage("com.android.vending")
          data = Uri.parse(uriString)
          putExtra("overlay", true)
          putExtra("callerId", context.packageName)
        }
      )
      return
    }
    // Health Connect is available, obtain a HealthConnectClient instance
    val healthConnectClient = HealthConnectClient.getOrCreate(context)
    // Issue operations with healthConnectClient
}
```

Depending on the status returned by `getSdkStatus()`, you can guide the user
to install or update Health Connect from the Google Play Store if necessary.

This guide provides information on how to request permissions from the user and
also outlines how apps receive permission to write route data as part of
an exercise session.

The read and write functionality for exercise routes includes:

1. Apps create a new write permission for exercise routes.
2. Insertion happens by writing an exercise session with a route as its field.
3. Reading:
   1. For the session owner, data is accessed using a session read.
   2. From a third-party app, through a dialog that allows the user to grant a one-time read of a route.

If the user doesn't have write permissions and the route is not set, the route
doesn't update.

If your app has a route write permission and tries to update a session by
passing in a session object without a route, the existing route is deleted.

## Feature availability

To determine whether a user's device supports planned exercise on Health Connect, check the availability of `FEATURE_PLANNED_EXERCISE` on the client:

<br />

    if (healthConnectClient
         .features
         .getFeatureStatus(
           HealthConnectFeatures.FEATURE_PLANNED_EXERCISE
         ) == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE) {

      // Feature is available
    } else {
      // Feature isn't available
    }

See [Check for feature availability](https://developer.android.com/health-and-fitness/guides/health-connect/develop/feature-availability) to learn more.

## Required permissions

Access to exercise route is protected by the following permissions:

- `android.permission.health.READ_EXERCISE_ROUTES`
- `android.permission.health.WRITE_EXERCISE_ROUTE`

Note: For this permission type, `READ_EXERCISE_ROUTES` is plural, while `WRITE_EXERCISE_ROUTE` is singular.

To add exercise route capability to your app, start by requesting
permissions for the `ExerciseSession` data type.

Here's the permission you need to declare to be able to write
exercise route:

    <application>
      <uses-permission
    android:name="android.permission.health.WRITE_EXERCISE_ROUTE" />
    ...
    </application>

To read exercise route, you need to request the following permissions:

    <application>
      <uses-permission
    android:name="android.permission.health.READ_EXERCISE_ROUTES" />
    ...
    </application>

You also have to declare an exercise permission, as each route is associated
with an exercise session (one session = one workout).

To request permissions, use the
`PermissionController.createRequestPermissionResultContract()` method when you
first connect your app to Health Connect. Several permissions that you might
want to request are:

- Read health and fitness data, including route data: `HealthPermission.getReadPermission(ExerciseSessionRecord::class)`
- Write health and fitness data, including route data: `HealthPermission.getWritePermission(ExerciseSessionRecord::class)`
- Write exercise route data: `HealthPermission.PERMISSION_WRITE_EXERCISE_ROUTE`

> [!NOTE]
> **Note:** If the user doesn't grant all of the permissions that your app requests, your app should still run, and it should perform as many tasks as it can with the permissions that the user granted.

### Request permissions from the user

After creating a client instance, your app needs to request permissions from
the user. Users must be allowed to grant or deny permissions at any time.

To do so, create a set of permissions for the required data types.
Make sure that the permissions in the set are declared in your Android
manifest first.


```kotlin
val permissions =
    setOf(
        HealthPermission.getReadPermission(ExerciseSessionRecord::class),
        HealthPermission.getWritePermission(ExerciseSessionRecord::class)
    )
```
Use [`getGrantedPermissions`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/PermissionController#getGrantedPermissions()) to see if your app already has the required permissions granted. If not, use [`createRequestPermissionResultContract`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/PermissionController#createRequestPermissionResultContract(kotlin.String)) to request those permissions. This displays the Health Connect permissions screen.

```kotlin
val permissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getWritePermission(StepsRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getWritePermission(HeartRateRecord::class)
    )

val requestPermissionsLauncher = rememberLauncherForActivityResult(
    contract = PermissionController.createRequestPermissionResultContract()
) { grantedPermissions ->
    if (grantedPermissions.containsAll(permissions)) {
        coroutineScope.launch { snackbarHostState.showSnackbar("Permissions granted!") }
    } else {
        coroutineScope.launch { snackbarHostState.showSnackbar("Permissions denied.") }
    }
}
```
Because users can grant or revoke permissions at any time, your app needs to check for permissions every time before using them and handle scenarios where permission is lost.

<br />

> [!NOTE]
> **Note:** Even if your app has been granted "Always allow" access to exercise route data, background access to routes created by other apps is restricted.

## Information included in an exercise session record

Each exercise session record contains the following information:

- The exercise **type**, for example, biking.
- The exercise **route**, which contains information such as latitude, longitude, and altitude.

## Supported aggregations

<br />

The following aggregate values are available for
`ExerciseSessionRecord`:

- [`EXERCISE_DURATION_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_DURATION_TOTAL())

<br />

## Example usage

The following code snippets show how to read and write an exercise route.

### Read exercise route

Your app can't read exercise route data created by other apps when it runs in
the background.

When your app runs in the background and tries to read an exercise route created
by another app, Health Connect returns an `ExerciseRouteResult.ConsentRequired`
response, even if your app has **Always allow** access to exercise
route data.

For this reason, we strongly recommend that you request routes upon deliberate
user interaction with your app, when the user is actively engaged with your
app's UI.

To learn more about background reads, see [Background read example](https://developer.android.com/health-and-fitness/guides/health-connect/develop/read-data#background-read-example).

The following code snippet demonstrates how to read a session in Health Connect
and request a route from that session:


```kotlin
private suspend fun readExerciseSessionAndRoute() {
    val client = healthConnectClient ?: return

    val endTime = Instant.now()
    val startTime = endTime.minus(Duration.ofHours(1))

    val grantedPermissions = client.permissionController.getGrantedPermissions()

    // 1. Verify basic Exercise Session permissions
    if (!grantedPermissions.contains(
            HealthPermission.getReadPermission(ExerciseSessionRecord::class)
        )
    ) {
        return
    }

    // 2. Read the sessions
    val readResponse = client.readRecords(
        ReadRecordsRequest(
            ExerciseSessionRecord::class,
            TimeRangeFilter.between(startTime, endTime)
        )
    )

    val exerciseRecord = readResponse.records.firstOrNull() ?: return
    val recordId = exerciseRecord.metadata.id

    // 3. Read the specific record to check for the route
    val sessionResponse = client.readRecord(ExerciseSessionRecord::class, recordId)

    // 4. Handle the Route Result directly from the response
    when (val routeResult = sessionResponse.record.exerciseRouteResult) {
        is ExerciseRouteResult.Data -> {
            displayExerciseRoute(routeResult.exerciseRoute)
        }
        is ExerciseRouteResult.ConsentRequired -> {
            // Since you are in a Service, you cannot launch ActivityResultLauncher.
            // Send a notification to the user to grant route-specific consent.
            handleConsentRequired(recordId)
        }
        is ExerciseRouteResult.NoData -> Unit
        else -> Unit
    }
}

private fun displayExerciseRoute(route: ExerciseRoute) {
    val locations = route.route.orEmpty()
    for (location in locations) {
        println(location)
    }
}
```

<br />

### Write an exercise route

The following code demonstrates how to record a session that includes an
exercise route:


```kotlin
private suspend fun insertExerciseRoute() {
    val client = healthConnectClient ?: return

    val grantedPermissions = client.permissionController.getGrantedPermissions()

    // 1. Verify Session Write Permission
    val hasWriteSession = grantedPermissions.contains(
        HealthPermission.getWritePermission(ExerciseSessionRecord::class)
    )
    if (!hasWriteSession) return

    val sessionStartTime = Instant.now()
    val sessionDuration = Duration.ofMinutes(20)
    val sessionEndTime = sessionStartTime.plus(sessionDuration)

    // 2. Build the route if route-specific write permission is granted
    val hasWriteRoute = grantedPermissions.contains(HealthPermission.PERMISSION_WRITE_EXERCISE_ROUTE)

    val exerciseRoute = if (hasWriteRoute) {
        ExerciseRoute(
            listOf(
                ExerciseRoute.Location(
                    time = sessionStartTime,
                    latitude = 6.5483,
                    longitude = 0.5488,
                    horizontalAccuracy = Length.meters(2.0),
                    verticalAccuracy = Length.meters(2.0),
                    altitude = Length.meters(9.0),
                ),
                ExerciseRoute.Location(
                    time = sessionEndTime.minusSeconds(1),
                    latitude = 6.4578,
                    longitude = 0.6577,
                    horizontalAccuracy = Length.meters(2.0),
                    verticalAccuracy = Length.meters(2.0),
                    altitude = Length.meters(9.2),
                )
            )
        )
    } else {
        null
    }

    // 3. Create the session record
    val exerciseSessionRecord = ExerciseSessionRecord(
        startTime = sessionStartTime,
        startZoneOffset = ZoneOffset.UTC,
        endTime = sessionEndTime,
        endZoneOffset = ZoneOffset.UTC,
        exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_BIKING,
        title = "Morning Bike Ride",
        exerciseRoute = exerciseRoute,
        metadata = Metadata.activelyRecorded(
            device = Device(type = Device.TYPE_PHONE)
        )
    )

    // 4. Insert into Health Connect
    client.insertRecords(listOf(exerciseSessionRecord))
}
```

<br />

## Exercise sessions

Exercise sessions can include anything from running to badminton.

### Write exercise sessions

This is how to build an insertion request that includes a session:

    suspend fun writeExerciseSession(healthConnectClient: HealthConnectClient) {
        healthConnectClient.insertRecords(
            listOf(
                ExerciseSessionRecord(
                    startTime = START_TIME,
                    startZoneOffset = START_ZONE_OFFSET,
                    endTime = END_TIME,
                    endZoneOffset = END_ZONE_OFFSET,
                    exerciseType = ExerciseSessionRecord.ExerciseType.RUNNING,
                    title = "My Run",
                    metadata = Metadata.manualEntry()
                ),
                // ... other records
            )
        )
    }

### Read an exercise session

Here's an example of how to read an exercise session:

    suspend fun readExerciseSessions(
        healthConnectClient: HealthConnectClient,
        startTime: Instant,
        endTime: Instant
    ) {
        val response =
            healthConnectClient.readRecords(
                ReadRecordsRequest(
                    ExerciseSessionRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
                )
            )
        for (exerciseRecord in response.records) {
            // Process each exercise record
            // Optionally pull in with other data sources of the same time range.
            val distanceRecord =
                healthConnectClient
                    .readRecords(
                        ReadRecordsRequest(
                            DistanceRecord::class,
                            timeRangeFilter =
                                TimeRangeFilter.between(
                                    exerciseRecord.startTime,
                                    exerciseRecord.endTime
                                )
                        )
                    )
                    .records
        }
    }

### Write subtype data

Sessions can also be comprised of optional subtype data, that enrich the
session with additional information.

For example, exercise sessions can include the `ExerciseSegment`, `ExerciseLap`
and `ExerciseRoute` classes:

    val segments = listOf(
      ExerciseSegment(
        startTime = Instant.parse("2022-01-02T10:10:10Z"),
        endTime = Instant.parse("2022-01-02T10:10:13Z"),
        segmentType = ActivitySegmentType.BENCH_PRESS,
        repetitions = 373
      )
    )

    val laps = listOf(
      ExerciseLap(
        startTime = Instant.parse("2022-01-02T10:10:10Z"),
        endTime = Instant.parse("2022-01-02T10:10:13Z"),
        length = 0.meters
      )
    )

    ExerciseSessionRecord(
      exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_CALISTHENICS,
        startTime = Instant.parse("2022-01-02T10:10:10Z"),
        endTime = Instant.parse("2022-01-02T10:10:13Z"),
      startZoneOffset = ZoneOffset.UTC,
      endZoneOffset = ZoneOffset.UTC,
      segments = segments,
      laps = laps,
      route = route,
      metadata = Metadata.manualEntry()
    )

### Delete an exercise session

There are two ways to delete an exercise session:

1. By time range.
2. By UID.

Here's how you delete subtype data according to time range:


```kotlin
suspend fun deleteExerciseSessionByTimeRange(
    healthConnectClient: HealthConnectClient,
    exerciseRecord: ExerciseSessionRecord,
) {
    val timeRangeFilter = TimeRangeFilter.between(exerciseRecord.startTime, exerciseRecord.endTime)
    healthConnectClient.deleteRecords(ExerciseSessionRecord::class, timeRangeFilter)
    // delete the associated distance record
    healthConnectClient.deleteRecords(DistanceRecord::class, timeRangeFilter)
}
```

<br />

You can also delete subtype data by UID. Doing so only deletes the
exercise session, not the associated data:


```kotlin
suspend fun deleteExerciseSessionByUid(
    healthConnectClient: HealthConnectClient,
    exerciseRecord: ExerciseSessionRecord,
) {
    healthConnectClient.deleteRecords(
        ExerciseSessionRecord::class,
        recordIdsList = listOf(exerciseRecord.metadata.id),
        clientRecordIdsList = emptyList()
    )
}
```

<br />

> This guide is compatible with Health Connect version [1.1.0-rc01](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0-rc01).

Health Connect provides a *mindfulness* data type to measure various aspects
of mental health, such as stress and anxiety. Mindfulness is a data type
that is part of overall wellness in Health Connect.

## Check Health Connect availability

Before attempting to use Health Connect, your app should verify that Health Connect is available
on the user's device. Health Connect might not be pre-installed on all devices or could be disabled.
You can check for availability using the `https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#getSdkStatus(android.content.Context,kotlin.String)`
method.

#### How to check for Health Connect availability

```kotlin
fun checkHealthConnectAvailability(context: Context) {
    val providerPackageName = "com.google.android.apps.healthdata" // Or get from HealthConnectClient.DEFAULT_PROVIDER_PACKAGE_NAME
    val availabilityStatus = HealthConnectClient.getSdkStatus(context, providerPackageName)

    if (availabilityStatus == HealthConnectClient.SDK_UNAVAILABLE) {
      // Health Connect is not available. Guide the user to install/enable it.
      // For example, show a dialog.
      return // early return as there is no viable integration
    }
    if (availabilityStatus == HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED) {
      // Health Connect is available but requires an update.
      // Optionally redirect to package installer to find a provider, for example:
      val uriString = "market://details?id=$providerPackageName&url=healthconnect%3A%2F%2Fonboarding"
      context.startActivity(
        Intent(Intent.ACTION_VIEW).apply {
          setPackage("com.android.vending")
          data = Uri.parse(uriString)
          putExtra("overlay", true)
          putExtra("callerId", context.packageName)
        }
      )
      return
    }
    // Health Connect is available, obtain a HealthConnectClient instance
    val healthConnectClient = HealthConnectClient.getOrCreate(context)
    // Issue operations with healthConnectClient
}
```

Depending on the status returned by `getSdkStatus()`, you can guide the user
to install or update Health Connect from the Google Play Store if necessary.

## Feature availability

To determine whether a user's device supports mindfulness session records on Health Connect, check the availability of `FEATURE_MINDFULNESS_SESSION` on the client:

<br />

    if (healthConnectClient
         .features
         .getFeatureStatus(
           HealthConnectFeatures.FEATURE_MINDFULNESS_SESSION
         ) == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE) {

      // Feature is available
    } else {
      // Feature isn't available
    }

See [Check for feature availability](https://developer.android.com/health-and-fitness/guides/health-connect/develop/feature-availability) to learn more.

## Required permissions

Access to mindfulness is protected by the following permissions:

- `android.permission.health.READ_MINDFULNESS`
- `android.permission.health.WRITE_MINDFULNESS`

To add mindfulness capability to your app, start by requesting
permissions for the `MindfulnessSession` data type.

Here's the permission you need to declare to be able to write
mindfulness:

    <application>
      <uses-permission
    android:name="android.permission.health.WRITE_MINDFULNESS" />
    ...
    </application>

To read mindfulness, you need to request the following permissions:

    <application>
      <uses-permission
    android:name="android.permission.health.READ_MINDFULNESS" />
    ...
    </application>

### Request permissions from the user

After creating a client instance, your app needs to request permissions from
the user. Users must be allowed to grant or deny permissions at any time.

To do so, create a set of permissions for the required data types.
Make sure that the permissions in the set are declared in your Android
manifest first.


```kotlin
val permissions =
    setOf(
        HealthPermission.getReadPermission(MindfulnessSessionRecord::class),
        HealthPermission.getWritePermission(MindfulnessSessionRecord::class)
    )
```
Use [`getGrantedPermissions`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/PermissionController#getGrantedPermissions()) to see if your app already has the required permissions granted. If not, use [`createRequestPermissionResultContract`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/PermissionController#createRequestPermissionResultContract(kotlin.String)) to request those permissions. This displays the Health Connect permissions screen.

```kotlin
val permissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getWritePermission(StepsRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getWritePermission(HeartRateRecord::class)
    )

val requestPermissionsLauncher = rememberLauncherForActivityResult(
    contract = PermissionController.createRequestPermissionResultContract()
) { grantedPermissions ->
    if (grantedPermissions.containsAll(permissions)) {
        coroutineScope.launch { snackbarHostState.showSnackbar("Permissions granted!") }
    } else {
        coroutineScope.launch { snackbarHostState.showSnackbar("Permissions denied.") }
    }
}
```
Because users can grant or revoke permissions at any time, your app needs to check for permissions every time before using them and handle scenarios where permission is lost.

<br />

## Information included in a mindfulness session record

Each mindfulness session record captures any type of mindfulness session
a user performs, for example meditation, breathing, and movement. The record
can also include additional notes about the session.


The following mindfulness session types are available for `MindfulnessSessionRecord`:

- `MINDFULNESS_SESSION_TYPE_UNKNOWN`
- `MINDFULNESS_SESSION_TYPE_MEDITATION`
- `MINDFULNESS_SESSION_TYPE_BREATHING`
- `MINDFULNESS_SESSION_TYPE_MUSIC`
- `MINDFULNESS_SESSION_TYPE_MOVEMENT`
- `MINDFULNESS_SESSION_TYPE_UNGUIDED`

<br />

For a full list of mindfulness session types, see the
[`MindfulnessSessionRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/MindfulnessSessionRecord)
reference documentation.

## Supported aggregations

<br />

The following aggregate values are available for
`MindfulnessSessionRecord`:

- [`MINDFULNESS_DURATION_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/MindfulnessSessionRecord#MINDFULNESS_DURATION_TOTAL())

<br />

## Write mindfulness session

The following code snippet demonstrates how to write a mindfulness session:


```kotlin
val isAvailable = healthConnectClient.features.getFeatureStatus(FEATURE_MINDFULNESS_SESSION)

if (isAvailable == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE) {

    val record = MindfulnessSessionRecord(
        startTime = Instant.now().minus(Duration.ofHours(1)),
        startZoneOffset = ZoneOffset.UTC,
        endTime = Instant.now(),
        endZoneOffset = ZoneOffset.UTC,
        mindfulnessSessionType = MindfulnessSessionRecord.MINDFULNESS_SESSION_TYPE_MEDITATION,
        title = "Lake meditation",
        notes = "Meditation by the lake",
        metadata = Metadata.activelyRecorded(
            clientRecordId = "myid",
            clientRecordVersion = 1L,
            device = Device(type = Device.TYPE_PHONE)
        )
    )
```

<br />

## Read mindfulness session

The following code snippet demonstrates how to read a mindfulness session
within a time range:

    Val now = Instant.now()

    val records = healthConnectClient.readRecords(
        ReadRecordsRequest(
            recordType = MindfulnessSessionRecord::class,
            timeRangeFilter = TimeRangeFilter.between(
                startTime = now.minus(Duration.ofHours(5)),
                endTime = now
            )
        )
    )

    // Process the returned records
    records.records.forEach { session ->
        println("Mindfulness session:")
        println("Start: ${session.startTime}")
        println("End: ${session.endTime}")
        println("Title: ${session.title}")
        println("Notes: ${session.notes}")
        println("Type: ${session.mindfulnessSessionType}")
    }

<br />

> [!NOTE]
> **Note:** This guide is compatible with Health Connect version [1.1.0-alpha12](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0-alpha12).

<br />

Health Connect provides a *planned exercise* data type to enable training apps
to write training plans and enable workout apps to read training plans. Recorded
exercises (workouts) can be read back for personalized performance analysis to
help users achieve their training goals.

## Check Health Connect availability

Before attempting to use Health Connect, your app should verify that Health Connect is available
on the user's device. Health Connect might not be pre-installed on all devices or could be disabled.
You can check for availability using the `https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#getSdkStatus(android.content.Context,kotlin.String)`
method.

#### How to check for Health Connect availability

```kotlin
fun checkHealthConnectAvailability(context: Context) {
    val providerPackageName = "com.google.android.apps.healthdata" // Or get from HealthConnectClient.DEFAULT_PROVIDER_PACKAGE_NAME
    val availabilityStatus = HealthConnectClient.getSdkStatus(context, providerPackageName)

    if (availabilityStatus == HealthConnectClient.SDK_UNAVAILABLE) {
      // Health Connect is not available. Guide the user to install/enable it.
      // For example, show a dialog.
      return // early return as there is no viable integration
    }
    if (availabilityStatus == HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED) {
      // Health Connect is available but requires an update.
      // Optionally redirect to package installer to find a provider, for example:
      val uriString = "market://details?id=$providerPackageName&url=healthconnect%3A%2F%2Fonboarding"
      context.startActivity(
        Intent(Intent.ACTION_VIEW).apply {
          setPackage("com.android.vending")
          data = Uri.parse(uriString)
          putExtra("overlay", true)
          putExtra("callerId", context.packageName)
        }
      )
      return
    }
    // Health Connect is available, obtain a HealthConnectClient instance
    val healthConnectClient = HealthConnectClient.getOrCreate(context)
    // Issue operations with healthConnectClient
}
```

Depending on the status returned by `getSdkStatus()`, you can guide the user
to install or update Health Connect from the Google Play Store if necessary.

## Feature availability

To determine whether a user's device supports training plans on Health Connect, check the availability of `FEATURE_PLANNED_EXERCISE` on the client:

<br />

    if (healthConnectClient
         .features
         .getFeatureStatus(
           HealthConnectFeatures.FEATURE_PLANNED_EXERCISE
         ) == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE) {

      // Feature is available
    } else {
      // Feature isn't available
    }

See [Check for feature availability](https://developer.android.com/health-and-fitness/guides/health-connect/develop/feature-availability) to learn more.

## Required permissions

Access to planned exercise is protected by the following permissions:

- `android.permission.health.READ_PLANNED_EXERCISE`
- `android.permission.health.WRITE_PLANNED_EXERCISE`

To add planned exercise capability to your app, start by requesting
permissions for the `PlannedExerciseSession` data type.

Here's the permission you need to declare to be able to write
planned exercise:

    <application>
      <uses-permission
    android:name="android.permission.health.WRITE_PLANNED_EXERCISE" />
    ...
    </application>

To read planned exercise, you need to request the following permissions:

    <application>
      <uses-permission
    android:name="android.permission.health.READ_PLANNED_EXERCISE" />
    ...
    </application>

### Request permissions from the user

After creating a client instance, your app needs to request permissions from
the user. Users must be allowed to grant or deny permissions at any time.

To do so, create a set of permissions for the required data types.
Make sure that the permissions in the set are declared in your Android
manifest first.


```kotlin
val permissions =
    setOf(
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getWritePermission(HeartRateRecord::class),
        HealthPermission.getReadPermission(PlannedExerciseSessionRecord::class),
        HealthPermission.getWritePermission(PlannedExerciseSessionRecord::class),
        HealthPermission.getReadPermission(ExerciseSessionRecord::class),
        HealthPermission.getWritePermission(ExerciseSessionRecord::class)
    )
```
Use [`getGrantedPermissions`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/PermissionController#getGrantedPermissions()) to see if your app already has the required permissions granted. If not, use [`createRequestPermissionResultContract`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/PermissionController#createRequestPermissionResultContract(kotlin.String)) to request those permissions. This displays the Health Connect permissions screen.

```kotlin
val permissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getWritePermission(StepsRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getWritePermission(HeartRateRecord::class)
    )

val requestPermissionsLauncher = rememberLauncherForActivityResult(
    contract = PermissionController.createRequestPermissionResultContract()
) { grantedPermissions ->
    if (grantedPermissions.containsAll(permissions)) {
        coroutineScope.launch { snackbarHostState.showSnackbar("Permissions granted!") }
    } else {
        coroutineScope.launch { snackbarHostState.showSnackbar("Permissions denied.") }
    }
}
```
Because users can grant or revoke permissions at any time, your app needs to check for permissions every time before using them and handle scenarios where permission is lost.

<br />

### Related permissions

Training plans are linked to *exercise sessions*. Therefore, the user must give
permission to use each record type related to a training plan in order to fully
utilize this feature of Health Connect.

For example, if a training plan measures a user's heart rate during a series
of runs, the following permissions might need to be declared by the developer
and granted by the user in order to write the exercise session and read the
results for later evaluation:

- `android.permission.health.READ_EXERCISE`
- `android.permission.health.READ_EXERCISE_ROUTES`
- `android.permission.health.READ_HEART_RATE`
- `android.permission.health.WRITE_EXERCISE`
- `android.permission.health.WRITE_EXERCISE_ROUTE`
- `android.permission.health.WRITE_HEART_RATE`

However, often the app that creates training plans and evaluates performance
against plans isn't the same as the app that consumes training plans and writes
actual exercise data. Depending on the type of app, not all read and write
permissions would be needed. For example, you may only need these permissions
for each type of app:

| Training plan app | Workout app |
|---|---|
| `WRITE_PLANNED_EXERCISE` | `READ_PLANNED_EXERCISE` |
| `READ_EXERCISE` | `WRITE_EXERCISE` |
| `READ_EXERCISE_ROUTES` | `WRITE_EXERCISE_ROUTE` |
| `READ_HEART_RATE` | `WRITE_HEART_RATE` |

> [!IMPORTANT]
> **Key Point:** Write permission also provides you read access to records you have written using that permission. It isn't always necessary to request both read and write permission for a data type.

## Information included in a planned exercise session record

- Title of the session.
- A list of [planned exercise blocks](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/PlannedExerciseBlock).
- Start and end time of the session.
- Exercise type.
- Notes for the activity.
- Metadata.
- Completed exercise session ID --- This is written automatically after an exercise session related to this planned exercise session is completed.

### Information included in a planned exercise block record

A planned exercise block contains a list of exercise steps, to support
repetition of different groups of steps (for example, do a sequence of arm
curls, burpies, and crunches five times in a row).

- Description of the block.
- A list of [planned exercise steps](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/PlannedExerciseStep).
- Number of repetitions.

### Information included in a planned exercise step record

- Description of the step.
- [Exercise category](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/PlannedExerciseStep#constants).
- [Exercise type](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSegment).
- A list of [performance targets](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExercisePerformanceTarget).
- [Completion goal](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseCompletionGoal).

## Supported aggregations


There are no supported aggregations for this data type.

<br />

## Example usage

Suppose a user plans a 90 minute run two days from now. This run will feature
three laps around a lake with a target heart rate between 90 and 110 bpm.

1. A planned exercise session with the following is defined by the user in a training plan app:
   1. Planned start and end of the run
   2. The type of exercise (running)
   3. Number of laps (repetitions)
   4. Performance target for heart rate (between 90 and 110 bpm)
2. This information is grouped into exercise blocks and steps and written to Health Connect by the training plan app as a `PlannedExerciseSessionRecord`.
3. The user performs the planned session (running).
4. Exercise data related to the session is recorded either:
   1. By a wearable during the session. For example, heart rate. This data is written to Health Connect as the record type for the activity. In this case, `HeartRateRecord`.
   2. Manually by the user after the session. For example, indicating the start and end of the actual run. This data is written to Health Connect as an `ExerciseSessionRecord`.
5. At a later time, the training plan app reads data from Health Connect to evaluate the actual performance against the targets set by the user in the planned exercise session.

### Plan exercises and set targets

A user may plan their exercise in the future and set targets. Write this to
Health Connect as a *planned exercise session*.

In the example described in [Example usage](https://developer.android.com/health-and-fitness/health-connect/features/training-plans#example-usage),
the user plans a 90 minute run two days from now. This run will feature three
laps around a lake with a target heart rate between 90 and 110 bpm.

A snippet like this may be found in the form handler for an app that logs
planned exercise sessions to Health Connect. It could also be found in the
ingest point for integrations, say with a service that offers training.


```kotlin
// Verify the user has granted all necessary permissions for this task
val grantedPermissions =
    healthConnectClient.permissionController.getGrantedPermissions()

if (!grantedPermissions.contains(
        HealthPermission.getWritePermission(PlannedExerciseSessionRecord::class))) {
    // The user hasn't granted the app permission to write planned exercise session data.
    Log.w("HealthConnect", "Write permission for PlannedExerciseSessionRecord not granted.")
    return
}

val plannedExerciseSessionRecord = PlannedExerciseSessionRecord(
    startTime = startTime,
    endTime = endTime,
    exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_RUNNING,
    blocks = listOf(
        PlannedExerciseBlock(
            repetitions = 1, steps = listOf(
                PlannedExerciseStep(
                    exerciseType = ExerciseSegment.EXERCISE_SEGMENT_TYPE_RUNNING,
                    exercisePhase = PlannedExerciseStep.EXERCISE_PHASE_ACTIVE,
                    completionGoal = ExerciseCompletionGoal.RepetitionsGoal(repetitions = 3),
                    performanceTargets = listOf(
                        ExercisePerformanceTarget.HeartRateTarget(
                            minHeartRate = 90.0, maxHeartRate = 110.0
                        )
                    )
                ),
            ), description = "Three laps around the lake"
        )
    ),
    title = "Run at lake",
    notes = null,
    metadata = Metadata.activelyRecorded(
        device = Device(type = Device.Companion.TYPE_PHONE),
    ),
    startZoneOffset = null,
    endZoneOffset = null,
)

try {
    // Attempt to insert the record
    val response = healthConnectClient.insertRecords(listOf(plannedExerciseSessionRecord))

    // If execution reaches here, the insert succeeded.
    // Safely extract the ID using firstOrNull()
    val insertedPlannedExerciseSessionId = response.recordIdsList.firstOrNull()

    if (insertedPlannedExerciseSessionId != null) {
        Log.d("HealthConnect", "Successfully inserted planned exercise session ID: $insertedPlannedExerciseSessionId")
    } else {
        Log.w("HealthConnect", "Insertion succeeded but no record IDs were returned.")
    }

} catch (e: Exception) {
    // Handle API failures, database errors, or system issues safely without crashing
    Log.e("HealthConnect", "Failed to insert planned exercise session record", e)
}
```

<br />

### Log exercise and activity data

Two days later, the user logs the actual exercise session. Write this to Health
Connect as an *exercise session*.

In this example, the user's session duration matched the planned duration
exactly.

The following snippet might be found in the form handler for an app that logs
exercise sessions to Health Connect. It might also be found in data ingest and
export handlers for a wearable capable of detecting and logging exercise
sessions.

`insertedPlannedExerciseSessionId` here is reused from the previous example. In
a real app, the ID would be determined by the user selecting a planned exercise
session from a list of existing sessions.


```kotlin
// Verify the user has granted all necessary permissions for this task
val grantedPermissions =
    healthConnectClient.permissionController.getGrantedPermissions()
if (!grantedPermissions.contains(
        HealthPermission.getWritePermission(ExerciseSessionRecord::class))) {
    // The user doesn't granted the app permission to write exercise session data.
    return
}

val sessionDuration = Duration.ofMinutes(90)
val sessionEndTime = Instant.now()
val sessionStartTime = sessionEndTime.minus(sessionDuration)

val exerciseSessionRecord = ExerciseSessionRecord(
    startTime = sessionStartTime,
    startZoneOffset = ZoneOffset.UTC,
    endTime = sessionEndTime,
    endZoneOffset = ZoneOffset.UTC,
    exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_RUNNING,
    segments = listOf(
        ExerciseSegment(
            startTime = sessionStartTime,
            endTime = sessionEndTime,
            repetitions = 3,
            segmentType = ExerciseSegment.EXERCISE_SEGMENT_TYPE_RUNNING
        )
    ),
    title = "Run at lake",
    plannedExerciseSessionId = insertedPlannedExerciseSessionId,
    metadata = Metadata.activelyRecorded(
        device = Device(type = Device.Companion.TYPE_PHONE)
    )
)
val insertedExerciseSessions =
    healthConnectClient.insertRecords(listOf(exerciseSessionRecord))
```

<br />

A wearable also logs their heart rate throughout the run. The following snippet
could be used to generate records within the target range.

In a real app, the primary pieces of this snippet might be found in the handler
for a message from a wearable, which would write measurement to Health Connect
upon collection.


```kotlin
// Verify the user has granted all necessary permissions for this task
val grantedPermissions =
    healthConnectClient.permissionController.getGrantedPermissions()
if (!grantedPermissions.contains(
        HealthPermission.getWritePermission(HeartRateRecord::class))) {
    // The user doesn't granted the app permission to write heart rate record data.
    return
}

val samples = mutableListOf<HeartRateRecord.Sample>()
var currentTime = sessionStartTime
while (currentTime.isBefore(sessionEndTime)) {
    val bpm = Random.nextInt(21) + 90
    val heartRateRecord = HeartRateRecord.Sample(
        time = currentTime,
        beatsPerMinute = bpm.toLong(),
    )
    samples.add(heartRateRecord)
    currentTime = currentTime.plusSeconds(180)
}

val heartRateRecord = HeartRateRecord(
    startTime = sessionStartTime,
    startZoneOffset = ZoneOffset.UTC,
    endTime = sessionEndTime,
    endZoneOffset = ZoneOffset.UTC,
    samples = samples,
    metadata = Metadata.activelyRecorded(
        device = Device(type = Device.Companion.TYPE_WATCH)
    )
)
val insertedHeartRateRecords = healthConnectClient.insertRecords(listOf(heartRateRecord))
```

<br />

### Evaluate performance targets

The day after the user's workout, you can retrieve the logged exercise, check
for any planned exercise targets, and evaluate additional data types to
determine if set targets were met.

A snippet like this would likely be found in a periodic job to evaluate
performance targets or when loading a list of exercises and displaying a
notification about performance targets in an app.


```kotlin
    // Verify the user has granted all necessary permissions for this task
    val grantedPermissions =
        healthConnectClient.permissionController.getGrantedPermissions()
    if (!grantedPermissions.containsAll(
            listOf(
                HealthPermission.getReadPermission(ExerciseSessionRecord::class),
                HealthPermission.getReadPermission(PlannedExerciseSessionRecord::class),
                HealthPermission.getReadPermission(HeartRateRecord::class)
            )
        )
    ) {
        // The user doesn't granted the app permission to read exercise session record data.
        return
    }

    val searchDuration = Duration.ofDays(1)
    val searchEndTime = Instant.now()
    val searchStartTime = searchEndTime.minus(searchDuration)

    val response = healthConnectClient.readRecords(
        ReadRecordsRequest<ExerciseSessionRecord>(
            timeRangeFilter = TimeRangeFilter.between(searchStartTime, searchEndTime)
        )
    )
    for (exerciseRecord in response.records) {
        val plannedExerciseRecordId = exerciseRecord.plannedExerciseSessionId
        val plannedExerciseRecord =
            if (plannedExerciseRecordId == null) null else healthConnectClient.readRecord(
                PlannedExerciseSessionRecord::class, plannedExerciseRecordId
            ).record
        if (plannedExerciseRecord != null) {
            val aggregateRequest = AggregateRequest(
                metrics = setOf(HeartRateRecord.BPM_AVG),
                timeRangeFilter = TimeRangeFilter.between(
                    exerciseRecord.startTime, exerciseRecord.endTime
                ),
            )
            val aggregationResult = healthConnectClient.aggregate(aggregateRequest)

            val maxBpm = aggregationResult[HeartRateRecord.BPM_MAX]
            val minBpm = aggregationResult[HeartRateRecord.BPM_MIN]
            if (maxBpm != null && minBpm != null) {
                plannedExerciseRecord.blocks.forEach { block ->
                    block.steps.forEach { step ->
                        step.performanceTargets.forEach { target ->
                            when (target) {
                                is ExercisePerformanceTarget.HeartRateTarget -> {
                                    val minTarget = target.minHeartRate
                                    val maxTarget = target.maxHeartRate
                                    if(
                                        minBpm >= minTarget && maxBpm <= maxTarget
                                    ) {
                                        // Success!
                                    }
                                }
                                // Handle more target types
                            }
                        }
                    }
                }
            }
        }
    }
}
```

<br />

## Exercise sessions

Exercise sessions can include anything from running to badminton.

### Write exercise sessions

This is how to build an insertion request that includes a session:

    suspend fun writeExerciseSession(healthConnectClient: HealthConnectClient) {
        healthConnectClient.insertRecords(
            listOf(
                ExerciseSessionRecord(
                    startTime = START_TIME,
                    startZoneOffset = START_ZONE_OFFSET,
                    endTime = END_TIME,
                    endZoneOffset = END_ZONE_OFFSET,
                    exerciseType = ExerciseSessionRecord.ExerciseType.RUNNING,
                    title = "My Run",
                    metadata = Metadata.manualEntry()
                ),
                // ... other records
            )
        )
    }

### Read an exercise session

Here's an example of how to read an exercise session:

    suspend fun readExerciseSessions(
        healthConnectClient: HealthConnectClient,
        startTime: Instant,
        endTime: Instant
    ) {
        val response =
            healthConnectClient.readRecords(
                ReadRecordsRequest(
                    ExerciseSessionRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
                )
            )
        for (exerciseRecord in response.records) {
            // Process each exercise record
            // Optionally pull in with other data sources of the same time range.
            val distanceRecord =
                healthConnectClient
                    .readRecords(
                        ReadRecordsRequest(
                            DistanceRecord::class,
                            timeRangeFilter =
                                TimeRangeFilter.between(
                                    exerciseRecord.startTime,
                                    exerciseRecord.endTime
                                )
                        )
                    )
                    .records
        }
    }

### Write subtype data

Sessions can also be comprised of optional subtype data, that enrich the
session with additional information.

For example, exercise sessions can include the `ExerciseSegment`, `ExerciseLap`
and `ExerciseRoute` classes:

    val segments = listOf(
      ExerciseSegment(
        startTime = Instant.parse("2022-01-02T10:10:10Z"),
        endTime = Instant.parse("2022-01-02T10:10:13Z"),
        segmentType = ActivitySegmentType.BENCH_PRESS,
        repetitions = 373
      )
    )

    val laps = listOf(
      ExerciseLap(
        startTime = Instant.parse("2022-01-02T10:10:10Z"),
        endTime = Instant.parse("2022-01-02T10:10:13Z"),
        length = 0.meters
      )
    )

    ExerciseSessionRecord(
      exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_CALISTHENICS,
        startTime = Instant.parse("2022-01-02T10:10:10Z"),
        endTime = Instant.parse("2022-01-02T10:10:13Z"),
      startZoneOffset = ZoneOffset.UTC,
      endZoneOffset = ZoneOffset.UTC,
      segments = segments,
      laps = laps,
      route = route,
      metadata = Metadata.manualEntry()
    )

> This guide is compatible with Health Connect version [1.1.0-alpha11](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0-alpha11).

Health Connect provides a *sleep session* data type, to store information about
a user's sleep, such as a nightly session or daytime nap.
The `SleepSessionRecord` data type is used to represent these sessions.

Sessions allow users to measure time-based performance over a period of time,
such as continuous heart rate or location data.

`SleepSessionRecord` sessions contain data that records sleep stages, such as
`AWAKE`, `SLEEPING` and `DEEP`.

**Subtype** data is data that "belongs" to a session and is only meaningful when
it's read with a parent session. For example, sleep stage.

**Associated data**, on the other hand, refers to data that is recorded
independently but falls within the time range of a session. For example, if a
user records Heart Rate during their sleep session, the Heart Rate data would
be associated data. Unlike subtype data which is part of the session record,
associated data consists of independent records, each with its own UUID.

## Check Health Connect availability

Before attempting to use Health Connect, your app should verify that Health Connect is available
on the user's device. Health Connect might not be pre-installed on all devices or could be disabled.
You can check for availability using the `https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#getSdkStatus(android.content.Context,kotlin.String)`
method.

#### How to check for Health Connect availability

```kotlin
fun checkHealthConnectAvailability(context: Context) {
    val providerPackageName = "com.google.android.apps.healthdata" // Or get from HealthConnectClient.DEFAULT_PROVIDER_PACKAGE_NAME
    val availabilityStatus = HealthConnectClient.getSdkStatus(context, providerPackageName)

    if (availabilityStatus == HealthConnectClient.SDK_UNAVAILABLE) {
      // Health Connect is not available. Guide the user to install/enable it.
      // For example, show a dialog.
      return // early return as there is no viable integration
    }
    if (availabilityStatus == HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED) {
      // Health Connect is available but requires an update.
      // Optionally redirect to package installer to find a provider, for example:
      val uriString = "market://details?id=$providerPackageName&url=healthconnect%3A%2F%2Fonboarding"
      context.startActivity(
        Intent(Intent.ACTION_VIEW).apply {
          setPackage("com.android.vending")
          data = Uri.parse(uriString)
          putExtra("overlay", true)
          putExtra("callerId", context.packageName)
        }
      )
      return
    }
    // Health Connect is available, obtain a HealthConnectClient instance
    val healthConnectClient = HealthConnectClient.getOrCreate(context)
    // Issue operations with healthConnectClient
}
```

Depending on the status returned by `getSdkStatus()`, you can guide the user
to install or update Health Connect from the Google Play Store if necessary.

## Feature availability

There is no feature availability flag for this data type.

## Required permissions

Access to sleep session is protected by the following permissions:

- `android.permission.health.READ_SLEEP`
- `android.permission.health.WRITE_SLEEP`

To add sleep session capability to your app, start by requesting
permissions for the `SleepSession` data type.

Here's the permission you need to declare to be able to write
sleep session:

    <application>
      <uses-permission
    android:name="android.permission.health.WRITE_SLEEP" />
    ...
    </application>

To read sleep session, you need to request the following permissions:

    <application>
      <uses-permission
    android:name="android.permission.health.READ_SLEEP" />
    ...
    </application>

### Request permissions from the user

After creating a client instance, your app needs to request permissions from
the user. Users must be allowed to grant or deny permissions at any time.

To do so, create a set of permissions for the required data types.
Make sure that the permissions in the set are declared in your Android
manifest first.


```kotlin
val permissions =
    setOf(
        HealthPermission.getReadPermission(SleepSessionRecord::class),
        HealthPermission.getWritePermission(SleepSessionRecord::class)
    )
```
Use [`getGrantedPermissions`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/PermissionController#getGrantedPermissions()) to see if your app already has the required permissions granted. If not, use [`createRequestPermissionResultContract`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/PermissionController#createRequestPermissionResultContract(kotlin.String)) to request those permissions. This displays the Health Connect permissions screen.

```kotlin
val permissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getWritePermission(StepsRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getWritePermission(HeartRateRecord::class)
    )

val requestPermissionsLauncher = rememberLauncherForActivityResult(
    contract = PermissionController.createRequestPermissionResultContract()
) { grantedPermissions ->
    if (grantedPermissions.containsAll(permissions)) {
        coroutineScope.launch { snackbarHostState.showSnackbar("Permissions granted!") }
    } else {
        coroutineScope.launch { snackbarHostState.showSnackbar("Permissions denied.") }
    }
}
```
Because users can grant or revoke permissions at any time, your app needs to check for permissions every time before using them and handle scenarios where permission is lost.

<br />

## Supported aggregations

<br />

The following aggregate values are available for
`SleepSessionRecord`:

- [`SLEEP_DURATION_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/SleepSessionRecord#SLEEP_DURATION_TOTAL())

<br />

## General guidance

Here are some best practice guidelines on how to work with sleep sessions in
Health Connect.

- Sessions should be used to add data from a specific sleep session, for sleep:


```kotlin
suspend fun writeSleepSession(healthConnectClient: HealthConnectClient) {
    healthConnectClient.insertRecords(
        listOf(
            SleepSessionRecord(
                startTime = Instant.parse("2022-05-10T23:00:00.000Z"),
                startZoneOffset = ZoneOffset.of("-08:00"),
                endTime = Instant.parse("2022-05-11T07:00:00.000Z"),
                endZoneOffset = ZoneOffset.of("-08:00"),
                title = "My Sleep",
                metadata = Metadata.activelyRecorded(device = Device(type = Device.TYPE_WATCH))
            ),
        )
    )
}
```

<br />

- Subtype data needs to be aligned in a session with sequential timestamps that don't overlap. Gaps are allowed, however.
- Subtype data doesn't contain a UUID, but associated data has distinct UUIDs.
- Sessions are useful if the user wants data to be associated with (and tracked as part of) a session, rather than recorded continuously.

## Sleep sessions

You can read or write sleep data in Health Connect. Sleep data is displayed as a
session, and can be divided into 8 distinct sleep stages:

- `UNKNOWN`: Unspecified or unknown if the user is sleeping.
- `AWAKE`: The user is awake within a sleep cycle, not during the day.
- `SLEEPING`: Generic or non-granular sleep description.
- `OUT_OF_BED`: The user gets out of bed in the middle of a sleep session.
- `AWAKE_IN_BED`: The user is awake in bed.
- `LIGHT`: The user is in a light sleep cycle.
- `DEEP`: The user is in a deep sleep cycle.
- `REM`: The user is in a REM sleep cycle.

These values represent the type of sleep a user experiences within a time range.
Writing sleep stages is optional, but recommended if available.

### Write sleep sessions

The `SleepSessionRecord` data type has two parts:

1. The overall session, spanning the entire duration of sleep.
2. Individual stages during the sleep session such as light sleep or deep sleep.

Here's how you insert a sleep session without stages:


```kotlin
val zoneRules = ZoneId.systemDefault().rules

// Calculate the specific offset for both start and end times
val startOffset = zoneRules.getOffset(startTime)
val endOffset = zoneRules.getOffset(endTime)

SleepSessionRecord(
    title = "weekend sleep",
    startTime = startTime,
    endTime = endTime,
    startZoneOffset = startOffset,
    endZoneOffset = endOffset,
    metadata = Metadata.activelyRecorded(device = Device(type = Device.TYPE_WATCH))
)
```

<br />

Here's how to add stages that cover the entire period of a sleep session:

    val stages = listOf(
        SleepSessionRecord.Stage(
            startTime = START_TIME,
            endTime = END_TIME,
            stage = SleepSessionRecord.STAGE_TYPE_SLEEPING,
        )
    )

    SleepSessionRecord(
            title = "weekend sleep",
            startTime = START_TIME,
            endTime = END_TIME,
            startZoneOffset = START_ZONE_OFFSET,
            endZoneOffset = END_ZONE_OFFSET,
            stages = stages,
    )

### Read a sleep session

For every sleep session returned, you should check whether sleep stage data is
also present:


```kotlin
val response =
    healthConnectClient.readRecords(
        ReadRecordsRequest(
            SleepSessionRecord::class,
            timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
        )
    )
for (sleepRecord in response.records) {
    // Retrieve relevant sleep stages from each sleep record
    val sleepStages = sleepRecord.stages
}
```

<br />

### Delete a sleep session

This is how to delete a session. For this example, we've used a sleep session:


```kotlin
val timeRangeFilter = TimeRangeFilter.between(sleepRecord.startTime, sleepRecord.endTime)
healthConnectClient.deleteRecords(SleepSessionRecord::class, timeRangeFilter)
```

<br />

> [!NOTE]
> **Note:** Deleting a session does not automatically delete data associated with that session.

Health Connect provides a *steps* data type for recording step counts using
the [`StepsRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/StepsRecord). Steps are a fundamental measurement in health
and fitness tracking.

<br />

> [!NOTE]
> **Note:** This guide is compatible with Health Connect version [1.1.0-alpha12](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0-alpha12).

<br />

## Read mobile steps

> [!WARNING]
> **Warning:** Starting with the Health Connect update in June 2026, on-device steps are attributed to a device-specific **Synthetic Package Name (SPN)** instead of the generic `"android"` package name. See [Attribution change for on-device steps](https://developer.android.com/health-and-fitness/health-connect/features/steps#attribution-change) for details.

With Android 14 (API level 34) and SDK Extension version 20 or higher,
Health Connect provides on-device step counting. If any app has been granted
the `READ_STEPS` permission, Health Connect starts capturing steps from the
Android-powered device, and users see steps data automatically added to
Health Connect **Steps** entries.

To check if on-device step counting is available, verify that the device is
running Android 14 (API level 34) and has at least SDK extension version 20:

    val isStepTrackingAvailable =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE &&
            SdkExtensions.getExtensionVersion(Build.VERSION_CODES.UPSIDE_DOWN_CAKE) >= 20

If your app reads aggregated step counts using
[`aggregate`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/aggregate/package-summary) and doesn't filter by `DataOrigin`, on-device
steps are automatically included in the total, and no changes are required for
the June 2026 update.

### Attribution change for on-device steps

Starting with the June 2026 update, steps tracked natively by Health
Connect are attributed to a **Synthetic Package Name (SPN)** , such as
`com.android.healthconnect.phone.jd5bdd37e1a8d3667a05d0abebfc4a89e`.

Previously, built-in steps were attributed to the package name `android`.
Historical step data recorded before June 2026 retains the `android` package
name.

SPNs are device-specific and scoped on a per-application basis to protect
user privacy:

- **Stable:** The SPN for the current device is stable for your application.
- **Application-Scoped:** Different applications on the same device see different SPNs for on-device step data.

#### Query for on-device steps

Because SPNs are scoped and device-specific, you **must not** hardcode SPN
values. Instead, use the `getCurrentDeviceDataSource()` API to retrieve the
SPN for the current device.

While on-device step counting requires SDK extension version 20 or higher,
the `getCurrentDeviceDataSource()` API is available on Android 14 (API level
34) with SDK extension version 11 or higher.

The `getCurrentDeviceDataSource()` API is not yet available in the Health
Connect Jetpack library. The following examples use the Android framework API
instead:

    import android.content.Context
    import android.health.connect.HealthConnectManager

    val healthConnectManager = context.getSystemService(HealthConnectManager::class.java)
    val deviceDataSource = healthConnectManager?.getCurrentDeviceDataSource()
    val currentDeviceSpn = deviceDataSource?.deviceDataOrigin?.packageName

If your app needs to read on-device steps, or if it displays step data
broken down by source application or device, you must query for records
where the `DataOrigin` is `android` **or** matches the device's SPN. If
your app shows attribution for step data, use [`metadata.device`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/metadata/Device)
to identify the source device for individual records. For on-device steps
identified by an SPN in aggregated data, you can use device metadata such as
`model` or `manufacturer` from `DeviceDataSource` for attribution, or use a
generic label like "Your phone" for on-device steps.

The following example shows how to read aggregated on-device step count data
by filtering for both `android` and the current device SPN:

    import android.content.Context
    import android.health.connect.HealthConnectManager
    import android.os.Build
    import android.os.ext.SdkExtensions
    import androidx.health.connect.client.HealthConnectClient
    import androidx.health.connect.client.records.StepsRecord
    import androidx.health.connect.client.records.metadata.DataOrigin
    import androidx.health.connect.client.request.AggregateRequest
    import androidx.health.connect.client.time.TimeRangeFilter
    import java.time.Instant

    suspend fun readDeviceStepsByTimeRange(
        healthConnectClient: HealthConnectClient,
        context: Context,
        startTime: Instant,
        endTime: Instant
    ) {
        // 1. Check if SDK Extension 11+ is available for getCurrentDeviceDataSource()
        val isDataSourceApiAvailable = Build.VERSION.SDK_INT >= Build.VERSION_CODES.U &&
                SdkExtensions.getExtensionVersion(Build.VERSION_CODES.U) >= 11

        try {
            val healthConnectManager = context.getSystemService(HealthConnectManager::class.java)

            // 2. Safely fetch the package name only if API is available and data exists
            val currentDeviceSpn = if (isDataSourceApiAvailable) {
                healthConnectManager?.getCurrentDeviceDataSource()?.deviceDataOrigin?.packageName
            } else {
                null
            }

            val dataOriginFilters = mutableSetOf(DataOrigin("android"))

            // 3. Explicit null-safety check using .let
            currentDeviceSpn?.let {
                dataOriginFilters.add(DataOrigin(it))
            }

            val response = healthConnectClient.aggregate(
                AggregateRequest(
                    metrics = setOf(StepsRecord.COUNT_TOTAL),
                    timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
                    dataOriginFilter = dataOriginFilters
                )
            )

            val stepCount = response[StepsRecord.COUNT_TOTAL]

        } catch (e: Exception) {
            // Now this catch block only handles actual runtime exceptions, 
            // rather than Errors from missing methods.
        }
    }

> [!NOTE]
> **Note:** If your app has significant users on Android 13 and lower, we recommend also maintaining or adding an integration with the local [Recording API](https://developer.android.com/health-and-fitness/recording-api).

### On-Device Step Counting

- **Sensor Usage** : Health Connect utilizes the [`TYPE_STEP_COUNTER`](https://developer.android.com/reference/android/hardware/Sensor#TYPE_STEP_COUNTER) sensor from `SensorManager`. This sensor is optimized for low power consumption, making it ideal for continuous background step tracking.
- **Data Granularity**: To conserve battery life, step data is typically batched and written to the Health Connect database no more frequently than once per minute.
- **Attribution** : Steps recorded by this feature before June 2026 are attributed to the `android` package name in the [`DataOrigin`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/metadata/DataOrigin). After this date, they are attributed to a device-specific SPN. See [Attribution change for on-device steps](https://developer.android.com/health-and-fitness/health-connect/features/steps#attribution-change).
- **Activation** : The on-device step counting mechanism is active only when at least one application on the device has been granted the `READ_STEPS` permission within Health Connect.

## Check Health Connect availability

Before attempting to use Health Connect, your app should verify that Health Connect is available
on the user's device. Health Connect might not be pre-installed on all devices or could be disabled.
You can check for availability using the `https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#getSdkStatus(android.content.Context,kotlin.String)`
method.

#### How to check for Health Connect availability

```kotlin
fun checkHealthConnectAvailability(context: Context) {
    val providerPackageName = "com.google.android.apps.healthdata" // Or get from HealthConnectClient.DEFAULT_PROVIDER_PACKAGE_NAME
    val availabilityStatus = HealthConnectClient.getSdkStatus(context, providerPackageName)

    if (availabilityStatus == HealthConnectClient.SDK_UNAVAILABLE) {
      // Health Connect is not available. Guide the user to install/enable it.
      // For example, show a dialog.
      return // early return as there is no viable integration
    }
    if (availabilityStatus == HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED) {
      // Health Connect is available but requires an update.
      // Optionally redirect to package installer to find a provider, for example:
      val uriString = "market://details?id=$providerPackageName&url=healthconnect%3A%2F%2Fonboarding"
      context.startActivity(
        Intent(Intent.ACTION_VIEW).apply {
          setPackage("com.android.vending")
          data = Uri.parse(uriString)
          putExtra("overlay", true)
          putExtra("callerId", context.packageName)
        }
      )
      return
    }
    // Health Connect is available, obtain a HealthConnectClient instance
    val healthConnectClient = HealthConnectClient.getOrCreate(context)
    // Issue operations with healthConnectClient
}
```

Depending on the status returned by `getSdkStatus()`, you can guide the user
to install or update Health Connect from the Google Play Store if necessary.

## Required permissions

Access to steps is protected by the following permissions:

- `android.permission.health.READ_STEPS`
- `android.permission.health.WRITE_STEPS`

To add steps capability to your app, start by requesting
permissions for the `Steps` data type.

Here's the permission you need to declare to be able to write
steps:

    <application>
      <uses-permission
    android:name="android.permission.health.WRITE_STEPS" />
    ...
    </application>

To read steps, you need to request the following permissions:

    <application>
      <uses-permission
    android:name="android.permission.health.READ_STEPS" />
    ...
    </application>

### Request permissions from the user

After creating a client instance, your app needs to request permissions from
the user. Users must be allowed to grant or deny permissions at any time.

To do so, create a set of permissions for the required data types.
Make sure that the permissions in the set are declared in your Android
manifest first.


```kotlin
val permissions =
    setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getWritePermission(StepsRecord::class)
    )
```
Use [`getGrantedPermissions`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/PermissionController#getGrantedPermissions()) to see if your app already has the required permissions granted. If not, use [`createRequestPermissionResultContract`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/PermissionController#createRequestPermissionResultContract(kotlin.String)) to request those permissions. This displays the Health Connect permissions screen.

```kotlin
val permissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getWritePermission(StepsRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getWritePermission(HeartRateRecord::class)
    )

val requestPermissionsLauncher = rememberLauncherForActivityResult(
    contract = PermissionController.createRequestPermissionResultContract()
) { grantedPermissions ->
    if (grantedPermissions.containsAll(permissions)) {
        coroutineScope.launch { snackbarHostState.showSnackbar("Permissions granted!") }
    } else {
        coroutineScope.launch { snackbarHostState.showSnackbar("Permissions denied.") }
    }
}
```
Because users can grant or revoke permissions at any time, your app needs to check for permissions every time before using them and handle scenarios where permission is lost.

<br />

## Information included in a Steps record

Each `StepsRecord` contains the following information:

- **`count`** : The number of steps taken in the time interval, as a `Long`.
- **`startTime`**: The start time of the measurement interval.
- **`endTime`**: The end time of the measurement interval.
- **`startZoneOffset`**: The zone offset for the start time.
- **`endZoneOffset`**: The zone offset for the end time.

## Supported aggregations

<br />

The following aggregate values are available for
`StepsRecord`:

- [`COUNT_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/StepsRecord#COUNT_TOTAL())

The following aggregate values are available for
`StepsCadenceRecord`:

- [`RATE_AVG`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/StepsCadenceRecord#RATE_AVG())
- [`RATE_MAX`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/StepsCadenceRecord#RATE_MAX())
- [`RATE_MIN`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/StepsCadenceRecord#RATE_MIN())

<br />

## Example usage

The following sections show how to read and write `StepsRecord` data.

### Write steps data

Your app can write step count data by inserting [`StepsRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/StepsRecord)
instances. The following example shows how to record 1000 steps taken by a user:


```kotlin
val zoneOffset = ZoneOffset.systemDefault().rules.getOffset(startTime)
val stepsRecord = StepsRecord(
    count = 120,
    startTime = startTime,
    endTime = endTime,
    startZoneOffset = zoneOffset,
    endZoneOffset = zoneOffset,
    metadata = Metadata.autoRecorded(
        device = Device(type = Device.TYPE_WATCH)
    )
)
healthConnectClient.insertRecords(listOf(stepsRecord))
```

<br />

### Read aggregate data

The most common way to read step data is to aggregate the total steps over a
time period. The following example shows how to read the total step count for a
user within a certain time range:


```kotlin
suspend fun readStepsAggregate(startTime: Instant, endTime: Instant): Long {
    val response = healthConnectClient.aggregate(
        AggregateRequest(
            metrics = setOf(StepsRecord.COUNT_TOTAL),
            timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
        )
    )
    return response[StepsRecord.COUNT_TOTAL] ?: 0L
}
```

<br />

### Read raw data

The following example shows how to read raw [`StepsRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/StepsRecord) data
between a start and end time:


```kotlin
val response = healthConnectClient.readRecords(
    ReadRecordsRequest(
        StepsRecord::class,
        timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
    )
)
response.records.forEach { record ->
    /* Process records */
}
```

<br />

<br />

> [!NOTE]
> **Note:** This guide is compatible with Health Connect version [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0).

<br />

If you're looking to build a workout experience in your app, you can use Health
Connect to do things like:

- Write exercise sessions
- Write workout routes
- Write workout metrics such as heart rate, speed, and distance
- Read workout data from other apps

This guide describes how to build these workout features, covering data types,
background execution, permissions, recommended workflows, and best practices.

## Overview: Building a Comprehensive Workout Tracker

You can build a comprehensive workout tracking experience using Health Connect
by following these core steps:

- Correctly implementing permissions based on Health Permissions.
- Recording sessions using [`ExerciseSessionRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord).
- Writing workout data consistently during the session.
- Managing background execution properly to verify continuous data capture.
- Reading session data for post-workout summaries and analysis.

This workflow enables interoperability with other Health Connect apps and
verifies user-controlled data access.

## Before you begin

Before implementing workout features:

- [Integrate Health Connect](https://developer.android.com/health-and-fitness/health-connect/get-started#step-1) using the appropriate dependency.
- [Create a `HealthConnectClient`](https://developer.android.com/health-and-fitness/health-connect/get-started#step-2) instance.
- Verify your app implements runtime [permission flows based on Health Permissions](https://developer.android.com/health-and-fitness/health-connect/get-started#declare-permissions).
- If your workflow uses GPS, set up location permission and a foreground service.

## Key concepts

Health Connect represents workout data using a few core components. An
`ExerciseSessionRecord` acts as the central record for a workout,
containing details like start or end times and exercise type. During a
session, various data types such as `HeartRateRecord` or `SpeedRecord` can
be recorded. For outdoor activities, `ExerciseRoute` stores GPS data, which
is linked to its corresponding session.

### Exercise sessions

`ExerciseSessionRecord` is the central record for workout data, representing a
single workout session. Each record stores:

- `startTime`
- `endTime`
- `exerciseType`
- Optional session metadata (title, notes)

An `ExerciseSessionRecord` can also contain exercise routes, laps, and
segments as part of its data. In addition, other data types such as
`HeartRateRecord` or `SpeedRecord` can be recorded during a session and
associated with it.

### Associated data types

Data associated with workout sessions is represented by individual record
types. Common types include:

- [`HeartRateRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord): Represents a series of heart rate measurements.
- [`SpeedRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/SpeedRecord): Represents a series of speed measurements.
- [`DistanceRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/DistanceRecord): Represents distance covered between readings.
- [`TotalCaloriesBurnedRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/TotalCaloriesBurnedRecord): Represents total calories burned between readings.
- [`ElevationGainedRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ElevationGainedRecord): Represents elevation gained between readings.
- [`StepsCadenceRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/StepsCadenceRecord): Represents steps cadence between readings.
- [`PowerRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/PowerRecord): Represents power output between readings, common in activities like cycling.

For a complete list of data types, see
[Health Connect data types](https://developer.android.com/health-and-fitness/health-connect/data-types).

### Exercise routes

You can associate a route with outdoor workouts using `ExerciseRoute`. Routes
consist of sequential `ExerciseRoute.Location` objects each containing:

- Latitude and longitude
- Optional altitude
- Optional bearing
- Accuracy information
- Timestamp

### Link session routes

An `ExerciseRoute` contains the sequential location data for an exercise
session. It isn't treated as an independent record in Health Connect. Instead,
you provide `ExerciseRoute` data when inserting or updating an
`ExerciseSessionRecord`.

## Development considerations

Workout tracking apps often need to run for extended periods, frequently
in the background when the screen is off. When building your workout
features, it's important to consider how to manage background execution
and request the necessary permissions for workout data.

### Background execution

Workout apps commonly run with the screen off. When in this state, you should
use:

- Foreground services for location and sensor sampling
- [`WorkManager`](https://developer.android.com/reference/androidx/work/WorkManager) for deferred write or syncing
- Batching strategies for regular record write

Maintain continuity by keeping session ID consistent across all writes.

### Permissions

Your app must request the relevant Health Connect permissions before reading or
writing workout data. Common permissions for workouts
include exercise sessions, exercise routes, and metrics like heart rate or
speed. This includes the following:

- **Exercise sessions:** Read and write permissions for `ExerciseSessionRecord`.
- **Exercise routes:** Read and write permissions for `ExerciseRoute`.
- **Heart rate:** Read and write permissions for `HeartRateRecord`.
- **Speed:** Read and write permissions for `SpeedRecord`.
- **Distance:** Read and write permissions for `DistanceRecord`.
- **Calories:** Read and write permissions for `TotalCaloriesBurnedRecord`.
- **Elevation Gained:** Read and write permissions for `ElevationGainedRecord`.
- **Steps Cadence:** Read and write permissions for `StepsCadenceRecord`.
- **Power:** Read and write permissions for `PowerRecord`.
- **Steps:** Read and write permissions for `StepsRecord`.

The following shows an example of how to request multiple permissions for a
workout session that includes route, heart rate, distance, calories, speed,
and steps data:

After creating a client instance, your app needs to request permissions from
the user. Users must be allowed to grant or deny permissions at any time.

To do so, create a set of permissions for the required data types.
Make sure that the permissions in the set are declared in your Android
manifest first.


```kotlin
val permissions =
    setOf(
        HealthPermission.getReadPermission(ExerciseSessionRecord::class),
        HealthPermission.getWritePermission(ExerciseSessionRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getWritePermission(HeartRateRecord::class),
        HealthPermission.getReadPermission(SpeedRecord::class),
        HealthPermission.getWritePermission(SpeedRecord::class),
        HealthPermission.getReadPermission(DistanceRecord::class),
        HealthPermission.getWritePermission(DistanceRecord::class),
        HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class),
        HealthPermission.getWritePermission(TotalCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getWritePermission(StepsRecord::class)
    )
```
Use [`getGrantedPermissions`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/PermissionController#getGrantedPermissions()) to see if your app already has the required permissions granted. If not, use [`createRequestPermissionResultContract`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/PermissionController#createRequestPermissionResultContract(kotlin.String)) to request those permissions. This displays the Health Connect permissions screen.

```kotlin
val permissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getWritePermission(StepsRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getWritePermission(HeartRateRecord::class)
    )

val requestPermissionsLauncher = rememberLauncherForActivityResult(
    contract = PermissionController.createRequestPermissionResultContract()
) { grantedPermissions ->
    if (grantedPermissions.containsAll(permissions)) {
        coroutineScope.launch { snackbarHostState.showSnackbar("Permissions granted!") }
    } else {
        coroutineScope.launch { snackbarHostState.showSnackbar("Permissions denied.") }
    }
}
```
Because users can grant or revoke permissions at any time, your app needs to check for permissions every time before using them and handle scenarios where permission is lost.

<br />

To request permissions, call the `checkPermissionsAndRun` function:


```kotlin
if (!granted.containsAll(permissions)) {
    // Check if required permissions are not granted, and return
    return emptySet()
}
// Permissions already granted; proceed with inserting or reading data
```

<br />

If you only need to request permissions for a single data type, such as heart
rate, include only that data type in your permissions set:

Access to heart rate is protected by the following permissions:

- `android.permission.health.READ_HEART_RATE`
- `android.permission.health.WRITE_HEART_RATE`

To add heart rate capability to your app, start by requesting
permissions for the `HeartRateRecord` data type.

Here's the permission you need to declare to be able to write
heart rate:

    <application>
      <uses-permission
    android:name="android.permission.health.WRITE_HEART_RATE" />
    ...
    </application>

To read heart rate, you need to request the following permissions:

    <application>
      <uses-permission
    android:name="android.permission.health.READ_HEART_RATE" />
    ...
    </application>

## Implement a workout session

This section describes the recommended workflow for recording workout data.

### Start the session

To create a new workout:

1. Generate a unique session ID: Verify this ID is stable. If your app process is killed and restarted, you must be able to resume using the same ID to prevent fragmented sessions.
2. Set a `metadata.clientRecordId` to prevent duplicates during sync retries.
3. Write an `ExerciseSessionRecord`: Include the start time.
4. Start collecting Data type and GPS data: Only start these after the session record is successfully initialized.

Example:


```kotlin
val sessionClientId = UUID.randomUUID().toString()
val zoneOffset = ZoneOffset.systemDefault().rules.getOffset(startTime)

val session =   ExerciseSessionRecord(
    startTime = startTime,
    startZoneOffset = zoneOffset,
    endTime = startTime.plusSeconds(3600),
    endZoneOffset = zoneOffset,
    exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_RUNNING,
    metadata = Metadata.activelyRecorded(clientRecordId = sessionClientId, device = Device(type = Device.TYPE_PHONE)),
)

healthConnectClient.insertRecords(listOf(session))
```

<br />

### Record exercise routes

To learn more about reading guidance see [Read raw data](https://developer.android.com/health-and-fitness/health-connect/read-data).

When recording an exercise route, you should batch your data. This means instead
of saving every single GPS point as it happens, you collect a group of points
and save them all at once in a single call.

This is important because every time your app reads or writes to Health Connect,
it uses a tiny bit of battery and processing power.

> [!NOTE]
> **Best Practice:** Data Integrity: Before batching, validate your GPS accuracy. Filter out points with high horizontal accuracy radius to verify a clean route. You can verify this logic using [Unit tests](https://developer.android.com/health-and-fitness/health-connect/test/unit-tests) to simulate "noisy" GPS data.

The following code shows how to record in batches:

    // 1. Create a list to hold your route locations
    val routeLocations = mutableListOf<ExerciseRoute.Location>()

    // 2. Add points to your list as the exercise happens
    routeLocations.add(
        ExerciseRoute.Location(
            time = Instant.now(),
            latitude = 37.7749,
            longitude = -122.4194
        )
    )

    // ... keep adding points over a period of time ...

    // 3. Save the whole list at once (Batching)
    val session = ExerciseSessionRecord(
        startTime = startTime,
        endTime = endTime,
        exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_RUNNING,
        // We pass the whole list here
        exerciseRoute = ExerciseRoute(routeLocations)
    )

    healthConnectClient.insertRecords(listOf(session))

### End a session

After stopping data collection:

- Update the record: Your app updates `ExerciseSessionRecord` with an `endTime`.
- Finalize data: Optionally compute summary values (like total distance or average pace) and write them as additional records.

> [!NOTE]
> **Best Practice:** Avoid Overlaps Before finalizing, verify that this session's **endTime** does not overlap with the **startTime** of any subsequent records. Overlapping sessions are a common cause of write failures. [See Troubleshooting](https://developer.android.com/health-and-fitness/health-connect/experiences/workouts#troubleshooting) for more.

    val finishedSession = session.copy(endTime = Instant.now())
    healthConnectClient.updateRecords(listOf(finishedSession))

## Reading workout data

Apps can read exercise sessions and their associated data to summarize activity,
provide health insights, or sync data with an external server. For example, you
can read an `ExerciseSessionRecord` and then query the `HeartRateRecord` or
`DistanceRecord` that occurred during that same time interval.

If you need to sync workout data with a backend server, or keep your app's
datastore up-to-date with Health Connect, use ChangeLogs. This lets you retrieve
a list of inserted, updated, or deleted records since a specific point in time,
which is more efficient than manually tracking changes or repeatedly reading all
data. For more information, see [Sync data with Health Connect](https://developer.android.com/health-and-fitness/health-connect/sync-data).

### Read sessions

To read exercise sessions, use a `ReadRecordsRequest` with
`ExerciseSessionRecord` as the type. You usually filter this by a specific time
range.

    suspend fun readExerciseSessions(
        healthConnectClient: HealthConnectClient,
        startTime: Instant,
        endTime: Instant
    ) {
        val response = healthConnectClient.readRecords(
            ReadRecordsRequest(
                recordType = ExerciseSessionRecord::class,
                timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
            )
        )

        for (exerciseRecord in response.records) {
            // Process each session
            val exerciseType = exerciseRecord.exerciseType
            val notes = exerciseRecord.notes
        }
    }

### Read routes

Although `ExerciseRoute` data is written as part of an exercise session, it
must be read separately. Use the `getExerciseRoute()` method with the session's
ID to read its route data:

    suspend fun readExerciseRoute(
        healthConnectClient: HealthConnectClient,
        exerciseSessionRecord: ExerciseSessionRecord
    ) {
        // Check if the session has a route
        val route = healthConnectClient.getExerciseRoute(
            exerciseSessionRecordId = exerciseSessionRecord.metadata.id
        )

        when (route) {
            is ExerciseRouteResponse.Success -> {
                val locations = route.exerciseRoute.locations
                for (location in locations) {
                    // Use latitude, longitude, and altitude
                }
            }
            is ExerciseRouteResponse.NoData -> {
                // Handle case where no route exists
            }
            is ExerciseRouteResponse.ConsentRequired -> {
                // Handle case where permissions are missing
            }
        }
    }

### Read data types

To read specific granular data (like heart rate) that occurred during a session,
use the session's `startTime` and `endTime` to filter the request for that data
type.

    suspend fun readHeartRateData(
        healthConnectClient: HealthConnectClient,
        exerciseSession: ExerciseSessionRecord
    ) {
        val response = healthConnectClient.readRecords(
            ReadRecordsRequest(
                recordType = HeartRateRecord::class,
                timeRangeFilter = TimeRangeFilter.between(
                    exerciseSession.startTime,
                    exerciseSession.endTime
                )
            )
        )

        for (heartRateRecord in response.records) {
            for (sample in heartRateRecord.samples) {
                val bpm = sample.beatsPerMinute
            }
        }
    }

## Best practices

Follow these guidelines to improve data reliability and user experience:

- **Write frequently during active tracking**: For active tracking, write data as it becomes available or at a maximum interval of 15 minutes.
- **Use WorkManager for background syncs** : Use [`WorkManager`](https://developer.android.com/reference/androidx/work/WorkManager) for deferred writes. Aim for a 15-minute interval to strike a balance between real-time data and battery efficiency.
- **Batch write requests**: Don't write every single sensor event individually. Chunk your requests. Health Connect handles up to 1000 records per write request.
- **Keep session IDs stable and unique**: Use consistent identifiers for your sessions. If a session is edited or updated, using the same ID prevents it from being treated as a new, separate session.
- **Use batching for both data types and route points** : To reduce Input/Output overhead and preserve battery life, group your data points into a single `insertRecords` call rather than writing each point individually.
- **Avoid writing duplicate data: Use Client IDs** : When creating records, set a `metadata.clientRecordId`. Health Connect uses this to identify unique records. If you attempt to write a record with a `clientRecordId` that already exists, Health Connect will ignore the duplicate or update the existing record rather than creating a new one. Setting a `metadata.clientRecordId` is the most effective way to prevent duplicates during sync retries or app reinstalls.  

  ```kotlin
  val record = StepsRecord(
      count = 100,
      startTime = startTime,
      endTime = endTime,
      startZoneOffset = ZoneOffset.UTC,
      endZoneOffset = ZoneOffset.UTC,
      metadata = Metadata(
          // Use a unique ID from your own database
          clientRecordId = "daily_steps_2023_10_27_user_123"
      )
  )
  ```
- **Check existing data**: Before syncing, query the time range to see if records from your app already exist.
- **Validate GPS accuracy** : Filter out low-accuracy GPS samples (For example, points with a high horizontal accuracy radius) before writing to the `ExerciseRoute` to verify the map looks clean and professional.
- **Ensure timestamps do not overlap**: Verify that a new session does not start before the previous one ends. Overlapping sessions can cause conflicts in fitness dashboards and summary calculations.
- **Provide clear rationales for permission** : Use the `Permission.createIntent` flow to explain why your app needs access to health data, for example: 'To monitor your blood pressure trends and provide insights.'
- **Support pause and resume**: Verify your app handles pauses correctly. When a user pauses, stop collecting route points and data types so that the average pace and duration remain accurate.
- **Test long-running sessions**: Monitor battery consumption during sessions lasting several hours to verify your batching interval and sensor usage don't drain the device.
- **Align timestamps with sensor rates**: Match your record timestamps to the actual frequency of your sensors to maintain data high-fidelity.

## Testing

To verify data correctness and a high-quality user experience, follow these
testing strategies and refer to the official [Test top use cases](https://developer.android.com/health-and-fitness/health-connect/test/test-cases)
documentation.

### Verification tools

- **[Health Connect Toolbox](https://developer.android.com/health-and-fitness/health-connect/test/health-connect-toolbox):** Use this companion app to manually inspect records, delete test data, and simulate changes to the database. It is the best way to verify that your records are being stored correctly.
- **[Unit testing with `FakeHealthConnectClient`](https://developer.android.com/health-and-fitness/health-connect/test/unit-tests):** Use the testing library to verify how your app handles edge cases, like permission revocation or API exceptions without needing a physical device.

### Quality checklist

**Confirm records in Health Connect:** Open the Health Connect app and navigate to Data and access to verify records appear with expected values. **Read data from other apps:** Test your app's ability to read sessions written by other apps to verify ecosystem compatibility. See [Reading workout data](https://developer.android.com/health-and-fitness/health-connect/experiences/workouts#reading-workout-data). **Verify route data on a map:** Render the coordinates from your `ExerciseRoute` using a map library to check for continuity and remove "zig-zag" artifacts from low-accuracy points. **Balance write frequency:** Monitor battery usage. Frequent writes provide high detail but increase drain.

## Typical architecture

A workout implementation commonly includes:

| Component | Manages |
|---|---|
| Session controller | Session state Timer Batching logic Data types controllers Location sampling |
| Repository layer (wraps Health Connect operations:) | Insert session Insert data types Inserts route points Read session summaries |
| UI Layer (Displays): | Duration Live data types Map preview Split calculations Live GPS Trace |

## Troubleshooting

<br />

| Symptom | Possible cause | Resolution |
|---|---|---|
| Route not associated with session | Session ID or time range mismatch. | Verify the `ExerciseRoute` is written with a time range that falls entirely within the `ExerciseSessionRecord` duration. Verify you are using consistent IDs if referencing the session later. See [Recording exercise routes](https://developer.android.com/health-and-fitness/health-connect/experiences/workouts#recording-exercise-routes). |
| Missing data types (for example, Heart Rate) | Missing write permissions or incorrect time filters. | Check that you have requested and the user has granted the specific data type permission. Verify your `ReadRecordsRequest` uses a `TimeRangeFilter` that matches the session. See [Permissions](https://developer.android.com/health-and-fitness/health-connect/experiences/workouts#permissions). |
| Session fails to write | Overlapping timestamps. | Health Connect may reject records that overlap with existing data from the same app. Validate that the `startTime` of a new session is after the `endTime` of the previous one. |
| No GPS data recorded | Foreground service was killed or inactive. | To collect data while the screen is off, you must use a [Foreground Service](https://developer.android.com/develop/background-work/services/fgs) with the `foregroundServiceType="health"` or location attribute. |
| Duplicate records appear | Missing `clientRecordId`. | Assign a unique `clientRecordId` in the `Metadata` of each record. This allows Health Connect to perform de-duplication if the same data is written twice during a sync retry. See [Best practices](https://developer.android.com/health-and-fitness/health-connect/experiences/workouts#best-practices). |

<br />

### Common debugging steps

<br />

|---|---|
| Check permission state. | Always call `getPermissionStatus()` before attempting a read or write operation. Users can revoke permissions in system settings at any time. |
| Verify execution mode. | If your app is not collecting data in the background, verify that you have declared the correct permissions in your `AndroidManifest.xml` file and that the user hasn't placed the app into "Battery Restricted" mode. |

<br />

# ExerciseSessionRecord

Artifact: [androidx.health.connect:connect-client](https://developer.android.com/jetpack/androidx/releases/health-connect) [View Source](https://cs.android.com/search?q=file:androidx/health/connect/client/records/ExerciseSessionRecord.kt+class:androidx.health.connect.client.records.ExerciseSessionRecord) Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

*** ** * ** ***

Kotlin \|[Java](https://developer.android.com/reference/androidx/health/connect/client/records/ExerciseSessionRecord "View this page in Java")


```
class ExerciseSessionRecord : Record
```

<br />

*** ** * ** ***

Captures any exercise a user does. This can be common fitness exercise like running or different sports.

Each record needs a start time and end time. Records don't need to be back-to-back or directly after each other, there can be gaps in between.

Example code demonstrate how to read exercise session:

```kotlin
import androidx.health.connect.client.readRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter

val response =
    healthConnectClient.readRecords(
        ReadRecordsRequest<ExerciseSessionRecord>(
            timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
        )
    )
for (exerciseRecord in response.records) {
    // Process each exercise record
    // Optionally pull in with other data sources of the same time range.
    val heartRateRecords =
        healthConnectClient
            .readRecords(
                ReadRecordsRequest<HeartRateRecord>(
                    timeRangeFilter =
                        TimeRangeFilter.between(
                            exerciseRecord.startTime,
                            exerciseRecord.endTime,
                        )
                )
            )
            .records
}
```

## Summary

| ### Constants |
|---|---|
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_BADMINTON() = 2` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_BASEBALL() = 4` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_BASKETBALL() = 5` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_BIKING() = 8` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_BIKING_STATIONARY() = 9` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_BOOT_CAMP() = 10` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_BOXING() = 11` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_CALISTHENICS() = 13` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_CRICKET() = 14` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_DANCING() = 16` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_ELLIPTICAL() = 25` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_EXERCISE_CLASS() = 26` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_FENCING() = 27` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_FOOTBALL_AMERICAN() = 28` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_FOOTBALL_AUSTRALIAN() = 29` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_FRISBEE_DISC() = 31` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_GOLF() = 32` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_GUIDED_BREATHING() = 33` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_GYMNASTICS() = 34` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_HANDBALL() = 35` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_HIGH_INTENSITY_INTERVAL_TRAINING() = 36` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_HIKING() = 37` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_ICE_HOCKEY() = 38` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_ICE_SKATING() = 39` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_MARTIAL_ARTS() = 44` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_OTHER_WORKOUT() = 0` Can be used to represent any generic workout that does not fall into a specific category. |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_PADDLING() = 46` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_PARAGLIDING() = 47` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_PILATES() = 48` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_RACQUETBALL() = 50` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_ROCK_CLIMBING() = 51` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_ROLLER_HOCKEY() = 52` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_ROWING() = 53` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_ROWING_MACHINE() = 54` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_RUGBY() = 55` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_RUNNING() = 56` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_RUNNING_TREADMILL() = 57` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_SAILING() = 58` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_SCUBA_DIVING() = 59` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_SKATING() = 60` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_SKIING() = 61` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_SNOWBOARDING() = 62` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_SNOWSHOEING() = 63` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_SOCCER() = 64` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_SOFTBALL() = 65` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_SQUASH() = 66` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_STAIR_CLIMBING() = 68` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_STAIR_CLIMBING_MACHINE() = 69` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_STRENGTH_TRAINING() = 70` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_STRETCHING() = 71` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_SURFING() = 72` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_SWIMMING_OPEN_WATER() = 73` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_SWIMMING_POOL() = 74` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_TABLE_TENNIS() = 75` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_TENNIS() = 76` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_VOLLEYBALL() = 78` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_WALKING() = 79` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_WATER_POLO() = 80` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_WEIGHTLIFTING() = 81` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_WHEELCHAIR() = 82` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_YOGA() = 83` |

| ### Public companion properties |
|---|---|
| `https://developer.android.com/reference/kotlin/androidx/health/connect/client/aggregate/AggregateMetric<https://developer.android.com/reference/java/time/Duration.html>` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_DURATION_TOTAL()` Metric identifier to retrieve the total exercise time from `https://developer.android.com/reference/kotlin/androidx/health/connect/client/aggregate/AggregationResult`. |

| ### Public constructors |
|---|
| `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#ExerciseSessionRecord(java.time.Instant,java.time.ZoneOffset,java.time.Instant,java.time.ZoneOffset,androidx.health.connect.client.records.metadata.Metadata,kotlin.Int,kotlin.String,kotlin.String,kotlin.collections.List,kotlin.collections.List,androidx.health.connect.client.records.ExerciseRoute,kotlin.String)( startTime: https://developer.android.com/reference/java/time/Instant.html, startZoneOffset: https://developer.android.com/reference/java/time/ZoneOffset.html?, endTime: https://developer.android.com/reference/java/time/Instant.html, endZoneOffset: https://developer.android.com/reference/java/time/ZoneOffset.html?, metadata: https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/metadata/Metadata, exerciseType: https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html, title: https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-string/index.html?, notes: https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-string/index.html?, segments: https://kotlinlang.org/api/core/kotlin-stdlib/kotlin.collections/-list/index.html<https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSegment>, laps: https://kotlinlang.org/api/core/kotlin-stdlib/kotlin.collections/-list/index.html<https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseLap>, exerciseRoute: https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseRoute?, plannedExerciseSessionId: https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-string/index.html? )` |

| ### Public functions |
|---|---|
| `open operator https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-boolean/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#equals(kotlin.Any)(other: https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-any/index.html?)` |
| `open https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#hashCode()()` |
| `open https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-string/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#toString()()` |

| ### Public properties |
|---|---|
| `open https://developer.android.com/reference/java/time/Instant.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#endTime()` End time of the record. |
| `open https://developer.android.com/reference/java/time/ZoneOffset.html?` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#endZoneOffset()` User experienced zone offset at `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/IntervalRecord#endTime()`, or null if unknown. |
| `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseRouteResult` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#exerciseRouteResult()` `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseRouteResult` of the session. |
| `https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#exerciseType()` Type of exercise (e.g. walking, swimming). |
| `https://kotlinlang.org/api/core/kotlin-stdlib/kotlin.collections/-list/index.html<https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseLap>` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#laps()` `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseLap`s of the session. |
| `open https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/metadata/Metadata` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#metadata()` Set of common metadata associated with the written record. |
| `https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-string/index.html?` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#notes()` Additional notes for the session. |
| `https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-string/index.html?` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#plannedExerciseSessionId()` |
| `https://kotlinlang.org/api/core/kotlin-stdlib/kotlin.collections/-list/index.html<https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSegment>` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#segments()` `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSegment`s of the session. |
| `open https://developer.android.com/reference/java/time/Instant.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#startTime()` Start time of the record. |
| `open https://developer.android.com/reference/java/time/ZoneOffset.html?` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#startZoneOffset()` User experienced zone offset at `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/IntervalRecord#startTime()`, or null if unknown. |
| `https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-string/index.html?` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#title()` Title of the session. |

## Constants

### EXERCISE_TYPE_BADMINTON

```
const val EXERCISE_TYPE_BADMINTON = 2: Int
```

### EXERCISE_TYPE_BASEBALL

```
const val EXERCISE_TYPE_BASEBALL = 4: Int
```

### EXERCISE_TYPE_BASKETBALL

```
const val EXERCISE_TYPE_BASKETBALL = 5: Int
```

### EXERCISE_TYPE_BIKING

```
const val EXERCISE_TYPE_BIKING = 8: Int
```

### EXERCISE_TYPE_BIKING_STATIONARY

```
const val EXERCISE_TYPE_BIKING_STATIONARY = 9: Int
```

### EXERCISE_TYPE_BOOT_CAMP

```
const val EXERCISE_TYPE_BOOT_CAMP = 10: Int
```

### EXERCISE_TYPE_BOXING

```
const val EXERCISE_TYPE_BOXING = 11: Int
```

### EXERCISE_TYPE_CALISTHENICS

```
const val EXERCISE_TYPE_CALISTHENICS = 13: Int
```

### EXERCISE_TYPE_CRICKET

```
const val EXERCISE_TYPE_CRICKET = 14: Int
```

### EXERCISE_TYPE_DANCING

```
const val EXERCISE_TYPE_DANCING = 16: Int
```

### EXERCISE_TYPE_ELLIPTICAL

```
const val EXERCISE_TYPE_ELLIPTICAL = 25: Int
```

### EXERCISE_TYPE_EXERCISE_CLASS

```
const val EXERCISE_TYPE_EXERCISE_CLASS = 26: Int
```

### EXERCISE_TYPE_FENCING

```
const val EXERCISE_TYPE_FENCING = 27: Int
```

### EXERCISE_TYPE_FOOTBALL_AMERICAN

```
const val EXERCISE_TYPE_FOOTBALL_AMERICAN = 28: Int
```

### EXERCISE_TYPE_FOOTBALL_AUSTRALIAN

```
const val EXERCISE_TYPE_FOOTBALL_AUSTRALIAN = 29: Int
```

### EXERCISE_TYPE_FRISBEE_DISC

```
const val EXERCISE_TYPE_FRISBEE_DISC = 31: Int
```

### EXERCISE_TYPE_GOLF

```
const val EXERCISE_TYPE_GOLF = 32: Int
```

### EXERCISE_TYPE_GUIDED_BREATHING

```
const val EXERCISE_TYPE_GUIDED_BREATHING = 33: Int
```

### EXERCISE_TYPE_GYMNASTICS

```
const val EXERCISE_TYPE_GYMNASTICS = 34: Int
```

### EXERCISE_TYPE_HANDBALL

```
const val EXERCISE_TYPE_HANDBALL = 35: Int
```

### EXERCISE_TYPE_HIGH_INTENSITY_INTERVAL_TRAINING

```
const val EXERCISE_TYPE_HIGH_INTENSITY_INTERVAL_TRAINING = 36: Int
```

### EXERCISE_TYPE_HIKING

```
const val EXERCISE_TYPE_HIKING = 37: Int
```

### EXERCISE_TYPE_ICE_HOCKEY

```
const val EXERCISE_TYPE_ICE_HOCKEY = 38: Int
```

### EXERCISE_TYPE_ICE_SKATING

```
const val EXERCISE_TYPE_ICE_SKATING = 39: Int
```

### EXERCISE_TYPE_MARTIAL_ARTS

```
const val EXERCISE_TYPE_MARTIAL_ARTS = 44: Int
```

### EXERCISE_TYPE_OTHER_WORKOUT

```
const val EXERCISE_TYPE_OTHER_WORKOUT = 0: Int
```

Can be used to represent any generic workout that does not fall into a specific category. Any unknown new value definition will also fall automatically into `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_OTHER_WORKOUT()`.

Next Id: 84.

### EXERCISE_TYPE_PADDLING

```
const val EXERCISE_TYPE_PADDLING = 46: Int
```

### EXERCISE_TYPE_PARAGLIDING

```
const val EXERCISE_TYPE_PARAGLIDING = 47: Int
```

### EXERCISE_TYPE_PILATES

```
const val EXERCISE_TYPE_PILATES = 48: Int
```

### EXERCISE_TYPE_RACQUETBALL

```
const val EXERCISE_TYPE_RACQUETBALL = 50: Int
```

### EXERCISE_TYPE_ROCK_CLIMBING

```
const val EXERCISE_TYPE_ROCK_CLIMBING = 51: Int
```

### EXERCISE_TYPE_ROLLER_HOCKEY

```
const val EXERCISE_TYPE_ROLLER_HOCKEY = 52: Int
```

### EXERCISE_TYPE_ROWING

```
const val EXERCISE_TYPE_ROWING = 53: Int
```

### EXERCISE_TYPE_ROWING_MACHINE

```
const val EXERCISE_TYPE_ROWING_MACHINE = 54: Int
```

### EXERCISE_TYPE_RUGBY

```
const val EXERCISE_TYPE_RUGBY = 55: Int
```

### EXERCISE_TYPE_RUNNING

```
const val EXERCISE_TYPE_RUNNING = 56: Int
```

### EXERCISE_TYPE_RUNNING_TREADMILL

```
const val EXERCISE_TYPE_RUNNING_TREADMILL = 57: Int
```

### EXERCISE_TYPE_SAILING

```
const val EXERCISE_TYPE_SAILING = 58: Int
```

### EXERCISE_TYPE_SCUBA_DIVING

```
const val EXERCISE_TYPE_SCUBA_DIVING = 59: Int
```

### EXERCISE_TYPE_SKATING

```
const val EXERCISE_TYPE_SKATING = 60: Int
```

### EXERCISE_TYPE_SKIING

```
const val EXERCISE_TYPE_SKIING = 61: Int
```

### EXERCISE_TYPE_SNOWBOARDING

```
const val EXERCISE_TYPE_SNOWBOARDING = 62: Int
```

### EXERCISE_TYPE_SNOWSHOEING

```
const val EXERCISE_TYPE_SNOWSHOEING = 63: Int
```

### EXERCISE_TYPE_SOCCER

```
const val EXERCISE_TYPE_SOCCER = 64: Int
```

### EXERCISE_TYPE_SOFTBALL

```
const val EXERCISE_TYPE_SOFTBALL = 65: Int
```

### EXERCISE_TYPE_SQUASH

```
const val EXERCISE_TYPE_SQUASH = 66: Int
```

### EXERCISE_TYPE_STAIR_CLIMBING

```
const val EXERCISE_TYPE_STAIR_CLIMBING = 68: Int
```

### EXERCISE_TYPE_STAIR_CLIMBING_MACHINE

```
const val EXERCISE_TYPE_STAIR_CLIMBING_MACHINE = 69: Int
```

### EXERCISE_TYPE_STRENGTH_TRAINING

```
const val EXERCISE_TYPE_STRENGTH_TRAINING = 70: Int
```

### EXERCISE_TYPE_STRETCHING

```
const val EXERCISE_TYPE_STRETCHING = 71: Int
```

### EXERCISE_TYPE_SURFING

```
const val EXERCISE_TYPE_SURFING = 72: Int
```

### EXERCISE_TYPE_SWIMMING_OPEN_WATER

```
const val EXERCISE_TYPE_SWIMMING_OPEN_WATER = 73: Int
```

### EXERCISE_TYPE_SWIMMING_POOL

```
const val EXERCISE_TYPE_SWIMMING_POOL = 74: Int
```

### EXERCISE_TYPE_TABLE_TENNIS

```
const val EXERCISE_TYPE_TABLE_TENNIS = 75: Int
```

### EXERCISE_TYPE_TENNIS

```
const val EXERCISE_TYPE_TENNIS = 76: Int
```

### EXERCISE_TYPE_VOLLEYBALL

```
const val EXERCISE_TYPE_VOLLEYBALL = 78: Int
```

### EXERCISE_TYPE_WALKING

```
const val EXERCISE_TYPE_WALKING = 79: Int
```

### EXERCISE_TYPE_WATER_POLO

```
const val EXERCISE_TYPE_WATER_POLO = 80: Int
```

### EXERCISE_TYPE_WEIGHTLIFTING

```
const val EXERCISE_TYPE_WEIGHTLIFTING = 81: Int
```

### EXERCISE_TYPE_WHEELCHAIR

```
const val EXERCISE_TYPE_WHEELCHAIR = 82: Int
```

### EXERCISE_TYPE_YOGA

```
const val EXERCISE_TYPE_YOGA = 83: Int
```

## Public companion properties

### EXERCISE_DURATION_TOTAL

```
val EXERCISE_DURATION_TOTAL: AggregateMetric<Duration>
```

Metric identifier to retrieve the total exercise time from `https://developer.android.com/reference/kotlin/androidx/health/connect/client/aggregate/AggregationResult`.

## Public constructors

### ExerciseSessionRecord

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
ExerciseSessionRecord(
    startTime: Instant,
    startZoneOffset: ZoneOffset?,
    endTime: Instant,
    endZoneOffset: ZoneOffset?,
    metadata: Metadata,
    exerciseType: Int,
    title: String? = null,
    notes: String? = null,
    segments: List<ExerciseSegment> = emptyList(),
    laps: List<ExerciseLap> = emptyList(),
    exerciseRoute: ExerciseRoute? = null,
    plannedExerciseSessionId: String? = null
)
```

## Public functions

### equals

```
open operator fun equals(other: Any?): Boolean
```

### hashCode

```
open fun hashCode(): Int
```

### toString

```
open fun toString(): String
```

## Public properties

### endTime

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
open val endTime: Instant
```

End time of the record.

### endZoneOffset

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
open val endZoneOffset: ZoneOffset?
```

User experienced zone offset at `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/IntervalRecord#endTime()`, or null if unknown. Providing these will help history aggregations results stay consistent should user travel. Queries with user experienced time filters will assume system current zone offset if the information is absent.

### exerciseRouteResult

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
val exerciseRouteResult: ExerciseRouteResult
```

`https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseRouteResult` of the session. Location data points of `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseRoute` should be within the parent session, and should be before the end time of the session.

### exerciseType

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
val exerciseType: Int
```

Type of exercise (e.g. walking, swimming). Required field.

### laps

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
val laps: List<ExerciseLap>
```

`https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseLap`s of the session. Optional field. Time in laps should be within the parent session, and should not overlap with each other.

### metadata

```
open val metadata: Metadata
```

Set of common metadata associated with the written record.

### notes

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
val notes: String?
```

Additional notes for the session. Optional field.

### plannedExerciseSessionId

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
val plannedExerciseSessionId: String?
```

### segments

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
val segments: List<ExerciseSegment>
```

`https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSegment`s of the session. Optional field. Time in segments should be within the parent session, and should not overlap with each other.

### startTime

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
open val startTime: Instant
```

Start time of the record.

### startZoneOffset

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
open val startZoneOffset: ZoneOffset?
```

User experienced zone offset at `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/IntervalRecord#startTime()`, or null if unknown. Providing these will help history aggregations results stay consistent should user travel. Queries with user experienced time filters will assume system current zone offset if the information is absent.

### title

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
val title: String?
```

Title of the session. Optional field.

# ExerciseSessionRecord

Artifact: [androidx.health.connect:connect-client](https://developer.android.com/jetpack/androidx/releases/health-connect) [View Source](https://cs.android.com/search?q=file:androidx/health/connect/client/records/ExerciseSessionRecord.kt+class:androidx.health.connect.client.records.ExerciseSessionRecord) Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

*** ** * ** ***

Kotlin \|[Java](https://developer.android.com/reference/androidx/health/connect/client/records/ExerciseSessionRecord "View this page in Java")


```
class ExerciseSessionRecord : Record
```

<br />

*** ** * ** ***

Captures any exercise a user does. This can be common fitness exercise like running or different sports.

Each record needs a start time and end time. Records don't need to be back-to-back or directly after each other, there can be gaps in between.

Example code demonstrate how to read exercise session:

```kotlin
import androidx.health.connect.client.readRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter

val response =
    healthConnectClient.readRecords(
        ReadRecordsRequest<ExerciseSessionRecord>(
            timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
        )
    )
for (exerciseRecord in response.records) {
    // Process each exercise record
    // Optionally pull in with other data sources of the same time range.
    val heartRateRecords =
        healthConnectClient
            .readRecords(
                ReadRecordsRequest<HeartRateRecord>(
                    timeRangeFilter =
                        TimeRangeFilter.between(
                            exerciseRecord.startTime,
                            exerciseRecord.endTime,
                        )
                )
            )
            .records
}
```

## Summary

| ### Constants |
|---|---|
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_BADMINTON() = 2` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_BASEBALL() = 4` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_BASKETBALL() = 5` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_BIKING() = 8` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_BIKING_STATIONARY() = 9` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_BOOT_CAMP() = 10` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_BOXING() = 11` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_CALISTHENICS() = 13` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_CRICKET() = 14` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_DANCING() = 16` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_ELLIPTICAL() = 25` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_EXERCISE_CLASS() = 26` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_FENCING() = 27` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_FOOTBALL_AMERICAN() = 28` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_FOOTBALL_AUSTRALIAN() = 29` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_FRISBEE_DISC() = 31` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_GOLF() = 32` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_GUIDED_BREATHING() = 33` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_GYMNASTICS() = 34` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_HANDBALL() = 35` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_HIGH_INTENSITY_INTERVAL_TRAINING() = 36` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_HIKING() = 37` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_ICE_HOCKEY() = 38` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_ICE_SKATING() = 39` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_MARTIAL_ARTS() = 44` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_OTHER_WORKOUT() = 0` Can be used to represent any generic workout that does not fall into a specific category. |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_PADDLING() = 46` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_PARAGLIDING() = 47` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_PILATES() = 48` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_RACQUETBALL() = 50` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_ROCK_CLIMBING() = 51` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_ROLLER_HOCKEY() = 52` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_ROWING() = 53` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_ROWING_MACHINE() = 54` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_RUGBY() = 55` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_RUNNING() = 56` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_RUNNING_TREADMILL() = 57` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_SAILING() = 58` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_SCUBA_DIVING() = 59` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_SKATING() = 60` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_SKIING() = 61` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_SNOWBOARDING() = 62` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_SNOWSHOEING() = 63` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_SOCCER() = 64` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_SOFTBALL() = 65` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_SQUASH() = 66` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_STAIR_CLIMBING() = 68` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_STAIR_CLIMBING_MACHINE() = 69` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_STRENGTH_TRAINING() = 70` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_STRETCHING() = 71` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_SURFING() = 72` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_SWIMMING_OPEN_WATER() = 73` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_SWIMMING_POOL() = 74` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_TABLE_TENNIS() = 75` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_TENNIS() = 76` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_VOLLEYBALL() = 78` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_WALKING() = 79` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_WATER_POLO() = 80` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_WEIGHTLIFTING() = 81` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_WHEELCHAIR() = 82` |
| `const https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_YOGA() = 83` |

| ### Public companion properties |
|---|---|
| `https://developer.android.com/reference/kotlin/androidx/health/connect/client/aggregate/AggregateMetric<https://developer.android.com/reference/java/time/Duration.html>` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_DURATION_TOTAL()` Metric identifier to retrieve the total exercise time from `https://developer.android.com/reference/kotlin/androidx/health/connect/client/aggregate/AggregationResult`. |

| ### Public constructors |
|---|
| `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#ExerciseSessionRecord(java.time.Instant,java.time.ZoneOffset,java.time.Instant,java.time.ZoneOffset,androidx.health.connect.client.records.metadata.Metadata,kotlin.Int,kotlin.String,kotlin.String,kotlin.collections.List,kotlin.collections.List,androidx.health.connect.client.records.ExerciseRoute,kotlin.String)( startTime: https://developer.android.com/reference/java/time/Instant.html, startZoneOffset: https://developer.android.com/reference/java/time/ZoneOffset.html?, endTime: https://developer.android.com/reference/java/time/Instant.html, endZoneOffset: https://developer.android.com/reference/java/time/ZoneOffset.html?, metadata: https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/metadata/Metadata, exerciseType: https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html, title: https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-string/index.html?, notes: https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-string/index.html?, segments: https://kotlinlang.org/api/core/kotlin-stdlib/kotlin.collections/-list/index.html<https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSegment>, laps: https://kotlinlang.org/api/core/kotlin-stdlib/kotlin.collections/-list/index.html<https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseLap>, exerciseRoute: https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseRoute?, plannedExerciseSessionId: https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-string/index.html? )` |

| ### Public functions |
|---|---|
| `open operator https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-boolean/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#equals(kotlin.Any)(other: https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-any/index.html?)` |
| `open https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#hashCode()()` |
| `open https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-string/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#toString()()` |

| ### Public properties |
|---|---|
| `open https://developer.android.com/reference/java/time/Instant.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#endTime()` End time of the record. |
| `open https://developer.android.com/reference/java/time/ZoneOffset.html?` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#endZoneOffset()` User experienced zone offset at `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/IntervalRecord#endTime()`, or null if unknown. |
| `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseRouteResult` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#exerciseRouteResult()` `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseRouteResult` of the session. |
| `https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#exerciseType()` Type of exercise (e.g. walking, swimming). |
| `https://kotlinlang.org/api/core/kotlin-stdlib/kotlin.collections/-list/index.html<https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseLap>` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#laps()` `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseLap`s of the session. |
| `open https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/metadata/Metadata` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#metadata()` Set of common metadata associated with the written record. |
| `https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-string/index.html?` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#notes()` Additional notes for the session. |
| `https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-string/index.html?` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#plannedExerciseSessionId()` |
| `https://kotlinlang.org/api/core/kotlin-stdlib/kotlin.collections/-list/index.html<https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSegment>` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#segments()` `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSegment`s of the session. |
| `open https://developer.android.com/reference/java/time/Instant.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#startTime()` Start time of the record. |
| `open https://developer.android.com/reference/java/time/ZoneOffset.html?` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#startZoneOffset()` User experienced zone offset at `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/IntervalRecord#startTime()`, or null if unknown. |
| `https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-string/index.html?` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#title()` Title of the session. |

## Constants

### EXERCISE_TYPE_BADMINTON

```
const val EXERCISE_TYPE_BADMINTON = 2: Int
```

### EXERCISE_TYPE_BASEBALL

```
const val EXERCISE_TYPE_BASEBALL = 4: Int
```

### EXERCISE_TYPE_BASKETBALL

```
const val EXERCISE_TYPE_BASKETBALL = 5: Int
```

### EXERCISE_TYPE_BIKING

```
const val EXERCISE_TYPE_BIKING = 8: Int
```

### EXERCISE_TYPE_BIKING_STATIONARY

```
const val EXERCISE_TYPE_BIKING_STATIONARY = 9: Int
```

### EXERCISE_TYPE_BOOT_CAMP

```
const val EXERCISE_TYPE_BOOT_CAMP = 10: Int
```

### EXERCISE_TYPE_BOXING

```
const val EXERCISE_TYPE_BOXING = 11: Int
```

### EXERCISE_TYPE_CALISTHENICS

```
const val EXERCISE_TYPE_CALISTHENICS = 13: Int
```

### EXERCISE_TYPE_CRICKET

```
const val EXERCISE_TYPE_CRICKET = 14: Int
```

### EXERCISE_TYPE_DANCING

```
const val EXERCISE_TYPE_DANCING = 16: Int
```

### EXERCISE_TYPE_ELLIPTICAL

```
const val EXERCISE_TYPE_ELLIPTICAL = 25: Int
```

### EXERCISE_TYPE_EXERCISE_CLASS

```
const val EXERCISE_TYPE_EXERCISE_CLASS = 26: Int
```

### EXERCISE_TYPE_FENCING

```
const val EXERCISE_TYPE_FENCING = 27: Int
```

### EXERCISE_TYPE_FOOTBALL_AMERICAN

```
const val EXERCISE_TYPE_FOOTBALL_AMERICAN = 28: Int
```

### EXERCISE_TYPE_FOOTBALL_AUSTRALIAN

```
const val EXERCISE_TYPE_FOOTBALL_AUSTRALIAN = 29: Int
```

### EXERCISE_TYPE_FRISBEE_DISC

```
const val EXERCISE_TYPE_FRISBEE_DISC = 31: Int
```

### EXERCISE_TYPE_GOLF

```
const val EXERCISE_TYPE_GOLF = 32: Int
```

### EXERCISE_TYPE_GUIDED_BREATHING

```
const val EXERCISE_TYPE_GUIDED_BREATHING = 33: Int
```

### EXERCISE_TYPE_GYMNASTICS

```
const val EXERCISE_TYPE_GYMNASTICS = 34: Int
```

### EXERCISE_TYPE_HANDBALL

```
const val EXERCISE_TYPE_HANDBALL = 35: Int
```

### EXERCISE_TYPE_HIGH_INTENSITY_INTERVAL_TRAINING

```
const val EXERCISE_TYPE_HIGH_INTENSITY_INTERVAL_TRAINING = 36: Int
```

### EXERCISE_TYPE_HIKING

```
const val EXERCISE_TYPE_HIKING = 37: Int
```

### EXERCISE_TYPE_ICE_HOCKEY

```
const val EXERCISE_TYPE_ICE_HOCKEY = 38: Int
```

### EXERCISE_TYPE_ICE_SKATING

```
const val EXERCISE_TYPE_ICE_SKATING = 39: Int
```

### EXERCISE_TYPE_MARTIAL_ARTS

```
const val EXERCISE_TYPE_MARTIAL_ARTS = 44: Int
```

### EXERCISE_TYPE_OTHER_WORKOUT

```
const val EXERCISE_TYPE_OTHER_WORKOUT = 0: Int
```

Can be used to represent any generic workout that does not fall into a specific category. Any unknown new value definition will also fall automatically into `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord#EXERCISE_TYPE_OTHER_WORKOUT()`.

Next Id: 84.

### EXERCISE_TYPE_PADDLING

```
const val EXERCISE_TYPE_PADDLING = 46: Int
```

### EXERCISE_TYPE_PARAGLIDING

```
const val EXERCISE_TYPE_PARAGLIDING = 47: Int
```

### EXERCISE_TYPE_PILATES

```
const val EXERCISE_TYPE_PILATES = 48: Int
```

### EXERCISE_TYPE_RACQUETBALL

```
const val EXERCISE_TYPE_RACQUETBALL = 50: Int
```

### EXERCISE_TYPE_ROCK_CLIMBING

```
const val EXERCISE_TYPE_ROCK_CLIMBING = 51: Int
```

### EXERCISE_TYPE_ROLLER_HOCKEY

```
const val EXERCISE_TYPE_ROLLER_HOCKEY = 52: Int
```

### EXERCISE_TYPE_ROWING

```
const val EXERCISE_TYPE_ROWING = 53: Int
```

### EXERCISE_TYPE_ROWING_MACHINE

```
const val EXERCISE_TYPE_ROWING_MACHINE = 54: Int
```

### EXERCISE_TYPE_RUGBY

```
const val EXERCISE_TYPE_RUGBY = 55: Int
```

### EXERCISE_TYPE_RUNNING

```
const val EXERCISE_TYPE_RUNNING = 56: Int
```

### EXERCISE_TYPE_RUNNING_TREADMILL

```
const val EXERCISE_TYPE_RUNNING_TREADMILL = 57: Int
```

### EXERCISE_TYPE_SAILING

```
const val EXERCISE_TYPE_SAILING = 58: Int
```

### EXERCISE_TYPE_SCUBA_DIVING

```
const val EXERCISE_TYPE_SCUBA_DIVING = 59: Int
```

### EXERCISE_TYPE_SKATING

```
const val EXERCISE_TYPE_SKATING = 60: Int
```

### EXERCISE_TYPE_SKIING

```
const val EXERCISE_TYPE_SKIING = 61: Int
```

### EXERCISE_TYPE_SNOWBOARDING

```
const val EXERCISE_TYPE_SNOWBOARDING = 62: Int
```

### EXERCISE_TYPE_SNOWSHOEING

```
const val EXERCISE_TYPE_SNOWSHOEING = 63: Int
```

### EXERCISE_TYPE_SOCCER

```
const val EXERCISE_TYPE_SOCCER = 64: Int
```

### EXERCISE_TYPE_SOFTBALL

```
const val EXERCISE_TYPE_SOFTBALL = 65: Int
```

### EXERCISE_TYPE_SQUASH

```
const val EXERCISE_TYPE_SQUASH = 66: Int
```

### EXERCISE_TYPE_STAIR_CLIMBING

```
const val EXERCISE_TYPE_STAIR_CLIMBING = 68: Int
```

### EXERCISE_TYPE_STAIR_CLIMBING_MACHINE

```
const val EXERCISE_TYPE_STAIR_CLIMBING_MACHINE = 69: Int
```

### EXERCISE_TYPE_STRENGTH_TRAINING

```
const val EXERCISE_TYPE_STRENGTH_TRAINING = 70: Int
```

### EXERCISE_TYPE_STRETCHING

```
const val EXERCISE_TYPE_STRETCHING = 71: Int
```

### EXERCISE_TYPE_SURFING

```
const val EXERCISE_TYPE_SURFING = 72: Int
```

### EXERCISE_TYPE_SWIMMING_OPEN_WATER

```
const val EXERCISE_TYPE_SWIMMING_OPEN_WATER = 73: Int
```

### EXERCISE_TYPE_SWIMMING_POOL

```
const val EXERCISE_TYPE_SWIMMING_POOL = 74: Int
```

### EXERCISE_TYPE_TABLE_TENNIS

```
const val EXERCISE_TYPE_TABLE_TENNIS = 75: Int
```

### EXERCISE_TYPE_TENNIS

```
const val EXERCISE_TYPE_TENNIS = 76: Int
```

### EXERCISE_TYPE_VOLLEYBALL

```
const val EXERCISE_TYPE_VOLLEYBALL = 78: Int
```

### EXERCISE_TYPE_WALKING

```
const val EXERCISE_TYPE_WALKING = 79: Int
```

### EXERCISE_TYPE_WATER_POLO

```
const val EXERCISE_TYPE_WATER_POLO = 80: Int
```

### EXERCISE_TYPE_WEIGHTLIFTING

```
const val EXERCISE_TYPE_WEIGHTLIFTING = 81: Int
```

### EXERCISE_TYPE_WHEELCHAIR

```
const val EXERCISE_TYPE_WHEELCHAIR = 82: Int
```

### EXERCISE_TYPE_YOGA

```
const val EXERCISE_TYPE_YOGA = 83: Int
```

## Public companion properties

### EXERCISE_DURATION_TOTAL

```
val EXERCISE_DURATION_TOTAL: AggregateMetric<Duration>
```

Metric identifier to retrieve the total exercise time from `https://developer.android.com/reference/kotlin/androidx/health/connect/client/aggregate/AggregationResult`.

## Public constructors

### ExerciseSessionRecord

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
ExerciseSessionRecord(
    startTime: Instant,
    startZoneOffset: ZoneOffset?,
    endTime: Instant,
    endZoneOffset: ZoneOffset?,
    metadata: Metadata,
    exerciseType: Int,
    title: String? = null,
    notes: String? = null,
    segments: List<ExerciseSegment> = emptyList(),
    laps: List<ExerciseLap> = emptyList(),
    exerciseRoute: ExerciseRoute? = null,
    plannedExerciseSessionId: String? = null
)
```

## Public functions

### equals

```
open operator fun equals(other: Any?): Boolean
```

### hashCode

```
open fun hashCode(): Int
```

### toString

```
open fun toString(): String
```

## Public properties

### endTime

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
open val endTime: Instant
```

End time of the record.

### endZoneOffset

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
open val endZoneOffset: ZoneOffset?
```

User experienced zone offset at `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/IntervalRecord#endTime()`, or null if unknown. Providing these will help history aggregations results stay consistent should user travel. Queries with user experienced time filters will assume system current zone offset if the information is absent.

### exerciseRouteResult

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
val exerciseRouteResult: ExerciseRouteResult
```

`https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseRouteResult` of the session. Location data points of `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseRoute` should be within the parent session, and should be before the end time of the session.

### exerciseType

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
val exerciseType: Int
```

Type of exercise (e.g. walking, swimming). Required field.

### laps

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
val laps: List<ExerciseLap>
```

`https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseLap`s of the session. Optional field. Time in laps should be within the parent session, and should not overlap with each other.

### metadata

```
open val metadata: Metadata
```

Set of common metadata associated with the written record.

### notes

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
val notes: String?
```

Additional notes for the session. Optional field.

### plannedExerciseSessionId

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
val plannedExerciseSessionId: String?
```

### segments

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
val segments: List<ExerciseSegment>
```

`https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSegment`s of the session. Optional field. Time in segments should be within the parent session, and should not overlap with each other.

### startTime

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
open val startTime: Instant
```

Start time of the record.

### startZoneOffset

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
open val startZoneOffset: ZoneOffset?
```

User experienced zone offset at `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/IntervalRecord#startTime()`, or null if unknown. Providing these will help history aggregations results stay consistent should user travel. Queries with user experienced time filters will assume system current zone offset if the information is absent.

### title

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
val title: String?
```

Title of the session. Optional field.

> This guide is compatible with Health Connect version [1.1.0-alpha11](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0-alpha11).

Health Connect provides a *sleep session* data type, to store information about
a user's sleep, such as a nightly session or daytime nap.
The `SleepSessionRecord` data type is used to represent these sessions.

Sessions allow users to measure time-based performance over a period of time,
such as continuous heart rate or location data.

`SleepSessionRecord` sessions contain data that records sleep stages, such as
`AWAKE`, `SLEEPING` and `DEEP`.

**Subtype** data is data that "belongs" to a session and is only meaningful when
it's read with a parent session. For example, sleep stage.

**Associated data**, on the other hand, refers to data that is recorded
independently but falls within the time range of a session. For example, if a
user records Heart Rate during their sleep session, the Heart Rate data would
be associated data. Unlike subtype data which is part of the session record,
associated data consists of independent records, each with its own UUID.

## Check Health Connect availability

Before attempting to use Health Connect, your app should verify that Health Connect is available
on the user's device. Health Connect might not be pre-installed on all devices or could be disabled.
You can check for availability using the `https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#getSdkStatus(android.content.Context,kotlin.String)`
method.

#### How to check for Health Connect availability

```kotlin
fun checkHealthConnectAvailability(context: Context) {
    val providerPackageName = "com.google.android.apps.healthdata" // Or get from HealthConnectClient.DEFAULT_PROVIDER_PACKAGE_NAME
    val availabilityStatus = HealthConnectClient.getSdkStatus(context, providerPackageName)

    if (availabilityStatus == HealthConnectClient.SDK_UNAVAILABLE) {
      // Health Connect is not available. Guide the user to install/enable it.
      // For example, show a dialog.
      return // early return as there is no viable integration
    }
    if (availabilityStatus == HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED) {
      // Health Connect is available but requires an update.
      // Optionally redirect to package installer to find a provider, for example:
      val uriString = "market://details?id=$providerPackageName&url=healthconnect%3A%2F%2Fonboarding"
      context.startActivity(
        Intent(Intent.ACTION_VIEW).apply {
          setPackage("com.android.vending")
          data = Uri.parse(uriString)
          putExtra("overlay", true)
          putExtra("callerId", context.packageName)
        }
      )
      return
    }
    // Health Connect is available, obtain a HealthConnectClient instance
    val healthConnectClient = HealthConnectClient.getOrCreate(context)
    // Issue operations with healthConnectClient
}
```

Depending on the status returned by `getSdkStatus()`, you can guide the user
to install or update Health Connect from the Google Play Store if necessary.

## Feature availability

There is no feature availability flag for this data type.

## Required permissions

Access to sleep session is protected by the following permissions:

- `android.permission.health.READ_SLEEP`
- `android.permission.health.WRITE_SLEEP`

To add sleep session capability to your app, start by requesting
permissions for the `SleepSession` data type.

Here's the permission you need to declare to be able to write
sleep session:

    <application>
      <uses-permission
    android:name="android.permission.health.WRITE_SLEEP" />
    ...
    </application>

To read sleep session, you need to request the following permissions:

    <application>
      <uses-permission
    android:name="android.permission.health.READ_SLEEP" />
    ...
    </application>

### Request permissions from the user

After creating a client instance, your app needs to request permissions from
the user. Users must be allowed to grant or deny permissions at any time.

To do so, create a set of permissions for the required data types.
Make sure that the permissions in the set are declared in your Android
manifest first.


```kotlin
val permissions =
    setOf(
        HealthPermission.getReadPermission(SleepSessionRecord::class),
        HealthPermission.getWritePermission(SleepSessionRecord::class)
    )
```
Use [`getGrantedPermissions`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/PermissionController#getGrantedPermissions()) to see if your app already has the required permissions granted. If not, use [`createRequestPermissionResultContract`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/PermissionController#createRequestPermissionResultContract(kotlin.String)) to request those permissions. This displays the Health Connect permissions screen.

```kotlin
val permissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getWritePermission(StepsRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getWritePermission(HeartRateRecord::class)
    )

val requestPermissionsLauncher = rememberLauncherForActivityResult(
    contract = PermissionController.createRequestPermissionResultContract()
) { grantedPermissions ->
    if (grantedPermissions.containsAll(permissions)) {
        coroutineScope.launch { snackbarHostState.showSnackbar("Permissions granted!") }
    } else {
        coroutineScope.launch { snackbarHostState.showSnackbar("Permissions denied.") }
    }
}
```
Because users can grant or revoke permissions at any time, your app needs to check for permissions every time before using them and handle scenarios where permission is lost.

<br />

## Supported aggregations

<br />

The following aggregate values are available for
`SleepSessionRecord`:

- [`SLEEP_DURATION_TOTAL`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/SleepSessionRecord#SLEEP_DURATION_TOTAL())

<br />

## General guidance

Here are some best practice guidelines on how to work with sleep sessions in
Health Connect.

- Sessions should be used to add data from a specific sleep session, for sleep:


```kotlin
suspend fun writeSleepSession(healthConnectClient: HealthConnectClient) {
    healthConnectClient.insertRecords(
        listOf(
            SleepSessionRecord(
                startTime = Instant.parse("2022-05-10T23:00:00.000Z"),
                startZoneOffset = ZoneOffset.of("-08:00"),
                endTime = Instant.parse("2022-05-11T07:00:00.000Z"),
                endZoneOffset = ZoneOffset.of("-08:00"),
                title = "My Sleep",
                metadata = Metadata.activelyRecorded(device = Device(type = Device.TYPE_WATCH))
            ),
        )
    )
}
```

<br />

- Subtype data needs to be aligned in a session with sequential timestamps that don't overlap. Gaps are allowed, however.
- Subtype data doesn't contain a UUID, but associated data has distinct UUIDs.
- Sessions are useful if the user wants data to be associated with (and tracked as part of) a session, rather than recorded continuously.

## Sleep sessions

You can read or write sleep data in Health Connect. Sleep data is displayed as a
session, and can be divided into 8 distinct sleep stages:

- `UNKNOWN`: Unspecified or unknown if the user is sleeping.
- `AWAKE`: The user is awake within a sleep cycle, not during the day.
- `SLEEPING`: Generic or non-granular sleep description.
- `OUT_OF_BED`: The user gets out of bed in the middle of a sleep session.
- `AWAKE_IN_BED`: The user is awake in bed.
- `LIGHT`: The user is in a light sleep cycle.
- `DEEP`: The user is in a deep sleep cycle.
- `REM`: The user is in a REM sleep cycle.

These values represent the type of sleep a user experiences within a time range.
Writing sleep stages is optional, but recommended if available.

### Write sleep sessions

The `SleepSessionRecord` data type has two parts:

1. The overall session, spanning the entire duration of sleep.
2. Individual stages during the sleep session such as light sleep or deep sleep.

Here's how you insert a sleep session without stages:


```kotlin
val zoneRules = ZoneId.systemDefault().rules

// Calculate the specific offset for both start and end times
val startOffset = zoneRules.getOffset(startTime)
val endOffset = zoneRules.getOffset(endTime)

SleepSessionRecord(
    title = "weekend sleep",
    startTime = startTime,
    endTime = endTime,
    startZoneOffset = startOffset,
    endZoneOffset = endOffset,
    metadata = Metadata.activelyRecorded(device = Device(type = Device.TYPE_WATCH))
)
```

<br />

Here's how to add stages that cover the entire period of a sleep session:

    val stages = listOf(
        SleepSessionRecord.Stage(
            startTime = START_TIME,
            endTime = END_TIME,
            stage = SleepSessionRecord.STAGE_TYPE_SLEEPING,
        )
    )

    SleepSessionRecord(
            title = "weekend sleep",
            startTime = START_TIME,
            endTime = END_TIME,
            startZoneOffset = START_ZONE_OFFSET,
            endZoneOffset = END_ZONE_OFFSET,
            stages = stages,
    )

### Read a sleep session

For every sleep session returned, you should check whether sleep stage data is
also present:


```kotlin
val response =
    healthConnectClient.readRecords(
        ReadRecordsRequest(
            SleepSessionRecord::class,
            timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
        )
    )
for (sleepRecord in response.records) {
    // Retrieve relevant sleep stages from each sleep record
    val sleepStages = sleepRecord.stages
}
```

<br />

### Delete a sleep session

This is how to delete a session. For this example, we've used a sleep session:


```kotlin
val timeRangeFilter = TimeRangeFilter.between(sleepRecord.startTime, sleepRecord.endTime)
healthConnectClient.deleteRecords(SleepSessionRecord::class, timeRangeFilter)
```

<br />

> [!NOTE]
> **Note:** Deleting a session does not automatically delete data associated with that session.

<br />

> [!NOTE]
> **Note:** This guide is compatible with Health Connect version [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0).

<br />

If you're looking to build an app that manages user vitals, you can use Health
Connect to do things like:

- Read vitals data like blood pressure, heart rate, and body temperature from other apps
- Write vitals data recorded by your app or connected devices
- Monitor trends and provide health insights based on vitals data

This guide describes how to work with vitals data types, covering permissions,
read and write workflows, and best practices.

## Overview: Building a Comprehensive Vitals Tracker

You can build a comprehensive vitals tracking experience using Health Connect by
following these core steps:

- Requesting the appropriate permissions for vitals data types.
- Writing vitals data using records like [`BloodPressureRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/BloodPressureRecord), [`HeartRateRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord), and other vitals records.
- Reading vitals data for display, analysis, or syncing.
- Using batching for efficient data writing and reading.

This workflow enables interoperability with other Health Connect apps and
verifies user-controlled data access.

## Before you begin

Before implementing vitals features:

- [Integrate Health Connect](https://developer.android.com/health-and-fitness/health-connect/get-started#step-1) using the appropriate dependency.
- [Create a `HealthConnectClient`](https://developer.android.com/health-and-fitness/health-connect/get-started#step-2) instance.
- Verify your app implements runtime [permission flows based on Health Permissions](https://developer.android.com/health-and-fitness/health-connect/get-started#declare-permissions).

## Key concepts

Vitals data in Health Connect is represented by various record types, each
corresponding to a specific physiological measurement. Unlike workout sessions,
vitals are often recorded as point-in-time or interval-based data.

### Vitals data types

Vitals data is represented by individual record types. Common types include:

- [`BloodPressureRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/BloodPressureRecord): Represents a single blood pressure reading, including systolic and diastolic pressure, and body position.
- [`HeartRateRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord): Represents a series of heart rate measurements.
- [`RestingHeartRateRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/RestingHeartRateRecord): Represents a single measurement of resting heart rate.
- [`BodyTemperatureRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/BodyTemperatureRecord): Represents a single body temperature reading, including measurement location.
- [`BloodGlucoseRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/BloodGlucoseRecord): Represents a single blood glucose reading, including relation to meal and specimen source.
- [`OxygenSaturationRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/OxygenSaturationRecord): Represents a single blood oxygen saturation reading.
- [`RespiratoryRateRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/RespiratoryRateRecord): Represents a single respiratory rate measurement.

For a complete list of data types, see [Health Connect data types](https://developer.android.com/health-and-fitness/health-connect/data-types).

## Development considerations

Vitals data can be sensitive, and apps may need to write data in response to
measurements from sensors or user input, or sync data from a backend.
Permissions are crucial for handling vitals data.

### Permissions

Your app must request the relevant Health Connect permissions before reading or
writing vitals data. Common permissions for vitals include blood pressure,
heart rate, body temperature, blood glucose, oxygen saturation, and
respiratory rate. This includes the following:

- **Blood Pressure:** Read and write permissions for [`BloodPressureRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/BloodPressureRecord).
- **Heart Rate:** Read and write permissions for [`HeartRateRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord).
- **Resting Heart Rate:** Read and write permissions for [`RestingHeartRateRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/RestingHeartRateRecord).
- **Body Temperature:** Read and write permissions for [`BodyTemperatureRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/BodyTemperatureRecord).
- **Blood Glucose:** Read and write permissions for [`BloodGlucoseRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/BloodGlucoseRecord).
- **Oxygen Saturation:** Read and write permissions for [`OxygenSaturationRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/OxygenSaturationRecord).
- **Respiratory Rate:** Read and write permissions for [`RespiratoryRateRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/RespiratoryRateRecord).

The following shows an example of how to request permissions for blood pressure,
heart rate, and body temperature:

After creating a client instance, your app needs to request permissions from
the user. Users must be allowed to grant or deny permissions at any time.

To do so, create a set of permissions for the required data types.
Make sure that the permissions in the set are declared in your Android
manifest first.


```kotlin
val permissions =
    setOf(
        HealthPermission.getReadPermission(BloodPressureRecord::class),
        HealthPermission.getWritePermission(BloodPressureRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getWritePermission(HeartRateRecord::class),
        HealthPermission.getReadPermission(BodyTemperatureRecord::class),
        HealthPermission.getWritePermission(BodyTemperatureRecord::class)
    )
```
Use [`getGrantedPermissions`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/PermissionController#getGrantedPermissions()) to see if your app already has the required permissions granted. If not, use [`createRequestPermissionResultContract`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/PermissionController#createRequestPermissionResultContract(kotlin.String)) to request those permissions. This displays the Health Connect permissions screen.

```kotlin
val permissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getWritePermission(StepsRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getWritePermission(HeartRateRecord::class)
    )

val requestPermissionsLauncher = rememberLauncherForActivityResult(
    contract = PermissionController.createRequestPermissionResultContract()
) { grantedPermissions ->
    if (grantedPermissions.containsAll(permissions)) {
        coroutineScope.launch { snackbarHostState.showSnackbar("Permissions granted!") }
    } else {
        coroutineScope.launch { snackbarHostState.showSnackbar("Permissions denied.") }
    }
}
```
Because users can grant or revoke permissions at any time, your app needs to check for permissions every time before using them and handle scenarios where permission is lost.

<br />

To request permissions, call the `checkPermissionsAndRun` function:


```kotlin
if (!granted.containsAll(permissions)) {
    // Check if required permissions are not granted, and return
    return emptySet()
}
// Permissions already granted; proceed with inserting or reading data
```

<br />

If you only need to request permissions for a single data type, such as blood
pressure, include only that data type in your permissions set:

Access to blood pressure is protected by the following permissions:

- `android.permission.health.READ_BLOOD_PRESSURE`
- `android.permission.health.WRITE_BLOOD_PRESSURE`

To add blood pressure capability to your app, start by requesting
permissions for the `BloodPressureRecord` data type.

Here's the permission you need to declare to be able to write
blood pressure:

    <application>
      <uses-permission
    android:name="android.permission.health.WRITE_BLOOD_PRESSURE" />
    ...
    </application>

To read blood pressure, you need to request the following permissions:

    <application>
      <uses-permission
    android:name="android.permission.health.READ_BLOOD_PRESSURE" />
    ...
    </application>

## Write vitals data

This section describes how to write vitals data to Health Connect. Vitals data
is typically written as individual records. If you are writing multiple records
at once, such as syncing from a sensor or backend, use batching.

> [!NOTE]
> **Best Practice:** Use Client IDs When creating records, set a **metadata.clientRecordId** . This is the most effective way to prevent duplicates during sync retries. See [Best practices](https://developer.android.com/health-and-fitness/health-connect/experiences/vitals#best-practices) for a code example.

Example of writing a [`BloodPressureRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/BloodPressureRecord):

```kotlin
suspend fun writeBloodPressureRecord(healthConnectClient: HealthConnectClient) {
    val record = BloodPressureRecord(
        time = Instant.now(),
        zoneOffset = ZoneOffset.UTC,
        systolic = Pressure.millimetersOfMercury(120.0),
        diastolic = Pressure.millimetersOfMercury(80.0),
        bodyPosition = BloodPressureRecord.BODY_POSITION_SITTING_DOWN,
        measurementLocation = BloodPressureRecord.MEASUREMENT_LOCATION_LEFT_WRIST
    )
    healthConnectClient.insertRecords(listOf(record))
}
```

### Batch writing

If your app needs to write multiple data points, such as syncing data from a
connected device or a backend service, you should batch writes to improve
efficiency and reduce battery consumption. Health Connect can handle up to 1000
records in a single write request.

The following code shows how to batch-write multiple records at once:

```kotlin
suspend fun writeBatchRecords(healthConnectClient: HealthConnectClient) {
    val bloodPressureRecord = BloodPressureRecord(
        time = Instant.now(),
        zoneOffset = ZoneOffset.UTC,
        systolic = Pressure.millimetersOfMercury(120.0),
        diastolic = Pressure.millimetersOfMercury(80.0),
        bodyPosition = BloodPressureRecord.BODY_POSITION_SITTING_DOWN,
        measurementLocation = BloodPressureRecord.MEASUREMENT_LOCATION_LEFT_WRIST
    )
    val heartRateRecord = HeartRateRecord(
        startTime = Instant.now().minusSeconds(60),
        startZoneOffset = ZoneOffset.UTC,
        endTime = Instant.now(),
        endZoneOffset = ZoneOffset.UTC,
        samples = listOf(HeartRateRecord.Sample(time = Instant.now().minusSeconds(30), beatsPerMinute = 80))
    )
    healthConnectClient.insertRecords(listOf(bloodPressureRecord, heartRateRecord))
}
```

## Reading vitals data

Apps can read vitals data to display measurements, analyze trends, or sync data
with an external server. To read vitals, use a `ReadRecordsRequest` with the
specific record type and filter by a time range.

Example of reading [`BloodPressureRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/BloodPressureRecord) data:

```kotlin
suspend fun readBloodPressureRecords(
    healthConnectClient: HealthConnectClient,
    startTime: Instant,
    endTime: Instant
) {
    val response = healthConnectClient.readRecords(
        ReadRecordsRequest(
            recordType = BloodPressureRecord::class,
            timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
        )
    )

    for (record in response.records) {
        // Process each blood pressure record
        val systolic = record.systolic
        val diastolic = record.diastolic
    }
}
```

If you need to sync vitals data with a backend server, or keep your app's
datastore up-to-date with Health Connect, use ChangeLogs. This lets you retrieve
a list of inserted, updated, or deleted records since a specific point in time,
which is more efficient than manually tracking changes or repeatedly reading all
data. For more information, see [Sync data with Health Connect](https://developer.android.com/health-and-fitness/health-connect/sync-data).

## Best practices

Follow these guidelines to improve data reliability and user experience:

- **Batch write requests** : To reduce Input/Output overhead and preserve battery life, group data points into a single `insertRecords` call with batches of up to 1000 records, rather than writing each point individually.
- **Write frequently during live tracking**: For frequent updates from sensors (like continuous glucose monitors or heart rate monitors), write data in batches at intervals of up to 15 minutes to balance real-time updates with battery efficiency.
- **Use WorkManager for background syncs** : Use `WorkManager` for deferred writes, such as syncing data from a companion device or backend service. Aim for a 15-minute interval for batch writes.
- **Avoid writing duplicate data: Use Client IDs** : When creating records, set a `metadata.clientRecordId`. Health Connect uses this to identify unique records. If you attempt to write a record with a `clientRecordId` that already exists, Health Connect will ignore the duplicate or update the existing record rather than creating a new one. Setting a `metadata.clientRecordId` is the most effective way to prevent duplicates during sync retries or app reinstalls.  

  ```kotlin
  val record = StepsRecord(
      count = 100,
      startTime = startTime,
      endTime = endTime,
      startZoneOffset = ZoneOffset.UTC,
      endZoneOffset = ZoneOffset.UTC,
      metadata = Metadata(
          // Use a unique ID from your own database
          clientRecordId = "daily_steps_2023_10_27_user_123"
      )
  )
  ```
- **Check existing data**: Before syncing data, query Health Connect for records within the sync time range to see if data from your app already exists, to avoid duplicates or overwriting newer data.
- **Provide clear rationales for permission** : Use the `Permission.createIntent` flow to explain why your app needs access to health data, for example: 'To monitor your blood pressure trends and provide insights.'
- **Align timestamps with measurements** : Verify record timestamps accurately reflect when measurements were taken. For interval data like [`HeartRateRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord), verify `startTime` and `endTime` are correct.

## Testing

To verify data correctness and a high-quality user experience, follow these
testing strategies and refer to the official [Test top use cases](https://developer.android.com/health-and-fitness/health-connect/test/test-cases)
documentation.

### Verification tools

- **[Health Connect Toolbox](https://developer.android.com/health-and-fitness/health-connect/test/health-connect-toolbox):** Use this companion app to manually inspect records, delete test data, and simulate changes to the database. It is the best way to verify that your records are being stored correctly.
- **[Unit testing with `FakeHealthConnectClient`](https://developer.android.com/health-and-fitness/health-connect/test/unit-tests):** Use the testing library to verify how your app handles edge cases, like permission revocation or API exceptions without needing a physical device.

### Quality checklist

**Confirm records in Health Connect:** Open the Health Connect app and navigate to Data and access to verify records appear with expected values. **Read data from other apps:** Test your app's ability to read vitals written by other apps to verify ecosystem compatibility. See [Reading vitals data](https://developer.android.com/health-and-fitness/health-connect/experiences/vitals#reading-vitals-data). **Balance write frequency:** Monitor battery usage if writing frequently. Frequent writes provide high detail but can increase drain.

## Typical architecture

A vitals implementation commonly includes:

| Component | Manages |
|---|---|
| Vitals controller | Sensor/Input reading Batching logic |
| Repository layer (wraps Health Connect operations:) | Insert vitals records Read vitals records |
| UI Layer (Displays): | Live readings Historical data Charts and trends |

## Troubleshooting

<br />

| Symptom | Possible cause | Resolution |
|---|---|---|
| Missing data types (For example, Blood Pressure) | Missing write permissions or incorrect time filters. | Check that you have requested and the user has granted the specific data type permission. Verify your `ReadRecordsRequest` uses a `TimeRangeFilter` that covers the time of measurement. See [Permissions](https://developer.android.com/health-and-fitness/health-connect/experiences/vitals#permissions). |
| Duplicate records appear | Missing `clientRecordId`. | Assign a unique `clientRecordId` in the `Metadata` of each record. This allows Health Connect to perform de-duplication if the same data is written twice during a sync retry. See [Best practices](https://developer.android.com/health-and-fitness/health-connect/experiences/vitals#best-practices). |
| Records fail to write | Incorrect units or values outside valid range. | Health Connect validates record values. For example, blood pressure values must be in a physiologically plausible range. Check data type documentation for valid ranges and units. |

<br />

### Common debugging steps

<br />

|---|---|
| Check permission state. | Always call `getPermissionStatus()` before attempting a read or write operation. Users can revoke permissions in system settings at any time. |

<br />

# HeartRateRecord

Artifact: [androidx.health.connect:connect-client](https://developer.android.com/jetpack/androidx/releases/health-connect) [View Source](https://cs.android.com/search?q=file:androidx/health/connect/client/records/HeartRateRecord.kt+class:androidx.health.connect.client.records.HeartRateRecord) Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

*** ** * ** ***

Kotlin \|[Java](https://developer.android.com/reference/androidx/health/connect/client/records/HeartRateRecord "View this page in Java")


```
class HeartRateRecord : Record
```

<br />

*** ** * ** ***

Captures the user's heart rate. Each record represents a series of measurements.

## Summary

| ### Nested types |
|---|
| `class https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord.Sample` Represents a single measurement of the heart rate. |

| ### Public companion properties |
|---|---|
| `https://developer.android.com/reference/kotlin/androidx/health/connect/client/aggregate/AggregateMetric<https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-long/index.html>` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord#BPM_AVG()` Metric identifier to retrieve the average heart rate from `https://developer.android.com/reference/kotlin/androidx/health/connect/client/aggregate/AggregationResult`. |
| `https://developer.android.com/reference/kotlin/androidx/health/connect/client/aggregate/AggregateMetric<https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-long/index.html>` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord#BPM_MAX()` Metric identifier to retrieve the maximum heart rate from `https://developer.android.com/reference/kotlin/androidx/health/connect/client/aggregate/AggregationResult`. |
| `https://developer.android.com/reference/kotlin/androidx/health/connect/client/aggregate/AggregateMetric<https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-long/index.html>` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord#BPM_MIN()` Metric identifier to retrieve the minimum heart rate from `https://developer.android.com/reference/kotlin/androidx/health/connect/client/aggregate/AggregationResult`. |
| `https://developer.android.com/reference/kotlin/androidx/health/connect/client/aggregate/AggregateMetric<https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-long/index.html>` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord#MEASUREMENTS_COUNT()` Metric identifier to retrieve the number of heart rate measurements from `https://developer.android.com/reference/kotlin/androidx/health/connect/client/aggregate/AggregationResult`. |

| ### Public constructors |
|---|
| `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord#HeartRateRecord(java.time.Instant,java.time.ZoneOffset,java.time.Instant,java.time.ZoneOffset,kotlin.collections.List,androidx.health.connect.client.records.metadata.Metadata)( startTime: https://developer.android.com/reference/java/time/Instant.html, startZoneOffset: https://developer.android.com/reference/java/time/ZoneOffset.html?, endTime: https://developer.android.com/reference/java/time/Instant.html, endZoneOffset: https://developer.android.com/reference/java/time/ZoneOffset.html?, samples: https://kotlinlang.org/api/core/kotlin-stdlib/kotlin.collections/-list/index.html<https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord.Sample>, metadata: https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/metadata/Metadata )` |

| ### Public functions |
|---|---|
| `open operator https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-boolean/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord#equals(kotlin.Any)(other: https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-any/index.html?)` |
| `open https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord#hashCode()()` |
| `open https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-string/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord#toString()()` |

| ### Public properties |
|---|---|
| `open https://developer.android.com/reference/java/time/Instant.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord#endTime()` End time of the record. |
| `open https://developer.android.com/reference/java/time/ZoneOffset.html?` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord#endZoneOffset()` User experienced zone offset at `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/IntervalRecord#endTime()`, or null if unknown. |
| `open https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/metadata/Metadata` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord#metadata()` Set of common metadata associated with the written record. |
| `open https://kotlinlang.org/api/core/kotlin-stdlib/kotlin.collections/-list/index.html<https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord.Sample>` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord#samples()` |
| `open https://developer.android.com/reference/java/time/Instant.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord#startTime()` Start time of the record. |
| `open https://developer.android.com/reference/java/time/ZoneOffset.html?` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/HeartRateRecord#startZoneOffset()` User experienced zone offset at `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/IntervalRecord#startTime()`, or null if unknown. |

## Public companion properties

### BPM_AVG

```
val BPM_AVG: AggregateMetric<Long>
```

Metric identifier to retrieve the average heart rate from `https://developer.android.com/reference/kotlin/androidx/health/connect/client/aggregate/AggregationResult`.

### BPM_MAX

```
val BPM_MAX: AggregateMetric<Long>
```

Metric identifier to retrieve the maximum heart rate from `https://developer.android.com/reference/kotlin/androidx/health/connect/client/aggregate/AggregationResult`.

### BPM_MIN

```
val BPM_MIN: AggregateMetric<Long>
```

Metric identifier to retrieve the minimum heart rate from `https://developer.android.com/reference/kotlin/androidx/health/connect/client/aggregate/AggregationResult`.

### MEASUREMENTS_COUNT

```
val MEASUREMENTS_COUNT: AggregateMetric<Long>
```

Metric identifier to retrieve the number of heart rate measurements from `https://developer.android.com/reference/kotlin/androidx/health/connect/client/aggregate/AggregationResult`.

## Public constructors

### HeartRateRecord

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
HeartRateRecord(
    startTime: Instant,
    startZoneOffset: ZoneOffset?,
    endTime: Instant,
    endZoneOffset: ZoneOffset?,
    samples: List<HeartRateRecord.Sample>,
    metadata: Metadata
)
```

## Public functions

### equals

```
open operator fun equals(other: Any?): Boolean
```

### hashCode

```
open fun hashCode(): Int
```

### toString

```
open fun toString(): String
```

## Public properties

### endTime

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
open val endTime: Instant
```

End time of the record.

### endZoneOffset

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
open val endZoneOffset: ZoneOffset?
```

User experienced zone offset at `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/IntervalRecord#endTime()`, or null if unknown. Providing these will help history aggregations results stay consistent should user travel. Queries with user experienced time filters will assume system current zone offset if the information is absent.

### metadata

```
open val metadata: Metadata
```

Set of common metadata associated with the written record.

### samples

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
open val samples: List<HeartRateRecord.Sample>
```

### startTime

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
open val startTime: Instant
```

Start time of the record.

### startZoneOffset

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
open val startZoneOffset: ZoneOffset?
```

User experienced zone offset at `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/IntervalRecord#startTime()`, or null if unknown. Providing these will help history aggregations results stay consistent should user travel. Queries with user experienced time filters will assume system current zone offset if the information is absent.

# OxygenSaturationRecord

Artifact: [androidx.health.connect:connect-client](https://developer.android.com/jetpack/androidx/releases/health-connect) [View Source](https://cs.android.com/search?q=file:androidx/health/connect/client/records/OxygenSaturationRecord.kt+class:androidx.health.connect.client.records.OxygenSaturationRecord) Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

*** ** * ** ***

Kotlin \|[Java](https://developer.android.com/reference/androidx/health/connect/client/records/OxygenSaturationRecord "View this page in Java")


```
class OxygenSaturationRecord : Record
```

<br />

*** ** * ** ***

Captures the amount of oxygen circulating in the blood, measured as a percentage of oxygen-saturated hemoglobin. Each record represents a single blood oxygen saturation reading at the time of measurement.

## Summary

| ### Public constructors |
|---|
| `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/OxygenSaturationRecord#OxygenSaturationRecord(java.time.Instant,java.time.ZoneOffset,androidx.health.connect.client.units.Percentage,androidx.health.connect.client.records.metadata.Metadata)( time: https://developer.android.com/reference/java/time/Instant.html, zoneOffset: https://developer.android.com/reference/java/time/ZoneOffset.html?, percentage: https://developer.android.com/reference/kotlin/androidx/health/connect/client/units/Percentage, metadata: https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/metadata/Metadata )` |

| ### Public functions |
|---|---|
| `open operator https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-boolean/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/OxygenSaturationRecord#equals(kotlin.Any)(other: https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-any/index.html?)` |
| `open https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-int/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/OxygenSaturationRecord#hashCode()()` |
| `open https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-string/index.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/OxygenSaturationRecord#toString()()` |

| ### Public properties |
|---|---|
| `open https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/metadata/Metadata` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/OxygenSaturationRecord#metadata()` Set of common metadata associated with the written record. |
| `https://developer.android.com/reference/kotlin/androidx/health/connect/client/units/Percentage` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/OxygenSaturationRecord#percentage()` Percentage. |
| `open https://developer.android.com/reference/java/time/Instant.html` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/OxygenSaturationRecord#time()` Time the record happened. |
| `open https://developer.android.com/reference/java/time/ZoneOffset.html?` | `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/OxygenSaturationRecord#zoneOffset()` User experienced zone offset at `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/InstantaneousRecord#time()`, or null if unknown. |

## Public constructors

### OxygenSaturationRecord

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
OxygenSaturationRecord(
    time: Instant,
    zoneOffset: ZoneOffset?,
    percentage: Percentage,
    metadata: Metadata
)
```

## Public functions

### equals

```
open operator fun equals(other: Any?): Boolean
```

### hashCode

```
open fun hashCode(): Int
```

### toString

```
open fun toString(): String
```

## Public properties

### metadata

```
open val metadata: Metadata
```

Set of common metadata associated with the written record.

### percentage

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
val percentage: Percentage
```

Percentage. Required field. Valid range: 0-100.

### time

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
open val time: Instant
```

Time the record happened.

### zoneOffset

Added in [1.1.0](https://developer.android.com/jetpack/androidx/releases/health-connect#1.1.0)

```
open val zoneOffset: ZoneOffset?
```

User experienced zone offset at `https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/InstantaneousRecord#time()`, or null if unknown. Providing these will help history aggregations results stay consistent should user travel. Queries with user experienced time filters will assume system current zone offset if the information is absent.