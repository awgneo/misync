import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:misync/screen.dart';
import '../device/module.dart';
import '../device/proto/xiaomi.pb.dart' as pb;
import '../device/proto/constants.dart';
import '../platform/module.dart';
import 'blobs/destinations.dart';
import 'blobs/rides.dart';
import 'sources/source.dart';
import 'sources/uber.dart';
import 'sources/lyft.dart';
import 'sources/waymo.dart';
import 'screen.dart';

class RideModule extends TabModule {
  @override
  String get name => 'ride';

  @override
  IconData get icon => Icons.local_taxi;

  @override
  late final Screen screen = RideScreen(this);

  static final RideModule _module = RideModule._();
  static RideModule get module => _module;
  RideModule._();

  final List<RideSource> _sources = const [
    UberSource(),
    LyftSource(),
    WaymoSource(),
  ];

  @override
  Future<void> start() async {
    DeviceModule.module.connection.listen(_receiveWatchCommand);
  }

  // --- Bluetooth Interconnect Handlers ---

  Future<void> _receiveWatchCommand(pb.Command cmd) async {
    if (cmd.type == CmdType.thirdPartyApp.value &&
        cmd.subtype == ThirdPartyAppSubtype.sendWearMessage.value &&
        cmd.hasThirdPartyApp() &&
        cmd.thirdPartyApp.hasMessage()) {
      final message = cmd.thirdPartyApp.message;
      final String package = message.appInfo.packageName;

      if (package != 'com.misync.ride') return;

      try {
        final String text = utf8.decode(message.content);
        final data = jsonDecode(text) as Map<String, dynamic>;
        final command = data['command']?.toString();

        if (command == 'getDestinations') {
          await _handleGetDestinations();
        } else if (command == 'getEstimates') {
          final destinationId = data['destinationId']?.toString() ?? '';
          final capacity = (data['capacity'] as num?)?.toInt() ?? 4;
          await _handleGetEstimates(destinationId, capacity);
        } else if (command == 'book') {
          final fareId = data['fareId']?.toString() ?? '';
          final provider = data['provider']?.toString() ?? '';
          final destinationId = data['destinationId']?.toString() ?? '';
          final capacity = (data['capacity'] as num?)?.toInt() ?? 4;
          await _handleBook(fareId, provider, destinationId, capacity);
        }
      } catch (e) {
        logger.error('Error parsing watch message in RideModule: $e');
      }
    }
  }

  Future<void> _handleGetDestinations() async {
    final list = DestinationsBlob.blob.value.map((d) => d.toJson()).toList();
    await _sendWatchPayload({'destinations': list});
  }

  Future<void> _handleGetEstimates(String destinationId, int capacity) async {
    logger.info(
      'getEstimates requested for destination: $destinationId, capacity: $capacity',
    );
    final destinations = DestinationsBlob.blob.value;
    if (destinations.isEmpty) {
      logger.error('No saved destinations available for ride estimates');
      await _sendWatchPayload({'estimates': []});
      return;
    }

    final Destination dest = destinations.firstWhere(
      (d) => d.id == destinationId,
      orElse: () => destinations.first,
    );

    // Fetch current GPS coordinates from Android native location manager
    double? originLat;
    double? originLon;
    try {
      final loc = await getCurrentLocation();
      if (loc != null &&
          loc.containsKey('latitude') &&
          loc.containsKey('longitude')) {
        originLat = (loc['latitude'] as num).toDouble();
        originLon = (loc['longitude'] as num).toDouble();
      }
    } catch (e) {
      logger.error('Failed to get location for ride estimate: $e');
    }

    if (originLat == null || originLon == null) {
      logger.error('GPS location unavailable, cannot calculate ride estimate');
      await _sendWatchPayload({'estimates': []});
      return;
    }

    final rideConfig = RidesBlob.blob.value;
    final bool mockMode = rideConfig.mockMode;

    // Fetch estimates from all sources concurrently
    final futures = _sources.map((source) {
      return source.getEstimates(
        originLat: originLat!,
        originLon: originLon!,
        destLat: dest.latitude,
        destLon: dest.longitude,
        capacity: capacity,
        mockMode: mockMode,
      );
    });

    final results = await Future.wait(futures);
    final List<RideEstimate> allEstimates = [];
    for (final list in results) {
      allEstimates.addAll(list);
    }

    // Filter matching capacity
    final filtered = allEstimates.where((e) => e.capacity == capacity).toList();

    // Sort strictly: Primary = Price ASC, Secondary = ETA ASC
    filtered.sort((a, b) {
      final priceComp = a.price.compareTo(b.price);
      if (priceComp != 0) return priceComp;
      return a.eta.compareTo(b.eta);
    });

    final jsonEstimates = filtered.map((e) => e.toJson()).toList();
    await _sendWatchPayload({'estimates': jsonEstimates});
  }

