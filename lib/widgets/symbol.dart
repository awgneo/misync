import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MiSymbol extends StatefulWidget {
  final String currentSymbol;
  final ValueChanged<String> onSymbolChanged;

  const MiSymbol({
    super.key,
    required this.currentSymbol,
    required this.onSymbolChanged,
  });

  @override
  State<MiSymbol> createState() => _MiSymbolState();
}

class _MiSymbolState extends State<MiSymbol> {
  void _showPicker(BuildContext context) {
    showDialog<String>(
      context: context,
      builder: (context) {
        return const _SymbolPickerDialog();
      },
    ).then((selected) {
      if (selected != null && selected.isNotEmpty) {
        widget.onSymbolChanged(selected);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: InkWell(
        onTap: () => _showPicker(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF141822),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF26324D)),
          ),
          child: Text(
            widget.currentSymbol.isEmpty ? 'bolt' : widget.currentSymbol,
            style: const TextStyle(
              fontFamily: 'Material',
              fontSize: 28,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _SymbolPickerDialog extends StatefulWidget {
  const _SymbolPickerDialog();

  @override
  State<_SymbolPickerDialog> createState() => _SymbolPickerDialogState();
}

class _SymbolPickerDialogState extends State<_SymbolPickerDialog> {
  List<String> _allSymbols = [];
  List<String> _filteredSymbols = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSymbols();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSymbols() async {
    try {
      final data = await rootBundle.loadString('assets/font/material.txt');
      final List<String> symbols = [];
      for (final line in data.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final parts = trimmed.split(' ');
        if (parts.isNotEmpty && parts[0].isNotEmpty) {
          symbols.add(parts[0]);
        }
      }
      if (mounted) {
        setState(() {
          _allSymbols = symbols;
          _filteredSymbols = _allSymbols.take(60).toList();
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

  void _onSearchChanged(String val) {
    final query = val.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredSymbols = _allSymbols.take(60).toList();
      } else {
        _filteredSymbols = _allSymbols
            .where((s) => s.contains(query))
            .take(60)
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF141822),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF26324D)),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Select Symbol',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 350,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search symbol name (e.g. play, lock)...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.grey,
                  size: 20,
                ),
                filled: true,
                fillColor: const Color(0xFF0F111A),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00E5FF),
                      ),
                    )
                  : _filteredSymbols.isEmpty
                  ? const Center(
                      child: Text(
                        'No matching symbols found',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _filteredSymbols.map((symbol) {
                          return InkWell(
                            onTap: () => Navigator.pop(context, symbol),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F111A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF26324D),
                                ),
                              ),
                              child: Text(
                                symbol,
                                style: const TextStyle(
                                  fontFamily: 'Material',
                                  fontSize: 28,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
