import 'package:flutter/material.dart';

class MiItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? delete;
  final IconData? icon;
  final bool? enabled;
  final ValueChanged<bool>? toggled;
  final Widget? order;

  const MiItem({
    super.key,
    required this.title,
    this.subtitle,
    this.delete,
    this.icon,
    this.enabled,
    this.toggled,
    this.order,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (delete != null) ...[
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: delete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
          ],
          if (icon != null) ...[
            Icon(icon, color: const Color(0xFF00E5FF), size: 22),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (enabled != null && toggled != null) ...[
            const SizedBox(width: 8),
            Switch(
              value: enabled!,
              onChanged: toggled,
              activeThumbColor: const Color(0xFF00E5FF),
              activeTrackColor: const Color(0xFF00E5FF).withValues(alpha: 0.3),
              inactiveThumbColor: Colors.grey,
              inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
            ),
          ],
          if (order != null) ...[
            const SizedBox(width: 8),
            order!,
          ],
        ],
      ),
    );
  }
}
