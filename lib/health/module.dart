import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../module.dart';
import '../device/module.dart';
import '../device/proto/xiaomi.pb.dart' as pb;
import '../device/connection.dart';
import '../device/proto/constants.dart';
import '../platform/module.dart';
import 'blobs/health.dart';
import 'screen.dart';
import 'parser.dart';

class HealthModule extends TabModule {
  @override
  String get name => 'health';

  @override
  IconData get icon => Icons.favorite;

  @override
  Widget get screen => const HealthScreen();

  static final HealthModule _instance = HealthModule._();
  static HealthModule get instance => _instance;
  HealthModule._();

  @override
  Future<void> start() async {
    DeviceModule.instance.register(this);
  }

  @override
  Future<void> sync() async {
    if (!HealthBlob.enabled) {
      logger.info('health sync is disabled');
      return;
    }

    if (!DeviceConnection.instance.connected.value) {
      logger.info('skip health sync (not connected)');
      return;
    }

    logger.info('starting health logs sync...');
    // Automatically sync user profile demographics and goals to the watch on every sync pass
    await _syncUserProfile();
    await _syncHealthFiles();
  }

  Future<void> _syncUserProfile() async {
    logger.info('syncing user profile and goals to watch');
    final latest = await PlatformModule.instance
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

    await DeviceConnection.instance.send(cmd: cmd);
    logger.info('user profile synced', {
      'height': settings.height,
      'weight': settings.weight,
      'birthday': settings.birthday,
      'gender': settings.gender,
      'goals': settings.goals.toJson(),
    });
  }

  Future<void> _syncHealthFiles() async {
    // Sync wear sport status first to commit standalone workout logs on the watch
    try {
      logger.info('syncing wear sport status');
      await DeviceConnection.instance.send(
        type: CmdType.health,
        subtype: HealthSubtype.getWearSportStatus,
        expectResponse: true,
        timeout: const Duration(seconds: 8),
      );
    } catch (e) {
      logger.error('failed to sync wear sport status', {'error': e.toString()});
    }

    final todayList = await _getWatchFileIds(getToday: true);
    final historyList = await _getWatchFileIds(getToday: false);

    final allIds = <FitnessDataId>{};
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

      final fileData = await _downloadWatchFile(id);
      if (fileData != null) {
        final success = await _syncHealthFile(id, fileData, workoutRanges);
        if (success) {
          newFilesSynced++;
          await _sendWatchFileAck(id);
        }
      }
    }

