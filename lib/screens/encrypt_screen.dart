import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../services/pdf_service.dart';
import '../services/file_saver.dart';
import '../widgets/file_chip.dart';
import 'decrypt_screen.dart';

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
  bool _checking = false;
  bool? _isEncrypted;

  @override
  void initState() {
    super.initState();
    _pwCtrl.addListener(() => setState(() {}));
  }

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

    if (_isEncrypted!) {
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
                    'Already encrypted. Decrypt it first if you want to re-encrypt.',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DecryptScreen()),
              ),
              child: const Text('Go to Decrypt'),
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
          Icon(Icons.lock_open, color: Colors.green, size: 16),
          SizedBox(width: 6),
          Text(
            'Ready to encrypt',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  _PasswordStrength _getStrength(String pw) {
    if (pw.isEmpty) return _PasswordStrength.none;
    if (pw.length < 6) return _PasswordStrength.weak;
    final hasUpper = pw.contains(RegExp(r'[A-Z]'));
    final hasLower = pw.contains(RegExp(r'[a-z]'));
    final hasDigit = pw.contains(RegExp(r'[0-9]'));
    final hasSpecial = pw.contains(RegExp(r'[^A-Za-z0-9]'));
    final mixed = (hasUpper ? 1 : 0) + (hasLower ? 1 : 0) + (hasDigit ? 1 : 0) + (hasSpecial ? 1 : 0);
    if (pw.length > 10 && mixed >= 3) return _PasswordStrength.strong;
    return _PasswordStrength.medium;
  }

  Widget _buildStrengthIndicator(String pw) {
    final strength = _getStrength(pw);
    if (strength == _PasswordStrength.none) return const SizedBox.shrink();

    final Color barColor;
    final String label;
    final double fraction;

    switch (strength) {
      case _PasswordStrength.weak:
        barColor = Colors.red;
        label = 'Weak';
        fraction = 0.33;
      case _PasswordStrength.medium:
        barColor = Colors.orange;
        label = 'Medium';
        fraction = 0.66;
      case _PasswordStrength.strong:
        barColor = Colors.green;
        label = 'Strong';
        fraction = 1.0;
      case _PasswordStrength.none:
        return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: barColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canEncrypt = _isEncrypted == false && !_checking;
    final pw = _pwCtrl.text;

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
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(_showPw ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showPw = !_showPw),
                ),
              ),
            ),
            _buildStrengthIndicator(pw),
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
                onPressed: (_loading || (_pickedBytes != null && !canEncrypt)) ? null : _process,
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

enum _PasswordStrength { none, weak, medium, strong }
