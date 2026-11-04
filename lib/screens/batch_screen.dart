import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/pdf_service.dart';
import '../services/file_saver.dart';

enum BatchMode { encrypt, decrypt }

class _PdfFile {
  final String name;
  final Uint8List bytes;
  _PdfFile(this.name, this.bytes);
}

class BatchScreen extends StatefulWidget {
  final BatchMode mode;
  const BatchScreen({super.key, required this.mode});

  @override
  State<BatchScreen> createState() => _BatchScreenState();
}

class _BatchScreenState extends State<BatchScreen> {
  final List<_PdfFile> _files = [];
  final _pwCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showPw = false;
  bool _showConfirm = false;
  bool _processing = false;
  int _currentIndex = -1;
  int _succeeded = 0;
  int _failed = 0;
  bool _done = false;

  bool get _isEncrypt => widget.mode == BatchMode.encrypt;

  @override
  void dispose() {
    _pwCtrl.dispose();
    _confirmCtrl.dispose();
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
        _done = false;
        _succeeded = 0;
        _failed = 0;
      });
    }
  }

  Future<void> _processAll() async {
    if (_files.isEmpty) {
      _showSnack('Add at least one PDF.');
      return;
    }
    if (_pwCtrl.text.isEmpty) {
      _showSnack('Password cannot be empty.');
      return;
    }
    if (_isEncrypt && _pwCtrl.text != _confirmCtrl.text) {
      _showSnack('Passwords do not match.');
      return;
    }

    setState(() {
      _processing = true;
      _succeeded = 0;
      _failed = 0;
      _done = false;
      _currentIndex = 0;
    });

    for (int i = 0; i < _files.length; i++) {
      if (!mounted) break;
      setState(() => _currentIndex = i);

      try {
        final f = _files[i];
        late Uint8List result;
        if (_isEncrypt) {
          result = PdfService.encrypt(f.bytes, _pwCtrl.text);
        } else {
          result = PdfService.decrypt(f.bytes, _pwCtrl.text);
        }

        final baseName = f.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
        final suffix = _isEncrypt ? '_encrypted' : '_decrypted';
        final outName = '$baseName$suffix.pdf';
        final path = await FileSaver.saveToDownloads(result, outName);
        if (path != null) {
          setState(() => _succeeded++);
        } else {
          setState(() => _failed++);
        }
      } catch (_) {
        setState(() => _failed++);
      }
    }

    if (mounted) {
      setState(() {
        _processing = false;
        _currentIndex = -1;
        _done = true;
      });
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEncrypt ? 'Batch Encrypt' : 'Batch Decrypt';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: _processing ? null : _addFiles,
              icon: const Icon(Icons.add),
              label: const Text('Add PDFs'),
            ),
            const SizedBox(height: 12),
            if (_files.isNotEmpty) ...[
              Text('${_files.length} file(s):',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (context, index) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: _processing && _currentIndex == index
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf,
                            color: Color(0xFFD32F2F), size: 20),
                    title: Text(_files[index].name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                    trailing: _processing
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setState(() => _files.removeAt(index)),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _pwCtrl,
              obscureText: !_showPw,
              enabled: !_processing,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(_showPw ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showPw = !_showPw),
                ),
              ),
            ),
            if (_isEncrypt) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _confirmCtrl,
                obscureText: !_showConfirm,
                enabled: !_processing,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  suffixIcon: IconButton(
                    icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showConfirm = !_showConfirm),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (_processing) ...[
              LinearProgressIndicator(
                value: _files.isEmpty ? 0 : _currentIndex / _files.length,
              ),
              const SizedBox(height: 8),
              Text('Processing ${_currentIndex + 1} of ${_files.length}…',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
            ],
            if (_done) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _failed == 0 ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _failed == 0
                          ? Colors.green.shade200
                          : Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      _failed == 0 ? Icons.check_circle : Icons.warning,
                      color: _failed == 0 ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_succeeded succeeded, $_failed failed.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _processing ? null : _processAll,
                child: Text(_isEncrypt ? 'Encrypt All' : 'Decrypt All'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
