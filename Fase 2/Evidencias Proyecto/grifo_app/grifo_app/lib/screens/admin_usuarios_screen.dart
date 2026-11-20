import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

/// Roles que maneja el sistema y lo que permite cada uno.
const rolesDisponibles = ['administrador', 'directorio', 'capitan', 'tesorero', 'bombero', 'pendiente'];

const _descripcionRol = {
  'administrador': 'Gestiona usuarios y roles, y tiene acceso a todos los módulos.',
  'directorio': 'Registra actas y supervisa tesorería y el equipo del personal.',
  'capitan': 'Gestiona el equipo personal y los registros de su compañía.',
  'tesorero': 'Registra ingresos, egresos y rendiciones de tesorería.',
  'bombero': 'Consulta grifos, inventario y su propio equipo personal.',
  'pendiente': 'Cuenta nueva sin verificar: no ve ni modifica nada hasta que un administrador le asigne un rol.',
};

String etiquetaRol(String rol) {
  switch (rol.toLowerCase().replaceAll('á', 'a')) {
    case 'administrador':
      return 'Administrador';
    case 'directorio':
      return 'Directorio';
    case 'capitan':
      return 'Capitán';
    case 'tesorero':
      return 'Tesorero';
    case 'bombero':
      return 'Bombero';
    case 'pendiente':
      return 'Sin verificar';
    default:
      return rol.isEmpty ? 'Sin rol' : rol;
  }
}

Color _colorRol(String rol) {
  switch (rol.toLowerCase().replaceAll('á', 'a')) {
    case 'administrador':
      return AppColors.rojo;
    case 'directorio':
      return Colors.purple.shade600;
    case 'capitan':
      return Colors.orange.shade800;
    case 'tesorero':
      return Colors.teal.shade600;
    case 'pendiente':
      return Colors.amber.shade800;
    default:
      return Colors.blueGrey.shade500;
  }
}

/// Pantalla de administración de usuarios: solo para el rol "administrador".
/// Permite ver a las personas de la compañía y cambiar su rol (que es lo que
/// define sus permisos), sin entrar a Supabase. El cambio lo valida la base de
/// datos (función cambiar_rol_usuario), no solo esta pantalla.
class AdminUsuariosScreen extends StatefulWidget {
  const AdminUsuariosScreen({super.key});

  @override
  State<AdminUsuariosScreen> createState() => _AdminUsuariosScreenState();
}

class _AdminUsuariosScreenState extends State<AdminUsuariosScreen> {
  final _db = SupabaseService();
  final _buscador = TextEditingController();

