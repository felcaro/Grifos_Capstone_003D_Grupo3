import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

/// Pantalla de registro. Crea la cuenta en Supabase Auth con el nombre y la
/// compañía elegidos; el perfil en la tabla "usuario" (rol "bombero") lo crea
/// automáticamente un trigger en la base de datos (ver registro_y_personal.sql).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = SupabaseService();

  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _password2Controller = TextEditingController();

  late Future<List<Map<String, dynamic>>> _companiasFuture;
  String? _companiaId;
  bool _cargando = false;
  bool _ocultarPassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _companiasFuture = _db.obtenerCompanias();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _password2Controller.dispose();
    super.dispose();
  }

  String _traducirError(String mensaje) {
    final m = mensaje.toLowerCase();
    if (m.contains('already registered') || m.contains('already been registered')) {
      return 'Ese correo ya está registrado. Inicia sesión.';
    }
    if (m.contains('password') && m.contains('at least')) return 'La contraseña debe tener al menos 6 caracteres.';
    if (m.contains('invalid') && m.contains('email')) return 'El correo no es válido.';
    if (m.contains('rate limit') || m.contains('too many')) return 'Demasiados intentos. Espera un minuto y reintenta.';
    if (m.contains('database error')) {
      return 'No se pudo crear tu perfil en la base de datos. Avisa al administrador (revisar el trigger de registro en Supabase).';
    }
    return mensaje;
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final nombre = _nombreController.text.trim();
      final respuesta = await AuthService.registrar(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        nombre: nombre,
        companiaId: _companiaId!,
      );

      // Supabase no avisa con error cuando el correo ya existe (por seguridad):
      // devuelve un usuario sin "identities".
      if (respuesta.user != null && (respuesta.user!.identities?.isEmpty ?? false)) {
        setState(() => _error = 'Ese correo ya está registrado. Inicia sesión.');
        return;
      }

      if (!mounted) return;

      if (respuesta.session == null) {
        // El proyecto exige confirmar el correo antes de entrar
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('Cuenta creada', style: TextStyle(color: AppColors.textoPrincipal)),
            content: const Text(
              'Te enviamos un correo para confirmar tu cuenta. Confírmalo y luego inicia sesión.',
              style: TextStyle(color: AppColors.textoSecundario),
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.rojo),
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('¡Cuenta creada! Bienvenido/a, $nombre')));
      }

      // Si ya hay sesión, AuthGate muestra la app; si no, queda el login.
      if (mounted) Navigator.of(context).pop();
    } on AuthException catch (e) {
      setState(() => _error = _traducirError(e.message));
    } catch (e) {
      setState(() => _error = _traducirError('$e'));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: AppColors.rojo,
        foregroundColor: Colors.white,
        title: const Text('Crear cuenta'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: decoracionTarjeta(),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.person_add_alt_1, size: 48, color: AppColors.rojo),
                    const SizedBox(height: 8),
                    const Text(
                      'Registro de personal',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textoPrincipal),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _nombreController,
                      textCapitalization: TextCapitalization.words,
                      decoration: decoracionCampo('Nombre completo', prefixIcon: const Icon(Icons.badge_outlined)),
                      validator: (v) => (v == null || v.trim().length < 3) ? 'Ingresa tu nombre completo' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: decoracionCampo('Correo electrónico', prefixIcon: const Icon(Icons.email_outlined)),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        return (t.contains('@') && t.contains('.')) ? null : 'Ingresa un correo válido';
                      },
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _companiasFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: LinearProgressIndicator(color: AppColors.rojo),
                          );
                        }
                        final companias = snapshot.data ?? [];
                        if (snapshot.hasError || companias.isEmpty) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                snapshot.hasError
                                    ? 'No se pudieron cargar las compañías.'
                                    : 'Aún no hay compañías registradas en el sistema.',
                                style: const TextStyle(color: AppColors.rojoAlerta, fontSize: 13),
                              ),
                              TextButton.icon(
                                onPressed: () => setState(() => _companiasFuture = _db.obtenerCompanias()),
                                icon: const Icon(Icons.refresh, color: AppColors.rojo),
                                label: const Text('Reintentar', style: TextStyle(color: AppColors.rojo)),
                              ),
                            ],
                          );
                        }
                        return DropdownButtonFormField<String>(
                          value: _companiaId,
                          isExpanded: true,
                          decoration: decoracionCampo('Compañía', prefixIcon: const Icon(Icons.local_fire_department_outlined)),
                          items: companias
                              .map((c) => DropdownMenuItem<String>(
                                    value: c['id'] as String,
                                    child: Text(
                                      '${c['nombre'] ?? 'Compañía'}${c['comuna'] != null ? ' · ${c['comuna']}' : ''}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _companiaId = v),
                          validator: (v) => v == null ? 'Elige tu compañía' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _ocultarPassword,
                      decoration: decoracionCampo(
                        'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_ocultarPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _ocultarPassword = !_ocultarPassword),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password2Controller,
                      obscureText: _ocultarPassword,
                      decoration: decoracionCampo('Repetir contraseña', prefixIcon: const Icon(Icons.lock_reset)),
                      validator: (v) => v != _passwordController.text ? 'Las contraseñas no coinciden' : null,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tu cuenta se crea con rol Bombero. Un oficial puede cambiar tu rol después.',
                      style: TextStyle(color: AppColors.textoSecundario, fontSize: 12),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(_error!, style: TextStyle(color: Colors.red.shade800, fontSize: 13), textAlign: TextAlign.center),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.rojo, padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: _cargando ? null : _registrar,
                      child: _cargando
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Crear cuenta', style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _cargando ? null : () => Navigator.of(context).pop(),
                      child: const Text('¿Ya tienes cuenta? Inicia sesión', style: TextStyle(color: AppColors.rojo)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
