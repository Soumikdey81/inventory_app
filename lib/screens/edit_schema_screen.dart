import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditSchemaScreen extends StatefulWidget {
  final String tableId;
  final Map<String, dynamic> schema;
  const EditSchemaScreen({
    required this.tableId,
    required this.schema,
    super.key,
  });

  @override
  State<EditSchemaScreen> createState() => _EditSchemaScreenState();
}

class _EditSchemaScreenState extends State<EditSchemaScreen> {
  late List<_ColumnEdit> _columns;
  String _status = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _columns = widget.schema.entries
        .map((e) => _ColumnEdit(oldName: e.key, nameController: TextEditingController(text: e.key)))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _columns) {
      c.nameController.dispose();
    }
    super.dispose();
  }

  void _addColumn() {
    setState(() {
      final idx = _columns.length + 1;
      _columns.add(_ColumnEdit(oldName: '', nameController: TextEditingController(text: 'field_$idx')));
    });
  }

  void _removeColumn(int index) {
    setState(() {
      _columns.removeAt(index);
    });
  }

  Future<void> _saveSchemaAndMigrate() async {
    // Validate names are non-empty and unique
    final newNames = _columns.map((c) => c.nameController.text.trim()).toList();
    if (newNames.any((n) => n.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Column names cannot be empty')));
      return;
    }
    final duplicates = <String>{};
    final seen = <String>{};
    for (final n in newNames) {
      if (seen.contains(n)) duplicates.add(n);
      seen.add(n);
    }
    if (duplicates.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Duplicate column names: ${duplicates.join(", ")}')));
      return;
    }

    setState(() {
      _saving = true;
      _status = 'Preparing schema...';
    });

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() { _saving = false; _status = 'Not authenticated'; });
      return;
    }
    final tableDoc = FirebaseFirestore.instance.collection('users').doc(uid).collection('tables').doc(widget.tableId);

    // Build new schema map (default type = 'string')
    final Map<String, dynamic> newSchema = {};
    for (final col in _columns) {
      final key = col.nameController.text.trim();
      newSchema[key] = {'type': 'string'};
    }

    // Determine rename map: oldName -> newName (only when different and oldName non-empty)
    final Map<String, String> renameMap = {};
    for (final col in _columns) {
      final oldName = col.oldName;
      final newName = col.nameController.text.trim();
      if (oldName.isNotEmpty && oldName != newName) {
        renameMap[oldName] = newName;
      }
    }

    try {
      // Update schema document first
      await tableDoc.update({'schema': newSchema, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      // If update fails, stop
      setState(() { _saving = false; _status = 'Failed to update schema: $e'; });
      return;
    }

    if (renameMap.isEmpty) {
      // Nothing to migrate
      setState(() { _saving = false; _status = 'Schema saved'; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schema updated')));
      Navigator.pop(context, true);
      return;
    }

    // Migrate existing rows safely in batches
    setState(() { _status = 'Migrating ${renameMap.length} column(s) in rows...'; });

    try {
      final rowsCol = tableDoc.collection('rows');
      const int pageLimit = 500;
      String? lastDocId;
      int processed = 0;

      while (true) {
        Query query = rowsCol.orderBy(FieldPath.documentId);
        Query q = query.limit(pageLimit);
        if (lastDocId != null) {
          final lastDoc = await rowsCol.doc(lastDocId).get();
          if (!lastDoc.exists) break;
          q = query.startAfterDocument(lastDoc);
        }

        final snapshot = await q.get();
        if (snapshot.docs.isEmpty) break;

        var writeBatch = FirebaseFirestore.instance.batch();
        int batchCount = 0;

        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final updates = <String, dynamic>{};
          bool needsUpdate = false;
          // For each rename mapping, move value if present
          for (final entry in renameMap.entries) {
            final oldKey = entry.key;
            final newKey = entry.value;
            if (data.containsKey(oldKey)) {
              final v = data[oldKey];
              final newVal = (v == null || v.toString().trim().isEmpty) ? null : v;
              updates[newKey] = newVal;
              updates[oldKey] = FieldValue.delete();
              needsUpdate = true;
            }
          }
          if (needsUpdate) {
            writeBatch.update(doc.reference, updates);
            batchCount++;
          }
          if (batchCount >= 200) {
            await writeBatch.commit();
            writeBatch = FirebaseFirestore.instance.batch();
            batchCount = 0;
          }
          processed++;
          if (processed % 100 == 0) {
            setState(() { _status = 'Migrated $processed rows...'; });
          }
        }
        if (batchCount > 0) {
          await writeBatch.commit();
        }

        lastDocId = snapshot.docs.last.id;
        if (snapshot.docs.length < pageLimit) break;
      }

      setState(() { _saving = false; _status = 'Migration complete ($processed rows)'; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schema and data migrated')));
      Navigator.pop(context, true);
      return;
    } catch (e) {
      setState(() { _saving = false; _status = 'Migration failed: $e'; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Migration failed: $e')));
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Schema'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _saveSchemaAndMigrate,
            icon: const Icon(Icons.check),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (_status.isNotEmpty) Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Text(_status),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _columns.length,
                itemBuilder: (context, index) {
                  final col = _columns[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: col.nameController,
                              decoration: InputDecoration(labelText: 'Column name', hintText: col.oldName.isEmpty ? 'new_column' : col.oldName),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _removeColumn(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _addColumn,
              icon: const Icon(Icons.add),
              label: const Text('Add Column'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ColumnEdit {
  final String oldName;
  final TextEditingController nameController;
  _ColumnEdit({required this.oldName, required this.nameController});
}
