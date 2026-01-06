import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/item_model.dart';

/// Service untuk data BARANG BARU (tabel "items" di Supabase)
class InventoryService {
  // ==========================
  // SINGLETON
  // ==========================
  static final InventoryService _instance = InventoryService._internal();
  factory InventoryService() => _instance;
  InventoryService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// List barang yang dipakai di UI (Home, dsb)
  final ValueNotifier<List<ItemModel>> items =
      ValueNotifier<List<ItemModel>>([]);

  List<ItemModel> get itemsList => items.value;

  // ==========================
  // HELPER: MAP ROW → ITEMMODEL
  // ==========================
 ItemModel _mapRowToItem(Map<String, dynamic> map) {
  // Ambil total sebagai quantity
  final totalValue = map['total'];
  int qty;
  if (totalValue is int) {
    qty = totalValue;
  } else if (totalValue is num) {
    qty = totalValue.toInt();
  } else {
    qty = 0;
  }

  final String category = (map['category'] ?? '').toString();
  final String condition = (map['condition'] ?? '').toString();

  // Kolom foto di Supabase, sesuaikan dengan nama kolom kamu:
  // misalnya: image_url
  final String? imageUrl = map['image_url'] as String?;

  // Gabungkan category + condition (kalau ada)
  final String combinedCategory = [
    if (category.isNotEmpty) category,
    if (condition.isNotEmpty) '($condition)',
  ].join(' ').trim();

  return ItemModel(
    id: map['id'].toString(),
    name: (map['name'] ?? '').toString(),
    category: combinedCategory,
    quantity: qty,
    imageUrl: imageUrl, // <-- PENTING
  );
}


  // ==========================
  // AMBIL DATA DARI DATABASE
  // ==========================
  Future<void> loadItems() async {
    try {
      final response = await _supabase
          .from('items')
          .select()
          .order('created_at', ascending: false);

      final loaded = (response as List)
          .map((row) => _mapRowToItem(row as Map<String, dynamic>))
          .toList();

      items.value = loaded;
    } catch (e, st) {
      debugPrint('Gagal load items dari Supabase: $e');
      debugPrint('$st');
    }
  }

 Future<ItemModel?> getItemByQr(String qrValue) async {
  try {
    final text = qrValue.trim();

    String? sku;
    String? nameInQr;

    // --- PARSE QR MULTILINE: ambil SKU & Nama saja ---
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      final lower = line.toLowerCase();

      if (lower.startsWith('sku:')) {
        // "SKU: gh"
        sku = line.substring(line.indexOf(':') + 1).trim();
      } else if (lower.startsWith('nama barang:')) {
        nameInQr = line.substring(line.indexOf(':') + 1).trim();
      } else if (lower.startsWith('nama:')) {
        nameInQr = line.substring(line.indexOf(':') + 1).trim();
      }
    }

    debugPrint('QR items text: "$text" | parsed sku: "$sku" | name: "$nameInQr"');

    Map<String, dynamic>? result;

    // 1) Kalau ada SKU → coba persis di kolom sku
    if (sku != null && sku!.isNotEmpty) {
      final res = await _supabase
          .from('items')
          .select()
          .eq('sku', sku)
          .maybeSingle();

      if (res != null) {
        result = res as Map<String, dynamic>;
      }
    }

    // 2) Kalau belum ketemu, tiru persis searchItems()
    if (result == null) {
      // pakai nama dari QR dulu, kalau nggak ada pakai seluruh teks QR
      final keyword = (nameInQr != null && nameInQr!.isNotEmpty)
          ? nameInQr!
          : text;

      final q = '%$keyword%';

      final response = await _supabase
          .from('items')
          .select()
          .or('name.ilike.$q,sku.ilike.$q,merk.ilike.$q,supplier.ilike.$q')
          .order('created_at', ascending: false)
          .limit(1);

      if (response is List && response.isNotEmpty) {
        result = response.first as Map<String, dynamic>;
      }
    }

    if (result == null) {
      debugPrint('getItemByQr: tetap tidak ada item untuk "$text"');
      return null;
    }

    return _mapRowToItem(result);
  } catch (e, st) {
    debugPrint('Error getItemByQr: $e');
    debugPrint('$st');
    return null;
  }
}





  /// Ambil RAW row berdasarkan id (untuk detail lengkap)
  Future<Map<String, dynamic>?> getItemRowById(String id) async {
    try {
      final result = await _supabase
          .from('items')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (result == null) return null;
      return result as Map<String, dynamic>;
    } catch (e, st) {
      debugPrint('Error getItemRowById: $e');
      debugPrint('$st');
      return null;
    }
  }

  // ==========================
  // SEARCH MANUAL
  // ==========================
  Future<List<ItemModel>> searchItems(String keyword) async {
    try {
      final q = '%$keyword%';
      final response = await _supabase
          .from('items')
          .select()
          .or('name.ilike.$q,sku.ilike.$q,merk.ilike.$q,supplier.ilike.$q')
          .order('created_at', ascending: false);

      final list = (response as List)
          .map((row) => _mapRowToItem(row as Map<String, dynamic>))
          .toList();

      return list;
    } catch (e, st) {
      debugPrint('Error searchItems: $e');
      debugPrint('$st');
      return [];
    }
  }

  // ==========================
  // UPDATE / DELETE DI DATABASE
  // ==========================

  /// Update beberapa kolom (misal dari dialog Edit)
  Future<bool> updateItemRemote(
    String id, {
    String? name,
    int? total,
  }) async {
    final Map<String, dynamic> update = {};
    if (name != null) update['name'] = name;
    if (total != null) update['total'] = total;

    if (update.isEmpty) return true;

    try {
      await _supabase.from('items').update(update).eq('id', id);

      // update cache lokal kalau ada
      final current = List<ItemModel>.from(items.value);
      final index = current.indexWhere((e) => e.id == id);
      if (index != -1) {
        final old = current[index];
        current[index] = ItemModel(
          id: old.id,
          name: name ?? old.name,
          category: old.category,
          quantity: total ?? old.quantity,
        );
        items.value = current;
      }
      return true;
    } catch (e, st) {
      debugPrint('Error updateItemRemote: $e');
      debugPrint('$st');
      return false;
    }
  }

  /// Hapus item di Supabase + cache lokal
  Future<bool> deleteItemRemote(String id) async {
    try {
      await _supabase.from('items').delete().eq('id', id);
      removeItem(id);
      return true;
    } catch (e, st) {
      debugPrint('Error deleteItemRemote: $e');
      debugPrint('$st');
      return false;
    }
  }

  // ==========================
  // FUNGSI LOKAL (LIST DI MEMORI)
  // ==========================

  /// Tambah item baru ke list (dipanggil setelah insert Supabase sukses)
  void addItem(ItemModel item) {
    final current = List<ItemModel>.from(items.value);
    current.insert(0, item); // taruh di paling atas
    items.value = current;
  }

  /// Hapus dari list lokal
  void removeItem(String id) {
    final current = List<ItemModel>.from(items.value);
    current.removeWhere((e) => e.id == id);
    items.value = current;
  }

  /// Update di list lokal (kalau dipakai dari layar lain)
  void updateItem(ItemModel item) {
    final current = List<ItemModel>.from(items.value);
    final index = current.indexWhere((e) => e.id == item.id);
    if (index != -1) {
      current[index] = item;
      items.value = current;
    }
  }
}
