import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../services/pdf_service.dart';
import '../services/file_saver.dart';
import '../widgets/file_chip.dart';

class EncryptScreen extends StatefulWidget {
  const EncryptScreen({super.key});

  @override
  State<EncryptScreen> createState() => _EncryptScreenState();
}

class _EncryptScreenState extends State<EncryptScreen> {
  String? _pickedName;
  Uint8List? _pickedBytes;
  final _pwCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showPw = false;
  bool _showConfirm = false;
  bool _loading = false;

  @override
  void dispose() {
    _pwCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _pickedName = result.files.single.name;
        _pickedBytes = result.files.single.bytes;
      });
    }
  }

  Future<void> _process() async {
    if (_pickedBytes == null) {
      _showSnack('Please pick a PDF first.');
      return;
    }
    if (_pwCtrl.text.isEmpty) {
      _showSnack('Password cannot be empty.');
      return;
    }
    if (_pwCtrl.text != _confirmCtrl.text) {
      _showSnack('Passwords do not match.');
      return;
    }

    setState(() => _loading = true);
    try {
      final encrypted = PdfService.encrypt(_pickedBytes!, _pwCtrl.text);
      final baseName = _pickedName!.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      final outName = '${baseName}_encrypted.pdf';
      final path = await FileSaver.saveToDownloads(encrypted, outName);
      if (!mounted) return;
      if (path == null) {
        _showError('Could not save file. Check storage permissions.');
        return;
      }
      _showSuccessSnack(path, outName);
    } catch (e) {
      if (mounted) _showError('Encryption failed: $e');
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnack(String path, String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved: $name'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => OpenFilex.open(path),
        ),
      ),
    );
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Encrypted!'),
        content: Text('Saved to Downloads:\n$name'),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Encrypt PDF')),
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
                });
              }),
            ],
            const SizedBox(height: 24),
            TextField(
              controller: _pwCtrl,
              obscureText: !_showPw,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(_showPw ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showPw = !_showPw),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirmCtrl,
              obscureText: !_showConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                suffixIcon: IconButton(
                  icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showConfirm = !_showConfirm),
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _process,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Encrypt PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
