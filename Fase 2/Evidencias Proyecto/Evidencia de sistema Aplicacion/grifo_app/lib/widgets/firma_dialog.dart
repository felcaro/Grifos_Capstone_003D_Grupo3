import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';

/// Resultado de capturar una firma: o es una foto, o es nombre+RUT escritos,
/// pero en ambos casos "nombreVerificado" viene de la cuenta cuya
/// contraseña se confirmó (no de lo que la persona haya escrito a mano).
class FirmaData {
  final bool esFoto;
  final String nombreVerificado;
  final String? rut;
  final Uint8List? fotoBytes;

  FirmaData.foto({required this.nombreVerificado, required this.fotoBytes})
      : esFoto = true,
        rut = null;

  FirmaData.texto({required this.nombreVerificado, required this.rut})
      : esFoto = false,
        fotoBytes = null;
}

/// Abre el flujo completo de firma: elegir modo (foto / nombre+RUT),
/// completar los datos, y verificar la contraseña de esa persona antes
/// de aceptar. Devuelve un FirmaData si todo salió bien, o null si se
/// canceló o la contraseña no coincidió.
Future<FirmaData?> mostrarDialogoFirma(BuildContext context, {required String tituloFirmante}) async {
  final modo = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Firma — $tituloFirmante', style: const TextStyle(color: AppColors.textoPrincipal)),
      content: const Text('¿Cómo quieres registrar la firma?', style: TextStyle(color: AppColors.textoSecundario)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(context, 'texto'), child: const Text('Nombre y RUT')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.rojo),
          onPressed: () => Navigator.pop(context, 'foto'),
          child: const Text('Subir foto'),
        ),
      ],
    ),
  );

  if (modo == null || !context.mounted) return null;

  if (modo == 'foto') {
    final picker = ImagePicker();
    final archivo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (archivo == null || !context.mounted) return null;
    final bytes = await archivo.readAsBytes();
    if (!context.mounted) return null;

    final identidad = await _pedirPasswordYVerificar(context, tituloFirmante);
    if (identidad == null) return null;
    return FirmaData.foto(nombreVerificado: identidad['nombre'] ?? '', fotoBytes: bytes);
  }

  // modo == 'texto'
  final rutController = TextEditingController();
  final confirmarDatos = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Firma — $tituloFirmante', style: const TextStyle(color: AppColors.textoPrincipal)),
      content: TextField(
        controller: rutController,
        decoration: const InputDecoration(labelText: 'R.U.N. de quien firma', labelStyle: TextStyle(color: AppColors.textoSecundario)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.rojo),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
  if (confirmarDatos != true || rutController.text.isEmpty || !context.mounted) return null;

  final identidad = await _pedirPasswordYVerificar(context, tituloFirmante);
  if (identidad == null) return null;
  return FirmaData.texto(nombreVerificado: identidad['nombre'] ?? '', rut: rutController.text);
}

/// Pide correo + contraseña de quien está firmando y los valida contra
/// Supabase Auth. El nombre que vuelve es el que la cuenta tiene
/// registrado en la tabla "usuario" (no editable por quien firma).
Future<Map<String, dynamic>?> _pedirPasswordYVerificar(BuildContext context, String tituloFirmante) async {
  final correoController = TextEditingController();
  final passwordController = TextEditingController();
  String? error;
  bool verificando = false;

  return showDialog<Map<String, dynamic>?>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Confirma que eres tú ($tituloFirmante)', style: const TextStyle(color: AppColors.textoPrincipal)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingresa tu correo y contraseña para confirmar la firma. No se cerrará la sesión de quien está llenando el acta.',
              style: TextStyle(color: AppColors.textoSecundario, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: correoController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo', labelStyle: TextStyle(color: AppColors.textoSecundario)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña', labelStyle: TextStyle(color: AppColors.textoSecundario)),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: AppColors.rojoAlerta, fontSize: 12)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rojo),
            onPressed: verificando
                ? null
                : () async {
                    setDialogState(() {
                      verificando = true;
                      error = null;
                    });
                    final identidad = await SupabaseService().verificarIdentidadPorPassword(
                      correoController.text.trim(),
                      passwordController.text,
                    );
                    if (identidad == null) {
                      setDialogState(() {
                        verificando = false;
                        error = 'Correo o contraseña incorrectos.';
                      });
                    } else if (context.mounted) {
                      Navigator.pop(context, identidad);
                    }
                  },
            child: verificando
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Confirmar firma'),
          ),
        ],
      ),
    ),
  );
}
