import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import '../module.dart';
import '../device/module.dart';
import '../device/connection.dart';
import '../device/proto/xiaomi.pb.dart' as pb;
import '../device/proto/constants.dart';
import '../debug/logger.dart';
import '../notifications/blobs/filters.dart';
import '../actions/blobs/actions.dart';
import 'screen.dart';

class AppsModule implements TabModule {
  @override
  String get name => 'apps';

  @override
  IconData get icon => Icons.apps;

  @override
  Widget get screen => const AppsScreen();

  static final AppsModule _instance = AppsModule._();
  static AppsModule get instance => _instance;
  AppsModule._();

  // State Notifiers
  final ValueNotifier<List<pb.RpkInfoList>> installedApps = ValueNotifier<List<pb.RpkInfoList>>([]);
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isUploading = ValueNotifier<bool>(false);
  final ValueNotifier<double> uploadProgress = ValueNotifier<double>(0.0);
  final ValueNotifier<String> uploadStatus = ValueNotifier<String>('');

  @override
  Future<void> start() async {
    DeviceModule.instance.register(this);
  }

  @override
  Future<void> sync() async {
    if (!DeviceConnection.connected.value) return;

    // Refresh RPK app list on start
    await fetchInstalledApps();

    // Auto sideload Messages Watch App if SMS mirroring is enabled
    if (FiltersBlob.smsEnabled) {
      Logger.info('apps', 'SMS mirroring enabled: checking com.misync.messages...');
      
      // Auto register incoming message action in UI
      ActionsBlob.ensureMessageReplyAction();

      try {
        final ByteData assetData = await rootBundle.load('assets/rpk/com.misync.messages.rpk');
        final Uint8List assetBytes = assetData.buffer.asUint8List();
        
        final localSha = sha256.convert(assetBytes).bytes;
        final localShaHex = hex.encode(localSha).toUpperCase();

        final watchApp = installedApps.value.firstWhere(
          (app) => app.id == 'com.misync.messages',
          orElse: () => pb.RpkInfoList(),
        );

        bool needsUpdate = false;
        if (watchApp.id.isEmpty) {
          Logger.info('apps', 'com.misync.messages not installed on watch: triggering sideload');
          needsUpdate = true;
        } else {
          final watchShaHex = hex.encode(watchApp.sha).toUpperCase();
          if (localShaHex != watchShaHex) {
            Logger.info('apps', 'com.misync.messages SHA mismatch (local=$localShaHex, watch=$watchShaHex): triggering update');
            needsUpdate = true;
          } else {
            Logger.info('apps', 'com.misync.messages is up to date.');
          }
        }

        if (needsUpdate) {
          isUploading.value = true;
          final success = await installApp('com.misync.messages', 1, assetBytes);
          isUploading.value = false;
          Logger.info('apps', 'Auto sideload com.misync.messages result: $success');
        }
      } catch (e) {
        Logger.error('apps', 'Error during com.misync.messages auto sync: $e');
      }
    }
  }

  Future<void> fetchInstalledApps() async {
    if (!DeviceConnection.connected.value) return;
    isSyncing.value = true;
    try {
      Logger.info('apps', 'Querying installed RPK list from watch...');
      final response = await DeviceConnection.send(
        type: CmdType.thirdPartyApp,
        subtype: 0, // CMD_RPK_LIST
        expectResponse: true,
      );
      if (response != null && response.hasRpk() && response.rpk.hasRpkList()) {
        final list = response.rpk.rpkList.rpkInfo;
        Logger.info('apps', 'Received ${list.length} installed apps from watch.');
        installedApps.value = list;
      } else {
        Logger.warning('apps', 'Received empty or invalid RPK list response.');
      }
    } catch (e) {
      Logger.error('apps', 'failed to fetch installed apps: $e');
    } finally {
      isSyncing.value = false;
    }
  }

  Future<void> deleteApp(String packageId, List<int> sha) async {
    if (!DeviceConnection.connected.value) return;
    Logger.info('apps', 'Requesting deletion for RPK: $packageId');
    
    await DeviceConnection.send(
      type: CmdType.thirdPartyApp,
      subtype: 3, // CMD_RPK_DELETE
      builder: (cmd) => cmd.rpk = (pb.Rpk()
        ..rpkDel = (pb.RpkInfoList()
          ..id = packageId
          ..sha = sha
        )
      ),
    );

    // Refresh list (watch doesn't reply to delete, it notifies us when deleted)
    await Future.delayed(const Duration(seconds: 1));
    await fetchInstalledApps();
  }

