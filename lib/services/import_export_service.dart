import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/foundation.dart';

class ImportExportService {
  Future<Map<String, dynamic>> pickExcelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true, // ✅ ensures bytes are available
      );
      if (result == null || result.files.isEmpty) {
        return {'ok': false, 'error': 'no file selected'};
      }

      Uint8List? bytes = result.files.single.bytes;
      final String? path = result.files.single.path;

      if (bytes == null && path != null) {
        bytes = await File(path).readAsBytes();
      }
      if (bytes == null) return {'ok': false, 'error': 'failed to read file'};

      return {'ok': true, 'bytes': bytes};
    } catch (e) {
      if (kDebugMode) print('pickExcelFile error: $e');
      return {'ok': false, 'error': e.toString()};
    }
  }

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

  Future<String> exportRowsToExcel(
    Map<String, dynamic> schema,
    List<Map<String, dynamic>> rows, {
    required String filename,
  }) async {
    final excel = Excel.createExcel();
    final sheetName = 'Sheet1';
    final sheet = excel[sheetName];

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
