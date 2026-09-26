import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/movimiento_tesoreria.dart';

class SupabaseService {
  final _client = Supabase.instance.client;

  // ==========================================================================
  // MÓDULO GRIFOS
  // ==========================================================================

  // Insertar un grifo
  Future<void> insertarGrifoPrueba(
    double lat,
    double lng,
    String direccion,
  ) async {
    await _client.from('grifo').insert({
      'sector_id': '22222222-2222-2222-2222-222222222222',
      'creado_por': '33333333-3333-3333-3333-333333333333',
      'latitud': lat,
      'longitud': lng,
      'direccion_referencial': direccion,
    });
  }

  // Traer todos los grifos
  Future<List<Map<String, dynamic>>> obtenerGrifos() async {
    final respuesta = await _client
        .from('grifo')
        .select('id, latitud, longitud, direccion_referencial');
    return respuesta;
  }

  // Actualizar un grifo existente usando su ID
  Future<void> actualizarGrifo(
    String id,
    double lat,
    double lng,
    String direccion,
  ) async {
    await _client
        .from('grifo')
        .update({
          'latitud': lat,
          'longitud': lng,
          'direccion_referencial': direccion,
        })
        .eq('id', id);
  }

  // Buscar grifos por su dirección referencial
  Future<List<Map<String, dynamic>>> buscarGrifoPorDireccion(String textoBusqueda) async {
    try {
      final respuesta = await _client
          .from('grifo')
          .select('id, latitud, longitud, direccion_referencial');
      
      print('>>> RESPUESTA DE SUPABASE: $respuesta');
      return respuesta;
    } catch (e) {
      print('>>> ERROR REAL AL BUSCAR: $e');
      return [];
    }
  }

  // ==========================================================================
  // MÓDULO TESORERÍA
  // ==========================================================================

  /// Consulta y retorna la lista de movimientos financieros registrados.
  Future<List<MovimientoTesoreria>> obtenerMovimientosTesoreria() async {
    try {
      final response = await _client
          .from('movimiento_tesoreria')
          .select()
          .order('fecha', ascending: false);

      final lista = (response as List)
          .map((json) => MovimientoTesoreria.fromJson(json))
          .toList();

      return lista;
    } catch (e) {
      print('Error al obtener movimientos de tesorería: $e');
      rethrow;
    }
  }

  /// Inserta un nuevo movimiento (ingreso o egreso) en la base de datos Supabase.
  Future<void> registrarMovimientoTesoreria({
    required String tipo, // 'ingreso' o 'egreso'
    required double monto,
    required String descripcion,
    String? campanaId,
    String? boletaUrl,
  }) async {
    // 1. Obtener el usuario autenticado actual
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    // 2. Obtener la compañía vinculada al usuario
    final usuarioResponse = await _client
        .from('usuario')
        .select('compania_id')
        .eq('id', user.id)
        .single();

    final companiaId = usuarioResponse['compania_id'];

    // 3. Insertar el registro en la tabla movimiento_tesoreria
    await _client.from('movimiento_tesoreria').insert({
      'compania_id': companiaId,
      'registrado_por': user.id,
      'tipo': tipo,
      'monto': monto,
      'descripcion': descripcion,
      'campana_id': (campanaId != null && campanaId.trim().isNotEmpty)
          ? campanaId.trim()
          : null,
      'boleta_url': boletaUrl,
      'fecha': DateTime.now().toIso8601String(),
    });
  }
}