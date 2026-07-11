import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:convert/convert.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';
import 'proto/xiaomi.pb.dart';
import 'proto/constants.dart';
import 'protocol/protocol.dart';
import 'protocol/packet.dart';
import '../debug/logger.dart';
import 'blobs/settings.dart';

class DeviceConnection extends ChangeNotifier {
  static late final Logger logger;
  // Singleton pattern
  static final DeviceConnection _instance = DeviceConnection._internal();
  static DeviceConnection get instance => _instance;
  factory DeviceConnection() => _instance;

  DeviceConnection._internal() {
    SettingsBlob.instance.addListener(() {
      notifyListeners();
      _connect();
    });
  }

  final _bluetooth = FlutterClassicBluetooth();
  BtcConnection? _connection;
  Protocol? _protocol;
  StreamSubscription? _subscription;
  bool _connecting = false;
  Timer? _retryTimer;

  final StreamController<Command> _multiplexer =
      StreamController<Command>.broadcast();

  final Map<String, List<Completer<Command>>> _requests = {};

  // Static delegate wrappers to avoid .instance verbose calls
  static final connected = ValueNotifier<bool>(false);
  static bool get connecting => instance._connecting;
  static ProtocolState get state => instance._state;

  static Future<Command?> send({
    Command? cmd,
    CmdType? type,
    ValuedEnum? subtype,
    void Function(Command)? builder,
    bool expectResponse = false,
    Duration timeout = const Duration(seconds: 5),
  }) {
    return instance._send(
      cmd: cmd,
      type: type,
      subtype: subtype,
      builder: builder,
      expectResponse: expectResponse,
      timeout: timeout,
    );
  }

  static Future<void> connect() => instance._connect();
  static Future<void> disconnect() => instance._disconnect();

  static StreamSubscription<Command> listen(void Function(Command) onData) {
    return instance._multiplexer.stream.listen(onData);
  }

  // Internal instance properties
  bool get _connected =>
      _connection != null && _protocol?.state == ProtocolState.authenticated;
  ProtocolState get _state => _protocol?.state ?? ProtocolState.disconnected;

  // ==========================================
  // 1. Connection Initiation
  // ==========================================

