import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/permisos.dart';

/// Helper con utilidades comunes de autenticación para usar en cualquier parte de la app.
class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Retorna el usuario autenticado actual (o null si no hay sesión).
  static User? get currentUser => _client.auth.currentUser;

  /// Retorna el correo del usuario actual.
  static String? get currentEmail => _client.auth.currentUser?.email;

  /// Retorna true si hay un usuario autenticado activo.
  static bool get isLoggedIn => _client.auth.currentSession != null;

  /// Registra una cuenta nueva en Supabase Auth. El nombre y la compañía viajan
  /// como metadatos: un trigger en la base de datos crea la fila en "usuario"
  /// (con rol "bombero") a partir de ellos. Ver registro_y_personal.sql.
  static Future<AuthResponse> registrar({
    required String email,
    required String password,
    required String nombre,
    required String companiaId,
    String? numeroVoluntario,
    String? numeroMaquinista,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'nombre': nombre,
        'compania_id': companiaId,
        if (numeroVoluntario != null && numeroVoluntario.trim().isNotEmpty)
          'numero_voluntario': numeroVoluntario.trim(),
        if (numeroMaquinista != null && numeroMaquinista.trim().isNotEmpty)
          'numero_maquinista': numeroMaquinista.trim(),
      },
    );
  }

  /// Cierra la sesión activa.
    /// Cierra la sesión activa.
  static Future<void> signOut() async {
    Permisos.limpiar();
    await _client.auth.signOut();
  }
}
