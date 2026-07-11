import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:archive/archive.dart';
import '../module.dart';
import '../device/module.dart';
import '../device/connection.dart';
import '../device/proto/xiaomi.pb.dart' as pb;
import '../device/proto/constants.dart';
import '../platform/module.dart';
import '../crc32.dart';
import 'blobs/apps.dart';
import 'screen.dart';

class AppsModule extends TabModule {
  @override
  String get name => 'apps';

  @override
  IconData get icon => Icons.apps;

  @override
  Widget get screen => const AppsScreen();

  static final AppsModule _instance = AppsModule._();
  static AppsModule get instance => _instance;
  AppsModule._();

  final List<String> internalApps = [];

  @override
  Future<void> start() async {
    DeviceModule.instance.register(this);
    DeviceConnection.listen(_handleCommand);
    await _loadInternalApps();
  }

  Future<void> _handleCommand(pb.Command cmd) async {
    if (cmd.type == CmdType.thirdPartyApp.value) {
      if (cmd.subtype == ThirdPartyAppSubtype.requestPhoneAppStatus.value) {
        await _handleAppStatusRequest(cmd);
      }
    } else if (cmd.type == CmdType.notification.value &&
        cmd.subtype == NotificationSubtype.iconQuery.value) {
      await _handleIconQuery(cmd);
    }
  }

  Future<void> _handleAppStatusRequest(pb.Command cmd) async {
    String package = '';
    List<int> fingerprint = [];
    bool hasQuery = false;

    if (cmd.hasThirdPartyApp() && cmd.thirdPartyApp.hasAppStatusReq()) {
      package = cmd.thirdPartyApp.appStatusReq.packageName;
      fingerprint = cmd.thirdPartyApp.appStatusReq.fingerprint;
      hasQuery = true;
    }

    if (hasQuery) {
      logger.info('Watch queried app status for: $package');
      await sendAppStatus(package, true, fingerprint: fingerprint);
    }
  }

