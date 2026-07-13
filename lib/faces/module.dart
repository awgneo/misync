import 'dart:async';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:misync/screen.dart';
import '../device/module.dart';
import '../device/proto/xiaomi.pb.dart';
import '../device/proto/constants.dart';
import 'screen.dart';

class FacesModule extends TabModule {
  @override
  String get name => 'faces';

  @override
  IconData get icon => Icons.watch;

  @override
  late final Screen screen = FacesScreen(this);

  static final FacesModule _module = FacesModule._();
  static FacesModule get module => _module;
  FacesModule._();

  final faces = ValueNotifier<List<WatchfaceInfo>>([]);

  @override
  Future<void> start() async {}

  @override
  Future<void> sync() async {
    await loadFaces();
  }

  Future<void> loadFaces() async {
    if (!DeviceModule.module.connection.connected.value) return;

    logger.info('querying installed watch faces from watch');
    final response = await DeviceModule.module.connection.send(
      type: CmdType.watchface,
      subtype: WatchfaceSubtype.list,
      expectResponse: true,
    );

    if (response == null ||
        !response.hasWatchface() ||
        !response.watchface.hasWatchfaceList()) {
      logger.error('failed to pull watch faces from watch');
      return;
    }

    final list = response.watchface.watchfaceList.watchface;
    faces.value = list;
    logger.info('watch faces sync complete: ${list.length} faces found');
  }

  Future<void> setFace(String id) async {
    if (!DeviceModule.module.connection.connected.value) return;

    logger.info('setting active watch face to $id');
    final result = await DeviceModule.module.connection.send(
      type: CmdType.watchface,
      subtype: WatchfaceSubtype.set,
      expectResponse: true,
      builder: (cmd) => cmd.watchface = (Watchface()..watchfaceId = id),
    );

    if (result != null) {
      await loadFaces();
    }
  }

  Future<void> deleteFace(String id) async {
    if (!DeviceModule.module.connection.connected.value) return;

    logger.info('deleting watch face $id');
    final result = await DeviceModule.module.connection.send(
      type: CmdType.watchface,
      subtype: WatchfaceSubtype.delete,
      expectResponse: true,
      builder: (cmd) => cmd.watchface = (Watchface()..watchfaceId = id),
    );

    if (result != null) {
      await loadFaces();
    }
  }

  Future<bool> installFace(String fileName, Uint8List bytes) async {
    if (!DeviceModule.module.connection.connected.value) return false;

    logger.info(
      'initiating watch face installation for $fileName (${bytes.length} bytes)',
    );

    // 1. Calculate MD5 Sum and set custom face ID
    final md5Sum = md5.convert(bytes).bytes;
    final watchfaceId = hex.encode(md5Sum).toUpperCase().substring(0, 16);

    // 2. Send Install Start Command
    final installStart = WatchfaceInstallStart()
      ..id = watchfaceId
      ..size = bytes.length;

    final response = await DeviceModule.module.connection.send(
      type: CmdType.watchface,
      subtype: WatchfaceSubtype.installStart,
      expectResponse: true,
      builder: (cmd) =>
          cmd.watchface = (Watchface()..watchfaceInstallStart = installStart),
    );

    if (response == null ||
        !response.hasWatchface() ||
        response.watchface.installStatus != 0) {
      logger.error('watch face installation start request rejected');
      return false;
    }

    logger.info(
      'watch face installation start request accepted. Uploading binary...',
    );

    // 3. Upload raw binary data (Type 16 = watchface)
    final success = await DeviceModule.module.connection.uploadData(
      type: 16,
      bytes: bytes,
    );

    if (!success) {
      logger.error('failed to upload watch face binary data');
      return false;
    }

    logger.info(
      'binary upload completed. Sending finish installation command...',
    );

    // 4. Send Install Finish Command
    final installFinish = WatchfaceInstallFinish()..id = watchfaceId;

    final finishResult = await DeviceModule.module.connection.send(
      type: CmdType.watchface,
      subtype: WatchfaceSubtype.installFinish,
      expectResponse: true,
      builder: (cmd) =>
          cmd.watchface = (Watchface()..watchfaceInstallFinish = installFinish),
    );

    if (finishResult == null) {
      logger.error('failed to complete watch face installation');
      return false;
    }

    logger.info(
      'watch face installation finish command accepted. Activating...',
    );

    // 5. Activate watch face
    await setFace(watchfaceId);
    return true;
  }
}
