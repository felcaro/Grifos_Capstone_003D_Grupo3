import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper con utilidades comunes de autenticación para usar en cualquier parte de la app.
class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Notificador para pruebas / modo demo (test@gmail.com)
  static final ValueNotifier<bool> testSessionNotifier =
      ValueNotifier<bool>(false);

  /// Retorna el usuario autenticado actual (o null si no hay sesión).
  static User? get currentUser => _client.auth.currentUser;

  /// Retorna el correo del usuario actual.
  static String? get currentEmail => testSessionNotifier.value
      ? 'test@gmail.com'
      : _client.auth.currentUser?.email;

  /// Retorna true si hay un usuario autenticado o sesión de prueba activa.
  static bool get isLoggedIn =>
      testSessionNotifier.value || _client.auth.currentSession != null;

  /// Activa o desactiva la sesión de prueba
  static void setTestSession(bool active) {
    testSessionNotifier.value = active;
  }

  /// Cierra la sesión activa.
  static Future<void> signOut() async {
    testSessionNotifier.value = false;
    await _client.auth.signOut();
  }
}
