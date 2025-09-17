
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class CreateTableScreen extends StatefulWidget {
  const CreateTableScreen({super.key});

  @override
  State<CreateTableScreen> createState() => _CreateTableScreenState();
}

class _CreateTableScreenState extends State<CreateTableScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _fieldsCtrl = TextEditingController();
  final _fs = FirestoreService();
  bool _loading = false;

  void _createTable() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final name = _nameCtrl.text.trim();
    final fieldsRaw = _fieldsCtrl.text.trim();
    final schema = <String, dynamic>{};
    if (fieldsRaw.isNotEmpty) {
      final parts = fieldsRaw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
      for (final p in parts) {
        schema[p] = {'type': 'string'}; // default type
      }
    }
    try {
      await _fs.createTable(name, schema);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _fieldsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Table')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Table name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fieldsCtrl,
                decoration: const InputDecoration(labelText: 'Fields (comma-separated)'),
                maxLines: 1,
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loading ? null : _createTable,
                child: _loading ? const CircularProgressIndicator() : const Text('Create'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
