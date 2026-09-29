import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/login_screen.dart';

/// Controla la navegación automática según el estado de la sesión:
/// - Si el usuario está autenticado -> Muestra [home].
/// - Si no está autenticado -> Muestra [loginScreen] (o LoginScreen por defecto).
class AuthGate extends StatelessWidget {
  final Widget home;
  final Widget? loginScreen;

  const AuthGate({
    super.key,
    required this.home,
    this.loginScreen,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Obtenemos la sesión actual de Supabase
        final session = Supabase.instance.client.auth.currentSession;

        if (session != null) {
          return home;
        }

        return loginScreen ?? const LoginScreen();
      },
    );
  }
}