  Future<void> _connect() async {
    final macAddress = SettingsBlob.watchMac;
    final authKey = SettingsBlob.authKeyHex;
    if (macAddress.isEmpty || authKey.isEmpty) {
      return;
    }

    if (_connecting || _connected) return;

    _retryTimer?.cancel();
    _retryTimer = null;

    _connecting = true;
    notifyListeners();
    logger.info('connecting to device $macAddress via classic bluetooth SPP',
    );
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        logger.info('connection attempt ${retryCount + 1}');
        await _cleanup();

        final conn = await _bluetooth.connect(
          address: macAddress,
          uuid: '00001101-0000-1000-8000-00805f9b34fb', // Standard SPP UUID
        );

        _session(conn);
        return; // Success!
      } catch (e) {
        logger.error('attempt ${retryCount + 1} failed: $e');
        retryCount++;
        if (retryCount < maxRetries) {
          logger.info('waiting 2 seconds before retrying');
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    logger.error('all connection attempts failed');
    disconnect();
  }

  Future<void> _cleanup() async {
    logger.info('closing existing socket');
    try {
      await _connection?.close();
    } catch (_) {}
    await _subscription?.cancel();
    _subscription = null;
  }

  void _session(BtcConnection conn) {
    _connection = conn;
    logger.info('connected over RFCOMM socket, initializing protocol manager',
    );

    _protocol = Protocol(
      authKeyHex: SettingsBlob.authKeyHex,
      deviceId: SettingsBlob.deviceId,
      deviceModel: SettingsBlob.deviceModel,
      logger: logger,
    );

    notifyListeners();

    // Listen for received bytes on SPP input stream
    _subscription = conn.input.listen(
      _receive,
      onError: (e) {
        logger.error('spp stream error: $e');
        disconnect();
      },
      onDone: () {
        logger.info('spp connection closed by peer');
        disconnect();
      },
    );

    logger.info('sending SPP version request');
    final versionReq = _protocol!.initiateVersionRequest();
    logger.debug('→ write SPP version req: ${hex.encode(versionReq).toUpperCase()}',
    );
    conn.output.add(Uint8List.fromList(versionReq));

    _connecting = false;
    notifyListeners();
  }

  // ==========================================
  // 2. Incoming Data & Handshaking Process
  // ==========================================

  void _receive(List<int> bytes) async {
    if (_protocol == null) return;

    final hexStr = hex.encode(bytes).toUpperCase();
    logger.debug('← raw rx: $hexStr');

    try {
      // 1. Check for SPP Version Response
      if (_isSppVersionResponse(bytes)) {
        await _handleSppVersionResponse(bytes);
        return;
      }

      // 2. Parse and handle L1/L2 framed packets
      final packets = _protocol!.feedBytes(bytes);
      logger.debug('spp parser: fed ${bytes.length} bytes, got ${packets.length} packets',
      );
      for (var packet in packets) {
        await _handlePacket(packet);
      }
    } catch (e, stackTrace) {
      logger.error('error in _receive processing: $e\n$stackTrace');
    }
  }

  bool _isSppVersionResponse(List<int> bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0xBA &&
        bytes[1] == 0xDC &&
        bytes[2] == 0xFE &&
        bytes[3] == 0x00;
  }

  Future<void> _handleSppVersionResponse(List<int> bytes) async {
    logger.info('← spp version response detected');
    if (bytes.length >= 8) {
      final givenLen = bytes[5] | (bytes[6] << 8);
      final payloadLen = givenLen - 3;
      if (payloadLen > 0 && bytes.length >= 10 + payloadLen) {
        final payload = bytes.sublist(10, 10 + payloadLen);
        logger.info('parsed watch SPP version: ${payload[0]}.${payload[1]}',
        );
      }
    }

    // Version confirmed. Handshake proceeds by sending SppPacketV2 Session Config Request.
    logger.info('session configuration: sending client session config',
    );
    final configBytes = _protocol!.initiateSessionConfig();
    logger.debug('→ write config bytes: ${hex.encode(configBytes).toUpperCase()}',
    );
    await _write(configBytes);
  }

  Future<void> _handlePacket(Packet packet) async {
    try {
      logger.debug('← packet parsed: type=${packet.packetType}, seq=${packet.sequenceNumber}, payloadLen=${packet.payload.length}',
      );

      // Acknowledge the V2 packet immediately
      final ackBytes = _protocol!.buildAck(packet.sequenceNumber);
      await _write(ackBytes);

      switch (packet.packetType) {
        case Packet.typeAck:
          // L1 ACK control packet handled silently
          break;
        case Packet.typeSessionConfig:
          _handleSessionConfig(packet);
          break;
        case Packet.typeData:
          await _handleData(packet);
          break;
        default:
          logger.error('unknown packet type: ${packet.packetType}');
          break;
      }
    } catch (e, stackTrace) {
      logger.error('error in _handlePacket: $e\n$stackTrace');
    }
  }

  void _handleSessionConfig(Packet packet) async {
    logger.debug('← session config packet payload: ${hex.encode(packet.payload).toUpperCase()}',
    );
    if (packet.payload.isNotEmpty && packet.payload[0] == 2) {
      // OPCODE_START_SESSION_RESPONSE = 2
      logger.info('session config complete, initiating handshake step 1: sending phone nonce',
      );
      final step1Bytes = _protocol!.initiateHandshake();
      await _write(step1Bytes);
      notifyListeners();
    }
  }

  Future<void> _handleData(Packet packet) async {
    try {
      final cmd = _protocol!.decryptAndParseCommand(packet);
      logger.debug('← parsed cmd: type=${cmd.type}, subtype=${cmd.subtype}',
      );

      if (_protocol!.state != ProtocolState.authenticated) {
        await _handleHandshake(cmd);
      } else {
        logger.debug('← secure cmd: type=${cmd.type}, content=${cmd.writeToJsonMap()}',
        );
        _read(cmd);
      }
    } catch (e, stackTrace) {
      logger.error('failed to decrypt/parse data command: $e\n$stackTrace',
      );
    }
  }

  Future<void> _handleHandshake(Command cmd) async {
    try {
      final response = _protocol!.handleHandshakeCommand(cmd);
      if (response != null) {
        logger.debug('→ send handshake: ${hex.encode(response).toUpperCase()}',
        );
        await _write(response);
      }

      if (_protocol!.state == ProtocolState.authenticated) {
        logger.info('handshake successful: secure channel is active');
        notifyListeners();
      } else if (_protocol!.state == ProtocolState.authFailed) {
        logger.error('handshake failed: auth key is invalid');
        _disconnect();
      } else {
        notifyListeners();
      }
    } catch (e, stackTrace) {
      logger.error('error during handshake processing: $e\n$stackTrace',
      );
    }
  }

  void _read(Command cmd) {
    _multiplexer.add(cmd);

    final key = '${cmd.type}:${cmd.subtype}';
    final pending = _requests[key];
    if (pending != null && pending.isNotEmpty) {
      final completer = pending.removeAt(0);
      completer.complete(cmd);
      if (pending.isEmpty) {
        _requests.remove(key);
      }
    }

    if (cmd.hasSystem()) {
      final sys = cmd.system;
      if (sys.hasFindDevice()) {
        final find = sys.findDevice;
        logger.info('system command: find device triggered ($find)');
        if (find == 1) {
          logger.info('ringing phone (triggered from watch find phone app)',
          );
          // Ring phone audio playback loop logic
        }
      }
    }
  }

  // ==========================================
  // 3. Outgoing Transmission Helpers
  // ==========================================

  Future<Command?> _send({
    Command? cmd,
    CmdType? type,
    ValuedEnum? subtype,
    void Function(Command)? builder,
    bool expectResponse = false,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!_connected) {
      logger.error('cannot send command: secure channel not active');
      return null;
    }

    try {
      Command targetCmd;
      if (cmd != null) {
        targetCmd = cmd;
      } else if (type != null) {
        targetCmd = Command()..type = type.value;
        if (subtype != null) {
          targetCmd.subtype = subtype.value;
        }
        if (builder != null) {
          builder(targetCmd);
        }
      } else {
        throw ArgumentError('Either cmd or type must be provided to send().');
      }

      Completer<Command>? completer;
      String? key;
      if (expectResponse) {
        key = '${targetCmd.type}:${targetCmd.subtype}';
        completer = Completer<Command>();
        _requests.putIfAbsent(key, () => []).add(completer);
      }

      final framed = _protocol!.encryptAndWrapCommand(targetCmd);
      logger.debug('→ send command: type=${targetCmd.type}, subtype=${targetCmd.subtype}, content=${targetCmd.writeToJsonMap()}',
      );
      await _write(framed);

      if (expectResponse && completer != null) {
        try {
          return await completer.future.timeout(timeout);
        } catch (e) {
          _requests[key]?.remove(completer);
          if (_requests[key]?.isEmpty ?? false) {
            _requests.remove(key);
          }
          logger.error('response timeout for $type/$subtype: $e');
          return null;
        }
      }
    } catch (e) {
      logger.error('failed to send command $type/$subtype: $e');
    }
    return null;
  }

  Future<void> _write(List<int> bytes) async {
    if (_connection == null) return;
    final hexStr = hex.encode(bytes).toUpperCase();
    logger.debug('→ raw tx: $hexStr');
    _connection!.output.add(Uint8List.fromList(bytes));
  }

  static Future<void> sendDataChunk(Uint8List chunk) async {
    final instance = _instance;
    if (!instance._connected || instance._protocol == null) {
      logger.error('cannot send data chunk: not connected');
      return;
    }
    final framed = instance._protocol!.wrapDataChunk(chunk);
    await instance._write(framed);
  }

  // ==========================================
  // 4. Connection Teardown & Reconnection
  // ==========================================

  Future<void> _disconnect() async {
    logger.info('disconnecting from watch');
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _connection?.close();
    } catch (_) {}

    _connection = null;
    _connecting = false;
    _protocol?.reset();

    logger.info('disconnected');
    notifyListeners();
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (SettingsBlob.watchMac.isEmpty || _connecting || _connected) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 10), () {
      if (SettingsBlob.watchMac.isNotEmpty && !_connected && !_connecting) {
        logger.info('reconnection loop: watch is disconnected, attempting connection',
        );
        _connect();
      }
    });
  }

  @override
  void notifyListeners() {
    connected.value = _connected;
    super.notifyListeners();
  }
}
