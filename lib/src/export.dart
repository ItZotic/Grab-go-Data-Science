import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Turns rows into a real CSV file and opens the OS share sheet, so a report can
/// be saved to Drive, emailed, or opened in a spreadsheet app. Works on Android,
/// iOS, desktop, and web (browser downloads the file when no share sheet exists).
Future<void> exportCsv({
  required BuildContext context,
  required String fileName,
  required String title,
  required List<List<Object?>> rows,
}) async {
  final buffer = StringBuffer();
  for (final row in rows) {
    buffer.writeln(row.map(_cell).join(','));
  }
  final bytes = utf8.encode('\uFEFF${buffer.toString()}'); // BOM so Excel reads UTF-8 (₱, ñ) correctly
  final file = XFile.fromData(bytes, name: fileName, mimeType: 'text/csv');

  try {
    await Share.shareXFiles([file], subject: title, text: title);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the share sheet — try again.')));
    }
  }
}

String _cell(Object? value) {
  if (value == null) return '';
  final s = value.toString().replaceAll('"', '""').replaceAll('\n', ' ');
  return s.contains(',') || s.contains('"') ? '"$s"' : s;
}

/// Builds a simple sectioned CSV: title row, blank row, header, data rows.
List<List<Object?>> csvReport(String title, List<Object?> headers, Iterable<List<Object?>> data) {
  return [
    [title],
    const [],
    headers,
    ...data,
  ];
}
