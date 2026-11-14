import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

/// Se muestra al abrir el enlace del correo de recuperación: el usuario ya
/// tiene una sesión temporal y solo debe elegir su nueva contraseña.
class ResetPasswordScreen extends StatefulWidget {
  final VoidCallback onTerminado;
  const ResetPasswordScreen({super.key, required this.onTerminado});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nueva = TextEditingController();
  final _repetir = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _nueva.dispose();
    _repetir.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await AuthService.cambiarPassword(_nueva.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña actualizada')));
      widget.onTerminado(); // AuthGate pasa al Home con la sesión ya iniciada
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
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: AppColors.rojo,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('Nueva contraseña'),
      ),
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
                  const Icon(Icons.lock_open, size: 64, color: AppColors.rojo),
                  const SizedBox(height: 12),
                  const Text('Elige tu nueva contraseña.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textoSecundario)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nueva,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Nueva contraseña', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _repetir,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Repite la contraseña', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder()),
                    validator: (v) => v != _nueva.text ? 'Las contraseñas no coinciden' : null,
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: AppColors.rojoAlerta), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.rojo, padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: _cargando ? null : _guardar,
                    child: _cargando
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Guardar contraseña', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _cargando ? null : () async => AuthService.signOut(),
                    child: const Text('Cancelar'),
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