    logger.info('health sync complete', {'newFilesSynced': newFilesSynced});
  }

  Future<List<FitnessDataId>> _getWatchFileIds({required bool getToday}) async {
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

    final response = await DeviceConnection.instance.send(
      cmd: cmd,
      expectResponse: true,
      timeout: const Duration(seconds: 8),
    );

    if (response == null || !response.hasHealth()) {
      return [];
    }

    final bytes = response.health.activityRequestFileIds;
    if (bytes.isEmpty) return [];

    final list = <FitnessDataId>[];
    for (int i = 0; i < bytes.length; i += 7) {
      if (i + 7 > bytes.length) break;
      try {
        final idBytes = Uint8List.fromList(bytes.sublist(i, i + 7));
        list.add(FitnessDataId.fromBytes(idBytes));
      } catch (e) {
        logger.error('failed to parse fitness data id', {
          'error': e.toString(),
        });
      }
    }
    return list;
  }

  Future<Uint8List?> _downloadWatchFile(FitnessDataId id) async {
    final cmd = pb.Command()
      ..type = CmdType.health.value
      ..subtype = HealthSubtype.requestSingleFitnessId.value
      ..health = (pb.Health()..activityRequestFileIds = id.toBytes());

    return await DeviceConnection.instance.downloadData(cmd: cmd);
  }

  Future<void> _sendWatchFileAck(FitnessDataId id) async {
    final cmd = pb.Command()
      ..type = CmdType.health.value
      ..subtype = HealthSubtype.confirmFitnessId.value
      ..health = (pb.Health()..activitySyncAckFileIds = id.toBytes());
    await DeviceConnection.instance.send(cmd: cmd);
  }

  Future<bool> _syncHealthFile(
    FitnessDataId id,
    Uint8List fileData,
    List<Map<String, DateTime>> workoutRanges,
  ) async {
    try {
      final rawHex = fileData
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .take(20)
          .join(' ');
      logger.info('processing file', {
        'id': id.toHexString(),
        'size': fileData.length,
        'hex': rawHex,
      });

      if (fileData.length < 7) {
        logger.error('file too short', {'length': fileData.length});
        return false;
      }

      if (id.dataType == 0 && id.fileType == 0) {
        return await _syncDailyActivity(id, fileData, workoutRanges);
      } else if (id.dataType == 0 && (id.dailyType == 3 || id.dailyType == 2)) {
        return await _syncSleepSession(id, fileData);
      } else if (id.dataType == 1 && id.fileType == 1) {
        return await _syncWorkoutSession(id, fileData, workoutRanges);
      } else if (id.dataType == 1 && id.fileType == 0) {
        logger.info('skipping detailed samples file for workout', {
          'id': id.toHexString(),
        });
        return true;
      }

      logger.info('unknown watch health data type', {'dataType': id.dataType});
      return true;
    } catch (e, stack) {
      logger.error('failed to parse or sync watch log', {
        'error': e.toString(),
        'stack': stack.toString(),
      });
      return false;
    }
  }

  Future<bool> _syncDailyActivity(
    FitnessDataId id,
    Uint8List fileData,
    List<Map<String, DateTime>> workoutRanges,
  ) async {
    final records = HealthFileParser.parseDailyRecordFile(fileData, id);
    logger.info('parsed minute-by-minute daily logs', {
      'count': records.length,
    });

    final futures = <Future<dynamic>>[];
    final now = DateTime.now();
    for (final r in records) {
      var startTime = DateTime.fromMillisecondsSinceEpoch(r.timestamp * 1000);
      if (startTime.isAfter(now)) {
        startTime = now;
      }
      final endTime = startTime.add(const Duration(minutes: 1));

      final isOverlapping = workoutRanges.any((range) {
        return startTime.isBefore(range['end']!) &&
            endTime.isAfter(range['start']!);
      });

      if (r.steps != null && r.steps! > 0) {
        if (isOverlapping) {
          logger.info('skipping overlapping daily steps', {
            'timestamp': r.timestamp,
            'steps': r.steps,
          });
        } else {
          futures.add(
            PlatformModule.instance.invokeMethod('health.writeSteps', {
              'startTime': startTime
                  .subtract(const Duration(minutes: 1))
                  .millisecondsSinceEpoch,
              'endTime': startTime.millisecondsSinceEpoch,
              'count': r.steps!,
            }),
          );
        }
      }
      if (r.hr != null && r.hr! > 0) {
        futures.add(
          PlatformModule.instance.invokeMethod('health.writeHeartRate', {
            'time': startTime.millisecondsSinceEpoch,
            'bpm': r.hr!,
          }),
        );
      }
      if (r.spo2 != null && r.spo2! > 0) {
        futures.add(
          PlatformModule.instance.invokeMethod('health.writeOxygenSaturation', {
            'time': startTime.millisecondsSinceEpoch,
            'percentage': r.spo2!.toDouble().clamp(0.0, 100.0),
          }),
        );
      }
    }

    if (futures.isNotEmpty) {
      logger.info('syncing data points to health connect', {
        'count': futures.length,
      });
      await _executePlatformBatch(futures);
      logger.info('health connect sync complete');
    }
    return true;
  }

  Future<void> _executePlatformBatch(
    List<Future<dynamic>> futures, {
    int batchSize = 50,
  }) async {
    for (int i = 0; i < futures.length; i += batchSize) {
      final end = (i + batchSize < futures.length)
          ? i + batchSize
          : futures.length;
      final batch = futures.sublist(i, end);
      await Future.wait(batch);
    }
  }

  Future<bool> _syncSleepSession(FitnessDataId id, Uint8List fileData) async {
    final sleep = HealthFileParser.parseSleepReportFile(fileData, id);
    logger.info('parsed sleep report', {
      'deep': sleep.deepDuration,
      'light': sleep.lightDuration,
    });

    if (sleep.stages.isNotEmpty) {
      final minStartTime = sleep.stages
          .map((s) => s.startTime)
          .reduce((a, b) => a < b ? a : b);
      final maxEndTime = sleep.stages
          .map((s) => s.endTime)
          .reduce((a, b) => a > b ? a : b);

      final sessionStart = DateTime.fromMillisecondsSinceEpoch(
        minStartTime * 1000,
      );
      final sessionEnd = DateTime.fromMillisecondsSinceEpoch(maxEndTime * 1000);

      final stagesList = sleep.stages.map((stage) {
        return {
          'start': stage.startTime * 1000,
          'end': stage.endTime * 1000,
          'stage': stage.sleepState,
        };
      }).toList();

      try {
        await PlatformModule.instance.invokeMethod('health.writeSleepSession', {
          'startTime': sessionStart.millisecondsSinceEpoch,
          'endTime': sessionEnd.millisecondsSinceEpoch,
          'stages': stagesList,
        });
        logger.info('synced native sleep session', {
          'start': sessionStart.toIso8601String(),
          'end': sessionEnd.toIso8601String(),
          'stagesCount': stagesList.length,
        });
      } catch (e) {
        logger.error('failed to sync sleep session', {'error': e.toString()});
      }
    }
    return true;
  }

  Future<bool> _syncWorkoutSession(
    FitnessDataId id,
    Uint8List fileData,
    List<Map<String, DateTime>> workoutRanges,
  ) async {
    final workout = HealthFileParser.parseWorkoutReportFile(fileData, id);
    logger.info('parsed workout report', {
      'duration': workout.duration,
      'distance': workout.distance,
      'calories': workout.calories,
      'steps': workout.steps,
      'sportType': workout.sportType,
    });

    if (workout.duration != null && workout.duration! > 0) {
      final sTime = DateTime.fromMillisecondsSinceEpoch(
        workout.timestamp * 1000,
      );
      final eTime = sTime.add(Duration(seconds: workout.duration!));

      workoutRanges.add({'start': sTime, 'end': eTime});

      final workoutTitle = _getWorkoutTitle(workout.sportType ?? 0);
      try {
        await PlatformModule.instance
            .invokeMethod('health.writeWorkoutSession', {
              'startTime': sTime.millisecondsSinceEpoch,
              'endTime': eTime.millisecondsSinceEpoch,
              'sportType': workout.sportType ?? 0,
              'title': workoutTitle,
              'calories': workout.calories?.toDouble(),
              'distance': workout.distance?.toDouble(),
              'skipCount': workout.sportType == 14 ? workout.steps : null,
            });
        logger.info('synced native workout session', {
          'title': workoutTitle,
          'start': sTime.toIso8601String(),
          'end': eTime.toIso8601String(),
        });
      } catch (e) {
        logger.error('failed to sync native workout session', {
          'error': e.toString(),
        });
      }
    }
    return true;
  }

  String _getWorkoutTitle(int sportType) {
    switch (sportType) {
      case 1:
        return 'Outdoor run';
      case 2:
        return 'Outdoor walk';
      case 3:
        return 'Treadmill';
      case 4:
        return 'Indoor walk';
      case 5:
        return 'Cross country run';
      case 6:
        return 'Outdoor biking';
      case 7:
        return 'Indoor biking';
      case 8:
        return 'Free training';
      case 9:
        return 'Pool swimming';
      case 10:
        return 'Open water swimming';
      case 11:
        return 'Elliptical';
      case 12:
        return 'Yoga';
      case 13:
        return 'Rowing machine';
      case 14:
        return 'Jump rope';
      case 15:
        return 'Hiking';
      case 16:
        return 'HIIT';
      case 19:
        return 'Basketball';
      case 20:
        return 'Golf';
      case 21:
        return 'Skiing';
      case 22:
        return 'Outdoor step';
      case 24:
        return 'Rock climbing';
      case 25:
        return 'Scuba diving';
      default:
        return 'Workout';
    }
  }

  Future<void> saveHealth(Health settings) async {
    await HealthBlob.instance.update(settings);
    if (DeviceConnection.instance.connected.value) {
      await _syncUserProfile();
    }
  }
}
