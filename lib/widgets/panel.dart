import 'package:flutter/material.dart';

class MiPanel extends StatelessWidget {
  final Widget child;
  final Widget? fab;
  final Color backgroundColor;

  const MiPanel({
    super.key,
    required this.child,
    this.fab,
    this.backgroundColor = const Color(0xFF0F111A),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: Stack(
        children: [
          SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(24, 24, 24, fab != null ? 100 : 24),
            child: child,
          ),
          if (fab != null)
            Positioned(
              right: 16,
              bottom: 16,
              child: fab!,
            ),
        ],
      ),
    );
  }
}
