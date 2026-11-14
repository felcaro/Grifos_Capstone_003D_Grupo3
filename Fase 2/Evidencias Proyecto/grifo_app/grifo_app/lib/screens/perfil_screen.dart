import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

/// Mi perfil: datos de la cuenta y cambio de correo y de contraseña.
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _db = SupabaseService();
  Map<String, dynamic>? _perfil;

  // correo
  final _formCorreo = GlobalKey<FormState>();
  final _correoNuevo = TextEditingController();
  bool _guardandoCorreo = false;

  // contraseña
  final _formPass = GlobalKey<FormState>();
  final _passActual = TextEditingController();
  final _passNueva = TextEditingController();
  final _passRepetir = TextEditingController();
  bool _guardandoPass = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _correoNuevo.dispose();
    _passActual.dispose();
    _passNueva.dispose();
    _passRepetir.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final p = await _db.obtenerPerfilActual();
      if (mounted) setState(() => _perfil = p);
    } catch (_) {}
  }

  void _aviso(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.rojoAlerta : null,
      duration: const Duration(seconds: 6),
    ));
  }

  Future<void> _cambiarCorreo() async {
    if (!_formCorreo.currentState!.validate()) return;
    final nuevo = _correoNuevo.text.trim();
    setState(() => _guardandoCorreo = true);
    try {
      await AuthService.cambiarCorreo(nuevo);
      _correoNuevo.clear();
      _aviso('Te enviamos un enlace de confirmación a $nuevo. El correo cambiará cuando lo confirmes (si se pide, confirma también en el correo actual).');
    } on AuthException catch (e) {
      _aviso(e.message, error: true);
    } catch (e) {
      _aviso('No se pudo cambiar el correo: $e', error: true);
    } finally {
      if (mounted) setState(() => _guardandoCorreo = false);
    }
  }

  Future<void> _cambiarPassword() async {
    if (!_formPass.currentState!.validate()) return;
    setState(() => _guardandoPass = true);
    try {
      try {
        await AuthService.verificarPassword(_passActual.text);
      } on AuthException {
        _aviso('La contraseña actual no es correcta', error: true);
        return;
      }
      await AuthService.cambiarPassword(_passNueva.text);
      _passActual.clear();
      _passNueva.clear();
      _passRepetir.clear();
      _aviso('Contraseña actualizada');
    } on AuthException catch (e) {
      _aviso(e.message, error: true);
    } catch (e) {
      _aviso('No se pudo cambiar la contraseña: $e', error: true);
    } finally {
      if (mounted) setState(() => _guardandoPass = false);
    }
  }

  InputDecoration _deco(String label, IconData icono) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icono),
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      );

  Widget _dato(String etiqueta, Object? valor) {
    final v = (valor ?? '').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(etiqueta, style: const TextStyle(color: AppColors.textoSecundario))),
          Expanded(child: Text(v.isEmpty ? '—' : v, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textoPrincipal))),
        ],
      ),
    );
  }

  Widget _tarjeta(String titulo, Widget hijo) => Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: decoracionTarjeta(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textoPrincipal)),
            const SizedBox(height: 12),
            hijo,
          ],
        ),
      );

  Widget _boton(String texto, bool cargando, VoidCallback onTap) => FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.rojo, padding: const EdgeInsets.symmetric(vertical: 14)),
        onPressed: cargando ? null : onTap,
        child: cargando
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(texto),
      );

  @override
  Widget build(BuildContext context) {
    final p = _perfil;
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: AppColors.rojo,
        foregroundColor: Colors.white,
        title: const Text('Mi perfil'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _tarjeta(
                'Mis datos',
                Column(
                  children: [
                    _dato('Nombre', p?['nombre']),
                    _dato('Correo', AuthService.currentEmail),
                    _dato('Rol', p?['rol']),
                    _dato('N° de voluntario', p?['numero_voluntario']),
                    _dato('N° de maquinista', p?['numero_maquinista']),
                  ],
                ),
              ),
              _tarjeta(
                'Cambiar correo',
                Form(
                  key: _formCorreo,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _correoNuevo,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _deco('Correo nuevo', Icons.email_outlined),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (!t.contains('@')) return 'Ingresa un correo válido';
                          if (t.toLowerCase() == (AuthService.currentEmail ?? '').toLowerCase()) return 'Es el mismo correo actual';
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      const Text('Te enviaremos un enlace de confirmación al correo nuevo.', style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                      const SizedBox(height: 12),
                      _boton('Cambiar correo', _guardandoCorreo, _cambiarCorreo),
                    ],
                  ),
                ),
              ),
              _tarjeta(
                'Cambiar contraseña',
                Form(
                  key: _formPass,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _passActual,
                        obscureText: true,
                        decoration: _deco('Contraseña actual', Icons.lock_outline),
                        validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña actual' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passNueva,
                        obscureText: true,
                        decoration: _deco('Contraseña nueva', Icons.lock_reset),
                        validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passRepetir,
                        obscureText: true,
                        decoration: _deco('Repite la contraseña nueva', Icons.lock_reset),
                        validator: (v) => v != _passNueva.text ? 'Las contraseñas no coinciden' : null,
                      ),
                      const SizedBox(height: 12),
                      _boton('Cambiar contraseña', _guardandoPass, _cambiarPassword),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
