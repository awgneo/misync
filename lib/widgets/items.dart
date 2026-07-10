import 'package:flutter/material.dart';

class MiItems extends StatelessWidget {
  final List<Widget> children;

  const MiItems({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Material(
      color: const Color(0xFF141822),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF26324D)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(
                color: Color(0xFF26324D),
                height: 1,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}
