import 'package:flutter/material.dart';

/// Paleta compartida, tomada de la pantalla de Tesorería, para que
/// Actas, Inventario de Carros y Entrega de EPP se vean consistentes
/// con el resto de la app (tema claro, acentos en rojo institucional).
class AppColors {
  static const rojo = Color(0xFFC62828); // AppBar / botones principales
  static const fondo = Color(0xFFFFF8F7); // fondo general de las pantallas
  static const tarjeta = Color(0xFFFFF0EE); // fondo de cards
  static const verde = Color(0xFF2E7D32); // valores positivos
  static const rojoAlerta = Color(0xFFF44336); // valores negativos / alertas
  static const textoPrincipal = Colors.black87;
  static const textoSecundario = Colors.black54;
  static const bordeCampo = Color(0xFFE0B4AF);
}
