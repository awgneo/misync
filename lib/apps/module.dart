import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final Map<String, Uint8List> appIcons = {};

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

      final updatedApps = Map<String, App>.from(AppsBlob.instance.value);

      for (final path in rpkPaths) {
        final filename = path.split('/').last;
        final package = filename.substring(0, filename.length - 4);

        // Read the asset RPK and parse manifest.json to extract versionCode
        final ByteData assetData = await rootBundle.load(path);
        final Uint8List assetBytes = assetData.buffer.asUint8List();
        final archive = ZipDecoder().decodeBytes(assetBytes);
        final manifestFile = archive.findFile('manifest.json');
        if (manifestFile == null) {
          logger.error('invalid RPK asset $path: manifest.json not found');
          continue;
        }

        final manifestString = utf8.decode(manifestFile.content as List<int>);
        final manifestJson = jsonDecode(manifestString) as Map<String, dynamic>;
        final versionCode = manifestJson['versionCode'] as int? ?? 1;

        final logoFile = archive.findFile('common/logo.png');
        if (logoFile != null) {
          appIcons[package] = Uint8List.fromList(logoFile.content as List<int>);
        }

        final current = updatedApps[package];
        updatedApps[package] = App(
          enabled: current?.enabled ?? false,
          versionCode: versionCode,
          package: package,
          external: false,
          fingerprint: current?.fingerprint ?? const [],
        );
      }

      await AppsBlob.instance.update(updatedApps);
      logger.info('initialized internal apps');
    } catch (e) {
      logger.error('failed to load internal apps from manifest: $e');
    }
  }

  Future<void> _receiveWatchCommand(pb.Command cmd) async {
    if (cmd.type == CmdType.thirdPartyApp.value) {
      if (cmd.subtype == ThirdPartyAppSubtype.requestPhoneAppStatus.value) {
        await _handleWatchAppStatusRequest(cmd);
      } else if (cmd.subtype == ThirdPartyAppSubtype.rpkInstalled.value) {
        await _handleWatchAppInstallResult(cmd);
      } else if (cmd.subtype == ThirdPartyAppSubtype.sendWearMessage.value) {
        await _handleWatchAppMessage(cmd);
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
      logger.info('watch queried app status for $package');
      await _sendWatchAppStatus(package, fingerprint: fingerprint);
    }
  }

  Future<void> _handleWatchAppInstallResult(pb.Command cmd) async {
    if (!cmd.hasThirdPartyApp() || !cmd.thirdPartyApp.hasRpkInstallResult()) {
      return;
    }

    final result = cmd.thirdPartyApp.rpkInstallResult;
    final status = result.status; // 0 success/installed, 1 fail, 2 uninstalled
    if (status != 0) return; // JUST handle the install message for now

    String package = '';
    if (result.hasRpkInfo() && result.rpkInfo.hasId()) {
      package = result.rpkInfo.id;
    } else if (result.hasPackageName()) {
      package = result.packageName;
    }

    if (package.isEmpty) {
      logger.error(
        'watch reported app install result, but package identifier is empty',
      );
      return;
    }

    logger.info('watch reported successful app install result for $package');

    final updatedApps = Map<String, App>.from(AppsBlob.instance.value);
    final current = updatedApps[package];
    if (current == null) {
      // New external app found on watch
      updatedApps[package] = App(
        enabled: true,
        versionCode: result.rpkInfo.versionCode,
        package: package,
        external: true,
        fingerprint: result.rpkInfo.sha,
      );
    } else {
      // Existing app, update fingerprint
      updatedApps[package] = current.copyWith(fingerprint: result.rpkInfo.sha);
    }

    AppsBlob.instance.update(updatedApps);
  }

  Future<void> _handleWatchAppMessage(pb.Command cmd) async {
    if (!cmd.hasThirdPartyApp() || !cmd.thirdPartyApp.hasMessage()) {
      return;
    }

    final message = cmd.thirdPartyApp.message;
    final String text = utf8.decode(message.content);
    try {
      final data = jsonDecode(text) as Map<String, dynamic>;
      final command = data['command']?.toString();
      if (command == 'log') {
        final String package = message.appInfo.packageName;
        final String msgText = data['message']?.toString() ?? '';
        logger.info('[WATCH_LOG] ($package) $msgText');
        return;
      } else if (command == 'getSymbol') {
        final name = data['name']?.toString() ?? '';
        if (name.isNotEmpty) {
          await _handleWatchGetSymbol(message.appInfo.packageName, name);
        }
      }
    } catch (e) {
      logger.error('failed to parse third-party message in AppsModule: $e');
    }
  }

  Future<void> _handleWatchGetSymbol(String watchPackage, String name) async {
    logger.info('watch requested symbol: $name for package: $watchPackage');

    final pngBytes = await renderSymbolToPng(name);
    if (pngBytes == null || pngBytes.isEmpty) {
      logger.error('failed to render symbol: $name');
      return;
    }

    final base64String = base64Encode(pngBytes);
    final payload = {'name': name, 'symbol': base64String};
    final jsonPayload = jsonEncode(payload);

    final appInfo = pb.ThirdPartyAppInfo()..packageName = watchPackage;
    final installed = AppsBlob.instance.value[watchPackage];
    if (installed != null && installed.fingerprint.isNotEmpty) {
      appInfo.fingerprint = installed.fingerprint;
    }

    final appMessage = pb.ThirdPartyAppMessage()
      ..appInfo = appInfo
      ..content = Uint8List.fromList(utf8.encode(jsonPayload));

    logger.info('sending rendered symbol $name to watch app $watchPackage');

    await DeviceModule.module.connection.send(
      type: CmdType.thirdPartyApp,
      subtype: ThirdPartyAppSubtype.sendPhoneMessage,
      builder: (cmd) =>
          cmd.thirdPartyApp = (pb.ThirdPartyApp()..message = appMessage),
    );
  }

  Future<Uint8List?> renderSymbolToPng(String name, {int size = 64}) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final painter = TextPainter(
        text: TextSpan(
          text: name,
          style: const TextStyle(
            fontFamily: 'Material',
            fontSize:
                54, // slightly smaller than the 64x64 canvas to avoid clipping
            fontWeight:
                FontWeight.w500, // clean weight for smartwatch readability
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      painter.layout(maxWidth: size.toDouble());

      // Center the symbol glyph in the square
      final xOffset = (size.toDouble() - painter.width) / 2;
      final yOffset = (size.toDouble() - painter.height) / 2;
      painter.paint(canvas, Offset(xOffset, yOffset));

      final picture = recorder.endRecording();
      final img = await picture.toImage(size, size);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (e) {
      logger.error('Failed to render symbol $name: $e');
      return null;
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
    Uint8List? rawBytes;
    try {
      rawBytes = await PlatformModule.module.getAppIcon(
        package,
        size: size,
      );
    } catch (e) {
      logger.error(
        'Failed to retrieve icon bytes from Android for $package: $e',
      );
    }

    if (rawBytes == null || rawBytes.isEmpty) {
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
    await _syncInstalledApps();
    await _syncInternalApps();
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
    final updatedApps = Map<String, App>.from(AppsBlob.instance.value);
    final Set<String> watchAppIds = watchApps.map((a) => a.id).toSet();

    // Process all apps reported by the watch
    for (final watchApp in watchApps) {
      final package = watchApp.id;
      final current = updatedApps[package];

      if (current == null) {
        // Discovered a new external app installed on the watch
        updatedApps[package] = App(
          enabled: true,
          versionCode: watchApp.versionCode,
          package: package,
          external: true,
          fingerprint: watchApp.sha,
        );
      } else {
        // App exists in database: update its fingerprint
        if (current.isInternal) {
          // If watch version is older than local version code, clear fingerprint to trigger update
          if (watchApp.versionCode < current.versionCode) {
            updatedApps[package] = current.copyWith(fingerprint: const []);
          } else {
            updatedApps[package] = current.copyWith(fingerprint: watchApp.sha);
          }
        } else {
          // External app: update both fingerprint and version code
          updatedApps[package] = current.copyWith(
            fingerprint: watchApp.sha,
            versionCode: watchApp.versionCode,
          );
        }
      }
    }

    // For any app currently in our database that is NOT in the watch's RPK list:
    // We must clear its watch fingerprint. If it is an internal app and was
    // previously installed (fingerprint.isNotEmpty), we also mark it as disabled
    // to detect watch-side manual uninstalls.
    for (final entry in updatedApps.entries) {
      final package = entry.key;
      final app = entry.value;
      if (!watchAppIds.contains(package)) {
        if (!app.external && app.fingerprint.isNotEmpty) {
          updatedApps[package] = app.copyWith(
            enabled: false,
            fingerprint: const [],
          );
        } else {
          updatedApps[package] = app.copyWith(fingerprint: const []);
        }
      }
    }

    // Remove any external apps from our blob registry that are no longer installed on the watch
    updatedApps.removeWhere((package, app) {
      return app.external && !watchAppIds.contains(package);
    });

    await AppsBlob.instance.update(updatedApps);
  }

  Future<void> _syncInternalApps() async {
    final apps = AppsBlob.instance.value;
    for (final app in apps.values) {
      if (app.external) continue;
      if (app.enabled) {
        await installInternalApp(app);
      } else {
        await uninstallApp(app.package);
      }
    }
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

  Future<bool> enableInternalApp(String package) async {
    final app = AppsBlob.instance.value[package];
    if (app == null || app.external) {
      logger.error('app $package is not an internal app');
      return false;
    }

    // See if already enabled
    if (app.enabled) {
      logger.info('app $package is already enabled');
      return true;
    }

    AppsBlob.setEnabled(package, true);
    // Mark as enabled in the blob first
    return await installInternalApp(app);
  }

  Future<void> disableInternalApp(String package) async {
    final app = AppsBlob.instance.value[package];
    if (app == null || app.external) {
      logger.error('app $package is not an internal app');
      return;
    }

    // See if already disabled
    if (!app.enabled) {
      logger.info('app $package is already disabled');
      return;
    }

    AppsBlob.setEnabled(package, false);
    // Uninstall the app on the watch (disables it)
    await uninstallApp(package);
  }

  Future<bool> installInternalApp(App app) async {
    if (!DeviceModule.module.connection.connected.value) return false;

    // Check if app is already installed
    if (app.fingerprint.isNotEmpty) {
      logger.info('app ${app.package} is already installed');
      return true;
    }

    // Load the rpk asset again
    final ByteData assetData = await rootBundle.load(
      'assets/rpk/${app.package}.rpk',
    );
    final Uint8List assetBytes = assetData.buffer.asUint8List();

    // Upload rpk to watch
    return _uploadApp(app.package, app.versionCode, assetBytes);
  }

  Future<bool> installExternalApp(String path) async {
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

    final logoFile = archive.findFile('common/logo.png');
    if (logoFile != null) {
      appIcons[package] = Uint8List.fromList(logoFile.content as List<int>);
    }

    logger.info(
      'Installing external app: $appName ($package), version: $versionCode',
    );

    // Upload rpk to watch
    return _uploadApp(package, versionCode, bytes);
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

    // Send rpk install message request
    final installResponse = await DeviceModule.module.connection.send(
      type: CmdType.thirdPartyApp,
      subtype: ThirdPartyAppSubtype.rpkInstall,
      builder: (cmd) =>
          cmd.thirdPartyApp = (pb.ThirdPartyApp()
            ..rpkInstallStart = (pb.RpkInstallStart()
              ..id = package
              ..versionCode = versionCode
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

    logger.info('successful installation of app $package');
    return true;
  }

  Future<void> uninstallApp(String package) async {
    if (!DeviceModule.module.connection.connected.value) return;

    logger.info('Requesting deletion for RPK: $package');

    final app = AppsBlob.instance.value[package];
    if (app == null) {
      logger.info('app $package is not registered');
      return;
    }

    if (app.fingerprint.isEmpty) {
      logger.info('app $package is not installed');
      return;
    }

    // Send RPK deletion request
    await DeviceModule.module.connection.send(
      type: CmdType.thirdPartyApp,
      subtype: ThirdPartyAppSubtype.rpkDelete,
      builder: (cmd) =>
          cmd.thirdPartyApp = (pb.ThirdPartyApp()
            ..appStatusReq = (pb.ThirdPartyAppInfo()
              ..packageName = package
              ..fingerprint = app.fingerprint)),
    );

    // Update the apps blob
    final updatedApps = Map<String, App>.from(AppsBlob.instance.value);
    final current = updatedApps[package];
    if (current != null) {
      if (current.external) {
        updatedApps.remove(package);
      } else {
        updatedApps[package] = current.copyWith(
          enabled: false,
          fingerprint: const [],
        );
      }

      AppsBlob.instance.update(updatedApps);
    }
  }
}
