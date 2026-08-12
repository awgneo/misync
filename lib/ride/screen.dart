import 'package:flutter/material.dart';
import 'package:misync/screen.dart';
import '../widgets/panel.dart';
import '../widgets/tabs.dart';
import '../widgets/items.dart';
import '../widgets/item.dart';
import '../widgets/button.dart';
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
        final ride = RidesBlob.blob.value;
        return MiPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MiItems(
                children: [
                  MiItem(
                    title: 'Mock Mode Engine',
                    subtitle: 'Simulate live pricing without OAuth keys',
                    primaryIcon: Icons.science_outlined,
                    enabled: ride.mockMode,
                    toggled: (val) => widget.module.setMockMode(val),
                  ),
                  MiItem(
                    title: 'Uber',
                    subtitle: ride.uber.enabled ? 'Enabled' : 'Disabled',
                    primaryIcon: Icons.local_taxi,
                    enabled: ride.uber.enabled,
                    toggled: (val) => widget.module.toggleUber(val),
                  ),
                  MiItem(
                    title: 'Lyft',
                    subtitle: ride.lyft.enabled ? 'Enabled' : 'Disabled',
                    primaryIcon: Icons.directions_car,
                    enabled: ride.lyft.enabled,
                    toggled: (val) => widget.module.toggleLyft(val),
                  ),
                  MiItem(
                    title: 'Waymo',
                    subtitle: ride.waymo.enabled ? 'Enabled' : 'Disabled',
                    primaryIcon: Icons.smart_toy_outlined,
                    enabled: ride.waymo.enabled,
                    toggled: (val) => widget.module.toggleWaymo(val),
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
                      primaryIcon: Icons.location_on,
                      clicked: () => _editDestination(dest),
                      delete: () => widget.module.deleteDestination(dest.id),
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
      child: const _DestinationSetupSheet(),
    );

    if (result != null) {
      await widget.module.addDestination(result);
    }
  }

  Future<void> _editDestination(Destination dest) async {
    final result = await MiPopup.show<Destination>(
      context,
      title: 'Edit Destination',
      child: _DestinationSetupSheet(destination: dest),
    );

    if (result != null) {
      await widget.module.addDestination(result);
    }
  }
}

class _DestinationSetupSheet extends StatefulWidget {
  final Destination? destination;

  const _DestinationSetupSheet({this.destination});

  @override
  State<_DestinationSetupSheet> createState() => _DestinationSetupSheetState();
}

class _DestinationSetupSheetState extends State<_DestinationSetupSheet> {
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
              decoration: InputDecoration(
                labelText: 'Destination Name (e.g. Home, Work)',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF141822),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF26324D)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF26324D)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                ),
              ),
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
              decoration: InputDecoration(
                labelText: 'Full Address',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF141822),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF26324D)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF26324D)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                ),
              ),
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
                    decoration: InputDecoration(
                      labelText: 'Latitude',
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF141822),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF26324D)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF26324D)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lonController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Longitude',
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF141822),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF26324D)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF26324D)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF00E5FF),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _save,
              child: const Text(
                'Save Destination',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
