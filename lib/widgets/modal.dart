import 'package:flutter/material.dart';

Future<T?> showMiModal<T>({
  required BuildContext context,
  required String title,
  String? label,
  String? text,
  String? body,
  String confirm = 'Confirm',
  String cancel = 'Cancel',
}) {
  final isTextInput = label != null;
  final controller = isTextInput ? TextEditingController(text: text) : null;

  return showDialog<T>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF141822),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF26324D)),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (body != null)
              Text(
                body,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            if (body != null && isTextInput) const SizedBox(height: 16),
            if (isTextInput)
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF26324D)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00E5FF)),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(cancel, style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (isTextInput) {
                Navigator.pop(context, controller!.text.trim() as T);
              } else {
                Navigator.pop(context, true as T);
              }
            },
            child: Text(
              confirm,
              style: const TextStyle(
                color: Color(0xFF00E5FF),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    },
  );
}
