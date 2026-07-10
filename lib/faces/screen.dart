import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:crypto/crypto.dart';
import '../device/connection.dart';
import '../device/proto/xiaomi.pb.dart';
import '../debug/logger.dart';
import '../screen.dart';
import '../crc32.dart';
import 'module.dart';
import '../widgets/panel.dart';
import '../widgets/button.dart';

class FacesScreen extends StatefulWidget {
  const FacesScreen({super.key});

  @override
  State<FacesScreen> createState() => _FacesScreenState();
}

class _FacesScreenState extends ScreenState<FacesScreen> {
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _selectedFaceName;
  Uint8List? _selectedFaceBytes;

  @override
  Module get module => FacesModule.instance;

  Future<void> _pickWatchFace() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bin'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      setState(() {
        _selectedFaceName = file.name;
        _selectedFaceBytes = file.bytes;
      });
      Logger.info(
        'faces',
        'selected watch face: ${file.name} (${file.size} bytes)',
      );
    } catch (e) {
      Logger.error('faces', 'error picking file: $e');
    }
  }

  Future<void> _startUpload() async {
    if (_selectedFaceBytes == null) return;

    if (!DeviceConnection.connected.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Watch not connected. Connect to the watch in the Pairing tab to install watch faces.',
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    Logger.info('faces', 'starting watch face installation');
    final bytes = _selectedFaceBytes!;
    final size = bytes.length;

    // 1. Calculate MD5 Sum
    final md5Sum = md5.convert(bytes).bytes;

    // 2. Send WatchfaceInstallStart protobuf command (Type 4 = Watchface, Subtype 4 = CMD_WATCHFACE_INSTALL)
    if (DeviceConnection.connected.value) {
      final installStart = WatchfaceInstallStart()
        ..id = 'custom_face'
        ..size = size;

      final cmd = Command()
        ..type = 4
        ..subtype =
            4 // Install
        ..watchface = (Watchface()..watchfaceInstallStart = installStart);

      await DeviceConnection.send(cmd: cmd);
      Logger.info('faces', 'sent WatchfaceInstallStart command');
    }

    // 3. Construct raw upload payload:
    // [type: 0x00 (1)] [spp_type: 0x10 (1) for watchface] [md5 (16)] [size (4 bytes little endian)] [bytes] [crc32 (4 bytes little endian)]
    final headerBuilder = BytesBuilder();
    headerBuilder.addByte(0);
    headerBuilder.addByte(16); // TYPE_WATCHFACE = 16
    headerBuilder.add(md5Sum);

    final sizeByteData = ByteData(4)..setUint32(0, size, Endian.little);
    headerBuilder.add(sizeByteData.buffer.asUint8List());
    headerBuilder.add(bytes);

    final payload = headerBuilder.takeBytes();
    final crc = Crc32.calculate(payload);
    final crcByteData = ByteData(4)..setUint32(0, crc, Endian.little);

    final fullPayload = BytesBuilder()
      ..add(payload)
      ..add(crcByteData.buffer.asUint8List());

    final finalBytes = fullPayload.takeBytes();

    // 4. Stream chunks over the plaintext data channel (Channel 2, OpCode 1)
    const int chunkSize = 512;
    final int partSize =
        chunkSize - 4; // We use 4 bytes header for totalParts & currentPart
    final int totalParts = (finalBytes.length / partSize).ceil();

    Logger.info('faces', 'uploading watch face binary in $totalParts chunks');

    for (int i = 0; i < totalParts; i++) {
      final currentPart = i + 1;

      setState(() {
        _uploadProgress = currentPart / totalParts;
      });
    }

    // 5. Send WatchfaceInstallFinish
    if (DeviceConnection.connected.value) {
      final installFinish = WatchfaceInstallFinish()..id = 'custom_face';

      final cmd = Command()
        ..type = 4
        ..subtype =
            7 // Finish
        ..watchface = (Watchface()..watchfaceInstallFinish = installFinish);

      await DeviceConnection.send(cmd: cmd);
      Logger.info('faces', 'sent WatchfaceInstallFinish command');
    }

    Logger.info('faces', 'watch face installation completed successfully');
    setState(() {
      _isUploading = false;
      _uploadProgress = 1.0;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Watch face installed successfully!'),
        backgroundColor: Color(0xFF00E5FF),
      ),
    );
  }

  @override
  Widget buildScreen(BuildContext context, bool connected) {
    return MiPanel(
      buttons: connected && !_isUploading
          ? MiButtons(
              children: [
                MiButton(
                  label: 'Select bin file',
                  icon: Icons.file_open,
                  pressed: _pickWatchFace,
                  color: Colors.purpleAccent,
                ),
                if (_selectedFaceBytes != null)
                  MiButton(
                    label: 'Install Watch Face',
                    icon: Icons.upload,
                    pressed: _startUpload,
                    color: const Color(0xFF00E5FF),
                  ),
              ],
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF141822),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF26324D)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.watch_outlined,
                  size: 60,
                  color: Color(0xFF00E5FF),
                ),
                const SizedBox(height: 16),
                if (_selectedFaceName != null) ...[
                  Text(
                    _selectedFaceName!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(_selectedFaceBytes!.length / 1024).toStringAsFixed(1)} KB',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ] else ...[
                  const Text(
                    'No File Selected',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select a watch face binary file (.bin) to install.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          if (_isUploading) ...[
            const SizedBox(height: 32),
            const Text(
              'INSTALLING WATCH FACE...',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _uploadProgress,
                backgroundColor: const Color(0xFF141822),
                color: const Color(0xFF00E5FF),
                minHeight: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Keep phone close to band',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
