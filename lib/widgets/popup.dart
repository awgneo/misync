import 'package:flutter/material.dart';

class MiPopup extends StatelessWidget {
  final String title;
  final Widget child;

  const MiPopup({
    super.key,
    required this.title,
    required this.child,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MiPopup(
        title: title,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.75;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: const BoxDecoration(
          color: Color(0xFF141822),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: Color(0xFF26324D))),
        ),
        padding: const EdgeInsets.only(
          top: 16,
          left: 24,
          right: 24,
          bottom: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
