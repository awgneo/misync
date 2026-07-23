import 'package:flutter/material.dart';
import '../screen.dart';
import 'module.dart';
import 'blobs/passes.dart';
import 'blobs/wallet.dart';
import '../widgets/panel.dart';
import '../widgets/items.dart';
import '../widgets/item.dart';
import '../widgets/modal.dart';

class WalletScreen extends Screen<WalletModule> {
  const WalletScreen(super.module, {super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ScreenState<WalletScreen> {
  void _showBarcodeDetails(Pass pass) {
    final fieldsBody = pass.fields.map((f) => '${f.label}: ${f.value}').join('\n');
    showMiModal<void>(
      context: context,
      title: pass.organizationName,
      body:
          '${pass.description}\n\n'
          'FIELDS:\n$fieldsBody\n\n'
          'BARCODE MESSAGE:\n${pass.barcodeMessage}\n\n'
          'Format: ${pass.barcodeFormat}\n'
          'Serial: ${pass.serialNumber}',
      confirm: 'OK',
      cancel: 'Dismiss',
    );
  }

  @override
  Widget buildScreen(BuildContext context, bool connected) {
    return ListenableBuilder(
      listenable: Listenable.merge([PassesBlob.instance, WalletBlob.instance]),
      builder: (context, _) {
        final passes = PassesBlob.passes;
        final walletSettings = WalletBlob.instance.value;
        final retentionDays = walletSettings.retentionDays;

        final enabledItem = MiItem(
          title: 'Wallet Sync',
          subtitle: 'Synchronize passes to the watch',
          primaryIcon: Icons.wallet,
          enabled: walletSettings.enabled,
          toggled: (val) => widget.module.saveSettings(enabled: val),
        );

        final dropdownItem = MiItem(
          title: 'Pass Retention',
          subtitle: 'Keep passes and sync for a set period',
          primaryIcon: Icons.auto_delete,
          options: const {
            7: '7 Days',
            15: '15 Days',
            30: '30 Days',
            90: '90 Days',
            180: '180 Days',
            365: '1 Year',
            0: 'Forever',
          },
          value: retentionDays,
          selected: (val) {
            if (val != null) {
              widget.module.saveSettings(retentionDays: val as int);
            }
          },
        );

        final List<Widget> children = [
          MiItems(children: [enabledItem, dropdownItem]),
          const SizedBox(height: 16),
        ];

        if (passes.isEmpty) {
          children.add(
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wallet_giftcard, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No Boarding Passes Intercepted',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Open a .pkpass file from an airline app or browser link. MiSync will automatically capture the barcode data.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          children.add(
            MiItems(
              children: passes.map((pass) {
                return MiItem(
                  title: pass.organizationName,
                  subtitle: pass.description,
                  primaryIcon: Icons.qr_code_2,
                  delete: () => widget.module.removePass(pass.serialNumber),
                  clicked: () => _showBarcodeDetails(pass),
                );
              }).toList(),
            ),
          );
        }

        return MiPanel(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }
}
