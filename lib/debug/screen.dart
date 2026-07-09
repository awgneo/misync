import 'package:flutter/material.dart';
import 'logger.dart';
import '../storage/module.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final ScrollController _scrollController = ScrollController();
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _logger.addListener(_onLogsChanged);
    // Scroll to bottom initially
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: false));
  }

  @override
  void dispose() {
    _logger.removeListener(_onLogsChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onLogsChanged() {
    debugPrint('DebugScreen: _onLogsChanged called. Log count: ${_logger.logs.length}');
    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: true));
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (_scrollController.hasClients) {
      final pos = _scrollController.position;
      final isNearBottom = pos.maxScrollExtent - pos.pixels < 100;
      if (isNearBottom || !animated) {
        final target = pos.maxScrollExtent;
        if (animated) {
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(target);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: false));
    final logs = _logger.logs;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CONSOLE',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await StorageModule.instance.clearAll();
                      Logger.info('storage', 'persistent storage wiped successfully, all active configurations reset reactively');
                    },
                    icon: const Icon(Icons.refresh, size: 16, color: Colors.orangeAccent),
                    label: const Text(
                      'Reset',
                      style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _logger.clear(),
                    icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFF00E5FF)),
                    label: const Text(
                      'Clear',
                      style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF26324D)),
            ),
            child: logs.isEmpty
                ? const Center(
                    child: Text(
                      'No logs captured yet. Pair the device or perform actions to begin logging.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      Color color = Colors.green;
                      if (log.contains('← raw') || log.contains('← RAW')) color = Colors.cyan;
                      if (log.contains('→ write') || log.contains('→ send') || log.contains('→ SEND')) color = Colors.yellowAccent;
                      if (log.contains('ERROR') || log.contains('failed')) color = Colors.redAccent;
                      if (log.contains('***')) color = Colors.purpleAccent;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: color,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
