import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../services/pdf_service.dart';
import '../services/file_saver.dart';

class _PdfFile {
  final String name;
  final Uint8List bytes;
  _PdfFile(this.name, this.bytes);
}

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key});

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  final List<_PdfFile> _files = [];
  final _outNameCtrl = TextEditingController(text: 'merged');
  bool _loading = false;

  @override
  void dispose() {
    _outNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _addFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
      withData: true,
    );
    if (result != null) {
      setState(() {
        for (final f in result.files) {
          if (f.bytes != null) {
            _files.add(_PdfFile(f.name, f.bytes!));
          }
        }
      });
    }
  }

  Future<void> _merge() async {
    if (_files.length < 2) {
      _showSnack('Add at least 2 PDFs to merge.');
      return;
    }

    setState(() => _loading = true);
    try {
      final merged = PdfService.merge(_files.map((f) => f.bytes).toList());
      final outName = '${_outNameCtrl.text.trim().isEmpty ? 'merged' : _outNameCtrl.text.trim()}.pdf';
      final path = await FileSaver.saveToDownloads(merged, outName);
      if (!mounted) return;
      if (path == null) {
        _showError('Could not save file. Check storage permissions.');
        return;
      }
      _showSuccessDialog(path, outName);
    } catch (e) {
      if (mounted) _showError('Merge failed: $e');
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

  void _showSuccessDialog(String path, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Merged!'),
        content: Text('${_files.length} PDFs merged.\nSaved: $name'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              OpenFilex.open(path);
            },
            child: const Text('Open'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Share.shareXFiles([XFile(path)], text: name);
            },
            child: const Text('Share'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Merge PDFs')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: _addFiles,
              icon: const Icon(Icons.add),
              label: const Text('Add PDFs'),
            ),
            const SizedBox(height: 16),
            if (_files.isNotEmpty) ...[
              Text('${_files.length} file(s) selected:',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    return Dismissible(
                      key: ValueKey('${_files[index].name}$index'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red[100],
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Icon(Icons.delete, color: Colors.red),
                      ),
                      onDismissed: (_) => setState(() => _files.removeAt(index)),
                      child: ListTile(
                        leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFD32F2F)),
                        title: Text(_files[index].name,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                            '${(_files[index].bytes.lengthInBytes / 1024).toStringAsFixed(1)} KB'),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _files.removeAt(index)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else
              const Expanded(
                child: Center(
                  child: Text(
                    'No files selected.\nTap "Add PDFs" to pick files.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _outNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Output filename',
                suffixText: '.pdf',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _merge,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Merge PDFs'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
