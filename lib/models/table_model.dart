import 'package:cloud_firestore/cloud_firestore.dart';

class TableModel {
  final String id;
  final String name;
  final Map<String, dynamic> schema;

  TableModel({required this.id, required this.name, required this.schema});

  factory TableModel.fromDoc(String id, Map<String, dynamic> data) =>
      TableModel(
        id: id,
        name: data['name'] ?? '',
        schema: Map<String, dynamic>.from(data['schema'] ?? {}),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'schema': schema,
      };
}
