import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

/// Roles que maneja el sistema y lo que permite cada uno.
const rolesDisponibles = ['administrador', 'directorio', 'capitan', 'tesorero', 'bombero'];

const _descripcionRol = {
  'administrador': 'Gestiona usuarios y roles, y tiene acceso a todos los módulos.',
  'directorio': 'Registra actas y supervisa tesorería y el equipo del personal.',
  'capitan': 'Gestiona el equipo personal y los registros de su compañía.',
  'tesorero': 'Registra ingresos, egresos y rendiciones de tesorería.',
  'bombero': 'Consulta grifos, inventario y su propio equipo personal.',
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

  Map<String, dynamic>? _perfil;
  List<Map<String, dynamic>> _usuarios = [];
  bool _cargando = true;
  String? _error;
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final perfil = await _db.obtenerMiPerfil();
      final usuarios = await _db.obtenerUsuariosAdmin();
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

  bool get _soyAdmin => ((_perfil?['rol'] ?? '').toString().toLowerCase() == 'administrador');

  void _aviso(String texto) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _cambiarRol(Map<String, dynamic> usuario) async {
    final rolActual = (usuario['rol'] ?? 'bombero').toString().toLowerCase().replaceAll('á', 'a');
    String seleccionado = rolesDisponibles.contains(rolActual) ? rolActual : 'bombero';

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
    final visibles = _usuarios.where((u) {
      if (_filtro.isEmpty) return true;
      final texto = '${u['nombre'] ?? ''} ${u['credencial'] ?? ''}'.toLowerCase();
      return texto.contains(_filtro);
    }).toList();

    final conteo = <String, int>{};
    for (final u in _usuarios) {
      final r = (u['rol'] ?? 'bombero').toString().toLowerCase().replaceAll('á', 'a');
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
            decoration: decoracionCampo('Buscar por nombre o correo', prefixIcon: const Icon(Icons.search)),
            onChanged: (v) => setState(() => _filtro = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 10),
          if (visibles.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No hay personas que coincidan.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textoSecundario)),
            ),
          ...visibles.map((u) {
            final esYo = u['id'] == miId;
            final rol = (u['rol'] ?? 'bombero').toString();
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
                subtitle: Text((u['credencial'] ?? '').toString(), style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
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
