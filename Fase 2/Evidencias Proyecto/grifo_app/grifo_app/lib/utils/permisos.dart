import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// Permisos de la app según el rol del usuario (columna "usuario.rol").
///
/// TODAS las reglas de la interfaz están aquí: para cambiar qué puede ver o
/// hacer un rol, edita solo este archivo. (La seguridad real la hace Supabase
/// con RLS: ver permisos_por_rol.sql; esto solo esconde lo que no corresponde.)
///
/// Roles: administrador, directorio, capitan, tesorero, bombero.
/// Una cuenta nueva queda como "pendiente" (sin verificar): no ve ni modifica
/// nada hasta que un administrador le asigna un rol. Un rol desconocido o sin
/// perfil cargado se trata igual que "pendiente" (sin acceso).
class Permisos {
  final String rol;
  const Permisos._(this.rol);

  factory Permisos.deRol(dynamic rol) => Permisos._(_normalizar(rol));

  static String _normalizar(dynamic r) =>
      (r ?? '').toString().toLowerCase().trim().replaceAll('á', 'a');

  static const _rolesDeGestion = {'administrador', 'directorio', 'capitan', 'tesorero'};

  /// Mismos roles que la función soy_oficial() de la base de datos (equipo personal).
  static const _rolesOficiales = {'administrador', 'capitan', 'directorio'};

  static const _rolesVerificados = {'administrador', 'directorio', 'capitan', 'tesorero', 'bombero'};

  /// true si un administrador ya verificó a la persona (tiene un rol real).
  bool get verificado => _rolesVerificados.contains(rol);

  /// true para bombero y para cuentas sin verificar.
  bool get esRestringido => !_rolesDeGestion.contains(rol);
  bool get esAdmin => rol == 'administrador';
  bool get esOficial => _rolesOficiales.contains(rol);

  // ---- Qué ventanas se ven ----
  bool get verMapa => verificado;
  bool get verGrifos => verificado;
  bool get verCarros => verificado;
  bool get verEquipoPersonal => verificado; // el bombero ve solo el suyo (ver verTodoElPersonal)
  bool get verParteServicio => verificado;
  bool get verActaDirectorio => verificado && !esRestringido;
  bool get verTodasLasActas => verificado && !esRestringido; // el bombero solo ve partes de servicio
  // Igual que las políticas de movimiento_tesoreria: lectura solo Tesorero y Directorio.
  // (Para que el administrador también la vea: agrega || esAdmin aquí Y en la
  //  política de lectura de la base de datos.)
  bool get verTesoreria => rol == 'tesorero' || rol == 'directorio';
  bool get verAdministracion => esAdmin;

  // ---- Qué se puede modificar ----
  bool get editarGrifos => verificado; // agregar y cambiar el estado de un grifo
  bool get editarCarros => verificado && !esRestringido; // carros, compartimentos, ítems, mantención
  bool get verTodoElPersonal => esOficial; // si no: solo su propio equipo (como soy_oficial())
  bool get editarEquipoPropio => verificado; // su traje e implementos

  // ---- Carga y caché del rol del usuario actual ----
  static Permisos? _cache;
  static String? _cacheUid;

  /// Lee el rol del usuario con sesión (queda en caché mientras sea la misma sesión).
  static Future<Permisos> cargar() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (_cache != null && _cacheUid == uid) return _cache!;
    Map<String, dynamic>? perfil;
    try {
      perfil = await SupabaseService().obtenerMiPerfil();
    } catch (_) {
      perfil = null;
    }
    final p = Permisos.deRol(perfil?['rol']);
    if (perfil != null) {
      _cache = p;
      _cacheUid = uid;
    }
    return p;
  }

  /// Llamar al cerrar sesión o al cambiar el rol de alguien.
  static void limpiar() {
    _cache = null;
    _cacheUid = null;
  }
}
