import 'package:flutter/material.dart';
import 'button.dart';

class MiPanel extends StatelessWidget {
  final Widget child;
  final MiButtons? buttons;
  final bool scrollable;

  const MiPanel({
    super.key,
    required this.child,
    this.buttons,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.all(24);
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF0F111A),
      child: Stack(
        children: [
          Positioned.fill(
            child: scrollable
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: padding,
                    child: child,
                  )
                : Padding(padding: padding, child: child),
          ),
          if (buttons != null)
            Positioned(right: 16, bottom: 16, child: buttons!),
        ],
      ),
    );
  }
}
