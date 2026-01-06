class ItemModel {
  final String id;
  final String name;
  final String category;
  final int quantity;

  // WAJIB DITAMBAHKAN
  final String? imageUrl;

  ItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    this.imageUrl,
  });
}
