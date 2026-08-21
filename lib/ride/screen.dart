import 'package:flutter/material.dart';
import '../screen.dart';
import '../widgets/tabs.dart';
import '../widgets/panel.dart';
import '../widgets/items.dart';
import '../widgets/item.dart';
import '../widgets/button.dart';
import '../widgets/modal.dart';
import '../widgets/popup.dart';
import 'blobs/destinations.dart';
import 'blobs/rides.dart';
import 'module.dart';

class RideScreen extends Screen<RideModule> {
  const RideScreen(super.module, {super.key});

  @override
  State<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends ScreenState<RideScreen> {
  final _uberFormKey = GlobalKey<FormState>();
  final _lyftFormKey = GlobalKey<FormState>();

  late final TextEditingController _uberClientIdController;
  late final TextEditingController _uberClientSecretController;
  late final TextEditingController _uberServerTokenController;
  late final TextEditingController _uberAccessTokenController;

  late final TextEditingController _lyftClientIdController;
  late final TextEditingController _lyftClientSecretController;
  late final TextEditingController _lyftAccessTokenController;

  @override
  void initState() {
    super.initState();
    final rides = RidesBlob.rides;

    _uberClientIdController = TextEditingController(text: rides.uber.clientId);
    _uberClientSecretController = TextEditingController(text: rides.uber.clientSecret);
    _uberServerTokenController = TextEditingController(text: rides.uber.serverToken);
    _uberAccessTokenController = TextEditingController(text: rides.uber.accessToken);

    _lyftClientIdController = TextEditingController(text: rides.lyft.clientId);
    _lyftClientSecretController = TextEditingController(text: rides.lyft.clientSecret);
    _lyftAccessTokenController = TextEditingController(text: rides.lyft.accessToken);
  }

  @override
  void dispose() {
    _uberClientIdController.dispose();
    _uberClientSecretController.dispose();
    _uberServerTokenController.dispose();
    _uberAccessTokenController.dispose();

    _lyftClientIdController.dispose();
    _lyftClientSecretController.dispose();
    _lyftAccessTokenController.dispose();
    super.dispose();
  }

  void _showUberAuthModal() {
    final rides = RidesBlob.rides;
    _uberClientIdController.text = rides.uber.clientId;
    _uberClientSecretController.text = rides.uber.clientSecret;
    _uberServerTokenController.text = rides.uber.serverToken;
    _uberAccessTokenController.text = rides.uber.accessToken;

    MiPopup.show(
      context,
      title: 'Uber API Credentials',
      child: Form(
        key: _uberFormKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _uberClientIdController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration('Client ID / Application ID'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _uberClientSecretController,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: _buildInputDecoration('Client Secret'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _uberAccessTokenController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration('Access Token / Bearer Token (Optional)'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _uberServerTokenController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration('Server Token (Optional)'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final current = RidesBlob.rides;
                  final updated = current.copyWith(
                    uber: current.uber.copyWith(
                      serverToken: _uberServerTokenController.text.trim(),
                      accessToken: _uberAccessTokenController.text.trim(),
                      clientId: _uberClientIdController.text.trim(),
                      clientSecret: _uberClientSecretController.text.trim(),
                    ),
                  );
                  await widget.module.saveRides(updated);
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLyftAuthModal() {
    final rides = RidesBlob.rides;
    _lyftClientIdController.text = rides.lyft.clientId;
    _lyftClientSecretController.text = rides.lyft.clientSecret;
    _lyftAccessTokenController.text = rides.lyft.accessToken;

    MiPopup.show(
      context,
      title: 'Lyft API Credentials',
      child: Form(
        key: _lyftFormKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _lyftAccessTokenController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration('Bearer Token / Client Token'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lyftClientIdController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration('Client ID (Optional)'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lyftClientSecretController,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: _buildInputDecoration('Client Secret (Optional)'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final current = RidesBlob.rides;
                  final updated = current.copyWith(
                    lyft: current.lyft.copyWith(
                      accessToken: _lyftAccessTokenController.text.trim(),
                      clientId: _lyftClientIdController.text.trim(),
                      clientSecret: _lyftClientSecretController.text.trim(),
                    ),
                  );
                  await widget.module.saveRides(updated);
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget buildScreen(BuildContext context, bool connected) {
    return MiTabs(
      tabs: [
        MiTab(
          label: 'Providers',
          child: _buildProvidersTab(context, connected),
        ),
        MiTab(
          label: 'Destinations',
          child: _buildDestinationsTab(context, connected),
        ),
      ],
    );
  }

  Widget _buildProvidersTab(BuildContext context, bool connected) {
    return ListenableBuilder(
      listenable: RidesBlob.blob,
      builder: (context, _) {
        final rides = RidesBlob.rides;

        final uberHasKeys = rides.uber.hasCredentials;
        final uberSubtitle = uberHasKeys
            ? 'Configured (${rides.uber.clientId.isNotEmpty ? 'ID: ${rides.uber.clientId.substring(0, rides.uber.clientId.length > 6 ? 6 : rides.uber.clientId.length)}...' : 'Token active'})'
            : 'Tap to configure credentials';

        final lyftHasKeys = rides.lyft.hasCredentials;
        final lyftSubtitle = lyftHasKeys
            ? 'Configured (${rides.lyft.clientId.isNotEmpty ? 'ID: ${rides.lyft.clientId.substring(0, rides.lyft.clientId.length > 6 ? 6 : rides.lyft.clientId.length)}...' : 'Token active'})'
            : 'Tap to configure credentials';

        return MiPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MiItems(
                children: [
                  MiItem(
                    title: 'Uber',
                    subtitle: uberSubtitle,
                    primaryIcon: const Icon(
                      Icons.local_taxi,
                      color: Color(0xFF00E5FF),
                    ),
                    enabled: rides.uber.enabled,
                    toggled: (val) => widget.module.toggleUber(val),
                    clicked: connected ? _showUberAuthModal : null,
                  ),
                  MiItem(
                    title: 'Lyft',
                    subtitle: lyftSubtitle,
                    primaryIcon: const Icon(
                      Icons.directions_car,
                      color: Color(0xFF00E5FF),
                    ),
                    enabled: rides.lyft.enabled,
                    toggled: (val) => widget.module.toggleLyft(val),
                    clicked: connected ? _showLyftAuthModal : null,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDestinationsTab(BuildContext context, bool connected) {
    return ListenableBuilder(
      listenable: DestinationsBlob.blob,
      builder: (context, _) {
        final destinations = DestinationsBlob.blob.value;
        return MiPanel(
          buttons: MiButtons(
            children: [
              MiButton(
                label: 'Add Destination',
                icon: Icons.add_location_alt_outlined,
                pressed: () => _addDestination(),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (destinations.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No saved destinations. Tap below to add one.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                MiItems(
                  children: destinations.map((dest) {
                    return MiItem(
                      title: dest.name,
                      subtitle:
                          '${dest.address} (${dest.latitude}, ${dest.longitude})',
                      primaryIcon: const Icon(
                        Icons.location_on,
                        color: Color(0xFF00E5FF),
                      ),
                      clicked: () => _editDestination(dest),
                      delete: () => _deleteDestination(dest),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addDestination() async {
    final result = await MiPopup.show<Destination>(
      context,
      title: 'Add Destination',
      child: const _DestinationSetupModal(),
    );

    if (result != null) {
      await widget.module.saveDestination(result);
    }
  }

  Future<void> _editDestination(Destination dest) async {
    final result = await MiPopup.show<Destination>(
      context,
      title: 'Edit Destination',
      child: _DestinationSetupModal(destination: dest),
    );

    if (result != null) {
      await widget.module.saveDestination(result);
    }
  }

  Future<void> _deleteDestination(Destination dest) async {
    final confirm = await showMiModal<bool>(
      context: context,
      title: 'Delete',
      label: 'Are you sure you want to delete "${dest.name}"?',
      confirm: 'Delete',
    );
    if (confirm == true) {
      await widget.module.deleteDestination(dest.id);
    }
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFF0F111A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF26324D)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF26324D)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF00E5FF)),
      ),
    );
  }
}

class _DestinationSetupModal extends StatefulWidget {
  final Destination? destination;

  const _DestinationSetupModal({this.destination});

  @override
  State<_DestinationSetupModal> createState() => _DestinationSetupModalState();
}

class _DestinationSetupModalState extends State<_DestinationSetupModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _latController;
  late final TextEditingController _lonController;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.destination?.name ?? '');
    _addressController =
        TextEditingController(text: widget.destination?.address ?? '');
    _latController = TextEditingController(
      text: widget.destination?.latitude.toString() ?? '',
    );
    _lonController = TextEditingController(
      text: widget.destination?.longitude.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final lat = double.tryParse(_latController.text.trim()) ?? 0.0;
    final lon = double.tryParse(_lonController.text.trim()) ?? 0.0;

    final dest = Destination(
      id: widget.destination?.id ??
          'dest_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      address: address.isNotEmpty ? address : name,
      latitude: lat,
      longitude: lon,
    );

    Navigator.of(context).pop(dest);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration('Destination Name (e.g. Home, Work)'),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a destination name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration('Full Address'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Latitude'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lonController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Longitude'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Save Destination',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFF0F111A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF26324D)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF26324D)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF00E5FF)),
      ),
    );
  }
}
