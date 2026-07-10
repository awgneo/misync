import 'package:flutter/material.dart';

class MiButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isFAB;

  const MiButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isFAB = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isFAB) {
      return FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: const Color(0xFF00E5FF),
        icon: icon != null ? Icon(icon, color: Colors.black) : null,
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final Widget labelWidget = Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );

    final style = ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF00E5FF),
      foregroundColor: Colors.black,
      disabledBackgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.3),
      disabledForegroundColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );

    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        style: style,
        icon: Icon(icon, size: 18),
        label: labelWidget,
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: style,
      child: labelWidget,
    );
  }
}
