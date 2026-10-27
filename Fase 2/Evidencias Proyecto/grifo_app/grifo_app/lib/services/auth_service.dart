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

  /// Registra una cuenta nueva en Supabase Auth. El nombre y la compañía viajan
  /// como metadatos: un trigger en la base de datos crea la fila en "usuario"
  /// (con rol "bombero") a partir de ellos. Ver registro_y_personal.sql.
  static Future<AuthResponse> registrar({
    required String email,
    required String password,
    required String nombre,
    required String companiaId,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'nombre': nombre, 'compania_id': companiaId},
    );
  }

  /// Cierra la sesión activa.
  static Future<void> signOut() async {
    testSessionNotifier.value = false;
    await _client.auth.signOut();
  }
}
