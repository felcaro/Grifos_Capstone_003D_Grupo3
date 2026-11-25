// ============================================================================
// MODELO DE DATOS: CampanaEconomica
// Mapea la tabla 'campana_economica' de PostgreSQL a objetos Dart.
// ============================================================================

class CampanaEconomica {
  final String id;
  final String companiaId;
  final String nombre;

  CampanaEconomica({
    required this.id,
    required this.companiaId,
    required this.nombre,
  });

  factory CampanaEconomica.fromJson(Map<String, dynamic> json) {
    return CampanaEconomica(
      id: json['id'] as String,
      companiaId: json['compania_id'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
    );
  }
}