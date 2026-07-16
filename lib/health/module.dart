import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:misync/screen.dart';
import '../device/module.dart';
import '../device/proto/xiaomi.pb.dart' as pb;
import '../device/proto/constants.dart';
import '../platform/module.dart';
import 'blobs/health.dart';
import 'screen.dart';
import 'parsers/parser.dart';

class HealthModule extends TabModule {
  @override
  String get name => 'health';

  @override
  IconData get icon => Icons.favorite;

  @override
  late final Screen screen = HealthScreen(this);

  static const int batchSize = 50;

  static final HealthModule _module = HealthModule._();
  static HealthModule get module => _module;
  HealthModule._();

  @override
  Future<void> start() async {
    DeviceModule.module.register(this);
    DeviceModule.module.connection.listen(_receiveWatchCommand);
    PlatformModule.module.register(_receivePhoneMethod);
  }

  void _receiveWatchCommand(pb.Command cmd) {
    if (cmd.type == CmdType.health.value) {
      if (cmd.subtype == HealthSubtype.workoutOpen.value) {
        _handleWorkoutOpenWatch(cmd);
      } else if (cmd.subtype == HealthSubtype.workoutStatus.value) {
        _handleWorkoutStatusWatch(cmd);
      }
    }
  }

  Future<void> _handleWorkoutOpenWatch(pb.Command cmd) async {
    if (!cmd.health.hasWorkoutOpenWatch()) return;
    final workout = cmd.health.workoutOpenWatch;
    logger.info('watch started outdoor workout: sport=${workout.sport}');

    // 1. Reply to WorkoutOpenWatch with WorkoutOpenReply (Type 8, Subtype 30)
    // gpsStatus = 0, gpsState = 2 tells the watch the phone's GPS is ready!
    await DeviceModule.module.connection.send(
      type: CmdType.health,
      subtype: HealthSubtype.workoutOpen,
      builder: (cmd) =>
          cmd.health = (pb.Health()
            ..workoutOpenReply = (pb.WorkoutOpenReply()
              ..gpsStatus = 0
              ..signalRequest = 2
              ..gpsState = 2)),
    );

    // 2. Start location updates on the phone
    logger.info('starting phone GPS location updates for workout');
    final success =
        await PlatformModule.module.invokeMethod(
          'device.startLocationUpdates',
        ) ??
        false;
    logger.info('phone GPS updates started: $success');
  }

  Future<void> _handleWorkoutStatusWatch(pb.Command cmd) async {
    if (!cmd.health.hasWorkoutStatusWatch()) return;
    final status = cmd.health.workoutStatusWatch;
    logger.info('received workout status update: status=${status.status}');

    // Stop updates when the workout is finished
    if (status.status == WorkoutStatus.finished.value) {
      logger.info('workout finished, stopping phone GPS updates');
      await PlatformModule.module.invokeMethod('device.stopLocationUpdates');
    }
  }

  Future<dynamic> _receivePhoneMethod(MethodCall call) async {
    if (call.method == 'locationUpdate') {
      await _handlePhoneLocationUpdate(call.arguments);
    }
  }

  Future<void> _handlePhoneLocationUpdate(dynamic arguments) async {
    if (!DeviceModule.module.connection.connected.value) return;
    if (arguments == null) return;

    final data = Map<String, dynamic>.from(arguments);
    final double lat = (data['latitude'] as num).toDouble();
    final double lon = (data['longitude'] as num).toDouble();
    final double alt = (data['altitude'] as num).toDouble();
    final double speed = (data['speed'] as num).toDouble();
    final double bearing = (data['bearing'] as num).toDouble();
    final double horizAcc = (data['horizontalAccuracy'] as num).toDouble();
    final double vertAcc = (data['verticalAccuracy'] as num).toDouble();

    logger.info('sending location update to watch: lat=$lat, lon=$lon');

    // Send coordinates via WorkoutLocation (CmdType 16, Subtype 2)
    await DeviceModule.module.connection.send(
      type: CmdType.location,
      subtype: LocationSubtype.workoutLocation,
      builder: (cmd) =>
          cmd.health = (pb.Health()
            ..workoutLocation = (pb.WorkoutLocation()
              ..gpsStatus = 2
              ..timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000
              ..longitude = lon
              ..latitude = lat
              ..altitude = alt
              ..speed = speed
              ..bearing = bearing
              ..horizontalAccuracy = horizAcc
              ..verticalAccuracy = vertAcc)),
    );
  }

