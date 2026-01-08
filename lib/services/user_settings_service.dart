import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Preferensi user untuk mengatur jenis notifikasi yang ditampilkan.
///
/// Penyimpanan: tabel `user_settings` (1 row per user).
/// Jika tabel belum ada / belum diset, service akan fallback ke default (semua aktif).
class UserSettingsService {
  static final UserSettingsService _instance = UserSettingsService._internal();
  factory UserSettingsService() => _instance;
  UserSettingsService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<NotificationPrefs> loadPrefs() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const NotificationPrefs();
    }

    try {
      final row = await _supabase
          .from('user_settings')
          .select('notif_item_added, notif_service_in, notif_stock_out')
          .eq('user_id', user.id)
          .maybeSingle();

      if (row == null) {
        // Buat row default agar persist untuk selanjutnya
        await savePrefs(const NotificationPrefs());
        return const NotificationPrefs();
      }

      return NotificationPrefs(
        notifItemAdded: (row['notif_item_added'] as bool?) ?? true,
        notifServiceIn: (row['notif_service_in'] as bool?) ?? true,
        notifStockOut: (row['notif_stock_out'] as bool?) ?? true,
      );
    } catch (e, st) {
      debugPrint('UserSettingsService.loadPrefs error: $e');
      debugPrint('$st');
      return const NotificationPrefs();
    }
  }

  Future<bool> savePrefs(NotificationPrefs prefs) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final data = {
        'user_id': user.id,
        'notif_item_added': prefs.notifItemAdded,
        'notif_service_in': prefs.notifServiceIn,
        'notif_stock_out': prefs.notifStockOut,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await _supabase.from('user_settings').upsert(data);
      return true;
    } catch (e, st) {
      debugPrint('UserSettingsService.savePrefs error: $e');
      debugPrint('$st');
      return false;
    }
  }
}

@immutable
class NotificationPrefs {
  final bool notifItemAdded;
  final bool notifServiceIn;
  final bool notifStockOut;

  /// Default: semua notifikasi aktif.
  const NotificationPrefs({
    this.notifItemAdded = true,
    this.notifServiceIn = true,
    this.notifStockOut = true,
  });

  NotificationPrefs copyWith({
    bool? notifItemAdded,
    bool? notifServiceIn,
    bool? notifStockOut,
  }) {
    return NotificationPrefs(
      notifItemAdded: notifItemAdded ?? this.notifItemAdded,
      notifServiceIn: notifServiceIn ?? this.notifServiceIn,
      notifStockOut: notifStockOut ?? this.notifStockOut,
    );
  }
}
