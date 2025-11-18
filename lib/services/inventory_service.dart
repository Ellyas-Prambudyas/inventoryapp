import 'package:flutter/foundation.dart';

import '../models/item_model.dart';

/// Service sederhana in-memory untuk menyimpan data inventory.
/// Untuk produksi, ini bisa diganti ke database lokal / API.
class InventoryService {
  InventoryService._internal();

  static final InventoryService _instance = InventoryService._internal();
  static InventoryService get instance => _instance;

  final ValueNotifier<List<ItemModel>> items = ValueNotifier<List<ItemModel>>([
    ItemModel(
      id: '1',
      name: 'Laptop',
      category: 'Elektronik',
      quantity: 5,
    ),
    ItemModel(
      id: '2',
      name: 'Mouse Wireless',
      category: 'Aksesoris',
      quantity: 20,
    ),
  ]);

  void addItem(ItemModel item) {
    final current = List<ItemModel>.from(items.value);
    current.add(item);
    items.value = current;
  }

  void removeItem(String id) {
    final current = List<ItemModel>.from(items.value);
    current.removeWhere((e) => e.id == id);
    items.value = current;
  }
}