  @override
  Future<void> sync() async {
    if (!HealthBlob.enabled) {
      logger.info('health sync is disabled');
      return;
    }

    if (!DeviceModule.module.connection.connected.value) {
      logger.info('skip health sync (not connected)');
      return;
    }

    logger.info('starting health logs sync...');
    // Automatically sync user profile demographics and goals to the watch on every sync pass
    await _syncUser();
    await _syncFiles();
  }

  Future<void> _syncUser() async {
    logger.info('syncing user profile and goals to watch');
    try {
      final latest = await PlatformModule.module
          .invokeMethod<Map<dynamic, dynamic>>('health.getLatestHeightAndWeight');

      double? weight = latest?['weight'] as double?;
      double? heightMeters = latest?['height'] as double?;
      double? heightCm = heightMeters != null ? heightMeters * 100 : null;

      final currentHealth = HealthBlob.settings;
      if (heightCm != null || weight != null) {
        final updatedHealth = currentHealth.copyWith(
          height: heightCm ?? currentHealth.height,
          weight: weight ?? currentHealth.weight,
        );
        await HealthBlob.instance.update(updatedHealth);
      }
    } catch (e) {
      logger.error('failed to get height and weight from health connect', {
        'error': e.toString(),
      });
    }

    final settings = HealthBlob.settings;
    final birthYear = int.tryParse(settings.birthday.substring(0, 4)) ?? 1995;
    final age = DateTime.now().year - birthYear;
    int maxHr = (age <= 40 ? 220 - age : 207 - (0.7 * age)).round();
    if (maxHr < 100 || maxHr > 220) maxHr = 175;

    final cmd = pb.Command()
      ..type = CmdType.health.value
      ..subtype = HealthSubtype.userInfo.value
      ..health = (pb.Health()
        ..userInfo = (pb.UserInfo()
          ..birthday = int.tryParse(settings.birthday) ?? 19950101
          ..gender = settings.gender
          ..maxHeartRate = maxHr
          ..goalCalories = settings.goals.calories
          ..goalSteps = settings.goals.steps
          ..goalStanding = settings.goals.standing
          ..goalMoving = settings.goals.moving));

    if (settings.height > 0) {
      cmd.health.userInfo.height = settings.height.round();
    }
    if (settings.weight > 0) {
      cmd.health.userInfo.weight = settings.weight;
    }

    await DeviceModule.module.connection.send(cmd: cmd);
    logger.info('user profile synced', {
      'height': settings.height,
      'weight': settings.weight,
      'birthday': settings.birthday,
      'gender': settings.gender,
      'goals': settings.goals.toJson(),
    });
  }

  Future<void> _syncFiles() async {
    // Sync wear sport status first to commit standalone workout logs on the watch
    try {
      logger.info('syncing wear sport status');
      await DeviceModule.module.connection.send(
        type: CmdType.health,
        subtype: HealthSubtype.getWearSportStatus,
        response: true,
        timeout: const Duration(seconds: 8),
      );
    } catch (e) {
      logger.error('failed to sync wear sport status', {'error': e.toString()});
    }

    final todayList = await _getFileIds(getToday: true);
    final historyList = await _getFileIds(getToday: false);

    final allIds = <Id>{};
    allIds.addAll(todayList);
    allIds.addAll(historyList);

    logger.info('discovered files on watch', {'count': allIds.length});

    // Time ranges of workouts synced during this pass to deduplicate steps
    final workoutRanges = <Map<String, DateTime>>[];

    // Convert to list and sort:
    // Workouts (dataType == 1) first, and summaries (fileType == 1) first, to record workout windows.
    final idList = allIds.toList();
    idList.sort((a, b) {
      if (a.dataType != b.dataType) {
        return b.dataType.compareTo(
          a.dataType,
        ); // 1 (workout) comes before 0 (daily)
      }
      if (a.fileType != b.fileType) {
        return b.fileType.compareTo(
          a.fileType,
        ); // 1 (summary) comes before 0 (details)
      }
      return a.timeStamp.compareTo(b.timeStamp);
    });

    int newFilesSynced = 0;

    for (final id in idList) {
      final idHex = id.toHexString();
      logger.info('downloading file', {'hex': idHex, 'id': id.toString()});
      final fileData = await _downloadFile(id);
      if (fileData != null) {
        final success = await _syncFile(id, fileData, workoutRanges);
        if (success) {
          newFilesSynced++;
          await _sendFileAck(id);
        }
      }
    }

    logger.info('health sync complete', {'newFilesSynced': newFilesSynced});
  }

