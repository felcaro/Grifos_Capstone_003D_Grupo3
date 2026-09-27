import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/movimiento_tesoreria.dart';

class SupabaseService {
  final _client = Supabase.instance.client;

  // ==========================================================================
  // MÓDULO GRIFOS
  // ==========================================================================

  // ==========================================================================
  // INSERTAR GRIFO (CON BYPASS DE UUIDs)
  // ==========================================================================
  Future<void> insertarGrifoPrueba(double lat, double lng, String direccion) async {
    await _client.from('grifo').insert({
      'latitud': lat,
      'longitud': lng,
      'direccion_referencial': direccion,
      // BYPASS: Enviamos las IDs fijas que ya existen en tu Supabase
      // Recuerda reemplazar los textos entre comillas con los UUIDs reales copiados de tu base de datos:
      'creado_por': '58abe9c4-c64e-414a-8ccb-b926357bd97c', 
      'sector_id': 'a24a10bd-cb20-4bab-8bcd-7228c7a8eb68',
    });
  }

  // Alias para mantener compatibilidad si se llama como insertarGrifo
  Future<void> insertarGrifo(double lat, double lng, String direccion) =>
      insertarGrifoPrueba(lat, lng, direccion);


  // Traer todos los grifos
  Future<List<Map<String, dynamic>>> obtenerGrifos() async {
    final respuesta = await _client
        .from('grifo')
        .select('id, latitud, longitud, direccion_referencial');
    return respuesta;
  }

  // Buscador de grifos por coincidencia de texto en la dirección referencial
  // (ilike no discrimina entre mayúsculas y minúsculas)
  Future<List<Map<String, dynamic>>> buscarGrifoPorDireccion(String texto) async {
    final respuesta = await _client
        .from('grifo')
        .select()
        .ilike('direccion_referencial', '%$texto%');
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