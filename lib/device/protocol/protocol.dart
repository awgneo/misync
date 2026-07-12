import 'dart:math';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import '../../debug/logger.dart';
import '../proto/xiaomi.pb.dart';
import 'packet.dart';
import 'crypto.dart';

enum ProtocolState {
  disconnected,
  versionRequestSent,
  sessionConfigSent,
  handshakeStep1,
  handshakeStep2,
  appVerifySent,
  appConfirmSent,
  authenticated,
  authFailed,
}

class Protocol {
  final Uint8List authKey;
  final String deviceId;
  final String deviceModel;
  final Logger logger;

  ProtocolState state = ProtocolState.disconnected;
  int _sppSeq = 0;
  int _dataSeq = 0;

  late Uint8List phoneNonce;
  late Uint8List watchNonce;
  late Uint8List appNonce;
  SessionKeys? sessionKeys;
  SessionKeys? _secondarySessionKeys;

  final List<int> _incomingBuffer = [];

  Protocol({
    required String authKeyHex,
    required this.deviceId,
    required this.deviceModel,
    required this.logger,
  }) : authKey = Uint8List.fromList(hex.decode(authKeyHex));

  void reset() {
    state = ProtocolState.disconnected;
    _sppSeq = 0;
    _dataSeq = 0;
    sessionKeys = null;
    _secondarySessionKeys = null;
    _incomingBuffer.clear();
  }

  int _nextSeq() {
    final seq = _sppSeq;
    _sppSeq = (_sppSeq + 1) & 0xFF;
    return seq;
  }

  int _nextDataSeq() {
    final seq = _dataSeq;
    _dataSeq = (_dataSeq + 1) & 0xFF;
    return seq;
  }

  Uint8List initiateVersionRequest() {
    state = ProtocolState.versionRequestSent;
    return Uint8List.fromList([
      0xBA,
      0xDC,
      0xFE,
      0x00,
      0xC0,
      0x03,
      0x00,
      0x00,
      0x00,
      0x00,
      0xEF,
    ]);
  }

  Uint8List initiateSessionConfig() {
    state = ProtocolState.sessionConfigSent;
    _sppSeq = 0;

    final payload = Uint8List.fromList([
      0x01, // OPCODE_START_SESSION_REQUEST
      0x01, 0x03, 0x00, 0x01, 0x00, 0x00, // Version: type 1, len 3, val 1.0.0
      0x02, 0x02, 0x00, 0x00, 0xFC, // Max Packet Size: type 2, len 2, val 64512
      0x03, 0x02, 0x00, 0x20, 0x00, // TX Win: type 3, len 2, val 32
      0x04, 0x02, 0x00, 0x10, 0x27, // Send Timeout: type 4, len 2, val 10000ms
    ]);

    final packet = Packet(
      packetType: Packet.typeSessionConfig,
      sequenceNumber: _nextSeq(),
      payload: payload,
    );

    return packet.encode();
  }

  Uint8List initiateHandshake() {
    state = ProtocolState.handshakeStep1;

    final random = Random.secure();
    phoneNonce = Uint8List.fromList(
      List.generate(16, (_) => random.nextInt(256)),
    );

    final cmd = Command()
      ..type = 1
      ..subtype = 26
      ..auth = (Auth()..phoneNonce = (PhoneNonce()..nonce = phoneNonce));

    final cmdPayload = cmd.writeToBuffer();

    final dataPayload = BytesBuilder()
      ..addByte(1) // CHANNEL_PROTOBUF
      ..addByte(1) // OPCODE_SEND_PLAINTEXT
      ..add(cmdPayload);

    final packet = Packet(
      packetType: Packet.typeData,
      sequenceNumber: _nextDataSeq(),
      payload: dataPayload.takeBytes(),
    );

    return packet.encode();
  }

  List<Packet> feedBytes(List<int> bytes) {
    _incomingBuffer.addAll(bytes);
    final List<Packet> parsedPackets = [];

    while (true) {
      if (_incomingBuffer.length < 8) break;

      int magicIdx = -1;
      for (int i = 0; i < _incomingBuffer.length - 1; i++) {
        if (_incomingBuffer[i] == 0xA5 && _incomingBuffer[i + 1] == 0xA5) {
          magicIdx = i;
          break;
        }
      }

      if (magicIdx == -1) {
        if (_incomingBuffer.isNotEmpty && _incomingBuffer.last == 0xA5) {
          _incomingBuffer.clear();
          _incomingBuffer.add(0xA5);
        } else {
          _incomingBuffer.clear();
        }
        break;
      }

      if (magicIdx > 0) {
        _incomingBuffer.removeRange(0, magicIdx);
      }

      if (_incomingBuffer.length < 8) break;

      final int payloadLength = _incomingBuffer[4] | (_incomingBuffer[5] << 8);
      final int totalLength = 8 + payloadLength;

      if (_incomingBuffer.length < totalLength) {
        break;
      }

      final Uint8List packetBytes = Uint8List.fromList(
        _incomingBuffer.sublist(0, totalLength),
      );
      _incomingBuffer.removeRange(0, totalLength);

      final packet = Packet.decode(packetBytes);
      if (packet != null) {
        parsedPackets.add(packet);
      }
    }

    return parsedPackets;
  }