  Future<List<Id>> _getFileIds({required bool getToday}) async {
    final cmd = pb.Command()
      ..type = CmdType.health.value
      ..subtype = getToday
          ? HealthSubtype.getTodayFitnessIds.value
          : HealthSubtype.getHistoryFitnessIds.value;

    if (getToday) {
      cmd.health = (pb.Health()
        ..activitySyncRequestToday = (pb.ActivitySyncRequestToday()
          ..unknown1 = 1));
    }

    final response = await DeviceModule.module.connection.send(
      cmd: cmd,
      response: true,
      timeout: const Duration(seconds: 8),
    );

    if (response == null || !response.hasHealth()) {
      return [];
    }

    final bytes = response.health.activityRequestFileIds;
    if (bytes.isEmpty) return [];

    final list = <Id>[];
    for (int i = 0; i < bytes.length; i += 7) {
      if (i + 7 > bytes.length) break;
      try {
        final idBytes = Uint8List.fromList(bytes.sublist(i, i + 7));
        list.add(Id.fromBytes(idBytes));
      } catch (e) {
        logger.error('failed to parse fitness data id', {
          'error': e.toString(),
        });
      }
    }
    return list;
  }

  Future<Uint8List?> _downloadFile(Id id) async {
    final cmd = pb.Command()
      ..type = CmdType.health.value
      ..subtype = HealthSubtype.requestSingleFitnessId.value
      ..health = (pb.Health()..activityRequestFileIds = id.toBytes());

    return await DeviceModule.module.connection.downloadData(cmd: cmd);
  }

  Future<void> _sendFileAck(Id id) async {
    final cmd = pb.Command()
      ..type = CmdType.health.value
      ..subtype = HealthSubtype.confirmFitnessId.value
      ..health = (pb.Health()..activitySyncAckFileIds = id.toBytes());
    await DeviceModule.module.connection.send(cmd: cmd);
  }

  Future<bool> _syncFile(
    Id id,
    Uint8List data,
    List<Map<String, DateTime>> exerciseRanges,
  ) async {
    logger.info('processing file', {
      'id': id.toHexString(),
      'size': data.length,
    });

    if (id.dataType == Id.dataTypeDaily && id.fileType == Id.fileTypeDetail) {
      if (id.dailyType == 6) {
        return await _syncMeasurementFile(id, data);
      }
      return await _syncSnapshotsFile(id, data, exerciseRanges);
    } else if (id.dataType == Id.dataTypeDaily &&
        (id.dailyType == Id.dailyTypeSleepNight ||
            id.dailyType == Id.dailyTypeSleepDay ||
            id.dailyType == Id.dailyTypeSleepAllDay)) {
      return await _syncSleepFile(id, data);
    } else if (id.dataType == Id.dataTypeDaily &&
        id.fileType == Id.fileTypeSummary) {
      logger.info('skipping daily summary file', {'id': id.toHexString()});
      return true;
    } else if (id.dataType == Id.dataTypeSport &&
        id.fileType == Id.fileTypeSummary) {
      return await _syncExerciseFile(id, data, exerciseRanges);
    } else if (id.dataType == Id.dataTypeSport &&
        id.fileType == Id.fileTypeDetail) {
      logger.info('skipping detailed samples file for workout', {
        'id': id.toHexString(),
      });
      return true;
    }

    logger.info('unknown watch health data type', {'dataType': id.dataType});
    return true;
  }

