/// Dirección pública de la versión web de GrifoApp (sin "/" al final).
/// Cámbiala por la URL real donde publiques `flutter build web`.
/// Debe estar también en Supabase > Authentication > URL Configuration
/// (Site URL y Redirect URLs).
class AppLinks {
  static const String webUrl = 'https://TU-APP-WEB.example.com';

  /// Abre directamente la pantalla "Recuperar contraseña" de la web.
  static Uri recuperar([String email = '']) => Uri.parse(webUrl).replace(
        queryParameters: {
          'recuperar': '1',
          if (email.isNotEmpty) 'email': email,
        },
      );
}