  Uint8List buildAck(int seqNum) {
    return Uint8List.fromList([
      0xA5,
      0xA5,
      0x01,
      seqNum,
      0x00,
      0x00,
      0x00,
      0x00,
    ]);
  }

  Command decryptAndParseCommand(Packet packet) {
    try {
      final opCode = packet.payload[1];
      final ciphertext = packet.payload.sublist(2);

      Uint8List plaintext;
      if (opCode == 2) {
        if (sessionKeys == null) {
          throw StateError('Cannot decrypt payload: sessionKeys is null');
        }
        plaintext = Crypto.decrypt(ciphertext, sessionKeys!.decryptionKey);
      } else {
        plaintext = ciphertext;
      }

      return Command.fromBuffer(plaintext);
    } catch (e, stackTrace) {
      logger.error(
        'decryptAndParseCommand failed: $e\n$stackTrace',
      );
      rethrow;
    }
  }

  Uint8List decryptDataPayload(Uint8List dataPayload) {
    if (dataPayload.isEmpty) return Uint8List(0);
    final opCode = dataPayload[0];
    final ciphertext = dataPayload.sublist(1);
    if (opCode == 2) {
      if (sessionKeys == null) {
        throw StateError('Cannot decrypt payload: sessionKeys is null');
      }
      return Crypto.decrypt(ciphertext, sessionKeys!.decryptionKey);
    } else {
      return ciphertext;
    }
  }

