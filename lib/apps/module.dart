import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:archive/archive.dart';
import 'package:misync/screen.dart';
import '../device/module.dart';
import '../device/proto/xiaomi.pb.dart' as pb;
import '../device/proto/constants.dart';
import '../platform/module.dart';
import 'blobs/apps.dart';
import 'screen.dart';

class AppsModule extends TabModule {
  @override
  String get name => 'apps';

  @override
  IconData get icon => Icons.apps;

  @override
  late final Screen screen = AppsScreen(this);

  static final AppsModule _module = AppsModule._();
  static AppsModule get module => _module;
  AppsModule._();

  final List<String> internalApps = [];

  @override
  Future<void> start() async {
    _startInternalApps();
    DeviceModule.module.register(this);
    DeviceModule.module.connection.listen(_receiveWatchCommand);
  }

  Future<void> _startInternalApps() async {
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

  Future<void> _receiveWatchCommand(pb.Command cmd) async {
    if (cmd.type == CmdType.thirdPartyApp.value) {
      if (cmd.subtype == ThirdPartyAppSubtype.requestPhoneAppStatus.value) {
        await _handleWatchAppStatusRequest(cmd);
      }
    } else if (cmd.type == CmdType.notification.value &&
        cmd.subtype == NotificationSubtype.iconQuery.value &&
        cmd.hasNotification() &&
        cmd.notification.hasNotificationIconQuery()) {
      await _handleWatchIconQuery(cmd);
    }
  }

  Future<void> _handleWatchAppStatusRequest(pb.Command cmd) async {
    String package = '';
    List<int> fingerprint = [];
    bool query = false;

    if (cmd.hasThirdPartyApp() && cmd.thirdPartyApp.hasAppStatusReq()) {
      package = cmd.thirdPartyApp.appStatusReq.packageName;
      fingerprint = cmd.thirdPartyApp.appStatusReq.fingerprint;
      query = true;
    }

    if (query) {
      logger.info('watch queried app status for: $package');
      await _sendWatchAppStatus(package, fingerprint: fingerprint);
    }
  }

  Future<void> _sendWatchAppStatus(
    String package, {
    List<int>? fingerprint,
  }) async {
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

    final appStatus = pb.ThirdPartyAppStatus()
      ..appInfo = appInfo
      ..status = 1;

    logger.info('sending app status for $package');

    await DeviceModule.module.connection.send(
      type: CmdType.thirdPartyApp,
      subtype: ThirdPartyAppSubtype.responsePhoneAppStatus,
      builder: (cmd) =>
          cmd.thirdPartyApp = (pb.ThirdPartyApp()..appStatusResp = appStatus),
    );
  }

  Future<void> _handleWatchIconQuery(pb.Command cmd) async {
    final query = cmd.notification.notificationIconQuery;
    final package = query.package;

    logger.info('watch requested app icon for: $package');

    final iconPackage = pb.NotificationIconPackage()..package = package;
    final iconResponse = await DeviceModule.module.connection.send(
      type: CmdType.notification,
      subtype: NotificationSubtype.iconRequest,
      builder: (c) =>
          c.notification = (pb.Notification()
            ..notificationIconReply = iconPackage),
      response: true,
    );

    if (iconResponse == null ||
        !iconResponse.hasNotification() ||
        !iconResponse.notification.hasNotificationIconRequest()) {
      logger.error(
        'watch did not respond to iconRequest or format was invalid',
      );
      return;
    }

    final iconRequest = iconResponse.notification.notificationIconRequest;
    final int pixelFormat = iconRequest.pixelFormat;
    final int size = iconRequest.size;

    logger.info('watch responded: format=$pixelFormat, size=$size pixels');

    // Fetch the app icon raw ARGB bytes from Android
    final Uint8List? rawBytes = await PlatformModule.module
        .invokeMethod<Uint8List>('notifications.getAppIcon', {
          'packageName': package,
          'size': size,
        });

    if (rawBytes == null || rawBytes.isEmpty) {
      logger.error('Failed to retrieve icon bytes from Android for $package');
      return;
    }

    // Format/Compress raw RGBA_8888 bytes to the watch's requested pixelFormat
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

    // Send the icon via Data Upload channel (type 22, subtype 0)
    final success = await DeviceModule.module.connection.uploadData(
      type: 50, // TYPE_ICON
      bytes: formattedBytes,
    );

    if (success) {
      logger.info('icon upload completed successfully for $package');
    } else {
      logger.error('icon upload failed for $package');
    }
  }

  @override
  Future<void> sync() async {
    if (!DeviceModule.module.connection.connected.value) return;
    await _syncInternalApps();
    await _syncInstalledApps();
  }

  Future<void> _syncInternalApps() async {
    for (final package in internalApps) {
      final bool enabled = AppsBlob.getEnabled(package);
      if (enabled) {
        await enableApp(package);
      } else {
        await disableApp(package);
      }
    }
  }

  Future<void> _syncInstalledApps() async {
    if (!DeviceModule.module.connection.connected.value) return;

    // Get installed apps (RPKs) on watch
    logger.info('querying installed RPK list from watch');
    final response = await DeviceModule.module.connection.send(
      type: CmdType.thirdPartyApp,
      subtype: ThirdPartyAppSubtype.rpkList,
      response: true,
    );

    if (response == null ||
        !response.hasThirdPartyApp() ||
        !response.thirdPartyApp.hasRpkList()) {
      logger.error('Failed to get RPK list from watch');
      return;
    }

    final watchApps = response.thirdPartyApp.rpkList.rpkInfo;
    logger.info('received ${watchApps.length} installed apps from watch.');
    // Update AppsBlob registry based on the watch list
    final updatedApps = Map<String, App>.from(AppsBlob.instance.value);

    // Identify all external apps currently reported by the watch
    final Set<String> watchExternalAppIds = {};
    for (final watchApp in watchApps) {
      final package = watchApp.id;
      final bool internal = internalApps.contains(package);

      if (!internal) {
        // External app, add to registry
        watchExternalAppIds.add(package);
        updatedApps[package] = App(
          enabled: true,
          hash: '',
          package: package,
          external: true,
          fingerprint: watchApp.sha,
        );
      } else {
        // Internal app, update fingerprint in blob registry
        final current = updatedApps[package];
        updatedApps[package] = App(
          enabled: current?.enabled ?? true,
          hash: current?.hash ?? '',
          package: package,
          external: false,
          fingerprint: watchApp.sha,
        );
      }
    }

    // Remove any external apps from our blob registry that are no longer installed on the watch
    updatedApps.removeWhere((package, app) {
      return app.external && !watchExternalAppIds.contains(package);
    });

    // Save to blob
    AppsBlob.instance.update(updatedApps);
  }

  Future<void> launchApp(String package, {String? uri}) async {
    logger.info('Launching watch app: $package');

    final appInfo = pb.ThirdPartyAppInfo()..packageName = package;
    final installed = AppsBlob.instance.value[package];
    if (installed != null && installed.fingerprint.isNotEmpty) {
      appInfo.fingerprint = installed.fingerprint;
    }

    final request = pb.ThirdPartyAppLaunch()..appInfo = appInfo;
    if (uri != null) {
      request.uri = uri;
    }

    await DeviceModule.module.connection.send(
      type: CmdType.thirdPartyApp,
      subtype: ThirdPartyAppSubtype.launchApp,
      builder: (cmd) =>
          cmd.thirdPartyApp = (pb.ThirdPartyApp()..appLaunchReq = request),
    );
  }

  Future<bool> enableApp(String package) async {
    if (!DeviceModule.module.connection.connected.value) return false;

    if (!internalApps.contains(package)) {
      logger.error('app $package is not an internal app');
      return false;
    }

    // Mark as enabled in the blob first
    AppsBlob.setEnabled(package, true);

    final ByteData assetData = await rootBundle.load('assets/rpk/$package.rpk');
    final Uint8List assetBytes = assetData.buffer.asUint8List();
    final localFileSha = sha256.convert(assetBytes).bytes;
    final localFileShaHex = hex.encode(localFileSha).toUpperCase();

    // Check if it is already installed with this exact hash
    final lastInstalledHash = AppsBlob.getHash(package);
    if (lastInstalledHash == localFileShaHex) {
      logger.info(
        'internal app $package is already up to date ($localFileShaHex). Skipping installation.',
      );
      return true;
    }

    final success = await _uploadApp(package, 1, assetBytes);
    logger.info('installation of $package result: $success');

    if (success) {
      final app = AppsBlob.instance.value[package];

      final updatedApps = Map<String, App>.from(AppsBlob.instance.value);
      updatedApps[package] =
          (app ??
                  App(
                    enabled: true,
                    hash: localFileShaHex,
                    package: package,
                    external: false,
                  ))
              .copyWith(
                enabled: true,
                hash: localFileShaHex,
                package: package,
                external: false,
              );

      AppsBlob.instance.update(updatedApps);
    }

    return success;
  }

  Future<void> disableApp(String package) async {
    if (!internalApps.contains(package)) return;

    // Mark as disabled in the blob first
    AppsBlob.setEnabled(package, false);

    // Perform the uninstallation from the watch
    final app = AppsBlob.instance.value[package];
    if (app != null && (app.hash.isNotEmpty || app.fingerprint.isNotEmpty)) {
      logger.info(
        'internal app $package is disabled and uninstalling from watch',
      );

      await uninstall(package);
    }
  }

  Future<bool> install(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      logger.error('file $path not found');
      return false;
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
    final appName = manifestJson['name'] as String? ?? path.split('/').last;
    final versionCode = manifestJson['versionCode'] as int? ?? 1;

    if (package.isEmpty) {
      throw StateError('Package identifier is missing');
    }

    logger.info(
      'Installing external app: $appName ($package), version: $versionCode',
    );

    final success = await _uploadApp(package, versionCode, bytes);
    if (success) {
      final updatedApps = Map<String, App>.from(AppsBlob.instance.value);
      updatedApps[package] = App(
        enabled: true,
        hash: '',
        package: package,
        external: true,
      );

      AppsBlob.instance.update(updatedApps);
    }

    return success;
  }

  Future<bool> _uploadApp(
    String package,
    int versionCode,
    Uint8List fileBytes,
  ) async {
    if (!DeviceModule.module.connection.connected.value) return false;

    logger.info(
      'Sending RPK install start command for $package ($versionCode)',
    );

    // Send CMD_RPK_INSTALL (type 20, subtype 1)
    final installResponse = await DeviceModule.module.connection.send(
      type: CmdType.thirdPartyApp,
      subtype: ThirdPartyAppSubtype.rpkInstall,
      builder: (cmd) =>
          cmd.thirdPartyApp = (pb.ThirdPartyApp()
            ..rpkInfo = (pb.RpkInfo()
              ..id = package
              ..unknown2 = versionCode
              ..size = fileBytes.length)),
      response: true,
    );

    if (installResponse == null || installResponse.status != 0) {
      logger.error(
        'RPK install request rejected status: ${installResponse?.status}',
      );
      return false;
    }

    // Send upload start request (type 22, subtype 0)
    final success = await DeviceModule.module.connection.uploadData(
      type: 64, // TYPE_RPK
      bytes: fileBytes,
    );

    if (!success) {
      logger.error('RPK data upload failed');
      return false;
    }

    logger.info('Sideload finalized. Waiting for device unpacking...');
    await _syncInstalledApps();
    return true;
  }

  Future<void> uninstall(String package) async {
    if (!DeviceModule.module.connection.connected.value) return;

    logger.info('Requesting deletion for RPK: $package');

    final app = AppsBlob.instance.value[package];
    final sha = app?.fingerprint ?? const <int>[];

    await DeviceModule.module.connection.send(
      type: CmdType.thirdPartyApp,
      subtype: ThirdPartyAppSubtype.rpkDelete,
      builder: (cmd) =>
          cmd.thirdPartyApp = (pb.ThirdPartyApp()
            ..appStatusReq = (pb.ThirdPartyAppInfo()
              ..packageName = package
              ..fingerprint = sha)),
    );

    // Immediately remove from blob registry to trigger UI update
    final updatedApps = Map<String, App>.from(AppsBlob.instance.value);
    final current = updatedApps[package];
    if (current != null) {
      if (current.external) {
        updatedApps.remove(package);
      } else {
        updatedApps[package] = current.copyWith(enabled: false, hash: '');
      }

      AppsBlob.instance.update(updatedApps);
    }
  }
}
