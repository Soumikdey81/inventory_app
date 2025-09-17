class RowModel {
  final String id;
  final Map<String, dynamic> data;

  RowModel({required this.id, required this.data});

  factory RowModel.fromDoc(String id, Map<String, dynamic> data) =>
      RowModel(id: id, data: data);
}
