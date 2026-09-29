import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper con utilidades comunes de autenticación para usar en cualquier parte de la app.
class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Retorna el usuario autenticado actual (o null si no hay sesión).
  static User? get currentUser => _client.auth.currentUser;

  /// Retorna el correo del usuario actual.
  static String? get currentEmail => _client.auth.currentUser?.email;

  /// Retorna true si hay un usuario autenticado.
  static bool get isLoggedIn => _client.auth.currentSession != null;

  /// Cierra la sesión activa.
  static Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
