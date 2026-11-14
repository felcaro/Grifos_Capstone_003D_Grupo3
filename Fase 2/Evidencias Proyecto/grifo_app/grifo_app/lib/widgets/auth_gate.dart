import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/login_screen.dart';
import '../screens/reset_password_screen.dart';

/// Controla la navegación automática según el estado de la sesión:
/// - Si el usuario llegó desde el enlace de recuperación -> pantalla de nueva contraseña.
/// - Si el usuario está autenticado -> Muestra [home].
/// - Si no está autenticado -> Muestra [loginScreen] (o LoginScreen por defecto).
class AuthGate extends StatefulWidget {
  final Widget home;
  final Widget? loginScreen;

  /// true si la app se abrió desde el enlace de recuperación de contraseña.
  final bool recuperacionInicial;

  const AuthGate({
    super.key,
    required this.home,
    this.loginScreen,
    this.recuperacionInicial = false,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _sub;
  late bool _recuperando = widget.recuperacionInicial;

  @override
  void initState() {
    super.initState();
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        if (mounted) setState(() => _recuperando = true);
      } else if (data.event == AuthChangeEvent.signedOut) {
        if (mounted) setState(() => _recuperando = false);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        if (_recuperando && session != null) {
          return ResetPasswordScreen(
            onTerminado: () => setState(() => _recuperando = false),
          );
        }

        if (session != null) {
          return widget.home;
        }

        return widget.loginScreen ??
            const LoginScreen(
              appTitle: 'GrifoApp',
              appIcon: Icons.local_fire_department,
              primaryColor: Colors.red,
            );
      },
    );
  }
}
