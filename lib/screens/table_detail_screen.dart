import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/data_table_widget.dart';
import 'add_edit_row_screen.dart';
import 'edit_schema_screen.dart';
import 'import_screen.dart';
import '../services/import_export_service.dart';

class TableDetailScreen extends StatefulWidget {
  final String tableId;
  const TableDetailScreen({super.key, required this.tableId});

  @override
  State<TableDetailScreen> createState() => _TableDetailScreenState();
}

class _TableDetailScreenState extends State<TableDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final tableDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tables')
        .doc(widget.tableId);

    return StreamBuilder<DocumentSnapshot>(
      stream: tableDoc.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snap.error}')));
        }
        if (!snap.hasData || !snap.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Table')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final schema = Map<String, dynamic>.from(data['schema'] ?? {});
        final name = data['name'] ?? 'Table';

        return Scaffold(
          appBar: AppBar(
            title: Text(name),
            actions: [
              // Import Excel
              IconButton(
                icon: const Icon(Icons.upload_file),
                tooltip: 'Import Excel',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ImportScreen(tableId: widget.tableId),
                    ),
                  );
                },
              ),
              // Export Excel
              IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'Export Excel',
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final rowsQuery = await tableDoc.collection('rows').get();
                    final rows = rowsQuery.docs
                        .map((d) => d.data() as Map<String, dynamic>)
                        .toList();
                    final svc = ImportExportService();
                    final filename =
                        '${name.replaceAll(RegExp(r"[^a-zA-Z0-9_]"), "_")}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
                    final path = await svc.exportRowsToExcel(
                      schema,
                      rows,
                      filename: filename,
                    );
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(content: Text('Exported to $path')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(content: Text('Export failed: $e')),
                    );
                  }
                },
              ),
              // Edit schema
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit schema',
                onPressed: () async {
                  final res = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditSchemaScreen(
                        tableId: widget.tableId,
                        schema: schema,
                      ),
                    ),
                  );
                  if (res == true && mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Schema updated!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(12.0),
            child: DataTableWidget(
              rowsRef: tableDoc.collection('rows'),
              schema: schema,
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditRowScreen(tableId: widget.tableId),
                ),
              );
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