  Future<void> _handleIconQuery(pb.Command cmd) async {
    if (!cmd.hasNotification() ||
        !cmd.notification.hasNotificationIconQuery()) {
      return;
    }
    final query = cmd.notification.notificationIconQuery;
    final package = query.package;
    logger.info('Watch requested app icon for package: $package');

    try {
      // 1. Send icon request (type 7, subtype 15) to watch to request size and format
      final packageProto = pb.NotificationIconPackage()..package = package;
      logger.info('Sending iconRequest (type 7, subtype 15) to watch...');
      final iconRequestResponse = await DeviceConnection.send(
        type: CmdType.notification,
        subtype: NotificationSubtype.iconRequest, // 15
        builder: (c) =>
            c.notification = (pb.Notification()
              ..notificationIconReply = packageProto),
        expectResponse: true,
      );

      if (iconRequestResponse == null ||
          !iconRequestResponse.hasNotification() ||
          !iconRequestResponse.notification.hasNotificationIconRequest()) {
        logger.error(
          'Watch did not respond to iconRequest or format was invalid',
        );
        return;
      }

      final iconReq = iconRequestResponse.notification.notificationIconRequest;
      final int pixelFormat = iconReq.pixelFormat;
      final int size = iconReq.size;
      logger.info('Watch responded: format=$pixelFormat, size=$size pixels');

      // 2. Fetch the app icon raw ARGB bytes from Android
      final Uint8List? rawBytes = await PlatformModule.instance
          .invokeMethod<Uint8List>('getAppIcon', {
            'packageName': package,
            'size': size,
          });

      if (rawBytes == null || rawBytes.isEmpty) {
        logger.error('Failed to retrieve icon bytes from Android for $package');
        return;
      }

      // 3. Format/Compress raw RGBA_8888 bytes to the watch's requested pixelFormat
      Uint8List formattedBytes;
      if (pixelFormat == 2 || pixelFormat == 3 || pixelFormat == 4) {
        // BGRA_8888 (Swap R and B channels)
        formattedBytes = Uint8List.fromList(rawBytes);
        for (int i = 0; i < formattedBytes.length; i += 4) {
          final r = formattedBytes[i];
          formattedBytes[i] = formattedBytes[i + 2];
          formattedBytes[i + 2] = r;
        }
      } else if (pixelFormat == 7) {
        // Swap channels and compress to RGB565 + Alpha
        formattedBytes = Uint8List((rawBytes.length ~/ 4) * 3);
        int dst = 0;
        for (int src = 0; src < rawBytes.length; src += 4) {
          final r = rawBytes[src];
          final g = rawBytes[src + 1];
          final b = rawBytes[src + 2];
          final a = rawBytes[src + 3];
          formattedBytes[dst] = ((b >> 3) & 31) | ((g & 28) << 3);
          formattedBytes[dst + 1] = (r & 248) | ((g >> 5) & 7);
          formattedBytes[dst + 2] = a;
          dst += 3;
        }
      } else if (pixelFormat == 8) {
        // Compress to RGB565 + Alpha
        formattedBytes = Uint8List((rawBytes.length ~/ 4) * 3);
        int dst = 0;
        for (int src = 0; src < rawBytes.length; src += 4) {
          final r = rawBytes[src];
          final g = rawBytes[src + 1];
          final b = rawBytes[src + 2];
          final a = rawBytes[src + 3];
          formattedBytes[dst] = (r & 248) | ((g >> 5) & 7);
          formattedBytes[dst + 1] = ((g & 28) << 3) | ((b >> 3) & 31);
          formattedBytes[dst + 2] = a;
          dst += 3;
        }
      } else {
        // Fallback: use raw RGBA_8888
        formattedBytes = rawBytes;
      }

      // 4. Send the icon via Data Upload channel (type 22, subtype 0)
      final md5Sum = md5.convert(formattedBytes).bytes;
      logger.info(
        'Initiating icon upload stream (size=${formattedBytes.length} bytes)...',
      );
      final uploadResponse = await DeviceConnection.send(
        type: CmdType.dataUpload,
        subtype: DataUploadSubtype.uploadStart,
        builder: (c) =>
            c.dataUpload = (pb.DataUpload()
              ..dataUploadRequest = (pb.DataUploadRequest()
                ..type =
                    50 // TYPE_ICON
                ..md5sum = md5Sum
                ..size = formattedBytes.length)),
        expectResponse: true,
      );

      if (uploadResponse == null ||
          !uploadResponse.hasDataUpload() ||
          !uploadResponse.dataUpload.hasDataUploadAck()) {
        logger.error('Icon upload request rejected by watch');
        return;
      }

      final ack = uploadResponse.dataUpload.dataUploadAck;
      final int chunkSize = ack.hasChunkSize() ? ack.chunkSize : 2048;
      final int resumePosition = ack.hasResumePosition()
          ? ack.resumePosition
          : 0;

      // 5. Construct payload
      final builder = BytesBuilder()
        ..addByte(0)
        ..addByte(50) // TYPE_ICON
        ..add(md5Sum);

      final sizeBytes = ByteData(4)
        ..setUint32(0, formattedBytes.length, Endian.little);
      builder.add(sizeBytes.buffer.asUint8List());
      builder.add(formattedBytes.sublist(resumePosition));

      final payload = builder.takeBytes();
      final crc = Crc32.calculate(payload);
      final crcBytes = ByteData(4)..setUint32(0, crc, Endian.little);

      final finalBytes =
          (BytesBuilder()
                ..add(payload)
                ..add(crcBytes.buffer.asUint8List()))
              .takeBytes();

      // 6. Stream chunks
      final int partSize = chunkSize - 4;
      final int totalParts = (finalBytes.length / partSize).ceil();
      logger.info('Streaming icon in $totalParts parts...');

      for (int i = 0; i < totalParts; i++) {
        final currentPart = i + 1;
        final int startIndex = i * partSize;
        final int endIndex = (currentPart * partSize > finalBytes.length)
            ? finalBytes.length
            : currentPart * partSize;

        final chunkPayload = finalBytes.sublist(startIndex, endIndex);
        final chunkToSend = BytesBuilder();

        final headerBytes = ByteData(4)
          ..setUint16(0, totalParts, Endian.little)
          ..setUint16(2, currentPart, Endian.little);
        chunkToSend.add(headerBytes.buffer.asUint8List());
        chunkToSend.add(chunkPayload);

        await DeviceConnection.sendDataChunk(chunkToSend.takeBytes());
      }
      logger.info('Icon upload completed successfully for $package!');
    } catch (e, stack) {
      logger.error('Error uploading icon: $e\n$stack');
    }
  }