  Future<void> _handleBook(
    String fareId,
    String provider,
    String destinationId,
    int capacity,
  ) async {
    logger.info('Executing ride booking: fareId=$fareId, provider=$provider');
    final destinations = DestinationsBlob.blob.value;
    if (destinations.isEmpty) return;

    final dest = destinations.firstWhere(
      (d) => d.id == destinationId,
      orElse: () => destinations.first,
    );

    double originLat = 0.0;
    double originLon = 0.0;
    try {
      final loc = await getCurrentLocation();
      if (loc != null &&
          loc.containsKey('latitude') &&
          loc.containsKey('longitude')) {
        originLat = (loc['latitude'] as num).toDouble();
        originLon = (loc['longitude'] as num).toDouble();
      }
    } catch (_) {}

    final mockMode = RidesBlob.blob.value.mockMode;

    RideSource targetSource = const UberSource();
    if (provider == 'lyft') {
      targetSource = const LyftSource();
    } else if (provider == 'waymo') {
      targetSource = const WaymoSource();
    }

    final success = await targetSource.book(
      fareId: fareId,
      originLat: originLat,
      originLon: originLon,
      destLat: dest.latitude,
      destLon: dest.longitude,
      mockMode: mockMode,
    );

    logger.info('Ride booking result for $provider: success=$success');
  }

  Future<void> _sendWatchPayload(Map<String, dynamic> payload) async {
    final jsonString = jsonEncode(payload);
    final appInfo = pb.ThirdPartyAppInfo()..packageName = 'com.misync.ride';
    final appMessage = pb.ThirdPartyAppMessage()
      ..appInfo = appInfo
      ..content = Uint8List.fromList(utf8.encode(jsonString));

    await DeviceModule.module.connection.send(
      type: CmdType.thirdPartyApp,
      subtype: ThirdPartyAppSubtype.sendPhoneMessage,
      builder: (cmd) =>
          cmd.thirdPartyApp = (pb.ThirdPartyApp()..message = appMessage),
    );
  }

  // --- Public Module State Mutation & Platform Methods ---

  Future<Map<String, dynamic>?> getCurrentLocation() async {
    try {
      final loc = await PlatformModule.module.invokeMethod<Map>(
        'device.getLocation',
      );
      if (loc != null) {
        return Map<String, dynamic>.from(loc);
      }
    } catch (e) {
      logger.error('Failed to get device location in RideModule: $e');
    }
    return null;
  }

  Future<void> setMockMode(bool enabled) async {
    final current = RidesBlob.blob.value;
    await RidesBlob.blob.update(current.copyWith(mockMode: enabled));
  }

  Future<void> toggleUber(bool enabled) async {
    final current = RidesBlob.blob.value;
    await RidesBlob.blob.update(
      current.copyWith(uber: current.uber.copyWith(enabled: enabled)),
    );
  }

  Future<void> toggleLyft(bool enabled) async {
    final current = RidesBlob.blob.value;
    await RidesBlob.blob.update(
      current.copyWith(lyft: current.lyft.copyWith(enabled: enabled)),
    );
  }

  Future<void> toggleWaymo(bool enabled) async {
    final current = RidesBlob.blob.value;
    await RidesBlob.blob.update(
      current.copyWith(waymo: current.waymo.copyWith(enabled: enabled)),
    );
  }

  Future<void> addDestination(Destination destination) async {
    final list = List<Destination>.from(DestinationsBlob.blob.value)
      ..add(destination);
    await DestinationsBlob.blob.update(list);
  }

  Future<void> deleteDestination(String id) async {
    final list = List<Destination>.from(DestinationsBlob.blob.value)
      ..removeWhere((d) => d.id == id);
    await DestinationsBlob.blob.update(list);
  }
}
