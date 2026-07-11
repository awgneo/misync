import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'connection.dart';
import 'module.dart';
import 'blobs/settings.dart';
import 'blobs/device.dart';
import '../screen.dart';
import '../widgets/panel.dart';
import '../widgets/modal.dart';
import '../widgets/item.dart';
import '../widgets/items.dart';
import '../widgets/button.dart';

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends ScreenState<DeviceScreen> {
  @override
  DeviceModule get module => DeviceModule.instance;

  Future<void> _extractDeviceCredentials() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'log', 'txt'],
      );

      if (result == null ||
          result.files.isEmpty ||
          result.files.first.path == null) {
        return;
      }

      final file = result.files.first;
      final success = await module.extractDeviceCredentials(
        file.path!,
        file.name,
      );

      if (!success) {
        if (!mounted) return;
        await showMiModal<bool>(
          context: context,
          title: 'Pairing Failed',
          body:
              'Failed to extract pairing credentials. Make sure the file is a valid Mi Fitness diagnostics log containing "encryptKey" and MAC address.',
          confirm: 'OK',
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      await showMiModal<bool>(
        context: context,
        title: 'Error Parsing File',
        body: 'An error occurred while parsing the file:\n$e',
        confirm: 'OK',
      );
    }
  }

  @override
  Widget buildScreen(BuildContext context, bool connected) {
    final bool isPaired =
        SettingsBlob.authKeyHex.isNotEmpty && SettingsBlob.watchMac.isNotEmpty;

    return ListenableBuilder(
      listenable: Listenable.merge([
        DeviceConnection.instance,
        DeviceBlob.instance,
        SettingsBlob.instance,
      ]),
      builder: (context, _) {
        final MiButtons? panelActions;
        if (!isPaired) {
          panelActions = MiButtons(
            children: [
              MiButton(
                label: 'Browse Files',
                icon: Icons.search,
                pressed: _extractDeviceCredentials,
              ),
            ],
          );
        } else {
          panelActions = MiButtons(
            children: [
              MiButton(
                label: 'Sync All Now',
                icon: Icons.sync,
                pressed: () async {
                  await module.sync();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Manual sync triggered successfully!'),
                      backgroundColor: Color(0xFF00E5FF),
                    ),
                  );
                },
                color: const Color(0xFF00E5FF),
              ),
            ],
          );
        }

        return MiPanel(
          buttons: panelActions,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isPaired) _buildUnpairedView() else _buildPairedView(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnpairedView() {
    return GestureDetector(
      onTap: _extractDeviceCredentials,
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
          ],
        ),
      ),
    );
  }

  Widget _buildPairedView() {
    final infoState = DeviceBlob.infoState;
    final modelName = infoState.model.isNotEmpty
        ? infoState.model
        : 'Xiaomi Smart Band 10 Pro';
    final serial = infoState.serialNumber.isNotEmpty
        ? infoState.serialNumber
        : 'Unknown';
    final firmware = infoState.firmwareVersion.isNotEmpty
        ? infoState.firmwareVersion
        : 'Unknown';

    String statusText = 'PAIRED';
    if (DeviceConnection.connected.value) {
      statusText = 'CONNECTED';
    } else if (DeviceConnection.connecting) {
      statusText = 'CONNECTING...';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MiItems(
          children: [
            MiItem(
              title: 'Connection Status',
              subtitle: statusText,
              icon: DeviceConnection.connected.value
                  ? Icons.link
                  : Icons.link_off,
            ),
            if (DeviceConnection.connected.value && infoState.batteryLevel > 0)
              MiItem(
                title: 'Battery Level',
                subtitle:
                    '${infoState.batteryLevel}%${infoState.isCharging ? " (Charging)" : ""}',
                icon: infoState.isCharging
                    ? Icons.battery_charging_full
                    : Icons.battery_std,
              ),
            MiItem(
              title: 'Device Model',
              subtitle: modelName,
              icon: Icons.watch,
            ),
            MiItem(
              title: 'MAC Address',
              subtitle: SettingsBlob.watchMac,
              icon: Icons.bluetooth,
            ),
            if (serial.isNotEmpty && serial != 'Unknown')
              MiItem(
                title: 'Serial Number',
                subtitle: serial,
                icon: Icons.info_outline,
              ),
            if (firmware.isNotEmpty && firmware != 'Unknown')
              MiItem(
                title: 'Firmware Version',
                subtitle: firmware,
                icon: Icons.system_update_tv,
              ),
            MiItem(
              title: 'Auth Key (Hex)',
              subtitle: SettingsBlob.authKeyHex,
              icon: Icons.vpn_key,
            ),
            MiItem(
              title: 'Sync Frequency',
              subtitle: 'Background auto-sync interval',
              icon: Icons.sync,
              options: const {
                0: 'Disabled (Manual Sync)',
                5: 'Every 5 Minutes',
                10: 'Every 10 Minutes',
                15: 'Every 15 Minutes',
                30: 'Every 30 Minutes',
                60: 'Every Hour',
              },
              value: SettingsBlob.syncIntervalMinutes,
              selected: (val) async {
                if (val != null) {
                  final current = SettingsBlob.instance.value;
                  await SettingsBlob.instance.update(
                    Settings(
                      authKeyHex: current.authKeyHex,
                      watchMac: current.watchMac,
                      deviceId: current.deviceId,
                      deviceModel: current.deviceModel,
                      syncIntervalMinutes: val as int,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