  Future<bool> _syncMeasurementFile(Id id, Uint8List data) async {
    final List<Measurement> measurements;

    try {
      measurements = MeasurementParser.parse(id, data);
    } catch (e, stack) {
      logger.error('failed to parse manual health records', {
        'error': e.toString(),
        'stack': stack.toString(),
      });
      return false;
    }

    logger.info('parsed manual health records', {'count': measurements.length});
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      for (int i = 0; i < measurements.length; i += batchSize) {
        final end = (i + batchSize < measurements.length)
            ? i + batchSize
            : measurements.length;
        final batch = measurements.sublist(i, end);
        final futures = <Future<dynamic>>[];
        for (final r in batch) {
          final timeMs = (r.timestamp * 1000).clamp(0, now);
          if (r is HeartRateMeasurement) {
            futures.add(
              PlatformModule.module.invokeMethod('health.writeHeartRate', {
                'time': timeMs,
                'bpm': r.bpm,
              }),
            );
          } else if (r is OxygenSaturationMeasurement) {
            futures.add(
              PlatformModule.module.invokeMethod(
                'health.writeOxygenSaturation',
                {'time': timeMs, 'percentage': r.percentage.toDouble()},
              ),
            );
          } else if (r is StressMeasurement) {
            futures.add(
              PlatformModule.module.invokeMethod(
                'health.writeMindfulnessSession',
                {'time': timeMs, 'stress': r.stress},
              ),
            );
          } else if (r is TemperatureMeasurement) {
            futures.add(
              PlatformModule.module.invokeMethod(
                'health.writeBodyTemperature',
                {
                  'time': timeMs,
                  'skinTemp': r.skinTemp,
                  'bodyTemp': r.bodyTemp,
                },
              ),
            );
          } else if (r is BloodPressureMeasurement) {
            futures.add(
              PlatformModule.module.invokeMethod('health.writeBloodPressure', {
                'time': timeMs,
                'systolic': r.systolic,
                'diastolic': r.diastolic,
                'pulse': r.pulse,
                'status': r.measurementStatus,
              }),
            );
          }
        }

        await Future.wait(futures);
      }
    } catch (e, stack) {
      logger.error('failed to sync manual health records to health connect', {
        'error': e.toString(),
        'stack': stack.toString(),
      });
      return false;
    }

