import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileData {
  final String fullName;
  final String email;
  final String warehouse;
  final String? avatarUrl;

  const ProfileData({
    required this.fullName,
    required this.email,
    required this.warehouse,
    required this.avatarUrl,
  });

  ProfileData copyWith({
    String? fullName,
    String? email,
    String? warehouse,
    String? avatarUrl,
  }) {
    return ProfileData(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      warehouse: warehouse ?? this.warehouse,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

class ProfileService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<ProfileData> load() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User belum login');
    }

    final uid = user.id;
    final email = user.email ?? '';

    // Ambil row profile, kalau belum ada -> create default
    final res = await _client
        .from('profiles')
        .select('full_name, warehouse, avatar_url')
        .eq('id', uid)
        .maybeSingle();

    if (res == null) {
      // buat default row
      await _client.from('profiles').insert({
        'id': uid,
        'full_name': user.userMetadata?['full_name'] ?? '',
        'warehouse': '',
        'avatar_url': null,
      });

      return ProfileData(
        fullName: (user.userMetadata?['full_name'] ?? '').toString(),
        email: email,
        warehouse: '',
        avatarUrl: null,
      );
    }

    return ProfileData(
      fullName: (res['full_name'] ?? '').toString(),
      email: email,
      warehouse: (res['warehouse'] ?? '').toString(),
      avatarUrl: res['avatar_url']?.toString(),
    );
  }

  Future<bool> update({
    required String fullName,
    required String warehouse,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      await _client.from('profiles').update({
        'full_name': fullName,
        'warehouse': warehouse,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      // Optional: update metadata auth juga
      await _client.auth.updateUser(
        UserAttributes(data: {'full_name': fullName}),
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Upload avatar ke bucket 'avatars' path: <uid>/avatar_<ts>.jpg
  /// Bucket disarankan public agar url bisa langsung dipakai.
  Future<String?> uploadAvatar(File file) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final uid = user.id;
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = '$uid/avatar_$ts.jpg';

      // Upload (upsert false karena nama file unik)
      await _client.storage.from('avatars').upload(
            path,
            file,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      final publicUrl = _client.storage.from('avatars').getPublicUrl(path);

      await _client.from('profiles').update({
        'avatar_url': publicUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', uid);

      return publicUrl;
    } catch (_) {
      return null;
    }
  }

  Future<bool> changePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
