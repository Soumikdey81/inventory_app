
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DataTableWidget extends StatelessWidget {
  final CollectionReference? rowsRef;
  final String? tableId;
  final Map<String, dynamic> schema;
  const DataTableWidget({super.key, this.rowsRef, this.tableId, required this.schema});

  CollectionReference _resolveRowsRef() {
    if (rowsRef != null) return rowsRef!;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('No authenticated user for rowsRef');
    if (tableId == null) throw Exception('No tableId or rowsRef provided');
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('tables').doc(tableId).collection('rows');
  }

  @override
  Widget build(BuildContext context) {
    final ref = _resolveRowsRef();
    final fieldKeys = schema.keys.toList();
    return StreamBuilder<QuerySnapshot>(
      stream: ref.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No rows yet'));
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              const DataColumn(label: Text('Actions')),
              ...fieldKeys.map((k) => DataColumn(label: Text(k))),
              const DataColumn(label: Text('Created')),
            ],
            rows: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final cells = <DataCell>[];
              cells.add(DataCell(Row(
                children: [
                  IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        // Left as navigation responsibility of parent
                      }),
                  IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        await ref.doc(doc.id).delete();
                      }),
                ],
              )));
              for (final key in fieldKeys) {
                cells.add(DataCell(Text('${data[key] ?? ''}')));
              }
              final ts = data['createdAt'];
              String created = '';
              try {
                if (ts is Timestamp) {
                  created = ts.toDate().toLocal().toString();
                } else {
                  created = data['createdAt']?.toString() ?? '';
                }
              } catch (e) {
                created = '';
              }
              cells.add(DataCell(Text(created)));
              return DataRow(cells: cells);
            }).toList(),
          ),
        );
      },
    );
  }
}
