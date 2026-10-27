import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Estilos compartidos (campos de texto y tarjetas) con la estética de Tesorería.
InputDecoration decoracionCampo(String label, {Widget? suffixIcon, Widget? prefixIcon}) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textoSecundario),
      suffixIcon: suffixIcon,
      prefixIcon: prefixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bordeCampo)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bordeCampo)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.rojo)),
    );

BoxDecoration decoracionTarjeta() => BoxDecoration(
      color: AppColors.tarjeta,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
    );
