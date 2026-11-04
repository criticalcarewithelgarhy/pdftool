import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/pdf_service.dart';
import '../widgets/file_chip.dart';

class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  String? _pickedName;
  Uint8List? _pickedBytes;
  final _pwCtrl = TextEditingController();
  bool _showPw = false;
  bool _loading = false;
  PdfInfo? _info;

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
      setState(() {
        _pickedName = result.files.single.name;
        _pickedBytes = result.files.single.bytes;
        _info = null;
      });
    }
  }

  Future<void> _loadInfo() async {
    if (_pickedBytes == null) {
      _showSnack('Please pick a PDF first.');
      return;
    }

    setState(() => _loading = true);
    try {
      final pw = _pwCtrl.text.isNotEmpty ? _pwCtrl.text : null;
      final info = PdfService.info(_pickedBytes!, password: pw);
      if (mounted) setState(() => _info = info);
    } catch (e) {
      if (mounted) {
        _showError('Could not read PDF. If it is encrypted, enter the password.\n\nDetail: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Info')),
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
                  _info = null;
                });
              }),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _pwCtrl,
              obscureText: !_showPw,
              decoration: InputDecoration(
                labelText: 'Password (if encrypted)',
                suffixIcon: IconButton(
                  icon: Icon(_showPw ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showPw = !_showPw),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _loadInfo,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Load Info'),
              ),
            ),
            if (_info != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _InfoRow(label: 'Pages', value: '${_info!.pageCount}'),
                      const Divider(),
                      _InfoRow(
                        label: 'Encrypted',
                        value: _info!.isEncrypted ? 'Yes' : 'No',
                        valueColor: _info!.isEncrypted ? Colors.orange : Colors.green,
                      ),
                      const Divider(),
                      _InfoRow(
                        label: 'File size',
                        value: '${_info!.fileSizeKb.toStringAsFixed(1)} KB'
                            ' (${(_info!.fileSizeKb / 1024).toStringAsFixed(2)} MB)',
                      ),
                      const Divider(),
                      _InfoRow(
                        label: 'Title',
                        value: _info!.title.isEmpty ? '—' : _info!.title,
                      ),
                      const Divider(),
                      _InfoRow(
                        label: 'Author',
                        value: _info!.author.isEmpty ? '—' : _info!.author,
                      ),
                      const Divider(),
                      _InfoRow(
                        label: 'Creator',
                        value: _info!.creator.isEmpty ? '—' : _info!.creator,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.black87,
                fontWeight: valueColor != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
