import 'package:flutter/material.dart';

class FileChip extends StatelessWidget {
  final String filename;
  final VoidCallback? onRemove;

  const FileChip({
    super.key,
    required this.filename,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.picture_as_pdf, size: 18, color: Color(0xFFD32F2F)),
      label: Text(
        filename,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
      deleteIcon: onRemove != null
          ? const Icon(Icons.close, size: 16)
          : null,
      onDeleted: onRemove,
      backgroundColor: const Color(0xFFFFEBEE),
      side: const BorderSide(color: Color(0xFFEF9A9A)),
    );
  }
}
