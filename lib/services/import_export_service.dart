import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/foundation.dart';

/// Handles import and export of Excel files. Caller must validate schema before writing to Firestore.
class ImportExportService {
  /// Let user pick an Excel file and return bytes. Returns {'ok': true, 'bytes': ...} or {'ok': false, 'error': ...}
  Future<Map<String, dynamic>> pickExcelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result == null || result.files.isEmpty) {
        return {'ok': false, 'error': 'no file selected'};
      }
      final path = result.files.single.path;
      if (path == null) return {'ok': false, 'error': 'path null'};
      final bytes = await File(path).readAsBytes();
      return {'ok': true, 'bytes': bytes};
    } catch (e) {
      if (kDebugMode) print('pickExcelFile error: $e');
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// Parse bytes into list of maps using first row as header.
  List<Map<String, dynamic>> parseExcelBytes(
    List<int> bytes, {
    int sheetIndex = 0,
  }) {
    final excel = Excel.decodeBytes(bytes);
    final sheetNames = excel.tables.keys.toList();
    if (sheetNames.isEmpty) return [];
    final sheet = excel.tables[sheetNames[sheetIndex]]!;
    final rows = <Map<String, dynamic>>[];
    if (sheet.maxRows == 0) return rows;
    // first row is header
    final header = sheet.rows.first
        .map((c) => c?.value?.toString() ?? '')
        .toList();
    for (int r = 1; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      final map = <String, dynamic>{};
      for (var c = 0; c < header.length; c++) {
        final key = header[c];
        final cell = c < row.length ? row[c] : null;
        map[key] = cell?.value;
      }
      rows.add(map);
    }
    return rows;
  }

  /// Export rows (list of maps) to an Excel file. Schema is a map where keys are column names.
  /// Returns the absolute file path.
  Future<String> exportRowsToExcel(
    Map<String, dynamic> schema,
    List<Map<String, dynamic>> rows, {
    required String filename,
  }) async {
    final excel = Excel.createExcel();
    final sheetName = 'Sheet1';
    final sheet = excel[sheetName];

    // Write header based on schema keys order
    final headers = schema.keys.toList();
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (final row in rows) {
      final rowVals = headers.map((h) {
        final v = row[h];
        if (v is Timestamp) return TextCellValue(v.toDate().toIso8601String());
        if (v is DateTime) return TextCellValue(v.toIso8601String());
        return TextCellValue(v?.toString() ?? '');
      }).toList();
      sheet.appendRow(rowVals);
    }

    final bytes = excel.encode()!;
    final directory =
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final dirPath = directory.path;
    final file = File('$dirPath/$filename');
    await file.writeAsBytes(bytes, flush: true);
    try {
      await OpenFile.open(file.path);
    } catch (_) {}
    return file.path;
  }
}
