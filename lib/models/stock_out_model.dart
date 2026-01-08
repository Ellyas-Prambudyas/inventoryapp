class StockOutModel {
  final String id;
  final String refId;
  final String refType; // 'ITEM' atau 'SERVICE'
  final String name;
  final int quantity;
  final DateTime createdAt;
  final String? note;

  const StockOutModel({
    required this.id,
    required this.refId,
    required this.refType,
    required this.name,
    required this.quantity,
    required this.createdAt,
    this.note,
  });

  factory StockOutModel.fromMap(Map<String, dynamic> map) {
    return StockOutModel(
      id: (map['id'] ?? '').toString(),
      refId: (map['ref_id'] ?? '').toString(),
      refType: (map['ref_type'] ?? '').toString(), // 'ITEM' atau 'SERVICE'
      name: (map['name'] ?? '').toString(),
      quantity: (map['quantity'] ?? 0) is int
          ? map['quantity'] as int
          : (map['quantity'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ??
          DateTime.now(),
      note: map['note']?.toString(),
    );
  }
}
