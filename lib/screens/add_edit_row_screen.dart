
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddEditRowScreen extends StatefulWidget {
  final String tableId;
  final String? rowId;
  const AddEditRowScreen({super.key, required this.tableId, this.rowId});

  @override
  State<AddEditRowScreen> createState() => _AddEditRowScreenState();
}

class _AddEditRowScreenState extends State<AddEditRowScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  Map<String, dynamic> _schema = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _nullables = {};

  @override
  void initState() {
    super.initState();
    _loadSchemaAndData();
  }

  Future<void> _loadSchemaAndData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final tableDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tables')
        .doc(widget.tableId);
    final snap = await tableDoc.get();
    final data = snap.data() ?? {};
    final schema = Map<String, dynamic>.from(data['schema'] ?? {});
    setState(() {
      _schema = schema;
    });
    // init controllers
    for (final k in _schema.keys) {
      _controllers[k] = TextEditingController();
      _nullables[k] = _schema[k]['nullable'] == true;
    }

    if (widget.rowId != null) {
      final rowSnap = await tableDoc.collection('rows').doc(widget.rowId).get();
      final rowData = rowSnap.data() ?? {};
      for (final k in _schema.keys) {
        final val = rowData[k];
        if (val != null) {
          _controllers[k]?.text = val.toString();
        }
      }
    }

    setState(() {
      _loading = false;
    });
  }

  Future<void> _saveRow() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final tableDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tables')
        .doc(widget.tableId);
    final rowsRef = tableDoc.collection('rows');
    final Map<String, dynamic> toSave = {};
    for (final k in _schema.keys) {
      final type = _schema[k]['type'] ?? 'string';
      final txt = _controllers[k]?.text ?? '';
      if (txt.isEmpty) {
        if (_nullables[k] == true) {
          toSave[k] = null;
        } else {
          toSave[k] = '';
        }
      } else {
        if (type == 'number') {
          toSave[k] = num.tryParse(txt) ?? txt;
        } else if (type == 'date') {
          // try parse ISO or milliseconds
          final parsed = DateTime.tryParse(txt);
          toSave[k] = parsed ?? txt;
        } else {
          toSave[k] = txt;
        }
      }
    }
    toSave['updatedAt'] = FieldValue.serverTimestamp();
    if (widget.rowId == null) {
      toSave['createdAt'] = FieldValue.serverTimestamp();
      await rowsRef.add(toSave);
    } else {
      await rowsRef.doc(widget.rowId).update(toSave);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final fields = _schema.keys.toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.rowId == null ? 'Add Row' : 'Edit Row')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              ...fields.map((k) {
                final type = _schema[k]['type'] ?? 'string';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: TextFormField(
                    controller: _controllers[k],
                    decoration: InputDecoration(
                      labelText: k,
                      hintText: type == 'date' ? 'YYYY-MM-DD or ISO' : null,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: type == 'number' ? TextInputType.number : TextInputType.text,
                    validator: (val) {
                      if ((val == null || val.isEmpty) && _nullables[k] != true) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                );
              }),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _saveRow, child: const Text('Save')),
            ],
          ),
        ),
      ),
    );
  }
}
