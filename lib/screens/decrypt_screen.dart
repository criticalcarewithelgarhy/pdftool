import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../services/pdf_service.dart';
import '../services/file_saver.dart';
import '../widgets/file_chip.dart';
import '../widgets/pdf_app_bar.dart';
import 'encrypt_screen.dart';

class DecryptScreen extends StatefulWidget {
  const DecryptScreen({super.key});

  @override
  State<DecryptScreen> createState() => _DecryptScreenState();
}

class _DecryptScreenState extends State<DecryptScreen> {
  String? _pickedName;
  Uint8List? _pickedBytes;
  final _pwCtrl = TextEditingController();
  bool _showPw = false;
  bool _loading = false;
  bool _checking = false;
  bool? _isEncrypted;

  @override
  void dispose() {
    _pwCtrl.dispose();
    super.dispose();
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
      setState(() {
        _pickedName = name;
        _pickedBytes = bytes;
        _isEncrypted = null;
        _checking = true;
      });
      await Future.microtask(() {});
      final encrypted = PdfService.checkEncrypted(bytes);
      if (mounted) {
        setState(() {
          _isEncrypted = encrypted;
          _checking = false;
        });
      }
    }
  }

  Future<void> _process() async {
    if (_pickedBytes == null) {
      _showSnack('Please pick a PDF first.');
      return;
    }
    if (_pwCtrl.text.isEmpty) {
      _showSnack('Enter the PDF password.');
      return;
    }

    setState(() => _loading = true);
    try {
      final decrypted = PdfService.decrypt(_pickedBytes!, _pwCtrl.text);
      final baseName = _pickedName!.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      final outName = '${baseName}_decrypted.pdf';
      final path = await FileSaver.saveToDownloads(decrypted, outName);
      if (!mounted) return;
      if (path == null) {
        _showError('Could not save file. Check storage permissions.');
        return;
      }
      _showSuccessDialog(path, outName);
    } catch (e) {
      if (mounted) {
        _showError('Decryption failed. Check that the password is correct.\n\nDetail: $e');
      }
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
        title: const Text('Decrypted!'),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ],
      ),
    );
  }

  Widget _buildStatusWidget() {
    if (_checking) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Checking file…', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    if (_isEncrypted == null) return const SizedBox.shrink();

    if (!_isEncrypted!) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This PDF has no password. Use Encrypt to add one.',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const EncryptScreen()),
              ),
              child: const Text('Go to Encrypt'),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock, color: Colors.green, size: 16),
          SizedBox(width: 6),
          Text(
            'Locked — ready to decrypt',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canDecrypt = _isEncrypted == true && !_checking;

    return Scaffold(
      appBar: pdfAppBar(
        title: 'Decrypt PDF',
        onSave: _process,
        saveEnabled: !_loading && canDecrypt && _pwCtrl.text.isNotEmpty,
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
                  _isEncrypted = null;
                  _checking = false;
                });
              }),
              _buildStatusWidget(),
            ],
            const SizedBox(height: 24),
            TextField(
              controller: _pwCtrl,
              obscureText: !_showPw,
              decoration: InputDecoration(
                labelText: 'PDF Password',
                suffixIcon: IconButton(
                  icon: Icon(_showPw ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showPw = !_showPw),
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_loading || (_pickedBytes != null && !canDecrypt)) ? null : _process,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Decrypt PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
