import 'package:flutter/material.dart';
import '../screen.dart';
import '../widgets/tabs.dart';
import '../widgets/panel.dart';
import '../widgets/items.dart';
import '../widgets/item.dart';
import '../widgets/button.dart';
import '../widgets/modal.dart';
import 'module.dart';
import 'blobs/finance.dart';
import 'blobs/investments.dart';

class FinanceScreen extends Screen<FinanceModule> {
  const FinanceScreen(super.module, {super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ScreenState<FinanceScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _apiKeyController;
  late final TextEditingController _secretKeyController;
  late final TextEditingController _symbolController;
  late final TextEditingController _watchlistNameController;

  String? _selectedWatchlistId;

  @override
  void initState() {
    super.initState();
    final investments = InvestmentsBlob.investments;
    _apiKeyController = TextEditingController(text: investments.apiKey);
    _secretKeyController = TextEditingController(text: investments.secretKey);
    _symbolController = TextEditingController();
    _watchlistNameController = TextEditingController();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _secretKeyController.dispose();
    _symbolController.dispose();
    _watchlistNameController.dispose();
    super.dispose();
  }

  Future<void> _saveCredentials() async {
    if (!_formKey.currentState!.validate()) return;

    final current = InvestmentsBlob.investments;
    final updated = current.copyWith(
      apiKey: _apiKeyController.text.trim(),
      secretKey: _secretKeyController.text.trim(),
    );
    await widget.module.saveInvestments(updated);
  }

  void _showAuthModal() {
    final investments = InvestmentsBlob.investments;
    _apiKeyController.text = investments.apiKey;
    _secretKeyController.text = investments.secretKey;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF141822),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(top: BorderSide(color: Color(0xFF26324D))),
            ),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Alpaca API Credentials',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _apiKeyController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('API Key ID'),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'API Key ID is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _secretKeyController,
                    style: const TextStyle(color: Colors.white),
                    obscureText: true,
                    decoration: _buildInputDecoration('Secret Key'),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Secret Key is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      if (!_formKey.currentState!.validate()) return;
                      await _saveCredentials();
                      if (context.mounted) {
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
      },
    );
  }

  void _showAddSymbolModal(List<InvestmentsWatchlist> watchlists) {
    if (_selectedWatchlistId == null) return;

    _symbolController.clear();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF141822),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(top: BorderSide(color: Color(0xFF26324D))),
            ),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Add Stock Symbol',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _symbolController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration(
                      'Stock Symbol (e.g., AAPL)',
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Symbol is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final targetSymbol = _symbolController.text
                          .trim()
                          .toUpperCase();
                      final wl = watchlists.firstWhere(
                        (w) => w.id == _selectedWatchlistId,
                      );
                      final exists = wl.items.any(
                        (i) => i.symbol == targetSymbol,
                      );
                      if (!exists) {
                        final symbols = wl.items.map((i) => i.symbol).toList()
                          ..add(targetSymbol);
                        await widget.module.saveWatchlist(
                          wl.id,
                          wl.name,
                          symbols,
                        );
                        await widget.module.sync();
                      }
                      if (context.mounted) {
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
                      'Add',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddWatchlistModal() {
    _watchlistNameController.clear();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF141822),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(top: BorderSide(color: Color(0xFF26324D))),
            ),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Create Watchlist',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _watchlistNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Watchlist Name'),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Watchlist Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final name = _watchlistNameController.text.trim();
                      try {
                        final newId = await widget.module.createWatchlist(
                          name,
                          [],
                        );
                        await widget.module.sync();
                        if (newId != null) {
                          setState(() {
                            _selectedWatchlistId = newId;
                          });
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to create watchlist: $e'),
                            ),
                          );
                        }
                      }
                      if (context.mounted) {
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
                      'Create',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEditWatchlistNameModal(InvestmentsWatchlist activeWl) {
    _watchlistNameController.text = activeWl.name;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF141822),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(top: BorderSide(color: Color(0xFF26324D))),
            ),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Edit Watchlist Name',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _watchlistNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Watchlist Name'),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Watchlist Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final newName = _watchlistNameController.text.trim();
                      try {
                        final symbols = activeWl.items
                            .map((i) => i.symbol)
                            .toList();
                        await widget.module.saveWatchlist(
                          activeWl.id,
                          newName,
                          symbols,
                        );
                        await widget.module.sync();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to update watchlist name: $e',
                              ),
                            ),
                          );
                        }
                      }
                      if (context.mounted) {
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
      },
    );
  }

  Future<void> _deleteActiveWatchlist(InvestmentsWatchlist activeWl) async {
    final confirm = await showMiModal<bool>(
      context: context,
      title: 'Delete Watchlist',
      label:
          'Are you sure you want to delete the watchlist "${activeWl.name}"?',
      confirm: 'Delete',
    );
    if (confirm == true) {
      try {
        await widget.module.deleteWatchlist(activeWl.id);
        setState(() {
          _selectedWatchlistId = null;
        });
        await widget.module.sync();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete watchlist: $e')),
          );
        }
      }
    }
  }

  @override
  Widget buildScreen(BuildContext context, bool connected) {
    return ListenableBuilder(
      listenable: FinanceBlob.instance,
      builder: (context, _) {
        final finance = FinanceBlob.finance;
        final showInvestments = FinanceBlob.isSubtypeEnabled('investments');

        return MiTabs(
          tabs: [
            MiTab(
              label: 'Finance',
              child: _buildFinanceTab(connected, finance),
            ),
            if (showInvestments)
              MiTab(
                label: 'Investments',
                child: ListenableBuilder(
                  listenable: InvestmentsBlob.instance,
                  builder: (context, _) {
                    final investments = InvestmentsBlob.investments;
                    return _buildInvestmentsTab(connected, investments);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFinanceTab(bool connected, Finance finance) {
    return MiPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              'FINANCE SUBTYPES SOURCES',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          MiItems(
            children: [
              MiItem(
                title: 'Investments Source',
                subtitle: 'Data provider for stock watchlists',
                primaryIcon: const Icon(
                  Icons.trending_up,
                  color: Color(0xFF00E5FF),
                ),
                options: const {'none': 'None (Disabled)', 'alpaca': 'Alpaca'},
                value: FinanceBlob.getSource('investments'),
                selected: (val) async {
                  if (val != null) {
                    final current = FinanceBlob.finance;
                    final updatedSources = Map<String, String>.from(
                      current.sources,
                    );
                    updatedSources['investments'] = val.toString();
                    await FinanceBlob.instance.update(
                      current.copyWith(sources: updatedSources),
                    );
                    await widget.module.sync();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentsTab(bool connected, Investments investments) {
    final hasKeys =
        investments.apiKey.isNotEmpty && investments.secretKey.isNotEmpty;
    final keysSubtitle = hasKeys
        ? 'Configured (Key: ${investments.apiKey.substring(0, investments.apiKey.length > 6 ? 6 : investments.apiKey.length)}...)'
        : 'Tap to configure Alpaca credentials';

    final watchlists = investments.watchlists;
    final watchlistsMap = {for (var wl in watchlists) wl.id: wl.name};

    if (watchlists.isNotEmpty) {
      if (_selectedWatchlistId == null ||
          !watchlists.any((w) => w.id == _selectedWatchlistId)) {
        _selectedWatchlistId = watchlists.first.id;
      }
    } else {
      _selectedWatchlistId = null;
    }

    final activeWl = _selectedWatchlistId != null
        ? watchlists.firstWhere(
            (w) => w.id == _selectedWatchlistId,
            orElse: () =>
                const InvestmentsWatchlist(id: '', name: '', items: []),
          )
        : null;

    final List<InvestmentsWatchlistItem> activeItems = activeWl?.items ?? [];

    return MiPanel(
      buttons: connected && hasKeys
          ? MiButtons(
              children: [
                if (activeWl != null && activeWl.id.isNotEmpty) ...[
                  MiButton(
                    label: 'Add Symbol',
                    icon: Icons.add,
                    pressed: () => _showAddSymbolModal(watchlists),
                  ),
                  MiButton(
                    label: 'Edit Name',
                    icon: Icons.edit,
                    pressed: () => _showEditWatchlistNameModal(activeWl),
                  ),
                  MiButton(
                    label: 'Delete Watchlist',
                    icon: Icons.delete,
                    pressed: () => _deleteActiveWatchlist(activeWl),
                  ),
                ],
                MiButton(
                  label: 'Add Watchlist',
                  icon: Icons.playlist_add,
                  pressed: () => _showAddWatchlistModal(),
                ),
              ],
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MiItems(
            children: [
              MiItem(
                title: 'Alpaca API Keys',
                subtitle: keysSubtitle,
                primaryIcon: const Icon(
                  Icons.vpn_key,
                  color: Color(0xFF00E5FF),
                ),
                clicked: connected ? _showAuthModal : null,
              ),
            ],
          ),
          if (hasKeys && watchlistsMap.isNotEmpty) ...[
            const SizedBox(height: 16),
            MiItems(
              children: [
                MiItem(
                  title: 'Watchlist',
                  subtitle: 'Active watchlist to display',
                  primaryIcon: const Icon(Icons.list, color: Color(0xFF00E5FF)),
                  options: Map<dynamic, String>.from(watchlistsMap),
                  value: _selectedWatchlistId,
                  selected: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedWatchlistId = val.toString();
                      });
                    }
                  },
                ),
                if (activeWl != null &&
                    activeWl.id.isNotEmpty &&
                    activeItems.isNotEmpty)
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: activeItems.length,
                    // ignore: deprecated_member_use
                    onReorder: (oldIndex, newIndex) async {
                      final wl = watchlists.firstWhere(
                        (w) => w.id == _selectedWatchlistId,
                      );
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final symbols = wl.items.map((i) => i.symbol).toList();
                      final item = symbols.removeAt(oldIndex);
                      symbols.insert(newIndex, item);
                      await widget.module.saveWatchlist(
                        wl.id,
                        wl.name,
                        symbols,
                      );
                      await widget.module.sync();
                    },
                    itemBuilder: (context, index) {
                      final item = activeItems[index];
                      return MiItem(
                        key: ValueKey('stock_${item.symbol}_$index'),
                        title: item.symbol,
                        subtitle:
                            '\$${item.price.toStringAsFixed(2)} (${item.change >= 0 ? '+' : ''}${item.change.toStringAsFixed(2)}%)',
                        primaryIcon: Icon(
                          item.change >= 0
                              ? Icons.trending_up
                              : Icons.trending_down,
                          color: item.change >= 0
                              ? const Color(0xFF00E676)
                              : const Color(0xFFFF1744),
                        ),
                        delete: () async {
                          final wl = watchlists.firstWhere(
                            (w) => w.id == _selectedWatchlistId,
                          );
                          final symbols = wl.items.map((i) => i.symbol).toList()
                            ..removeAt(index);
                          await widget.module.saveWatchlist(
                            wl.id,
                            wl.name,
                            symbols,
                          );
                          await widget.module.sync();
                        },
                        order: ReorderableDragStartListener(
                          index: index,
                          child: const Icon(
                            Icons.drag_handle,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ],
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
