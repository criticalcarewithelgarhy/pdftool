import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/pdf_app_bar.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../services/pdf_service.dart';
import '../services/file_saver.dart';
import '../widgets/file_chip.dart';

class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key});

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  String? _pickedName;
  Uint8List? _pickedBytes;
  int? _pageCount;
  final _rangeCtrl = TextEditingController();
  final _outNameCtrl = TextEditingController();
  bool _loading = false;
  String? _rangeError;
  final List<Map<String, String>> _resultFiles = [];

  @override
  void initState() {
    super.initState();
    _rangeCtrl.addListener(_validateRange);
  }

  @override
  void dispose() {
    _rangeCtrl.removeListener(_validateRange);
    _rangeCtrl.dispose();
    _outNameCtrl.dispose();
    super.dispose();
  }

  void _validateRange() {
    if (_pageCount == null || _rangeCtrl.text.trim().isEmpty) {
      if (_rangeError != null) setState(() => _rangeError = null);
      return;
    }
    final error = _checkRangeExceedsPages(_rangeCtrl.text.trim(), _pageCount!);
    if (error != _rangeError) setState(() => _rangeError = error);
  }

  String? _checkRangeExceedsPages(String rangeStr, int maxPages) {
    final parts = rangeStr.split(',');
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.contains('-')) {
        final bounds = trimmed.split('-');
        final end = int.tryParse(bounds.length > 1 ? bounds[1].trim() : '');
        if (end != null && end > maxPages) return 'Max page is $maxPages';
        final start = int.tryParse(bounds[0].trim());
        if (start != null && start > maxPages) return 'Max page is $maxPages';
      } else {
        final page = int.tryParse(trimmed);
        if (page != null && page > maxPages) return 'Max page is $maxPages';
      }
    }
    return null;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      final name = result.files.single.name;
      int count = 0;
      try {
        final info = PdfService.info(bytes);
        count = info.pageCount;
      } catch (_) {}
      setState(() {
        _pickedName = name;
        _pickedBytes = bytes;
        _pageCount = count;
        _outNameCtrl.text = name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
        _resultFiles.clear();
        _rangeError = null;
      });
    }
  }

  Future<void> _split() async {
    if (_pickedBytes == null) {
      _showSnack('Please pick a PDF first.');
      return;
    }
    if (_rangeCtrl.text.trim().isEmpty) {
      _showSnack('Enter a page range (e.g. 1-3, 5, 7-9).');
      return;
    }
    if (_rangeError != null) {
      _showSnack(_rangeError!);
      return;
    }

    setState(() {
      _loading = true;
      _resultFiles.clear();
    });

    try {
      final parts = PdfService.split(_pickedBytes!, _rangeCtrl.text.trim());
      final baseName = _outNameCtrl.text.trim().isEmpty
          ? 'split'
          : _outNameCtrl.text.trim();

      final saved = <Map<String, String>>[];
      for (int i = 0; i < parts.length; i++) {
        final outName = '${baseName}_part${i + 1}.pdf';
        final path = await FileSaver.saveToDownloads(parts[i], outName);
        if (path != null) {
          saved.add({'name': outName, 'path': path});
        }
      }

      if (!mounted) return;
      setState(() => _resultFiles.addAll(saved));
      if (saved.isEmpty) {
        _showError('No files were saved. Check storage permissions.');
      } else {
        _showSnack('Split into ${saved.length} file(s). Saved to Downloads.');
      }
    } catch (e) {
      if (mounted) _showError('Split failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pdfAppBar(
        title: 'Split PDF',
        onSave: _split,
        saveEnabled: !_loading && _pickedBytes != null && _rangeError == null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Pick PDF'),
            ),
            if (_pickedName != null) ...[
              const SizedBox(height: 12),
              FileChip(filename: _pickedName!, onRemove: () {
                setState(() {
                  _pickedName = null;
                  _pickedBytes = null;
                  _pageCount = null;
                  _rangeError = null;
                  _resultFiles.clear();
                });
              }),
              if (_pageCount != null && _pageCount! > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '$_pageCount page${_pageCount == 1 ? '' : 's'} — enter range below (e.g. 1-3, 5, 7-9)',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _rangeCtrl,
              decoration: InputDecoration(
                labelText: 'Page range',
                hintText: 'e.g. 1-3, 5, 7-9',
                helperText: 'Comma-separated pages or ranges',
                errorText: _rangeError,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _outNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Output base name',
                helperText: 'Files will be saved as name_part1.pdf, name_part2.pdf…',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_loading || _rangeError != null) ? null : _split,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Split PDF'),
              ),
            ),
            if (_resultFiles.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('Output files:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._resultFiles.map((f) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFE65100)),
                    title: Text(f['name']!, overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.open_in_new, size: 20),
                          onPressed: () => OpenFilex.open(f['path']!),
                          tooltip: 'Open',
                        ),
                        IconButton(
                          icon: const Icon(Icons.share, size: 20),
                          onPressed: () => Share.shareXFiles(
                            [XFile(f['path']!)],
                            text: f['name']!,
                          ),
                          tooltip: 'Share',
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
