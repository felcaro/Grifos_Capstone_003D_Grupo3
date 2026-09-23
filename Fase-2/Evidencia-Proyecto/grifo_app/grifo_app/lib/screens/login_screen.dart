import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final String appTitle;
  final IconData appIcon;
  final Color primaryColor;

  const LoginScreen({
    super.key,
    this.appTitle = 'GrifoApp',
    this.appIcon = Icons.local_fire_department,
    this.primaryColor = Colors.red,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Prellenado con las credenciales de prueba solicitadas
  final _emailController = TextEditingController(text: 'test@gmail.com');
  final _passwordController = TextEditingController(text: 'test123456');

  bool _cargando = false;
  bool _esRegistro = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Caso especial para credenciales de prueba: test@gmail.com / test123456
    if (email.toLowerCase() == 'test@gmail.com' && password == 'test123456') {
      try {
        final client = Supabase.instance.client;
        // Intentamos autenticar con Supabase por si el usuario ya existe
        await client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } catch (_) {
        // Si no está registrado en Supabase o requiere confirmación, activamos la sesión de prueba de inmediato
        AuthService.setTestSession(true);
      } finally {
        if (mounted) setState(() => _cargando = false);
      }
      return;
    }

    try {
      final client = Supabase.instance.client;
      if (_esRegistro) {
        await client.auth.signUp(
          email: email,
          password: password,
        );
        if (mounted) {
          setState(() {
            _esRegistro = false;
            _error =
                'Cuenta creada con éxito. Si tu proyecto requiere confirmación, revisa tu correo antes de iniciar sesión.';
          });
        }
      } else {
        await client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(widget.appIcon, size: 64, color: widget.primaryColor),
                  const SizedBox(height: 12),
                  Text(
                    widget.appTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ingreso al Sistema de Grifos',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Ingresa un correo válido'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Mínimo 6 caracteres'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: widget.primaryColor,
                    ),
                    onPressed: _cargando ? null : _submit,
                    child: _cargando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _esRegistro ? 'Crear cuenta' : 'Iniciar sesión',
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _cargando
                        ? null
                        : () => setState(() {
                              _esRegistro = !_esRegistro;
                              _error = null;
                            }),
                    child: Text(
                      _esRegistro
                          ? '¿Ya tienes cuenta? Inicia sesión'
                          : '¿No tienes cuenta? Regístrate',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
