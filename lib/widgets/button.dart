import 'package:flutter/material.dart';

class MiButton {
  final String label;
  final IconData icon;
  final VoidCallback pressed;
  final Color? color;

  const MiButton({
    required this.label,
    required this.icon,
    required this.pressed,
    this.color,
  });
}

class MiButtons extends StatefulWidget {
  final List<MiButton> children;

  const MiButtons({
    super.key,
    required this.children,
  });

  @override
  State<MiButtons> createState() => _MiButtonsState();
}

class _MiButtonsState extends State<MiButtons> with SingleTickerProviderStateMixin {
  bool _isOpen = false;

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Filter out any null entries if list has conditionals
    final activeChildren = widget.children.where((c) => true).toList();

    if (activeChildren.isEmpty) return const SizedBox.shrink();

    if (activeChildren.length == 1) {
      final btn = activeChildren.first;
      return FloatingActionButton(
        heroTag: 'mi_single_fab_${btn.label}',
        onPressed: btn.pressed,
        backgroundColor: btn.color ?? const Color(0xFF00E5FF),
        foregroundColor: Colors.black,
        child: Icon(btn.icon),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isOpen) ...[
          for (int i = 0; i < activeChildren.length; i++) ...[
            _buildMiniFab(activeChildren[i], i),
            const SizedBox(height: 12),
          ],
        ],
        FloatingActionButton(
          heroTag: 'mi_menu_fab',
          onPressed: _toggle,
          backgroundColor: const Color(0xFF00E5FF),
          foregroundColor: Colors.black,
          child: Icon(_isOpen ? Icons.close : Icons.menu),
        ),
      ],
    );
  }

  Widget _buildMiniFab(MiButton btn, int index) {
    final backgroundColor = btn.color ?? const Color(0xFF00E5FF);
    // Determine high contrast icon color based on background
    final foregroundColor = (backgroundColor == const Color(0xFF00E5FF)) ? Colors.black : Colors.white;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF141822),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF26324D)),
          ),
          child: Text(
            btn.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        FloatingActionButton.small(
          heroTag: 'mi_mini_fab_$index',
          onPressed: () {
            _toggle();
            btn.pressed();
          },
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          child: Icon(btn.icon),
        ),
      ],
    );
  }
}
