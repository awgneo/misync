import 'package:flutter/material.dart';
import '../screen.dart';
import 'logger.dart';
import 'module.dart';
import '../widgets/panel.dart';
import '../widgets/items.dart';
import '../widgets/item.dart';
import 'blobs/debug.dart';

class DebugScreen extends Screen<DebugModule> {
  const DebugScreen(super.module, {super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ScreenState<DebugScreen> {
  final Set<String> _selectedLevels = {'INFO', 'DEBUG', 'ERROR'};

  Widget _buildFilterChips() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: ['INFO', 'DEBUG', 'ERROR'].map((level) {
        final isSelected = _selectedLevels.contains(level);
        final Color activeColor;
        switch (level) {
          case 'INFO':
            activeColor = Colors.greenAccent;
            break;
          case 'DEBUG':
            activeColor = Colors.grey;
            break;
          case 'ERROR':
            activeColor = Colors.redAccent;
            break;
          default:
            activeColor = Colors.cyan;
        }

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                if (_selectedLevels.length > 1) {
                  _selectedLevels.remove(level);
                }
              } else {
                _selectedLevels.add(level);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withOpacity(0.15)
                  : const Color(0xFF141822),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? activeColor : const Color(0xFF26324D),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 14,
                  color: isSelected ? activeColor : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  level,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildConsoleList() {
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF26324D)),
        ),
        child: ListenableBuilder(
          listenable: Logger.global,
          builder: (context, _) {
            final filteredLogs = Logger.global.logs
                .where((l) => _selectedLevels.contains(l.level))
                .toList()
                .reversed
                .toList();

            if (filteredLogs.isEmpty) {
              return const Center(
                child: Text(
                  'No logs match the selected filters.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              );
            }

            return ListView.builder(
              reverse: true,
              itemCount: filteredLogs.length,
              itemBuilder: (context, index) {
                final record = filteredLogs[index];
                Color color = Colors.white;
                switch (record.level) {
                  case 'INFO':
                    color = Colors.greenAccent;
                    break;
                  case 'DEBUG':
                    color = Colors.grey;
                    break;
                  case 'ERROR':
                    color = Colors.redAccent;
                    break;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    record.toString(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: color,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  @override
  Widget buildScreen(BuildContext context, bool connected) {
    return MiPanel(
      scrollable: false,
      child: Column(
        children: [
          ListenableBuilder(
            listenable: DebugBlob.instance,
            builder: (context, _) {
              return MiItems(
                children: [
                  MiItem(
                    title: 'Enable Logging',
                    subtitle: 'Capture logs from all modules',
                    primaryIcon: Icons.bug_report,
                    enabled: DebugBlob.enabled,
                    toggled: (value) {
                      DebugBlob.enabled = value;
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _buildFilterChips(),
          const SizedBox(height: 16),
          _buildConsoleList(),
        ],
      ),
    );
  }
}
