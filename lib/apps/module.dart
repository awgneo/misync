import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive.dart';
import '../module.dart';
import '../device/module.dart';
import '../device/connection.dart';
import '../device/proto/xiaomi.pb.dart' as pb;
import '../device/proto/constants.dart';
import '../debug/logger.dart';
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

  final Map<String, String> internalApps = {};

  // State Notifiers
  final ValueNotifier<List<pb.RpkInfoList>> installedApps =
      ValueNotifier<List<pb.RpkInfoList>>([]);
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isUploading = ValueNotifier<bool>(false);
  final ValueNotifier<double> uploadProgress = ValueNotifier<double>(0.0);
  final ValueNotifier<String> uploadStatus = ValueNotifier<String>('');

  @override
  Future<void> start() async {
    DeviceModule.instance.register(this);
    DeviceConnection.listen(_handleCommand);
    await _loadInternalApps();
  }

  @override
  Future<void> sync() async {
    if (!DeviceConnection.connected.value) return;
    await fetchInstalledApps();
  }

  Future<void> _handleCommand(pb.Command cmd) async {
    if (cmd.type == CmdType.thirdPartyApp.value) {
      if (cmd.subtype == ThirdPartyAppSubtype.requestPhoneAppStatus.value) {
        await _handleAppStatusRequest(cmd);
      }
    }
  }

  Future<void> _handleAppStatusRequest(pb.Command cmd) async {
    String packageName = '';
    List<int> fingerprint = [];
    bool hasQuery = false;

    if (cmd.hasThirdPartyApp() && cmd.thirdPartyApp.hasAppStatusReq()) {
      packageName = cmd.thirdPartyApp.appStatusReq.packageName;
      fingerprint = cmd.thirdPartyApp.appStatusReq.fingerprint;
      hasQuery = true;
    }

    if (hasQuery) {
      Logger.info('apps', 'Watch queried app status for: $packageName');
      await sendAppStatus(packageName, true, fingerprint: fingerprint);
    }
  }

  Future<void> _loadInternalApps() async {
    try {
      final AssetManifest assetManifest =
          await AssetManifest.loadFromAssetBundle(rootBundle);
      final List<String> allAssets = assetManifest.listAssets();
      final rpkPaths = allAssets.where(
        (path) => path.startsWith('assets/rpk/') && path.endsWith('.rpk'),
      );

      internalApps.clear();
      for (final path in rpkPaths) {
        try {
          final ByteData assetData = await rootBundle.load(path);
          final Uint8List assetBytes = assetData.buffer.asUint8List();
          final archive = ZipDecoder().decodeBytes(assetBytes);
          final manifestFile = archive.findFile('manifest.json');
          if (manifestFile != null) {
            final manifestString = utf8.decode(
              manifestFile.content as List<int>,
            );
            final manifestJson =
                jsonDecode(manifestString) as Map<String, dynamic>;
            final packageId = manifestJson['package'] as String? ?? '';
            final appName =
                manifestJson['name'] as String? ?? packageId.split('.').last;
            if (packageId.isNotEmpty) {
              internalApps[packageId] = appName;
            }
          }
        } catch (e) {
          Logger.error(
            'apps',
            'Failed to parse manifest for asset RPK $path: $e',
          );
        }
      }
      Logger.info('apps', 'Loaded internal apps: $internalApps');
    } catch (e) {
      Logger.error(
        'apps',
        'Failed to load internal apps from asset manifest: $e',
      );
    }
  }

  Future<void> launch(String packageId, {String? uri}) async {
    Logger.info('apps', 'Launching watch app: $packageId');

    final appInfo = pb.ThirdPartyAppInfo()..packageName = packageId;
    final installed = installedApps.value.firstWhere(
      (app) => app.id == packageId,
      orElse: () => pb.RpkInfoList(),
    );
    if (installed.id.isNotEmpty && installed.sha.isNotEmpty) {
      appInfo.fingerprint = installed.sha;
      Logger.info(
        'apps',
        'Found fingerprint for $packageId: ${hex.encode(installed.sha)}',
      );
    }

    final launchReq = pb.ThirdPartyAppLaunch()..appInfo = appInfo;
    if (uri != null) {
      launchReq.uri = uri;
    }

    await DeviceConnection.send(
      type: CmdType.thirdPartyApp,
      subtype: ThirdPartyAppSubtype.launchApp,
      builder: (cmd) =>
          cmd.thirdPartyApp = (pb.ThirdPartyApp()..appLaunchReq = launchReq),
    );
  }

  Future<bool> install(String packageId) async {
    if (!DeviceConnection.connected.value) return false;

    // Refresh RPK app list if empty
    if (installedApps.value.isEmpty) {
      await fetchInstalledApps();
    }

    if (!internalApps.containsKey(packageId)) {
      Logger.error(
        'apps',
        'App $packageId is not an internal app and cannot be auto-installed.',
      );
      return false;
    }

    try {
      final ByteData assetData = await rootBundle.load(
        'assets/rpk/$packageId.rpk',
      );
      final Uint8List assetBytes = assetData.buffer.asUint8List();

      final localFileSha = sha256.convert(assetBytes).bytes;
      final localFileShaHex = hex.encode(localFileSha).toUpperCase();

      final watchApp = installedApps.value.firstWhere(
        (app) => app.id == packageId,
        orElse: () => pb.RpkInfoList(),
      );

      final prefs = await SharedPreferences.getInstance();
      final installedSha = ''; // Force sideload during debug to push latest code

      bool needsUpdate = false;
      if (watchApp.id.isEmpty) {
        Logger.info(
          'apps',
          '$packageId not installed on watch: triggering sideload',
        );
        needsUpdate = true;
      } else if (installedSha != localFileShaHex) {
        Logger.info(
          'apps',
          '$packageId file updated locally (prev=$installedSha, new=$localFileShaHex): triggering update',
        );
        needsUpdate = true;
      } else {
        Logger.info('apps', '$packageId is up to date.');
      }

      if (needsUpdate) {
        isUploading.value = true;
        final success = await installRpk(packageId, 1, assetBytes);
        isUploading.value = false;
        Logger.info('apps', 'Auto sideload $packageId result: $success');
        if (success) {
          await prefs.setString(
            'installed_rpk_sha_$packageId',
            localFileShaHex,
          );
        }
        return success;
      }
      return true;
    } catch (e) {
      Logger.error('apps', 'Error during $packageId auto sync: $e');
      return false;
    }
  }

  Future<bool> installRpk(
    String packageId,
    int versionCode,
    Uint8List fileBytes,
  ) async {
    if (!DeviceConnection.connected.value) {
      uploadStatus.value = 'Not connected';
      return false;
    }
    uploadProgress.value = 0.0;
    uploadStatus.value = 'Initiating installation...';

    try {
      // 1. Send CMD_RPK_INSTALL (type 20, subtype 1)
      Logger.info(
        'apps',
        'Sending RPK install start command for $packageId ($versionCode)',
      );
      final installResponse = await DeviceConnection.send(
        type: CmdType.thirdPartyApp,
        subtype: ThirdPartyAppSubtype.rpkInstall,
        builder: (cmd) =>
            cmd.thirdPartyApp = (pb.ThirdPartyApp()
              ..rpkInfo = (pb.RpkInfo()
                ..id = packageId
                ..unknown2 = versionCode
                ..size = fileBytes.length)),
        expectResponse: true,
      );

      if (installResponse == null || installResponse.status != 0) {
        uploadStatus.value = 'Installation request rejected';
        Logger.error(
          'apps',
          'RPK install request rejected status: ${installResponse?.status}',
        );
        return false;
      }

      // 2. Send upload start request (type 22, subtype 0)
      uploadStatus.value = 'Initiating upload channel...';
      final md5Sum = md5.convert(fileBytes).bytes;
      final uploadResponse = await DeviceConnection.send(
        type: CmdType.dataUpload,
        subtype: DataUploadSubtype.uploadStart,
        builder: (cmd) =>
            cmd.dataUpload = (pb.DataUpload()
              ..dataUploadRequest = (pb.DataUploadRequest()
                ..type =
                    64 // TYPE_RPK
                ..md5sum = md5Sum
                ..size = fileBytes.length)),
        expectResponse: true,
      );

      if (uploadResponse == null ||
          !uploadResponse.hasDataUpload() ||
          !uploadResponse.dataUpload.hasDataUploadAck()) {
        uploadStatus.value = 'Upload channel request rejected';
        Logger.error('apps', 'Data upload start request rejected');
        return false;
      }

      final ack = uploadResponse.dataUpload.dataUploadAck;
      final int chunkSize = ack.hasChunkSize() ? ack.chunkSize : 2048;
      final int resumePosition = ack.hasResumePosition()
          ? ack.resumePosition
          : 0;
      Logger.info(
        'apps',
        'Upload accepted. ChunkSize=$chunkSize, ResumePosition=$resumePosition',
      );

      // 3. Construct raw payload
      // [type: 0x00 (1)] [rpk_type: 0x40 (1)] [md5 (16)] [size (4)] [bytes]
      final builder = BytesBuilder()
        ..addByte(0)
        ..addByte(64) // TYPE_RPK
        ..add(md5Sum);

      final sizeBytes = ByteData(4)
        ..setUint32(0, fileBytes.length, Endian.little);
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
      final int partSize =
          chunkSize - 4; // 4-byte header for totalParts & currentPart
      final int totalParts = (finalBytes.length / partSize).ceil();

      for (int i = 0; i < totalParts; i++) {
        final currentPart = i + 1;
        final int startIndex = i * partSize;
        final int endIndex = (currentPart * partSize > finalBytes.length)
            ? finalBytes.length
            : currentPart * partSize;

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
        uploadStatus.value =
            'Uploading app: ${(uploadProgress.value * 100).toStringAsFixed(0)}%';
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

  Future<void> fetchInstalledApps() async {
    if (!DeviceConnection.connected.value) return;
    isSyncing.value = true;
    try {
      Logger.info('apps', 'Querying installed RPK list from watch...');
      final response = await DeviceConnection.send(
        type: CmdType.thirdPartyApp,
        subtype: ThirdPartyAppSubtype.rpkList,
        expectResponse: true,
      );
      if (response != null &&
          response.hasThirdPartyApp() &&
          response.thirdPartyApp.hasRpkList()) {
        final list = response.thirdPartyApp.rpkList.rpkInfo;
        Logger.info(
          'apps',
          'Received ${list.length} installed apps from watch.',
        );
        installedApps.value = list;
      } else {
        Logger.info('apps', 'Received empty or invalid RPK list response.');
      }
    } catch (e) {
      Logger.error('apps', 'failed to fetch installed apps: $e');
    } finally {
      isSyncing.value = false;
    }
  }

  Future<void> sendAppStatus(String packageId, bool isConnected, {List<int>? fingerprint}) async {
    if (!DeviceConnection.connected.value) return;

    final appInfo = pb.ThirdPartyAppInfo()..packageName = packageId;
    if (fingerprint != null && fingerprint.isNotEmpty) {
      appInfo.fingerprint = fingerprint;
    } else {
      final installed = installedApps.value.firstWhere(
        (app) => app.id == packageId,
        orElse: () => pb.RpkInfoList(),
      );
      if (installed.id.isNotEmpty && installed.sha.isNotEmpty) {
        appInfo.fingerprint = installed.sha;
      } else {
        appInfo.fingerprint = [];
      }
    }

    final statusResp = pb.ThirdPartyAppStatus()
      ..appInfo = appInfo
      ..status = isConnected ? 1 : 2;

    Logger.info(
      'apps',
      'Proactively sending app status for $packageId: ${isConnected ? "connected" : "disconnected"}',
    );

    await DeviceConnection.send(
      type: CmdType.thirdPartyApp,
      subtype: ThirdPartyAppSubtype.responsePhoneAppStatus,
      builder: (cmd) =>
          cmd.thirdPartyApp = (pb.ThirdPartyApp()..appStatusResp = statusResp),
    );
  }

  Future<void> deleteApp(String packageId, List<int> sha) async {
    if (!DeviceConnection.connected.value) return;
    Logger.info('apps', 'Requesting deletion for RPK: $packageId');

    await DeviceConnection.send(
      type: CmdType.thirdPartyApp,
      subtype: ThirdPartyAppSubtype.rpkDelete,
      builder: (cmd) =>
          cmd.thirdPartyApp = (pb.ThirdPartyApp()
            ..appStatusReq = (pb.ThirdPartyAppInfo()
              ..packageName = packageId
              ..fingerprint = sha)),
    );

    // Update local state immediately
    installedApps.value = installedApps.value
        .where((app) => app.id != packageId)
        .toList();
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