  Uint8List? handleHandshakeCommand(Command cmd) {
    if (state == ProtocolState.handshakeStep1) {
      if (cmd.type == 1 && cmd.auth.hasWatchNonce()) {
        final watchNonceObj = cmd.auth.watchNonce;
        watchNonce = Uint8List.fromList(watchNonceObj.nonce);

        sessionKeys = Crypto.deriveKeys(authKey, phoneNonce, watchNonce);

        final verifyData = Uint8List(watchNonce.length + phoneNonce.length);
        verifyData.setRange(0, watchNonce.length, watchNonce);
        verifyData.setRange(watchNonce.length, verifyData.length, phoneNonce);

        final expectedHmac = Crypto.hmacSha256(
          sessionKeys!.decryptionKey,
          verifyData,
        );

        if (hex.encode(expectedHmac) != hex.encode(watchNonceObj.hmac)) {
          logger.error('spp: HMAC mismatch');
          state = ProtocolState.authFailed;
          return null;
        }

        final authDeviceInfo = AuthDeviceInfo()
          ..unknown1 = 0
          ..phoneApiLevel = 33
          ..phoneName = 'CPH2551'
          ..region = 'CN'
          ..unknown3 = 224;

        final encryptedNonces = Crypto.hmacSha256(
          sessionKeys!.encryptionKey,
          Uint8List.fromList(phoneNonce + watchNonce),
        );

        final nonceBytes = BytesBuilder()
          ..add(sessionKeys!.encryptionNonce)
          ..add(Uint8List(8));
        final ccmNonce = nonceBytes.takeBytes();

        final encryptedDeviceInfo = Crypto.encryptCcm(
          authDeviceInfo.writeToBuffer(),
          sessionKeys!.encryptionKey,
          ccmNonce,
        );

        final authStep3 = AuthStep3()
          ..encryptedNonces = encryptedNonces
          ..encryptedDeviceInfo = encryptedDeviceInfo;

        final responseCmd = Command()
          ..type = 1
          ..subtype = 27
          ..auth = (Auth()..authStep3 = authStep3);

        final responsePayload = responseCmd.writeToBuffer();

        final dataPayload = BytesBuilder()
          ..addByte(1) // CHANNEL_PROTOBUF
          ..addByte(1) // OPCODE_SEND_PLAINTEXT
          ..add(responsePayload);

        final packet = Packet(
          packetType: Packet.typeData,
          sequenceNumber: _nextDataSeq(),
          payload: dataPayload.takeBytes(),
        );

        state = ProtocolState.handshakeStep2;
        return packet.encode();
      }
    } else if (state == ProtocolState.handshakeStep2) {
      if (cmd.type == 1) {
        if (cmd.subtype == 27 ||
            cmd.auth.status == 1 ||
            cmd.auth.hasAuthStep4()) {
          final appVerifyPacket = _buildAppVerifyPacket();
          state = ProtocolState.appVerifySent;
          return appVerifyPacket;
        } else {
          state = ProtocolState.authFailed;
        }
      }
    } else if (state == ProtocolState.appVerifySent) {
      if (cmd.type == 1 && cmd.subtype == 26 && cmd.auth.hasWatchNonce()) {
        final watchNonceObj = cmd.auth.watchNonce;
        final deviceNonce = Uint8List.fromList(watchNonceObj.nonce);
        final deviceConfirmHmac = Uint8List.fromList(watchNonceObj.hmac);

        final secondarySessionKeys = Crypto.deriveKeys(
          authKey,
          appNonce,
          deviceNonce,
        );

        final verifyData = Uint8List(deviceNonce.length + appNonce.length);
        verifyData.setRange(0, deviceNonce.length, deviceNonce);
        verifyData.setRange(deviceNonce.length, verifyData.length, appNonce);

        final expectedHmac = Crypto.hmacSha256(
          secondarySessionKeys.decryptionKey,
          verifyData,
        );

        if (hex.encode(expectedHmac) != hex.encode(deviceConfirmHmac)) {
          logger.error('spp: secondary HMAC mismatch');
          state = ProtocolState.authFailed;
          return null;
        }

        _secondarySessionKeys = secondarySessionKeys;

        final confirmData = Uint8List(appNonce.length + deviceNonce.length);
        confirmData.setRange(0, appNonce.length, appNonce);
        confirmData.setRange(appNonce.length, confirmData.length, deviceNonce);

        final appConfirmHmac = Crypto.hmacSha256(
          secondarySessionKeys.encryptionKey,
          confirmData,
        );

        final authDeviceInfo = AuthDeviceInfo()
          ..unknown1 = 0
          ..phoneApiLevel = 33
          ..phoneName = 'CPH2551'
          ..region = 'CN'
          ..unknown3 = 25171684;

        final nonceBytes = BytesBuilder()
          ..add(secondarySessionKeys.encryptionNonce)
          ..add(Uint8List(8));
        final ccmNonce = nonceBytes.takeBytes();

        final encryptedDeviceInfo = Crypto.encryptCcm(
          authDeviceInfo.writeToBuffer(),
          secondarySessionKeys.encryptionKey,
          ccmNonce,
        );

        final authStep3Obj = AuthStep3()
          ..encryptedNonces = appConfirmHmac
          ..encryptedDeviceInfo = encryptedDeviceInfo;

        final responseCmd = Command()
          ..type = 1
          ..subtype = 27
          ..auth = (Auth()..authStep3 = authStep3Obj);

        state = ProtocolState.appConfirmSent;
        return encryptAndWrapCommand(responseCmd);
      }
    } else if (state == ProtocolState.appConfirmSent) {
      if (cmd.type == 1 && cmd.subtype == 27 && cmd.auth.hasAuthStep4()) {
        final authStep4Obj = cmd.auth.authStep4;
        if (authStep4Obj.unknown1 == 1) {
          sessionKeys = _secondarySessionKeys;
          state = ProtocolState.authenticated;
        } else {
          state = ProtocolState.authFailed;
        }
      }
    }
    return null;
  }

  Uint8List _buildAppVerifyPacket() {
    final random = Random.secure();
    appNonce = Uint8List.fromList(
      List.generate(16, (_) => random.nextInt(256)),
    );

    final phoneNonceObj = PhoneNonce()..nonce = appNonce;

    final cmd = Command()
      ..type = 1
      ..subtype = 26
      ..auth = (Auth()..phoneNonce = phoneNonceObj);

    return encryptAndWrapCommand(cmd);
  }

  Uint8List encryptAndWrapCommand(Command cmd) {
    final cmdPayload = cmd.writeToBuffer();
    final ciphertext = Crypto.encrypt(cmdPayload, sessionKeys!.encryptionKey);

    final dataPayload = BytesBuilder()
      ..addByte(1) // CHANNEL_PROTOBUF
      ..addByte(2) // OPCODE_SEND_ENCRYPTED
      ..add(ciphertext);

    final packet = Packet(
      packetType: Packet.typeData,
      sequenceNumber: _nextDataSeq(),
      payload: dataPayload.takeBytes(),
    );

    return packet.encode();
  }

  Uint8List wrapDataChunk(Uint8List chunkBytes) {
    final dataPayload = BytesBuilder()
      ..addByte(2) // CHANNEL_DATA = 2
      ..addByte(1) // OPCODE_SEND_PLAINTEXT = 1
      ..add(chunkBytes);

    final packet = Packet(
      packetType: Packet.typeData,
      sequenceNumber: _nextDataSeq(),
      payload: dataPayload.takeBytes(),
    );

    return packet.encode();
  }
}
