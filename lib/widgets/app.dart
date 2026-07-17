import 'package:flutter/material.dart';
import '../platform/module.dart';
import '../platform/app.dart' as phone;

class MiApp extends StatefulWidget {
  final List<String> removed;
  final ValueChanged<String> selected;

  const MiApp({
    super.key,
    required this.removed,
    required this.selected,
  });

  @override
  State<MiApp> createState() => _MiAppState();
}

class _MiAppState extends State<MiApp> {
  final List<phone.App> _apps = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInstalledApps() async {
    try {
      final appsMap = await PlatformModule.module.getApps();
      final list = appsMap.values.toList();

      // Sort alphabetically by name
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (mounted) {
        setState(() {
          _apps.addAll(list);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _apps.where((app) {
      if (widget.removed.contains(app.package)) {
        return false;
      }
      final name = app.name.toLowerCase();
      final pkg = app.package.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || pkg.contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
            ),
          )
        else ...[
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search apps...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
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
              filled: true,
              fillColor: const Color(0xFF141822),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
          ),
          const SizedBox(height: 16),
          filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'No apps found matching search query.',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        if (_searchQuery.trim().isNotEmpty) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              widget.selected(_searchQuery.trim());
                              Navigator.pop(context);
                            },
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: Color(0xFF0F1219),
                            ),
                            label: Text(
                              'Register manually: ${_searchQuery.trim()}',
                              style: const TextStyle(
                                color: Color(0xFF0F1219),
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
                        ],
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final app = filtered[index];

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF141822),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: app.icon != null
                            ? Image.memory(app.icon!, fit: BoxFit.contain)
                            : const Icon(Icons.android, color: Colors.grey),
                      ),
                      title: Text(
                        app.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        app.package,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                      onTap: () {
                        widget.selected(app.package);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        ],
      ],
    );
  }
}