  Future<bool> installApp(String packageId, int versionCode, Uint8List fileBytes) async {
    if (!DeviceConnection.connected.value) {
      uploadStatus.value = 'Not connected';
      return false;
    }
    uploadProgress.value = 0.0;
    uploadStatus.value = 'Initiating installation...';

    try {
      // 1. Send CMD_RPK_INSTALL (type 20, subtype 1)
      Logger.info('apps', 'Sending RPK install start command for $packageId ($versionCode)');
      final installResponse = await DeviceConnection.send(
        type: CmdType.thirdPartyApp,
        subtype: 1, // CMD_RPK_INSTALL
        builder: (cmd) => cmd.rpk = (pb.Rpk()
          ..rpkInfo = (pb.RpkInfo()
            ..id = packageId
            ..versionCode = versionCode
            ..size = fileBytes.length
          )
        ),
        expectResponse: true,
      );

      if (installResponse == null || installResponse.status != 0) {
        uploadStatus.value = 'Installation request rejected';
        Logger.error('apps', 'RPK install request rejected status: ${installResponse?.status}');
        return false;
      }

      // 2. Send upload start request (type 22, subtype 0)
      uploadStatus.value = 'Initiating upload channel...';
      final md5Sum = md5.convert(fileBytes).bytes;
      final uploadResponse = await DeviceConnection.send(
        type: CmdType.dataUpload,
        subtype: 0, // CMD_UPLOAD_START
        builder: (cmd) => cmd.dataUpload = (pb.DataUpload()
          ..dataUploadRequest = (pb.DataUploadRequest()
            ..type = 64 // TYPE_RPK
            ..md5sum = md5Sum
            ..size = fileBytes.length
          )
        ),
        expectResponse: true,
      );

      if (uploadResponse == null || !uploadResponse.hasDataUpload() || !uploadResponse.dataUpload.hasDataUploadAck()) {
        uploadStatus.value = 'Upload channel request rejected';
        Logger.error('apps', 'Data upload start request rejected');
        return false;
      }

      final ack = uploadResponse.dataUpload.dataUploadAck;
      final int chunkSize = ack.hasChunkSize() ? ack.chunkSize : 2048;
      final int resumePosition = ack.hasResumePosition() ? ack.resumePosition : 0;
      Logger.info('apps', 'Upload accepted. ChunkSize=$chunkSize, ResumePosition=$resumePosition');

      // 3. Construct raw payload
      // [type: 0x00 (1)] [rpk_type: 0x40 (1)] [md5 (16)] [size (4)] [bytes]
      final builder = BytesBuilder()
        ..addByte(0)
        ..addByte(64) // TYPE_RPK
        ..add(md5Sum);

      final sizeBytes = ByteData(4)..setUint32(0, fileBytes.length, Endian.little);
      builder.add(sizeBytes.buffer.asUint8List());
      builder.add(fileBytes.sublist(resumePosition));

      final payload = builder.takeBytes();
      final crc = _crc32(payload);
      final crcBytes = ByteData(4)..setUint32(0, crc, Endian.little);

      final fullPayload = BytesBuilder()
        ..add(payload)
        ..add(crcBytes.buffer.asUint8List());

      final finalBytes = fullPayload.takeBytes();

      // 4. Stream chunks over plain data channel
      final int partSize = chunkSize - 4; // 4-byte header for totalParts & currentPart
      final int totalParts = (finalBytes.length / partSize).ceil();

      for (int i = 0; i < totalParts; i++) {
        final currentPart = i + 1;
        final int startIndex = i * partSize;
        final int endIndex = (currentPart * partSize > finalBytes.length) ? finalBytes.length : currentPart * partSize;

        final chunkPayload = finalBytes.sublist(startIndex, endIndex);
        final chunkToSend = BytesBuilder();

        // 4-byte header: totalParts (2 bytes) + currentPart (2 bytes)
        final headerBytes = ByteData(4)
          ..setUint16(0, totalParts, Endian.little)
          ..setUint16(2, currentPart, Endian.little);
        chunkToSend.add(headerBytes.buffer.asUint8List());
        chunkToSend.add(chunkPayload);

        await DeviceConnection.sendDataChunk(chunkToSend.takeBytes());

        uploadProgress.value = currentPart / totalParts;
        uploadStatus.value = 'Uploading app: ${(uploadProgress.value * 100).toStringAsFixed(0)}%';
      }

      uploadStatus.value = 'Finalizing installation...';
      // Wait for device to unpack and notify
      await Future.delayed(const Duration(seconds: 3));

      uploadStatus.value = 'Success!';
      await fetchInstalledApps();
      return true;
    } catch (e) {
      uploadStatus.value = 'Upload error: $e';
      Logger.error('apps', 'Error uploading RPK: $e');
      return false;
    }
  }

  // Pure Dart CRC32 helper
  int _crc32(List<int> bytes) {
    final table = List<int>.generate(256, (i) {
      int c = i;
      for (int k = 0; k < 8; ++k) {
        if ((c & 1) != 0) {
          c = 0xEDB88320 ^ (c >> 1);
        } else {
          c = c >> 1;
        }
      }
      return c;
    });

    int c = 0xFFFFFFFF;
    for (int i = 0; i < bytes.length; ++i) {
      c = table[(c ^ bytes[i]) & 0xFF] ^ (c >> 8);
    }
    return c ^ 0xFFFFFFFF;
  }
}
