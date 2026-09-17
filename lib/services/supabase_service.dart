import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final _client = Supabase.instance.client;

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

  // NUEVO: Actualizar un grifo existente usando su ID
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
        .eq('id', id); // El .eq significa "donde el id sea IGUAL a este id"
  }
}
