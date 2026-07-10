import 'package:flutter/material.dart';
import 'button.dart';

class MiPanel extends StatelessWidget {
  final Widget child;
  final MiButtons? buttons;

  const MiPanel({
    super.key,
    required this.child,
    this.buttons,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF0F111A),
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(24, 24, 24, buttons != null ? 100 : 24),
              child: child,
            ),
          ),
          if (buttons != null)
            Positioned(
              right: 16,
              bottom: 16,
              child: buttons!,
            ),
        ],
      ),
    );
  }
}