  Map<String, dynamic>? _perfil;
  List<Map<String, dynamic>> _usuarios = [];
  bool _cargando = true;
  String? _error;
  String _filtro = '';
  String _filtroRol = 'todos'; // 'todos' o uno de rolesDisponibles
  String _orden = 'nuevos'; // nuevos | antiguos | nombre

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final perfil = await _db.obtenerMiPerfil();
      final usuarios = await _leerUsuarios();
      if (!mounted) return;
      setState(() {
        _perfil = perfil;
        _usuarios = usuarios;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _cargando = false;
      });
    }
  }

  /// Lee las personas de la compañía. Pide también N° de voluntario/maquinista y la
  /// fecha de registro; si la base aún no tiene esas columnas, reintenta sin ellas.
  Future<List<Map<String, dynamic>>> _leerUsuarios() async {
    final companiaId = await _db.obtenerCompaniaIdUsuarioActual();
    if (companiaId == null) return [];
    final client = Supabase.instance.client;
    try {
      final filas = await client
          .from('usuario')
          .select('id, nombre, credencial, rol, numero_voluntario, numero_maquinista, created_at')
          .eq('compania_id', companiaId);
      return List<Map<String, dynamic>>.from(filas);
    } catch (_) {
      final filas = await client.from('usuario').select('id, nombre, credencial, rol').eq('compania_id', companiaId);
      return List<Map<String, dynamic>>.from(filas);
    }
  }

  static String _norm(String t) {
    const de = 'áàäâéèëêíìïîóòöôúùüûñ';
    const a = 'aaaaeeeeiiiioooouuuun';
    var r = t.toLowerCase();
    for (var i = 0; i < de.length; i++) {
      r = r.replaceAll(de[i], a[i]);
    }
    return r;
  }

  static String _rolNorm(dynamic r) => _norm((r ?? 'pendiente').toString().trim());

  DateTime _fecha(Map<String, dynamic> u) =>
      DateTime.tryParse((u['created_at'] ?? '').toString())?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);

  String _fechaTexto(Map<String, dynamic> u) {
    final f = _fecha(u);
    if (f.millisecondsSinceEpoch == 0) return '';
    String d2(int n) => n.toString().padLeft(2, '0');
    return '${d2(f.day)}/${d2(f.month)}/${f.year}';
  }

  /// Aplica búsqueda (nombre, apellido, correo, N° de voluntario o de maquinista),
  /// filtro por rol y orden.
  List<Map<String, dynamic>> _filtrarYOrdenar() {
    final palabras = _norm(_filtro).split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final lista = _usuarios.where((u) {
      if (_filtroRol != 'todos' && _rolNorm(u['rol']) != _filtroRol) return false;
      if (palabras.isEmpty) return true;
      final texto = _norm('${u['nombre'] ?? ''} ${u['credencial'] ?? ''} ${u['numero_voluntario'] ?? ''} ${u['numero_maquinista'] ?? ''}');
      return palabras.every(texto.contains); // "juan perez" encuentra "Juan Pérez González"
    }).toList();
    int porNombre(Map<String, dynamic> a, Map<String, dynamic> b) =>
        _norm('${a['nombre'] ?? ''}').compareTo(_norm('${b['nombre'] ?? ''}'));
    switch (_orden) {
      case 'antiguos':
        lista.sort((a, b) {
          final c = _fecha(a).compareTo(_fecha(b));
          return c != 0 ? c : porNombre(a, b);
        });
        break;
      case 'nombre':
        lista.sort(porNombre);
        break;
      default:
        lista.sort((a, b) {
          final c = _fecha(b).compareTo(_fecha(a));
          return c != 0 ? c : porNombre(a, b);
        });
    }
    return lista;
  }

  bool get _soyAdmin => ((_perfil?['rol'] ?? '').toString().toLowerCase() == 'administrador');

  void _aviso(String texto) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _cambiarRol(Map<String, dynamic> usuario) async {
    final rolActual = _rolNorm(usuario['rol']);
    // A una cuenta sin verificar se le propone "bombero" para verificarla con un toque.
    String seleccionado = rolActual == 'pendiente' || !rolesDisponibles.contains(rolActual) ? 'bombero' : rolActual;

    final guardar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text((usuario['nombre'] ?? 'Usuario').toString(), style: const TextStyle(color: AppColors.textoPrincipal)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text((usuario['credencial'] ?? '').toString(), style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
              if ((usuario['numero_voluntario'] ?? '').toString().isNotEmpty)
                Text('N° de voluntario: ${usuario['numero_voluntario']}', style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: seleccionado,
                decoration: decoracionCampo('Rol'),
                items: rolesDisponibles.map((r) => DropdownMenuItem(value: r, child: Text(etiquetaRol(r)))).toList(),
                onChanged: (v) => setD(() => seleccionado = v ?? seleccionado),
              ),
              const SizedBox(height: 10),
              Text(_descripcionRol[seleccionado] ?? '', style: const TextStyle(color: AppColors.textoSecundario, fontSize: 13)),
              if (seleccionado == 'administrador') ...[
                const SizedBox(height: 8),
                Text(
                  'Un administrador puede cambiar los roles de los demás. Asígnalo con cuidado.',
                  style: TextStyle(color: Colors.orange.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.rojo),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (guardar != true || seleccionado == rolActual) return;

    try {
      await _db.cambiarRolUsuario(usuario['id'] as String, seleccionado);
      _aviso('Rol de ${usuario['nombre'] ?? 'la persona'} cambiado a ${etiquetaRol(seleccionado)}');
      await _cargar();
    } catch (e) {
      _aviso('No se pudo cambiar el rol: ${e is PostgrestException ? e.message : e}');
    }
  }

  Widget _chip(String texto, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Text(texto, style: const TextStyle(color: Colors.white, fontSize: 11)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: AppColors.rojo,
        foregroundColor: Colors.white,
        title: const Text('Administración de usuarios'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _cargando ? null : _cargar)],
      ),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const Center(child: CircularProgressIndicator(color: AppColors.rojo));

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No se pudo cargar: $_error', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.rojoAlerta)),
        ),
      );
    }

    if (!_soyAdmin) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Solo los administradores pueden entrar a esta sección.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textoSecundario),
          ),
        ),
      );
    }

    final miId = _perfil?['id'];
    final visibles = _filtrarYOrdenar();

    final conteo = <String, int>{};
    for (final u in _usuarios) {
      final r = _rolNorm(u['rol']);
      conteo[r] = (conteo[r] ?? 0) + 1;
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: decoracionTarjeta(),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Text('${_usuarios.length} personas', style: const TextStyle(color: AppColors.textoPrincipal, fontWeight: FontWeight.bold)),
                ...rolesDisponibles.where((r) => (conteo[r] ?? 0) > 0).map((r) => _chip('${etiquetaRol(r)}: ${conteo[r]}', _colorRol(r))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Container(
              decoration: decoracionTarjeta(),
              child: ExpansionTile(
                title: const Text('¿Qué puede hacer cada rol?', style: TextStyle(color: AppColors.textoPrincipal, fontWeight: FontWeight.bold)),
                iconColor: AppColors.rojo,
                collapsedIconColor: AppColors.textoSecundario,
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: rolesDisponibles
                    .map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 100, child: _chip(etiquetaRol(r), _colorRol(r))),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_descripcionRol[r] ?? '', style: const TextStyle(color: AppColors.textoSecundario, fontSize: 13))),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: decoracionCampo(
              'Buscar por nombre, apellido, correo o N° de voluntario',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _filtro.isEmpty
                  ? null
                  : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _filtro = '')),
            ),
            controller: _buscador,
            onChanged: (v) => setState(() => _filtro = v.trim()),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, c) {
            final filtroRol = DropdownButtonFormField<String>(
              value: _filtroRol,
              isExpanded: true,
              decoration: decoracionCampo('Rol'),
              items: [
                const DropdownMenuItem(value: 'todos', child: Text('Todos los roles')),
                ...rolesDisponibles.map((r) => DropdownMenuItem(value: r, child: Text(etiquetaRol(r)))),
              ],
              onChanged: (v) => setState(() => _filtroRol = v ?? 'todos'),
            );
            final orden = DropdownButtonFormField<String>(
              value: _orden,
              isExpanded: true,
              decoration: decoracionCampo('Ordenar'),
              items: const [
                DropdownMenuItem(value: 'nuevos', child: Text('Más nuevos primero')),
                DropdownMenuItem(value: 'antiguos', child: Text('Más antiguos primero')),
                DropdownMenuItem(value: 'nombre', child: Text('Nombre (A-Z)')),
              ],
              onChanged: (v) => setState(() => _orden = v ?? 'nuevos'),
            );
            if (c.maxWidth < 420) {
              return Column(children: [filtroRol, const SizedBox(height: 10), orden]);
            }
            return Row(children: [Expanded(child: filtroRol), const SizedBox(width: 10), Expanded(child: orden)]);
          }),
          const SizedBox(height: 6),
          Text(
            '${visibles.length} de ${_usuarios.length} personas',
            style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12),
          ),
          const SizedBox(height: 6),
          if (visibles.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No hay personas que coincidan.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textoSecundario)),
            ),
          ...visibles.map((u) {
            final esYo = u['id'] == miId;
            final rol = _rolNorm(u['rol']);
            final nombre = (u['nombre'] ?? 'Sin nombre').toString();
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: decoracionTarjeta(),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _colorRol(rol),
                  child: Text(nombre.isNotEmpty ? nombre[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
                ),
                title: Text(esYo ? '$nombre (tú)' : nombre, style: const TextStyle(color: AppColors.textoPrincipal, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  [
                    (u['credencial'] ?? '').toString(),
                    if ((u['numero_voluntario'] ?? '').toString().isNotEmpty) 'N° voluntario ${u['numero_voluntario']}',
                    if ((u['numero_maquinista'] ?? '').toString().isNotEmpty) 'N° maquinista ${u['numero_maquinista']}',
                    if (_fechaTexto(u).isNotEmpty) 'Registro: ${_fechaTexto(u)}',
                  ].where((t) => t.isNotEmpty).join('\n'),
                  style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12),
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _chip(etiquetaRol(rol), _colorRol(rol)),
                    const SizedBox(width: 6),
                    Icon(esYo ? Icons.lock_outline : Icons.edit, size: 18, color: AppColors.textoSecundario),
                  ],
                ),
                onTap: esYo ? () => _aviso('No puedes cambiar tu propio rol. Pídeselo a otro administrador.') : () => _cambiarRol(u),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
