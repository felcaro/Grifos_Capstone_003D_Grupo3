import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_links.dart';
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
  static Future<void> signOut() async {
    Permisos.limpiar();
    await _client.auth.signOut();
  }

  /// Envía un correo con el enlace para restablecer la contraseña.
  /// El enlace del correo siempre abre la versión web (en web, la misma
  /// dirección; en la app, AppLinks.webUrl). Debe estar en Supabase >
  /// Authentication > URL Configuration.
  static Future<void> enviarRecuperacion(String email) {
    return _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: kIsWeb ? Uri.base.origin : AppLinks.webUrl,
    );
  }

  /// Cambia la contraseña de la sesión activa (también al volver del enlace
  /// de recuperación).
  static Future<void> cambiarPassword(String nueva) async {
    await _client.auth.updateUser(UserAttributes(password: nueva));
  }

  /// Comprueba la contraseña actual volviendo a iniciar sesión con ella.
  static Future<void> verificarPassword(String actual) async {
    final email = currentEmail;
    if (email == null) throw const AuthException('No hay sesión activa');
    await _client.auth.signInWithPassword(email: email, password: actual);
  }

  /// Pide el cambio de correo. Supabase envía un enlace de confirmación al
  /// correo nuevo (y puede pedir confirmar también en el antiguo).
  static Future<void> cambiarCorreo(String nuevo) async {
    await _client.auth.updateUser(
      UserAttributes(email: nuevo.trim()),
      emailRedirectTo: kIsWeb ? Uri.base.origin : AppLinks.webUrl,
    );
  }
}
