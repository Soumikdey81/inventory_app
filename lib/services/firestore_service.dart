
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference tablesRef(String uid) =>
      _db.collection('users').doc(uid).collection('tables');

  DocumentReference tableDoc(String uid, String tableId) =>
      tablesRef(uid).doc(tableId);

  CollectionReference rowsRef(String uid, String tableId) =>
      tableDoc(uid, tableId).collection('rows');

  // Create table for a given uid
  Future<DocumentReference> createTableForUid(String uid, String name, Map<String, dynamic> schema) {
    final data = {
      'name': name,
      'schema': schema,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    return tablesRef(uid).add(data);
  }

  // Convenience: create table for current user
  Future<DocumentReference> createTable(String name, Map<String, dynamic> schema) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('No authenticated user');
    return createTableForUid(uid, name, schema);
  }

  Future<void> updateTable(String uid, String tableId, Map<String, dynamic> updates) {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    return tableDoc(uid, tableId).update(updates);
  }

  Future<void> renameTable(String uid, String tableId, String newName) {
    return updateTable(uid, tableId, {'name': newName});
  }

  Future<void> deleteTable(String uid, String tableId) async {
    // delete all rows in subcollection, then delete the table doc
    final rows = await rowsRef(uid, tableId).get();
    final batch = _db.batch();
    for (final doc in rows.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(tableDoc(uid, tableId));
    await batch.commit();
  }

  Future<DocumentReference> addRow(String uid, String tableId, Map<String, dynamic> row) {
    final data = Map<String, dynamic>.from(row);
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    return rowsRef(uid, tableId).add(data);
  }

  Future<void> updateRow(String uid, String tableId, String rowId, Map<String, dynamic> updates) {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    return rowsRef(uid, tableId).doc(rowId).update(updates);
  }

  Future<void> deleteRow(String uid, String tableId, String rowId) {
    return rowsRef(uid, tableId).doc(rowId).delete();
  }

  Stream<QuerySnapshot> tablesStream(String uid) {
    return tablesRef(uid).orderBy('createdAt', descending: true).snapshots();
  }

  Stream<QuerySnapshot> rowsStream(String uid, String tableId, {int limit = 100}) {
    return rowsRef(uid, tableId).orderBy('createdAt', descending: true).limit(limit).snapshots();
  }

  // Wrappers using current user
  Future<void> updateTableSchema(String tableId, Map<String, dynamic> schema) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('No authenticated user');
    return updateTable(uid, tableId, {'schema': schema});
  }

  Future<void> updateTableName(String tableId, String newName) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('No authenticated user');
    return renameTable(uid, tableId, newName);
  }
}
