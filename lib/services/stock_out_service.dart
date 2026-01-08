import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stock_out_model.dart';

class StockOutService {
  // =============== SINGLETON ===============
  static final StockOutService _instance = StockOutService._internal();
  factory StockOutService() => _instance;
  StockOutService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Total semua quantity yang sudah dikeluarkan (all time)
  final ValueNotifier<int> totalOut = ValueNotifier<int>(0);

  /// List log barang keluar (semua ITEM + SERVICE)
  final ValueNotifier<List<StockOutModel>> logs =
      ValueNotifier<List<StockOutModel>>([]);

  List<StockOutModel> get logsList => logs.value;

  // =============== HELPER REFRESH ===============
  Future<void> refreshAll() async {
    await Future.wait([
      loadLogs(),
      loadTotalOut(),
    ]);
  }

  // =============== LOAD TOTAL DARI DB ===============
  Future<void> loadTotalOut() async {
    try {
      final response = await _supabase.from('stock_out').select('quantity');

      int sum = 0;
      for (final row in response as List) {
        final q = row['quantity'];
        if (q is int) {
          sum += q;
        } else if (q is num) {
          sum += q.toInt();
        }
      }

      totalOut.value = sum;
    } catch (e, st) {
      debugPrint('Error loadTotalOut: $e');
      debugPrint('$st');
    }
  }

  // =============== LOAD LIST LOG ===============
  /// Ambil semua log barang keluar dari tabel stock_out (ordered desc)
  Future<void> loadLogs() async {
    try {
      final response = await _supabase
          .from('stock_out')
          .select()
          .order('created_at', ascending: false);

      final list = (response as List)
          .map((row) => StockOutModel.fromMap(row as Map<String, dynamic>))
          .toList();

      logs.value = list;
    } catch (e, st) {
      debugPrint('Error loadLogs: $e');
      debugPrint('$st');
    }
  }

  // =============== INSERT LOG BARANG KELUAR ===============
  /// Digunakan oleh HomePage untuk mencatat barang keluar (ITEM/SERVICE)
  Future<bool> insertOut({
    required String refId,
    required String refType, // 'ITEM' atau 'SERVICE'
    required String name,
    required int qty,
    String? note,
  }) async {
    try {
      final now = DateTime.now().toUtc();

      final data = {
        'ref_id': refId,
        'ref_type': refType,
        'name': name,
        'quantity': qty,
        'note': note,
        'created_at': now.toIso8601String(),
      };

      final inserted = await _supabase
          .from('stock_out')
          .insert(data)
          .select()
          .maybeSingle();

      // kalau sukses insert di server, baru update lokal
      if (inserted != null) {
        final model =
            StockOutModel.fromMap(inserted as Map<String, dynamic>);

        totalOut.value = totalOut.value + qty;

        final current = List<StockOutModel>.from(logs.value);
        current.insert(0, model); // taruh di atas
        logs.value = current;
      } else {
        // fallback: paksa refresh supaya data sinkron
        await refreshAll();
      }

      return true;
    } on PostgrestException catch (e, st) {
      debugPrint('Error insertOut (Postgrest): $e');
      debugPrint('$st');
      return false;
    } catch (e, st) {
      debugPrint('Error insertOut: $e');
      debugPrint('$st');
      return false;
    }
  }

  // =============== HAPUS SATU LOG ===============
  Future<bool> deleteOut(String id) async {
    try {
      // cari dulu item di lokal supaya bisa kurangi totalOut
      final current = List<StockOutModel>.from(logs.value);
      final idx = current.indexWhere((e) => e.id == id);

      int qty = 0;
      if (idx != -1) {
        qty = current[idx].quantity ?? 0;
      }

      // hapus di Supabase
      await _supabase.from('stock_out').delete().eq('id', id);

      // update lokal
      if (idx != -1) {
        current.removeAt(idx);
        logs.value = current;
      }

      totalOut.value = (totalOut.value - qty).clamp(0, 1 << 31);

      return true;
    } on PostgrestException catch (e, st) {
      debugPrint('Error deleteOut (Postgrest): $e');
      debugPrint('$st');
      return false;
    } catch (e, st) {
      debugPrint('Error deleteOut: $e');
      debugPrint('$st');
      return false;
    }
  }

  // =============== HAPUS MASSAL ===============
  /// Jika [refType] null  -> hapus semua log (ITEM + SERVICE).
  /// Jika [refType] = 'ITEM' -> hapus semua log barang baru.
  /// Jika [refType] = 'SERVICE' -> hapus semua log service.
  Future<bool> deleteAllLogs({String? refType}) async {
    try {
      PostgrestFilterBuilder<dynamic> builder =
          _supabase.from('stock_out').delete();

      if (refType != null) {
        // hapus hanya log dengan tipe tertentu
        builder = builder.eq('ref_type', refType);
      } else {
        // WAJIB ada WHERE, pakai filter aman ke kolom timestamp
        // semua row normal pasti punya created_at >= 1900-01-01
        builder = builder.gte('created_at', '1900-01-01T00:00:00Z');
      }

      await builder;

      // setelah hapus di server, refresh ulang dari DB
      await refreshAll();

      return true;
    } on PostgrestException catch (e, st) {
      debugPrint('Error deleteAllLogs (Postgrest): $e');
      debugPrint('$st');
      return false;
    } catch (e, st) {
      debugPrint('Error deleteAllLogs: $e');
      debugPrint('$st');
      return false;
    }
  }
}
