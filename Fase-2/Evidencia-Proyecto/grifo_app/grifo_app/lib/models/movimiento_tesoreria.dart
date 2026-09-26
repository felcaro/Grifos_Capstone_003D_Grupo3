// ============================================================================
// MODELO DE DATOS: MovimientoTesoreria
// Representa un registro de ingreso o egreso dentro del módulo de Tesorería.
// Mapea la estructura descrita en el DAS (Software Architecture Document).
// ============================================================================

class MovimientoTesoreria {
  final String id;
  final String? companiaId;
  final String? registradoPor;
  final String tipo;
  final double monto;
  final String descripcion;
  final String? campanaId;
  final String? boletaUrl;
  final DateTime fecha;

  MovimientoTesoreria({
    required this.id,
    this.companiaId,
    this.registradoPor,
    required this.tipo,
    required this.monto,
    required this.descripcion,
    this.campanaId,
    this.boletaUrl,
    required this.fecha,
  });

  factory MovimientoTesoreria.fromJson(Map<String, dynamic> json) {
    return MovimientoTesoreria(
      id: json['id'] as String,
      companiaId: json['compania_id'] as String?,
      registradoPor: json['registrado_por'] as String?,
      tipo: json['tipo'] as String? ?? 'ingreso',
      monto: (json['monto'] as num).toDouble(),
      descripcion: json['descripcion'] as String? ?? '',
      campanaId: json['campana_id'] as String?,
      boletaUrl: json['boleta_url'] as String?,
      fecha: DateTime.parse(json['fecha'] as String),
    );
  }
}