import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfInfo {
  final int pageCount;
  final String title;
  final String author;
  final String creator;
  final bool isEncrypted;
  final double fileSizeKb;

  const PdfInfo({
    required this.pageCount,
    required this.title,
    required this.author,
    required this.creator,
    required this.isEncrypted,
    required this.fileSizeKb,
  });
}

class PdfService {
  static Uint8List encrypt(Uint8List bytes, String password) {
    final doc = PdfDocument(inputBytes: bytes);
    doc.security.userPassword = password;
    doc.security.ownerPassword = password;
    doc.security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;
    final result = Uint8List.fromList(doc.saveSync());
    doc.dispose();
    return result;
  }

  static Uint8List decrypt(Uint8List bytes, String password) {
    final doc = PdfDocument(inputBytes: bytes, password: password);
    doc.security.userPassword = '';
    doc.security.ownerPassword = '';
    final result = Uint8List.fromList(doc.saveSync());
    doc.dispose();
    return result;
  }

  static Uint8List merge(List<Uint8List> files) {
    final result = PdfDocument.mergeMultipleDocuments(files);
    return Uint8List.fromList(result);
  }

  static List<Uint8List> split(Uint8List bytes, String rangeStr) {
    final doc = PdfDocument(inputBytes: bytes);
    final totalPages = doc.pages.count;
    final ranges = _parseRanges(rangeStr, totalPages);
    final results = <Uint8List>[];

    for (final range in ranges) {
      final startIdx = range[0].clamp(0, totalPages - 1);
      final endIdx = range[1].clamp(0, totalPages - 1);

      final out = PdfDocument();
      for (int p = startIdx; p <= endIdx; p++) {
        final srcPage = doc.pages[p];
        final size = srcPage.size;
        final outPage = out.pages.add(
          PdfPageSettings(size, srcPage.rotation),
        );
        final template = srcPage.createTemplate();
        outPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
      }
      results.add(Uint8List.fromList(out.saveSync()));
      out.dispose();
    }

    doc.dispose();
    return results;
  }

  static PdfInfo info(Uint8List bytes, {String? password}) {
    final providedPassword = password != null && password.isNotEmpty;
    final doc = providedPassword
        ? PdfDocument(inputBytes: bytes, password: password)
        : PdfDocument(inputBytes: bytes);

    final pageCount = doc.pages.count;
    final title = doc.documentInformation.title ?? '';
    final author = doc.documentInformation.author ?? '';
    final creator = doc.documentInformation.creator ?? '';
    final fileSizeKb = bytes.lengthInBytes / 1024.0;

    doc.dispose();

    return PdfInfo(
      pageCount: pageCount,
      title: title,
      author: author,
      creator: creator,
      isEncrypted: providedPassword,
      fileSizeKb: fileSizeKb,
    );
  }

  static List<List<int>> _parseRanges(String rangeStr, int totalPages) {
    final parts = rangeStr.split(',');
    final ranges = <List<int>>[];

    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.contains('-')) {
        final bounds = trimmed.split('-');
        final start = int.tryParse(bounds[0].trim()) ?? 1;
        final end = int.tryParse(bounds[1].trim()) ?? totalPages;
        ranges.add([start - 1, end - 1]);
      } else {
        final page = int.tryParse(trimmed) ?? 1;
        ranges.add([page - 1, page - 1]);
      }
    }

    return ranges;
  }
}
