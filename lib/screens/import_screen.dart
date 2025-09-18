import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ImportScreen extends StatefulWidget {
  final String tableId;
  const ImportScreen({super.key, required this.tableId});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  String _status = 'Ready to import';

  Future<void> _importExcel() async {
    setState(() => _status = 'Picking file...');
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true, // ✅ ensures bytes are available on device
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _status = 'No file selected');
        return;
      }
      setState(() => _status = 'Reading file...');

      Uint8List? bytes = result.files.first.bytes;
      final String? pickedPath = result.files.first.path;

      // ✅ fallback to path if bytes are null
      if (bytes == null && pickedPath != null) {
        try {
          bytes = await File(pickedPath).readAsBytes();
        } catch (e) {
          setState(() => _status = 'Unable to read file: $e');
          return;
        }
      }

      if (bytes == null) {
        setState(() => _status = 'Failed to read file bytes');
        return;
      }

      final excel = Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) {
        setState(() => _status = 'No sheets found in file');
        return;
      }

      final sheetName = excel.tables.keys.first;
      final table = excel.tables[sheetName]!;
      if (table.rows.isEmpty) {
        setState(() => _status = 'No rows in sheet');
        return;
      }

      final header = table.rows.first
          .map((c) => c?.value?.toString() ?? '')
          .toList();

      setState(() => _status = 'Fetching schema...');
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final tableDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tables')
          .doc(widget.tableId);
      final tableSnap = await tableDoc.get();
      if (!tableSnap.exists) {
        setState(() => _status = 'Table not found');
        return;
      }
      final schema = Map<String, dynamic>.from(
        tableSnap.data()!['schema'] ?? {},
      );

      String _norm(String s) => s.trim().toLowerCase();
      final normSchema = {for (var k in schema.keys) _norm(k): k};
      final normHeader = header.map((h) => _norm(h)).toList();

      final missing = <String>[];
      for (final realKey in schema.keys) {
        if (!normHeader.contains(_norm(realKey))) missing.add(realKey);
      }
      if (missing.isNotEmpty) {
        setState(
          () => _status =
              'Warning: Missing columns: ${missing.join(", ")}. Missing fields will be saved as null.',
        );
      } else {
        setState(() => _status = 'Importing rows...');
      }

      const int chunkSize = 200;
      var batch = FirebaseFirestore.instance.batch();
      int counter = 0;
      int imported = 0;
      final totalRows = table.rows.length - 1;

      for (int r = 1; r < table.rows.length; r++) {
        final row = table.rows[r];
        final data = <String, dynamic>{};

        for (int c = 0; c < header.length; c++) {
          final rawKey = header[c];
          final normalized = _norm(rawKey);
          final realKey = normSchema[normalized];
          if (realKey == null) continue;
          final cell = row.length > c ? row[c] : null;
          dynamic val = cell?.value;

          final schemaDef = schema[realKey];
          if (schemaDef is Map && schemaDef['type'] == 'number') {
            val = (val == null || val.toString().isEmpty)
                ? null
                : num.tryParse(val.toString());
          } else if (schemaDef is Map && schemaDef['type'] == 'date') {
            val = (val is DateTime)
                ? val
                : DateTime.tryParse(val?.toString() ?? '');
          } else {
            val = (val == null || val.toString().trim().isEmpty)
                ? null
                : val.toString();
          }
          data[realKey] = val;
        }

        for (final k in schema.keys) {
          data.putIfAbsent(k, () => null);
        }

        final docRef = tableDoc.collection('rows').doc();
        batch.set(docRef, {
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        counter++;
        imported++;

        if (imported % 20 == 0 || imported == totalRows) {
          if (mounted) {
            setState(
              () => _status = 'Importing rows... $imported / $totalRows',
            );
          }
        }

        if (counter % chunkSize == 0) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
        }
      }

      if (counter % chunkSize != 0) {
        await batch.commit();
      }

      if (mounted) setState(() => _status = 'Imported $imported rows');
    } catch (e) {
      if (mounted) setState(() => _status = 'Import failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Import Data")),
      body: Center(child: Text(_status)),
      floatingActionButton: FloatingActionButton(
        onPressed: _importExcel,
        child: const Icon(Icons.file_open),
      ),
    );
  }
}
