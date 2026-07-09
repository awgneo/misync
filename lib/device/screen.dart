import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'pairing/extractor.dart';
import 'connection.dart';
import 'module.dart';
import 'blobs/settings.dart';
import 'blobs/device.dart';

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _pickAndParseLog() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'log', 'txt'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null) {
        setState(() {
          _errorMessage = 'Could not read file bytes.';
          _isLoading = false;
        });
        return;
      }

      final creds = Extractor.extractFromBytes(
        Uint8List.fromList(bytes),
        file.name,
      );

      if (creds == null) {
        setState(() {
          _errorMessage =
              'Failed to extract pairing credentials. Make sure the file is a valid Mi Fitness diagnostics log containing "encryptKey" and MAC address.';
          _isLoading = false;
        });
        return;
      }

      // Save credentials via singleton
      await SettingsBlob.instance.update(
        Settings(
          authKeyHex: creds.authKey,
          watchMac: creds.macAddress,
          deviceId: creds.deviceId,
          deviceModel: creds.model,
          syncIntervalMinutes: SettingsBlob.syncIntervalMinutes,
        ),
      );

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device paired successfully!'),
          backgroundColor: Color(0xFF00E5FF),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error parsing file: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _triggerUnpair() async {
    await SettingsBlob.instance.update(SettingsBlob.instance.defaultValue);
    await DeviceConnection.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final bool isPaired =
        SettingsBlob.authKeyHex.isNotEmpty && SettingsBlob.watchMac.isNotEmpty;

    return ListenableBuilder(
      listenable: Listenable.merge([DeviceConnection.instance, DeviceBlob.instance]),
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PAIRING & AUTHENTICATION',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: Color(0xFF00E5FF)),
                        SizedBox(height: 16),
                        Text(
                          'Analyzing diagnostic logs...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else if (!isPaired)
                _buildUnpairedView()
              else
                _buildPairedView(),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnpairedView() {
    return GestureDetector(
      onTap: _pickAndParseLog,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF141822),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF26324D), width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_zip_outlined,
                size: 50,
                color: Color(0xFF00E5FF),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Upload Diagnostic Logs',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select the ZIP file containing your Mi Fitness logs. We will automatically extract the Auth Key and MAC address.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickAndParseLog,
              icon: const Icon(Icons.search, color: Colors.black),
              label: const Text(
                'Browse Files',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPairedView() {
    final infoState = DeviceBlob.infoState;
    final modelName = infoState.model.isNotEmpty ? infoState.model : 'Xiaomi Smart Band 10 Pro';
    final serial = infoState.serialNumber.isNotEmpty ? infoState.serialNumber : 'Unknown';
    final firmware = infoState.firmwareVersion.isNotEmpty ? infoState.firmwareVersion : 'Unknown';

    String statusText = 'PAIRED';
    Color statusColor = const Color(0xFF00E5FF);
    if (DeviceConnection.connected.value) {
      statusText = 'CONNECTED';
      statusColor = const Color(0xFF00E676);
    } else if (DeviceConnection.connecting) {
      statusText = 'CONNECTING...';
      statusColor = Colors.orangeAccent;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF181C26), Color(0xFF1E2433)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF26324D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (DeviceConnection.connected.value && infoState.batteryLevel > 0)
                Row(
                  children: [
                    Icon(
                      infoState.isCharging
                          ? Icons.battery_charging_full
                          : Icons.battery_std,
                      color: statusColor,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${infoState.batteryLevel}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            modelName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoRow('MAC Address', SettingsBlob.watchMac),
          const Divider(color: Color(0xFF26324D), height: 24),
          _buildInfoRow('Serial Number', serial),
          const Divider(color: Color(0xFF26324D), height: 24),
          _buildInfoRow('Firmware Version', firmware),
          const Divider(color: Color(0xFF26324D), height: 24),
          _buildInfoRow('Auth Key (Hex)', SettingsBlob.authKeyHex),
          const Divider(color: Color(0xFF26324D), height: 24),
          _buildSyncIntervalSelector(context),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () async {
                await DeviceModule.instance.sync();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Manual sync triggered successfully!'),
                      backgroundColor: Color(0xFF00E5FF),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.sync, color: Colors.black),
              label: const Text(
                'Sync All Now',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _triggerUnpair,
              icon: const Icon(Icons.link_off, color: Colors.redAccent),
              label: const Text(
                'Unpair Device',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        SelectableText(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontFamily: 'monospace',
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSyncIntervalSelector(BuildContext context) {
    final currentVal = SettingsBlob.syncIntervalMinutes;
    final options = {
      0: 'Disabled (Manual Sync)',
      5: 'Every 5 Minutes',
      10: 'Every 10 Minutes',
      15: 'Every 15 Minutes',
      30: 'Every 30 Minutes',
      60: 'Every Hour',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AUTO-SYNC FREQUENCY',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF141822),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF26324D)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: options.containsKey(currentVal) ? currentVal : 15,
              dropdownColor: const Color(0xFF141822),
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00E5FF)),
              isExpanded: true,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              items: options.entries.map((e) {
                return DropdownMenuItem<int>(
                  value: e.key,
                  child: Text(e.value),
                );
              }).toList(),
              onChanged: (val) async {
                if (val != null) {
                  final current = SettingsBlob.instance.value;
                  await SettingsBlob.instance.update(
                    Settings(
                      authKeyHex: current.authKeyHex,
                      watchMac: current.watchMac,
                      deviceId: current.deviceId,
                      deviceModel: current.deviceModel,
                      syncIntervalMinutes: val,
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
