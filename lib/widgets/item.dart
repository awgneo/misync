import 'package:flutter/material.dart';

class MiItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? delete;
  final dynamic primaryIcon;
  final dynamic secondaryIcon;
  final bool? enabled;
  final ValueChanged<bool>? toggled;
  final Widget? order;
  final Map<dynamic, String>? options;
  final dynamic value;
  final ValueChanged<dynamic>? selected;
  final VoidCallback? clicked;

  const MiItem({
    super.key,
    required this.title,
    this.subtitle,
    this.delete,
    this.primaryIcon,
    this.secondaryIcon,
    this.enabled,
    this.toggled,
    this.order,
    this.options,
    this.value,
    this.selected,
    this.clicked,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (delete != null) ...[
            InkWell(
              onTap: delete,
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (primaryIcon != null) ...[
            if (primaryIcon is IconData)
              Icon(primaryIcon as IconData, color: const Color(0xFF00E5FF), size: 22)
            else if (primaryIcon is Widget)
              primaryIcon as Widget,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: GestureDetector(
              onTap: clicked,
              behavior: HitTestBehavior.opaque,
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
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (secondaryIcon != null) ...[
            const SizedBox(width: 8),
            if (secondaryIcon is IconData)
              Icon(secondaryIcon as IconData, color: const Color(0xFF00E5FF), size: 22)
            else if (secondaryIcon is Widget)
              secondaryIcon as Widget,
          ],
          if (options != null) ...[
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<dynamic>(
                value: value,
                dropdownColor: const Color(0xFF141822),
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: Color(0xFF00E5FF),
                ),
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                items: options!.entries.map((e) {
                  return DropdownMenuItem<dynamic>(
                    value: e.key,
                    child: Text(e.value),
                  );
                }).toList(),
                onChanged: selected,
              ),
            ),
          ],
          if (enabled != null) ...[
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
          if (order != null) ...[const SizedBox(width: 8), order!],
        ],
      ),
    );
  }
}