  Future<void> _loadInternalApps() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final allAssets = manifest.listAssets();

      final rpkPaths = allAssets.where(
        (path) => path.startsWith('assets/rpk/') && path.endsWith('.rpk'),
      );

      internalApps.clear();
      for (final path in rpkPaths) {
        final filename = path.split('/').last;
        final package = filename.substring(0, filename.length - 4);
        internalApps.add(package);
      }
      if (internalApps.isEmpty) {
        internalApps.add('com.misync.messages');
      }
      logger.info('Loaded internal apps: $internalApps');
    } catch (e) {
      logger.error(
        'Failed to load internal apps from manifest: $e. Falling back to hardcoded.',
      );
      internalApps.clear();
      internalApps.add('com.misync.messages');
    }
  }

  @override
  Future<void> sync() async {
    if (!DeviceConnection.connected.value) return;
    try {
      await _syncInternalApps();
      await _syncInstalledApps();
    } catch (e) {
      logger.error('Error during apps module sync: $e');
    }
  }

  Future<List<pb.RpkInfoList>> _syncInstalledApps() async {
    if (!DeviceConnection.connected.value) return const [];
    try {
      logger.info('Querying installed RPK list from watch...');
      final response = await DeviceConnection.send(
        type: CmdType.thirdPartyApp,
        subtype: ThirdPartyAppSubtype.rpkList,
        expectResponse: true,
      );
      if (response != null &&
          response.hasThirdPartyApp() &&
          response.thirdPartyApp.hasRpkList()) {
        final list = response.thirdPartyApp.rpkList.rpkInfo;
        logger.info('Received ${list.length} installed apps from watch.');

        // Update AppsBlob registry based on the watch list
        final updatedRegistry = Map<String, App>.from(AppsBlob.instance.value);

        // A. Identify all external apps currently reported by the watch
        final Set<String> watchExternalAppIds = {};
        for (final watchApp in list) {
          final package = watchApp.id;
          final bool isInternal = internalApps.contains(package);

          if (!isInternal) {
            watchExternalAppIds.add(package);
            // Add or update external app in the blob registry
            updatedRegistry[package] = App(
              enabled: true,
              hash: '',
              name: watchApp.name.isNotEmpty
                  ? watchApp.name
                  : package.split('.').last,
              external: true,
              fingerprint: watchApp.sha,
            );
          } else {
            // It is an internal app. Ensure fingerprint is updated in our blob registry!
            final current = updatedRegistry[package];
            updatedRegistry[package] = App(
              enabled: current?.enabled ?? true,
              hash: current?.hash ?? '',
              name: current?.name ?? 'Messages',
              external: false,
              fingerprint: watchApp.sha,
            );
          }
        }

        // B. Remove any external apps from our blob registry that are no longer installed on the watch
        updatedRegistry.removeWhere((package, app) {
          return app.external && !watchExternalAppIds.contains(package);
        });

        // Save to blob
        AppsBlob.instance.update(updatedRegistry);

        return list;
      }
    } catch (e) {
      logger.error('failed to fetch installed apps: $e');
    }
    return const [];
  }

  Future<void> _syncInternalApps() async {
    for (final package in internalApps) {
      final bool isEnabled = AppsBlob.isEnabled(package);
      if (isEnabled) {
        await enable(package);
      } else {
        await disable(package);
      }
    }
  }

  Future<void> launch(String package, {String? uri}) async {
    logger.info('Launching watch app: $package');

    final appInfo = pb.ThirdPartyAppInfo()..packageName = package;
    final installed = AppsBlob.instance.value[package];
    if (installed != null && installed.fingerprint.isNotEmpty) {
      appInfo.fingerprint = installed.fingerprint;
      logger.info(
        'Found fingerprint for $package: ${hex.encode(installed.fingerprint)}',
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

  Future<bool> enable(String package) async {
    if (!DeviceConnection.connected.value) return false;

    if (!internalApps.contains(package)) {
      logger.error('App $package is not an internal app.');
      return false;
    }

    // 1. Mark as enabled in the blob first
    AppsBlob.setEnabled(package, true);

    try {
      final ByteData assetData = await rootBundle.load(
        'assets/rpk/$package.rpk',
      );
      final Uint8List assetBytes = assetData.buffer.asUint8List();

      final localFileSha = sha256.convert(assetBytes).bytes;
      final localFileShaHex = hex.encode(localFileSha).toUpperCase();

      // Check if it is already installed with this exact hash
      final lastInstalledHash = AppsBlob.getHash(package);
      if (lastInstalledHash == localFileShaHex) {
        logger.info(
          'Internal app $package is already up to date ($localFileShaHex). Skipping installation.',
        );
        return true;
      }

      final success = await _uploadRpk(package, 1, assetBytes);
      logger.info('Installation of $package result: $success');
      if (success) {
        final current = AppsBlob.instance.value[package];
        final defaultName = package.split('.').last;
        final capitalizedName =
            '${defaultName[0].toUpperCase()}${defaultName.substring(1)}';

        final updated = Map<String, App>.from(AppsBlob.instance.value);
        updated[package] =
            (current ??
                    App(
                      enabled: true,
                      hash: localFileShaHex,
                      name: capitalizedName,
                      external: false,
                    ))
                .copyWith(
                  enabled: true,
                  hash: localFileShaHex,
                  name: current?.name.isNotEmpty == true
                      ? current!.name
                      : capitalizedName,
                  external: false,
                );
        AppsBlob.instance.update(updated);
      }
      return success;
    } catch (e) {
      logger.error('Error enabling $package: $e');
      return false;
    }
  }

  Future<void> disable(String package) async {
    if (!internalApps.contains(package)) return;

    // 1. Mark as disabled in the blob first
    AppsBlob.setEnabled(package, false);

    // 2. Perform the uninstallation from the watch
    final app = AppsBlob.instance.value[package];
    if (app != null && (app.hash.isNotEmpty || app.fingerprint.isNotEmpty)) {
      logger.info(
        'Internal app $package is disabled. Uninstalling from watch...',
      );
      await uninstall(package);
    }
  }

  Future<bool> install(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw StateError('File not found at $filePath');
      }
      final bytes = await file.readAsBytes();

      // Parse manifest
      final archive = ZipDecoder().decodeBytes(bytes);
      final manifestFile = archive.findFile('manifest.json');
      if (manifestFile == null) {
        throw StateError('Invalid RPK: manifest.json not found');
      }

      final manifestString = utf8.decode(manifestFile.content as List<int>);
      final manifestJson = jsonDecode(manifestString) as Map<String, dynamic>;

      final package = manifestJson['package'] as String? ?? '';
      final appName =
          manifestJson['name'] as String? ?? filePath.split('/').last;
      final versionCode = manifestJson['versionCode'] as int? ?? 1;

      if (package.isEmpty) {
        throw StateError('Package identifier is missing');
      }

      logger.info(
        'Installing external app: $appName ($package), version: $versionCode',
      );

      final success = await _uploadRpk(package, versionCode, bytes);

      if (success) {
        final updated = Map<String, App>.from(AppsBlob.instance.value);
        updated[package] = App(
          enabled: true,
          hash: '',
          name: appName,
          external: true,
        );
        AppsBlob.instance.update(updated);
      }
      return success;
    } catch (e) {
      logger.error('Failed to install external RPK: $e');
      return false;
    }
  }

  Future<bool> _uploadRpk(
    String package,
    int versionCode,
    Uint8List fileBytes,
  ) async {
    if (!DeviceConnection.connected.value) {
      return false;
    }

    try {
      // 1. Send CMD_RPK_INSTALL (type 20, subtype 1)
      logger.info(
        'Sending RPK install start command for $package ($versionCode)',
      );
      final installResponse = await DeviceConnection.send(
        type: CmdType.thirdPartyApp,
        subtype: ThirdPartyAppSubtype.rpkInstall,
        builder: (cmd) =>
            cmd.thirdPartyApp = (pb.ThirdPartyApp()
              ..rpkInfo = (pb.RpkInfo()
                ..id = package
                ..unknown2 = versionCode
                ..size = fileBytes.length)),
        expectResponse: true,
      );

      if (installResponse == null || installResponse.status != 0) {
        logger.error(
          'RPK install request rejected status: ${installResponse?.status}',
        );
        return false;
      }

      // 2. Send upload start request (type 22, subtype 0)
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
        logger.error('RPK upload request rejected by watch');
        return false;
      }

      final ack = uploadResponse.dataUpload.dataUploadAck;
      final int chunkSize = ack.hasChunkSize() ? ack.chunkSize : 2048;
      final int resumePosition = ack.hasResumePosition()
          ? ack.resumePosition
          : 0;

      // 3. Construct payload bytes and headers
      final builder = BytesBuilder()
        ..addByte(0)
        ..addByte(64) // TYPE_RPK
        ..add(md5Sum);

      final sizeBytes = ByteData(4)
        ..setUint32(0, fileBytes.length, Endian.little);
      builder.add(sizeBytes.buffer.asUint8List());
      builder.add(fileBytes.sublist(resumePosition));

      final payload = builder.takeBytes();
      final crc = Crc32.calculate(payload);
      final crcBytes = ByteData(4)..setUint32(0, crc, Endian.little);

      final finalBytes =
          (BytesBuilder()
                ..add(payload)
                ..add(crcBytes.buffer.asUint8List()))
              .takeBytes();

      // 4. Stream chunks over SPP
      final int partSize = chunkSize - 4;
      final int totalParts = (finalBytes.length / partSize).ceil();
      logger.info('Streaming RPK in $totalParts parts...');

      for (int i = 0; i < totalParts; i++) {
        final currentPart = i + 1;
        final int startIndex = i * partSize;
        final int endIndex = (currentPart * partSize > finalBytes.length)
            ? finalBytes.length
            : currentPart * partSize;

        final chunkPayload = finalBytes.sublist(startIndex, endIndex);
        final chunkToSend = BytesBuilder();

        final headerBytes = ByteData(4)
          ..setUint16(0, totalParts, Endian.little)
          ..setUint16(2, currentPart, Endian.little);
        chunkToSend.add(headerBytes.buffer.asUint8List());
        chunkToSend.add(chunkPayload);

        await DeviceConnection.sendDataChunk(chunkToSend.takeBytes());
      }

      logger.info('Sideload finalized. Waiting for device unpacking...');
      await Future.delayed(const Duration(seconds: 3));

      // After install succeeds, run sync to refresh the list from the watch
      await _syncInstalledApps();
      return true;
    } catch (e) {
      logger.error('Error uploading RPK: $e');
      return false;
    }
  }

  Future<void> sendAppStatus(
    String package,
    bool isConnected, {
    List<int>? fingerprint,
  }) async {
    if (!DeviceConnection.connected.value) return;

    final appInfo = pb.ThirdPartyAppInfo()..packageName = package;
    if (fingerprint != null && fingerprint.isNotEmpty) {
      appInfo.fingerprint = fingerprint;
    } else {
      final app = AppsBlob.instance.value[package];
      if (app != null && app.fingerprint.isNotEmpty) {
        appInfo.fingerprint = app.fingerprint;
      } else {
        appInfo.fingerprint = [];
      }
    }

    final statusResp = pb.ThirdPartyAppStatus()
      ..appInfo = appInfo
      ..status = isConnected ? 1 : 2;

    logger.info(
      'Proactively sending app status for $package: ${isConnected ? "connected" : "disconnected"}',
    );

    await DeviceConnection.send(
      type: CmdType.thirdPartyApp,
      subtype: ThirdPartyAppSubtype.responsePhoneAppStatus,
      builder: (cmd) =>
          cmd.thirdPartyApp = (pb.ThirdPartyApp()..appStatusResp = statusResp),
    );
  }

  Future<void> uninstall(String package) async {
    if (!DeviceConnection.connected.value) return;
    logger.info('Requesting deletion for RPK: $package');

    final app = AppsBlob.instance.value[package];
    final sha = app?.fingerprint ?? const <int>[];

    await DeviceConnection.send(
      type: CmdType.thirdPartyApp,
      subtype: ThirdPartyAppSubtype.rpkDelete,
      builder: (cmd) =>
          cmd.thirdPartyApp = (pb.ThirdPartyApp()
            ..appStatusReq = (pb.ThirdPartyAppInfo()
              ..packageName = package
              ..fingerprint = sha)),
    );

    // Immediately remove from blob registry to trigger UI update
    final updated = Map<String, App>.from(AppsBlob.instance.value);
    final current = updated[package];
    if (current != null) {
      if (current.external) {
        updated.remove(package);
      } else {
        updated[package] = current.copyWith(enabled: false, hash: '');
      }
      AppsBlob.instance.update(updated);
    }
  }
}
