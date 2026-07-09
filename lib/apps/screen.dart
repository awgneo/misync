import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import '../device/connection.dart';
import '../debug/logger.dart';
import 'module.dart';

class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key});

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  final _module = AppsModule.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (DeviceConnection.connected.value) {
        _module.fetchInstalledApps();
      }
    });
  }

  Future<void> _pickAndInstallRpk() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        throw StateError('Could not read file data');
      }

      // Parse RPK manifest.json to extract package name and version code
      final archive = ZipDecoder().decodeBytes(bytes);
      final manifestFile = archive.findFile('manifest.json');
      if (manifestFile == null) {
        throw StateError('Invalid RPK: manifest.json not found inside package.');
      }
      
      final manifestString = utf8.decode(manifestFile.content as List<int>);
      final manifestJson = jsonDecode(manifestString) as Map<String, dynamic>;
      
      final packageId = manifestJson['package'] as String? ?? '';
      final appName = manifestJson['name'] as String? ?? file.name;
      final versionCode = manifestJson['versionCode'] as int? ?? 1;

      if (packageId.isEmpty) {
        throw StateError('Package identifier is missing in manifest.json');
      }

      Logger.info('apps', 'User selected RPK: $appName ($packageId), version: $versionCode');

      setState(() {
        _module.isUploading.value = true;
      });

      final success = await _module.installApp(packageId, versionCode, bytes);
      
      setState(() {
        _module.isUploading.value = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Successfully installed $appName!' : 'Failed to install $appName.'),
          backgroundColor: success ? const Color(0xFF00E5FF) : Colors.redAccent,
        ),
      );
    } catch (e) {
      setState(() {
        _module.isUploading.value = false;
      });
      Logger.error('apps', 'Failed to pick or parse custom RPK: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _installSystemApp() async {
    try {
      setState(() {
        _module.isUploading.value = true;
      });
      
      final assetData = await DefaultAssetBundle.of(context).load('assets/rpk/com.misync.messages.rpk');
      final bytes = assetData.buffer.asUint8List();
      
      final success = await _module.installApp('com.misync.messages', 1, bytes);
      
      setState(() {
        _module.isUploading.value = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Successfully installed Messages App!' : 'Failed to install Messages App.'),
          backgroundColor: success ? const Color(0xFF00E5FF) : Colors.redAccent,
        ),
      );
    } catch (e) {
      setState(() {
        _module.isUploading.value = false;
      });
      Logger.error('apps', 'Failed to install system RPK: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DeviceConnection.connected,
      builder: (context, connected, _) {
        return Stack(
          children: [
            Scaffold(
              backgroundColor: const Color(0xFF0F111A),
              body: RefreshIndicator(
                color: const Color(0xFF00E5FF),
                backgroundColor: const Color(0xFF141822),
                onRefresh: () async {
                  if (connected) {
                    await _module.fetchInstalledApps();
                  }
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'APPS MANAGER',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!connected) ...[
                        _buildStatusCard(
                          title: 'Disconnected',
                          subtitle: 'Connect to the watch to manage applications.',
                          icon: Icons.link_off,
                          color: Colors.orangeAccent,
                        ),
                      ] else ...[
                        _buildSystemAppCard(),
                        const SizedBox(height: 24),
                        const Text(
                          'INSTALLED APPS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInstalledAppsList(),
                      ],
                    ],
                  ),
                ),
              ),
              floatingActionButton: connected
                  ? FloatingActionButton.extended(
                      onPressed: _pickAndInstallRpk,
                      backgroundColor: const Color(0xFF00E5FF),
                      icon: const Icon(Icons.add, color: Colors.black),
                      label: const Text(
                        'Install Custom RPK',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
            ),
            
            // Progress Indicator Overlay
            ValueListenableBuilder<bool>(
              valueListenable: _module.isUploading,
              builder: (context, uploading, _) {
                if (!uploading) return const SizedBox.shrink();
                return Container(
                  color: Colors.black87,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Card(
                        color: const Color(0xFF141822),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFF26324D)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                              ),
                              const SizedBox(height: 24),
                              ValueListenableBuilder<String>(
                                valueListenable: _module.uploadStatus,
                                builder: (context, status, _) {
                                  return Text(
                                    status,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              ValueListenableBuilder<double>(
                                valueListenable: _module.uploadProgress,
                                builder: (context, progress, _) {
                                  return Column(
                                    children: [
                                      LinearProgressIndicator(
                                        value: progress,
                                        backgroundColor: const Color(0xFF26324D),
                                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${(progress * 100).toStringAsFixed(0)}%',
                                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141822),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF26324D)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSystemAppCard() {
    return ValueListenableBuilder<List<dynamic>>(
      valueListenable: _module.installedApps,
      builder: (context, list, _) {
        final messagesInstalled = list.any((app) => app.id == 'com.misync.messages');
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF141822),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF26324D)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.chat_bubble_outline,
                size: 40,
                color: Color(0xFF00E5FF),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Messages Watch App',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      messagesInstalled ? 'Status: Sideloaded' : 'Status: Missing',
                      style: TextStyle(
                        color: messagesInstalled ? const Color(0xFF00E5FF) : Colors.orangeAccent,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _installSystemApp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(messagesInstalled ? 'Update' : 'Install'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInstalledAppsList() {
    return ValueListenableBuilder<bool>(
      valueListenable: _module.isSyncing,
      builder: (context, syncing, _) {
        if (syncing) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
              ),
            ),
          );
        }

        return ValueListenableBuilder<List<dynamic>>(
          valueListenable: _module.installedApps,
          builder: (context, list, _) {
            if (list.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: const Text(
                  'No third-party apps found.',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final app = list[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141822),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF26324D)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.android, color: Colors.grey, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.name.isNotEmpty ? app.name : 'Unknown Application',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              app.id,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _module.deleteApp(app.id, app.sha),
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
