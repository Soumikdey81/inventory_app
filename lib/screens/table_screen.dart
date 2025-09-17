
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import 'create_table_screen.dart';
import 'edit_schema_screen.dart';
import 'table_detail_screen.dart';

class TableScreen extends StatefulWidget {
  const TableScreen({super.key});

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  final fs = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Tables')),
      body: StreamBuilder(
        stream: fs.tablesStream(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = (snapshot.data as dynamic).docs;
          if (docs.isEmpty) return const Center(child: Text('No tables yet'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return ListTile(
                title: Text(data['name'] ?? 'Unnamed'),
                subtitle: Text('Columns: ${(data['schema'] as Map?)?.length ?? 0}'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TableDetailScreen(tableId: doc.id))),
                trailing: PopupMenuButton(
                  onSelected: (v) async {
                    if (v == 'rename') {
                      final controller = TextEditingController(text: data['name'] ?? '');
                      final res = await showDialog<String>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Rename table'),
                          content: TextField(controller: controller),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('OK')),
                          ],
                        ),
                      );
                      if (res != null && res.isNotEmpty) {
                        await fs.updateTableName(doc.id, res);
                      }
                    } else if (v == 'edit_schema') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => EditSchemaScreen(tableId: doc.id, schema: Map<String,dynamic>.from(data['schema'] ?? {}))));
                    } else if (v == 'delete') {
                      final uid = FirebaseAuth.instance.currentUser!.uid;
                      await fs.deleteTable(uid, doc.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'edit_schema', child: Text('Edit Schema')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTableScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}
