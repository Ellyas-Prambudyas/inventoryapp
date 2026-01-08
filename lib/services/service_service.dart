import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/item_model.dart';

class ServiceService {
  // ==========================
  // SINGLETON
  // ==========================
  static final ServiceService _instance = ServiceService._internal();
  factory ServiceService() => _instance;
  ServiceService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// List item service yang dipakai di UI (Home, dsb)
  final ValueNotifier<List<ItemModel>> services =
      ValueNotifier<List<ItemModel>>([]);

  List<ItemModel> get servicesList => services.value;

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
    final String status = (map['status'] ?? '').toString();

    // akan tampil di Home sebagai: "Service - Service Handphone (Dalam Proses)"
    final combinedCategory = [
      'Service',
      if (category.isNotEmpty) '- $category',
      if (status.isNotEmpty) '($status)',
    ].join(' ').trim();

    final String? imageUrl =
        map['image_url'] != null ? map['image_url'].toString() : null;

    return ItemModel(
      id: map['id'].toString(),
      name: (map['name'] ?? '').toString(),
      category: combinedCategory,
      quantity: qty,
      imageUrl: imageUrl,
    );
  }

  // ================= LOAD SERVICES ================
  Future<void> loadServices() async {
    try {
      final response = await _supabase
          .from('services')
          .select()
          .order('created_at', ascending: false);

      final loaded = (response as List)
          .map((row) => _mapRowToItem(row as Map<String, dynamic>))
          .toList();

      services.value = loaded;
    } catch (e, st) {
      debugPrint('Gagal load services: $e');
      debugPrint('$st');
    }
  }

  // ================= DETAIL 1 ROW =================
  /// Ambil 1 baris lengkap dari tabel "services" berdasarkan id
  /// Dipakai untuk tampilan detail (isi lengkap: sku, merk, customer, harga, dll)
  Future<Map<String, dynamic>?> getServiceRowById(String id) async {
    try {
      final result = await _supabase
          .from('services')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (result == null) return null;
      return result as Map<String, dynamic>;
    } catch (e, st) {
      debugPrint('Error getServiceRowById: $e');
      debugPrint('$st');
      return null;
    }
  }

  // ============= GET SERVICE DARI QR =============
  Future<ItemModel?> getServiceByQr(String qrValue) async {
    try {
      final text = qrValue.trim();
      Map<String, dynamic>? result;

      String? serial;       // No. Seri / IMEI -> kolom sku
      String? nameInQr;
      String? categoryInQr;
      String? totalInQr;

      // Parsing QR multiline
      for (final rawLine in text.split('\n')) {
        final line = rawLine.trim();
        final lower = line.toLowerCase();

        if (lower.startsWith('no. seri/imei:')) {
          // ambil teks setelah titik dua
          final idx = line.indexOf(':');
          if (idx != -1) {
            serial = line.substring(idx + 1).trim();
          }
        } else if (lower.startsWith('nama barang:')) {
          final idx = line.indexOf(':');
          if (idx != -1) {
            nameInQr = line.substring(idx + 1).trim();
          }
        } else if (lower.startsWith('nama:')) {
          final idx = line.indexOf(':');
          if (idx != -1) {
            nameInQr = line.substring(idx + 1).trim();
          }
        } else if (lower.startsWith('jenis service:')) {
          final idx = line.indexOf(':');
          if (idx != -1) {
            categoryInQr = line.substring(idx + 1).trim();
          }
        } else if (lower.startsWith('jumlah unit:') ||
            lower.startsWith('total:')) {
          final idx = line.indexOf(':');
          if (idx != -1) {
            totalInQr = line.substring(idx + 1).trim();
          }
        }
      }

      debugPrint(
          'QR service text: "$text" | parsed serial: "$serial" | name: "$nameInQr" | category: "$categoryInQr" | total: "$totalInQr"');

      // 1) kalau ada serial → cari di sku
      if (serial != null && serial.isNotEmpty) {
        final res = await _supabase
            .from('services')
            .select()
            .eq('sku', serial)
            .maybeSingle();

        if (res != null) {
          result = res as Map<String, dynamic>;
        }
      }

      // 2) Nama + Jenis Service
      if (result == null &&
          nameInQr != null &&
          nameInQr!.isNotEmpty &&
          categoryInQr != null &&
          categoryInQr!.isNotEmpty) {
        final res = await _supabase
            .from('services')
            .select()
            .ilike('name', '%$nameInQr%')
            .ilike('category', '%$categoryInQr%')
            .maybeSingle();

        if (res != null) {
          result = res as Map<String, dynamic>;
        }
      }

      // 3) Nama + Total/Jumlah
      final total = int.tryParse(totalInQr ?? '');
      if (result == null &&
          nameInQr != null &&
          nameInQr!.isNotEmpty &&
          total != null) {
        final res = await _supabase
            .from('services')
            .select()
            .ilike('name', '%$nameInQr%')
            .eq('total', total)
            .maybeSingle();

        if (res != null) {
          result = res as Map<String, dynamic>;
        }
      }

      // 4) fallback id/sku/nama pakai seluruh teks QR
      if (result == null && text.isNotEmpty) {
        final res = await _supabase
            .from('services')
            .select()
            .or('id.eq.$text,sku.eq.$text,name.ilike.%$text%')
            .maybeSingle();

        if (res != null) {
          result = res as Map<String, dynamic>;
        }
      }

      if (result == null) {
        debugPrint('getServiceByQr: tetap tidak ada service untuk "$text"');
        return null;
      }

      return _mapRowToItem(result);
    } catch (e, st) {
      debugPrint('Error getServiceByQr: $e');
      debugPrint('$st');
      return null;
    }
  }

  // ============ SEARCH SERVICE ============
  Future<List<ItemModel>> searchServices(String keyword) async {
    try {
      final q = '%$keyword%';
      final response = await _supabase
          .from('services')
          .select()
          .or('name.ilike.$q,sku.ilike.$q,merk.ilike.$q,customer.ilike.$q')
          .order('created_at', ascending: false);

      final list = (response as List)
          .map((row) => _mapRowToItem(row as Map<String, dynamic>))
          .toList();

      return list;
    } catch (e, st) {
      debugPrint('Error searchServices: $e');
      debugPrint('$st');
      return [];
    }
  }

  // ============ UPDATE / DELETE REMOTE ============
  /// Update langsung ke Supabase + sinkron list lokal
  Future<bool> updateServiceRemote(
    String id, {
    String? name,
    int? total,
    String? status,
  }) async {
    final Map<String, dynamic> update = {};
    if (name != null) update['name'] = name;
    if (total != null) update['total'] = total;
    if (status != null) update['status'] = status;

    if (update.isEmpty) return true;

    try {
      await _supabase.from('services').update(update).eq('id', id);
      await loadServices(); // ✅ biar UI update benar (status/qty)

      final current = List<ItemModel>.from(services.value);
      final index = current.indexWhere((e) => e.id == id);
      if (index != -1) {
        final old = current[index];
        current[index] = ItemModel(
          id: old.id,
          name: name ?? old.name,
          category: old.category,
          quantity: total ?? old.quantity,
          imageUrl: old.imageUrl,
        );
        services.value = current;
      }
      return true;
    } catch (e, st) {
      debugPrint('Error updateServiceRemote: $e');
      debugPrint('$st');
      return false;
    }
  }

  Future<bool> deleteServiceRemote(String id) async {
    try {
      await _supabase.from('services').delete().eq('id', id);
      removeService(id);
      return true;
    } catch (e, st) {
      debugPrint('Error deleteServiceRemote: $e');
      debugPrint('$st');
      return false;
    }
  }

  // ============ FUNGSI LOKAL LIST ============
  void addService(ItemModel item) {
    final current = List<ItemModel>.from(services.value);
    current.insert(0, item);
    services.value = current;
  }

  void updateService(ItemModel item) {
    final current = List<ItemModel>.from(services.value);
    final index = current.indexWhere((e) => e.id == item.id);
    if (index != -1) {
      current[index] = item;
      services.value = current;
    }
  }

  void removeService(String id) {
    final current = List<ItemModel>.from(services.value);
    current.removeWhere((e) => e.id == id);
    services.value = current;
  }
}