    return true;
  }

  Future<bool> _syncSnapshotsFile(
    Id id,
    Uint8List data,
    List<Map<String, DateTime>> exerciseRanges,
  ) async {
    final List<Snapshot> snapshots;

    try {
      snapshots = SnapshotsParser.parse(id, data);
    } catch (e, stack) {
      logger.error('failed to parse minute-by-minute daily logs', {
        'error': e.toString(),
        'stack': stack.toString(),
      });
      return false;
    }

    logger.info('parsed minute-by-minute daily logs', {
      'count': snapshots.length,
    });

    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      for (int i = 0; i < snapshots.length; i += batchSize) {
        final end = (i + batchSize < snapshots.length)
            ? i + batchSize
            : snapshots.length;
        final batch = snapshots.sublist(i, end);
        final futures = <Future<dynamic>>[];
        for (final r in batch) {
          var startMs = r.startTime.millisecondsSinceEpoch;
          var endMs = r.endTime.millisecondsSinceEpoch;

          if (endMs > now) {
            endMs = now;
          }
          if (startMs >= endMs) {
            startMs = endMs - 1000; // Ensure start is before end
          }

          final isOverlapping = exerciseRanges.any((range) {
            final rStart = DateTime.fromMillisecondsSinceEpoch(startMs);
            final rEnd = DateTime.fromMillisecondsSinceEpoch(endMs);
            return rStart.isBefore(range['end']!) &&
                rEnd.isAfter(range['start']!);
          });

          if (r.steps != null && r.steps! > 0) {
            if (isOverlapping) {
              logger.info('skipping overlapping daily steps', {
                'timestamp': r.timestamp,
                'steps': r.steps,
              });
            } else {
              futures.add(
                PlatformModule.module.invokeMethod('health.writeSteps', {
                  'startTime': startMs,
                  'endTime': endMs,
                  'count': r.steps!,
                }),
              );
            }
          }
          if (r.hr != null && r.hr! > 0) {
            futures.add(
              PlatformModule.module.invokeMethod('health.writeHeartRate', {
                'time': endMs,
                'bpm': r.hr!,
              }),
            );
          }
          if (r.spo2 != null && r.spo2! > 0) {
            futures.add(
              PlatformModule.module.invokeMethod(
                'health.writeOxygenSaturation',
                {
                  'time': endMs,
                  'percentage': r.spo2!.toDouble().clamp(0.0, 100.0),
                },
              ),
            );
          }
        }

        await Future.wait(futures);
      }
    } catch (e, stack) {
      logger.error(
        'failed to sync minute-by-minute daily logs to health connect',
        {'error': e.toString(), 'stack': stack.toString()},
      );
      return false;
    }

    return true;
  }

  Future<bool> _syncSleepFile(Id id, Uint8List data) async {
    final Sleep sleep;

    try {
      sleep = SleepParser.parse(id, data);
    } catch (e, stack) {
      logger.error('failed to parse sleep report', {
        'error': e.toString(),
        'stack': stack.toString(),
      });
      return false;
    }

    logger.info('parsed sleep report', {
      'deep': sleep.deepDuration,
      'light': sleep.lightDuration,
    });

    final startTime = sleep.startTime;
    final endTime = sleep.endTime;

    if (endTime.isAfter(startTime)) {
      final stages = sleep.formattedStages;

      try {
        await PlatformModule.module.invokeMethod('health.writeSleepSession', {
          'startTime': startTime.millisecondsSinceEpoch,
          'endTime': endTime.millisecondsSinceEpoch,
          'stages': stages,
        });
        logger.info('synced native sleep session', {
          'start': startTime.toIso8601String(),
          'end': endTime.toIso8601String(),
          'stagesCount': stages.length,
        });
      } catch (e, stack) {
        logger.error('failed to sync sleep session', {
          'error': e.toString(),
          'stack': stack.toString(),
        });
        return false;
      }
    } else {
      logger.debug('skipping sleep session with invalid time range', {
        'start': startTime.toIso8601String(),
        'end': endTime.toIso8601String(),
      });
    }

    return true;
  }

  Future<bool> _syncExerciseFile(
    Id id,
    Uint8List data,
    List<Map<String, DateTime>> exerciseRanges,
  ) async {
    final Exercise exercise;

    try {
      exercise = ExerciseParser.parse(id, data);
    } catch (e, stack) {
      logger.error('failed to parse workout report', {
        'error': e.toString(),
        'stack': stack.toString(),
      });
      return false;
    }

    logger.info('parsed workout report', {
      'duration': exercise.duration,
      'distance': exercise.distance,
      'calories': exercise.calories,
      'steps': exercise.steps,
      'sportType': exercise.sportType,
    });

    if (exercise.duration != null && exercise.duration! > 0) {
      final sTime = exercise.startTime;
      final eTime = exercise.endTime;

      exerciseRanges.add({'start': sTime, 'end': eTime});

      try {
        await PlatformModule.module.invokeMethod('health.writeExerciseSession', {
          'startTime': sTime.millisecondsSinceEpoch,
          'endTime': eTime.millisecondsSinceEpoch,
          'sportType': exercise.sportType ?? 0,
          'title': exercise.title,
          'calories': exercise.calories?.toDouble(),
          'distance': exercise.distance?.toDouble(),
          'skipCount': exercise.sportType == 14 ? exercise.steps : null,
        });
        logger.info('synced native exercise session', {
          'title': exercise.title,
          'start': sTime.toIso8601String(),
          'end': eTime.toIso8601String(),
        });
      } catch (e, stack) {
        logger.error('failed to sync native exercise session', {
          'error': e.toString(),
          'stack': stack.toString(),
        });
        return false;
      }
    }

    return true;
  }

  Future<void> saveHealth(Health settings) async {
    await HealthBlob.instance.update(settings);
    if (DeviceModule.module.connection.connected.value) {
      await _syncUser();
    }
  }
}
