import 'package:flutter/material.dart';

String _todayLabel() {
  final now = DateTime.now();
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${now.day} ${months[now.month - 1]} ${now.year}';
}

/// AppBar with optional save/action button on the left and today's date on the right.
AppBar pdfAppBar({
  required String title,
  VoidCallback? onSave,       // null → shows back arrow (default behaviour)
  bool saveEnabled = true,
}) {
  return AppBar(
    title: Text(title),
    leading: onSave != null
        ? IconButton(
            icon: const Icon(Icons.save_rounded),
            tooltip: 'Save',
            onPressed: saveEnabled ? onSave : null,
          )
        : null,
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Center(
          child: Text(
            _todayLabel(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    ],
  );
}
