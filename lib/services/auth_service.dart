import 'package:supabase_flutter/supabase_flutter.dart';

/// Wrapper ringan untuk Supabase Auth agar pemanggilan dari UI rapi dan konsisten.
class AuthService {
  AuthService._();

  static final SupabaseClient _client = Supabase.instance.client;

  static Session? get session => _client.auth.currentSession;
  static User? get user => _client.auth.currentUser;

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {
        if (fullName != null && fullName.trim().isNotEmpty)
          'full_name': fullName.trim(),
      },
    );
  }

  static Future<void> signOut() => _client.auth.signOut();
}
