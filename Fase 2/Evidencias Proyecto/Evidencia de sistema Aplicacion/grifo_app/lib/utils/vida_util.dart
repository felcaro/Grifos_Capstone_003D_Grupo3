import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

String _plural(int n, String uno, String varios) => '$n ${n == 1 ? uno : varios}';

String fechaIso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String fechaVisible(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Resultado del cálculo de vida útil de un equipo (ej: traje de bombero, 10 años).
class VidaUtil {
  final String texto;
  final Color color;
  final double usado; // 0.0 (nuevo) a 1.0 (vencido)
  final int diasRestantes; // negativo si ya venció
  const VidaUtil(this.texto, this.color, this.usado, this.diasRestantes);

  bool get vencido => diasRestantes <= 0;
  bool get porVencer => diasRestantes > 0 && diasRestantes <= 365;
}

/// Calcula cuánto le queda de vida útil desde la fecha de compra.
/// Devuelve null si el equipo no tiene fecha de compra registrada.
VidaUtil? calcularVidaUtil(dynamic fechaCompraRaw, dynamic aniosRaw) {
  if (fechaCompraRaw == null) return null;
  final compra = DateTime.tryParse(fechaCompraRaw.toString());
  if (compra == null) return null;
  final anios = aniosRaw is int ? aniosRaw : (int.tryParse('${aniosRaw ?? 10}') ?? 10);

  final hoy = DateTime.now();
  final vence = DateTime(compra.year + anios, compra.month, compra.day);
  final totalDias = vence.difference(compra).inDays;
  final usadoDias = hoy.difference(compra).inDays;
  final usado = totalDias <= 0 ? 1.0 : (usadoDias / totalDias).clamp(0.0, 1.0).toDouble();

  if (!vence.isAfter(hoy)) {
    final diasVencido = hoy.difference(vence).inDays;
    return VidaUtil('Vida útil vencida hace ${_plural(diasVencido, 'día', 'días')}', AppColors.rojoAlerta, 1.0, -diasVencido);
  }

  var meses = (vence.year - hoy.year) * 12 + (vence.month - hoy.month);
  if (vence.day < hoy.day) meses -= 1;
  final diasRestantes = vence.difference(hoy).inDays;
  final a = meses ~/ 12;
  final m = meses % 12;

  String texto;
  if (a > 0) {
    texto = m > 0 ? '${_plural(a, 'año', 'años')} y ${_plural(m, 'mes', 'meses')}' : _plural(a, 'año', 'años');
  } else if (m > 0) {
    texto = _plural(m, 'mes', 'meses');
  } else {
    texto = _plural(diasRestantes, 'día', 'días');
  }

  // Verde: más de 2 años · Naranja: entre 1 y 2 años · Rojo: menos de 1 año
  final color = diasRestantes > 730
      ? AppColors.verde
      : (diasRestantes > 365 ? Colors.orange.shade700 : AppColors.rojoAlerta);
  return VidaUtil('Le quedan $texto de vida útil', color, usado, diasRestantes);
}
