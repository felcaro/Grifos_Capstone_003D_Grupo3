import 'dart:typed_data';
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

  // ==========================================================================
  // UTILIDAD COMPARTIDA: compañía del usuario autenticado
  // ==========================================================================
  Future<String?> obtenerCompaniaIdUsuarioActual() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final fila = await _client
        .from('usuario')
        .select('compania_id')
        .eq('id', uid)
        .maybeSingle();
    return fila == null ? null : fila['compania_id'] as String?;
  }

  // ==========================================================================
  // VERIFICACIÓN DE IDENTIDAD (para firmas)
  // ==========================================================================
  //
  // Comprueba que "correo" + "password" corresponden a una cuenta válida,
  // SIN dejar esa sesión activa: se guarda el refresh token de quien tiene
  // la app abierta y se restaura apenas termina la verificación, para no
  // perder lo que esa persona ya había llenado en el formulario.
  //
  // Devuelve la fila de "usuario" (con su nombre real) si la contraseña es
  // correcta, o null si no lo es. Lanza una excepción solo si algo más
  // falla (ej. sin conexión).
  Future<Map<String, dynamic>?> verificarIdentidadPorPassword(String correo, String password) async {
    final sesionOriginal = _client.auth.currentSession;

    try {
      final respuesta = await _client.auth.signInWithPassword(email: correo, password: password);
      final uid = respuesta.user?.id;
      if (uid == null) return null;

      final fila = await _client.from('usuario').select().eq('id', uid).maybeSingle();
      return fila;
    } on AuthException {
      return null; // contraseña incorrecta (o correo inexistente)
    } finally {
      // Restaurar siempre la sesión de quien estaba llenando el formulario
      if (sesionOriginal != null) {
        await _client.auth.setSession(sesionOriginal.refreshToken!);
      }
    }
  }

  // ==========================================================================
  // MÓDULO ACTAS
  // ==========================================================================

  // Sube el PDF del acta ya generado al bucket "actas" y retorna su URL pública
  Future<String> subirActaPdf(Uint8List bytesPdf, String nombreArchivo) async {
    await _client.storage.from('actas').uploadBinary(
          nombreArchivo,
          bytesPdf,
          fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
        );
    return _client.storage.from('actas').getPublicUrl(nombreArchivo);
  }

  // Inserta el registro del acta (solo referencia al PDF, no el contenido)
  Future<void> insertarActa({
    required String titulo,
    required String fechaReunion, // yyyy-MM-dd
    required String archivoUrl,
    String? companiaId,
  }) async {
    await _client.from('acta').insert({
      'titulo': titulo,
      'fecha_reunion': fechaReunion,
      'archivo_url': archivoUrl,
      'compania_id': companiaId,
      'creado_por': _client.auth.currentUser?.id,
    });
  }

  Future<List<Map<String, dynamic>>> obtenerActas() async {
    return await _client
        .from('acta')
        .select()
        .order('fecha_reunion', ascending: false);
  }

  // ==========================================================================
  // MÓDULO INVENTARIO DE CARROS
  // ==========================================================================

  Future<List<Map<String, dynamic>>> obtenerCarros() async {
    return await _client.from('carro').select().order('nombre');
  }

  Future<void> agregarCarro(String nombre, String tipo) async {
    final companiaId = await obtenerCompaniaIdUsuarioActual();
    await _client.from('carro').insert({'nombre': nombre, 'tipo': tipo, 'compania_id': companiaId});
  }

  Future<void> agregarCompartimento(String carroId, String nombre, int orden) async {
    await _client.from('compartimento').insert({'carro_id': carroId, 'nombre': nombre, 'orden': orden});
  }

  // Trae los compartimentos de un carro junto con sus items, en una sola consulta
  Future<List<Map<String, dynamic>>> obtenerCompartimentosConItems(String carroId) async {
    return await _client
        .from('compartimento')
        .select('*, item_inventario(*)')
        .eq('carro_id', carroId)
        .order('orden');
  }

  Future<void> actualizarItem(String itemId, {int? cantidad, String? estado, String? observacion}) async {
    final datos = <String, dynamic>{'actualizado_en': DateTime.now().toIso8601String()};
    if (cantidad != null) datos['cantidad'] = cantidad;
    if (estado != null) datos['estado'] = estado;
    if (observacion != null) datos['observacion'] = observacion;
    await _client.from('item_inventario').update(datos).eq('id', itemId);
  }

  Future<void> agregarItem(String compartimentoId, String nombre, int cantidad, String estado) async {
    await _client.from('item_inventario').insert({
      'compartimento_id': compartimentoId,
      'nombre': nombre,
      'cantidad': cantidad,
      'estado': estado,
    });
  }

  Future<void> eliminarItem(String itemId) async {
    await _client.from('item_inventario').delete().eq('id', itemId);
  }

  // ==========================================================================
  // MÓDULO REGISTRO DE ENTREGA DE EPP
  // ==========================================================================

  Future<String> subirRegistroEpp(Uint8List bytesPdf, String nombreArchivo) async {
    await _client.storage.from('entregas-epp').uploadBinary(
          nombreArchivo,
          bytesPdf,
          fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
        );
    return _client.storage.from('entregas-epp').getPublicUrl(nombreArchivo);
  }

  Future<void> insertarEntregaEpp({
    required String voluntarioNombre,
    required String voluntarioRun,
    String? nRegistro,
    required String fecha, // yyyy-MM-dd
    required String archivoUrl,
    String? companiaId,
  }) async {
    await _client.from('entrega_epp').insert({
      'voluntario_nombre': voluntarioNombre,
      'voluntario_run': voluntarioRun,
      'n_registro': nRegistro,
      'fecha': fecha,
      'archivo_url': archivoUrl,
      'compania_id': companiaId,
      'creado_por': _client.auth.currentUser?.id,
    });
  }
}