import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../utils/vida_util.dart';

const _categorias = ['ESTRUCTURAL', 'RESCATE', 'FORESTAL', 'ACCESORIOS', 'OTRO'];
const _estados = ['BUENO', 'REGULAR', 'MALO'];

bool _esOficial(dynamic rol) {
  final r = (rol ?? '').toString().toLowerCase().replaceAll('á', 'a');
  return r == 'administrador' || r == 'capitan' || r == 'directorio';
}

Color _colorEstado(String estado) {
  switch (estado) {
    case 'BUENO':
      return AppColors.verde;
    case 'REGULAR':
      return Colors.orange.shade700;
    case 'MALO':
      return AppColors.rojoAlerta;
    default:
      return Colors.grey;
  }
}

Widget _scaffoldMensaje(String titulo, String mensaje) => Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(backgroundColor: AppColors.rojo, foregroundColor: Colors.white, title: Text(titulo)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(mensaje, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textoSecundario)),
        ),
      ),
    );

/// Punto de entrada del módulo "Equipo del Personal" (trajes y cosas personales
/// de cada bombero, separado del inventario de los carros).
/// - Oficiales (administrador, capitán, directorio): ven la lista de la compañía
///   y pueden agregar/editar el equipo de cada persona.
/// - Bomberos: ven directamente su propio equipo (solo lectura).
class PersonalScreen extends StatefulWidget {
  const PersonalScreen({super.key});

  @override
  State<PersonalScreen> createState() => _PersonalScreenState();
}

class _PersonalScreenState extends State<PersonalScreen> {
  final _db = SupabaseService();
  late Future<Map<String, dynamic>?> _perfilFuture;

  @override
  void initState() {
    super.initState();
    _perfilFuture = _db.obtenerMiPerfil();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _perfilFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.fondo,
            appBar: AppBar(backgroundColor: AppColors.rojo, foregroundColor: Colors.white, title: const Text('Equipo del Personal')),
            body: const Center(child: CircularProgressIndicator(color: AppColors.rojo)),
          );
        }
        if (snap.hasError) {
          return _scaffoldMensaje('Equipo del Personal', 'No se pudo cargar tu perfil: ${snap.error}');
        }
        final perfil = snap.data;
        if (perfil == null) {
          return _scaffoldMensaje(
            'Equipo del Personal',
            'No encontramos tu perfil. Inicia sesión con una cuenta registrada (no con el modo de prueba).',
          );
        }
        if (_esOficial(perfil['rol'])) {
          return _ListaPersonal(perfil: perfil);
        }
        return EquipoBomberoScreen(
          usuarioId: perfil['id'] as String,
          nombre: (perfil['nombre'] ?? 'Mi equipo').toString(),
          puedeEditar: false,
        );
      },
    );
  }
}

class _Resumen {
  int total = 0;
  int vencidos = 0;
  int porVencer = 0;
}

/// Lista de las personas de la compañía (solo oficiales).
class _ListaPersonal extends StatefulWidget {
  final Map<String, dynamic> perfil;
  const _ListaPersonal({required this.perfil});

  @override
  State<_ListaPersonal> createState() => _ListaPersonalState();
}

class _ListaPersonalState extends State<_ListaPersonal> {
  final _db = SupabaseService();
  late Future<List<List<Map<String, dynamic>>>> _future;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _future = Future.wait([_db.obtenerPersonal(), _db.obtenerResumenEquipo()]);
  }

  Future<void> _refrescar() async {
    setState(_cargar);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(backgroundColor: AppColors.rojo, foregroundColor: Colors.white, title: const Text('Equipo del Personal')),
      body: RefreshIndicator(
        onRefresh: _refrescar,
        child: FutureBuilder<List<List<Map<String, dynamic>>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.rojo));
            }
            if (snap.hasError) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error: ${snap.error}', style: const TextStyle(color: AppColors.rojoAlerta)),
                ),
              ]);
            }
            final personas = snap.data![0];
            final equipos = snap.data![1];

            final resumen = <String, _Resumen>{};
            for (final e in equipos) {
              final id = e['usuario_id'] as String;
              final r = resumen.putIfAbsent(id, () => _Resumen());
              r.total++;
              final vida = calcularVidaUtil(e['fecha_compra'], e['vida_util_anios']);
              if (vida != null) {
                if (vida.vencido) {
                  r.vencidos++;
                } else if (vida.porVencer) {
                  r.porVencer++;
                }
              }
            }

            if (personas.isEmpty) {
              return ListView(children: const [
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Aún no hay personas registradas en tu compañía.', style: TextStyle(color: AppColors.textoSecundario)),
                ),
              ]);
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: personas.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final p = personas[i];
                final nombre = (p['nombre'] ?? 'Sin nombre').toString();
                final r = resumen[p['id']] ?? _Resumen();

                Widget? alerta;
                if (r.vencidos > 0) {
                  alerta = _chip('${r.vencidos} vencido${r.vencidos == 1 ? '' : 's'}', AppColors.rojoAlerta);
                } else if (r.porVencer > 0) {
                  alerta = _chip('${r.porVencer} por vencer', Colors.orange.shade700);
                }

                return Container(
                  decoration: decoracionTarjeta(),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.rojo,
                      child: Text(nombre.isNotEmpty ? nombre[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(nombre, style: const TextStyle(color: AppColors.textoPrincipal, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${(p['rol'] ?? 'bombero').toString()} · ${r.total} equipo${r.total == 1 ? '' : 's'}',
                      style: const TextStyle(color: AppColors.textoSecundario),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (alerta != null) alerta,
                        const Icon(Icons.chevron_right, color: AppColors.textoSecundario),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EquipoBomberoScreen(usuarioId: p['id'] as String, nombre: nombre, puedeEditar: true),
                        ),
                      );
                      if (mounted) _refrescar();
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _chip(String texto, Color color) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Text(texto, style: const TextStyle(color: Colors.white, fontSize: 11)),
      );
}

/// Trajes y cosas personales de UNA persona, agrupados por categoría, con la
/// cuenta regresiva de vida útil (10 años por defecto desde la compra).
class EquipoBomberoScreen extends StatefulWidget {
  final String usuarioId;
  final String nombre;
  final bool puedeEditar;

  const EquipoBomberoScreen({super.key, required this.usuarioId, required this.nombre, required this.puedeEditar});

  @override
  State<EquipoBomberoScreen> createState() => _EquipoBomberoScreenState();
}

class _EquipoBomberoScreenState extends State<EquipoBomberoScreen> {
  final _db = SupabaseService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _future = _db.obtenerEquipoPersonal(widget.usuarioId);
  }

  Future<void> _refrescar() async {
    setState(_cargar);
    await _future;
  }

  void _aviso(String texto) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _dialogoEquipo({Map<String, dynamic>? item}) async {
    final editando = item != null;
    final nombreCtrl = TextEditingController(text: (item?['nombre'] ?? '').toString());
    final detalleCtrl = TextEditingController(text: (item?['detalle'] ?? '').toString());
    final obsCtrl = TextEditingController(text: (item?['observacion'] ?? '').toString());
    DateTime? fecha = item?['fecha_compra'] == null ? null : DateTime.tryParse(item!['fecha_compra'].toString());
    final fechaCtrl = TextEditingController(text: fecha == null ? '' : fechaVisible(fecha));
    final vidaCtrl = TextEditingController(text: '${item?['vida_util_anios'] ?? 10}');
    String categoria = (item?['categoria'] ?? 'ESTRUCTURAL').toString();
    if (!_categorias.contains(categoria)) categoria = 'OTRO';
    String estado = (item?['estado'] ?? 'BUENO').toString();
    if (!_estados.contains(estado)) estado = 'BUENO';

    final accion = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text(editando ? 'Editar equipo' : 'Nuevo equipo', style: const TextStyle(color: AppColors.textoPrincipal)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: categoria,
                  decoration: decoracionCampo('Categoría'),
                  items: _categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setD(() => categoria = v ?? categoria),
                ),
                const SizedBox(height: 10),
                TextField(controller: nombreCtrl, decoration: decoracionCampo('Equipo (ej: Casaca normada, Traje encapsulado)')),
                const SizedBox(height: 10),
                TextField(controller: detalleCtrl, decoration: decoracionCampo('Talla / N° de serie (opcional)')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: estado,
                  decoration: decoracionCampo('Estado'),
                  items: _estados.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setD(() => estado = v ?? estado),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: fechaCtrl,
                  readOnly: true,
                  decoration: decoracionCampo('Fecha de compra', suffixIcon: const Icon(Icons.calendar_today, size: 18)),
                  onTap: () async {
                    final f = await showDatePicker(
                      context: context,
                      initialDate: fecha ?? DateTime.now(),
                      firstDate: DateTime(1990),
                      lastDate: DateTime.now(),
                    );
                    if (f != null) {
                      setD(() {
                        fecha = f;
                        fechaCtrl.text = fechaVisible(f);
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: vidaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: decoracionCampo('Vida útil (años)'),
                ),
                const SizedBox(height: 10),
                TextField(controller: obsCtrl, decoration: decoracionCampo('Observación (opcional)')),
              ],
            ),
          ),
          actions: [
            if (editando)
              TextButton(
                onPressed: () => Navigator.pop(context, 'eliminar'),
                child: const Text('Eliminar', style: TextStyle(color: AppColors.rojoAlerta)),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.rojo),
              onPressed: () => Navigator.pop(context, 'guardar'),
              child: Text(editando ? 'Guardar' : 'Agregar'),
            ),
          ],
        ),
      ),
    );

    if (accion == null) return;

    try {
      if (accion == 'eliminar') {
        final seguro = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('¿Eliminar este equipo?', style: TextStyle(color: AppColors.textoPrincipal)),
            content: Text(nombreCtrl.text, style: const TextStyle(color: AppColors.textoSecundario)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.rojoAlerta),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        );
        if (seguro != true) return;
        await _db.eliminarEquipoPersonal(item!['id'] as String);
      } else {
        if (nombreCtrl.text.trim().isEmpty) {
          _aviso('Escribe el nombre del equipo');
          return;
        }
        final vida = (int.tryParse(vidaCtrl.text) ?? 10).clamp(1, 50).toInt();
        final detalle = detalleCtrl.text.trim().isEmpty ? null : detalleCtrl.text.trim();
        final obs = obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim();
        final fechaTxt = fecha == null ? null : fechaIso(fecha!);

        if (editando) {
          await _db.actualizarEquipoPersonal(
            item!['id'] as String,
            categoria: categoria,
            nombre: nombreCtrl.text.trim(),
            detalle: detalle,
            estado: estado,
            fechaCompra: fechaTxt,
            vidaUtilAnios: vida,
            observacion: obs,
          );
        } else {
          await _db.agregarEquipoPersonal(
            usuarioId: widget.usuarioId,
            categoria: categoria,
            nombre: nombreCtrl.text.trim(),
            detalle: detalle,
            estado: estado,
            fechaCompra: fechaTxt,
            vidaUtilAnios: vida,
            observacion: obs,
          );
        }
      }
      await _refrescar();
    } catch (e) {
      _aviso('No se pudo guardar: $e');
    }
  }

  Widget? _subtitulo(Map<String, dynamic> item) {
    final detalle = (item['detalle'] ?? '').toString();
    final obs = (item['observacion'] ?? '').toString();
    final vida = calcularVidaUtil(item['fecha_compra'], item['vida_util_anios']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (detalle.isNotEmpty) Text(detalle, style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
        if (obs.isNotEmpty) Text(obs, style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
        if (vida != null) ...[
          const SizedBox(height: 4),
          Text(vida.texto, style: TextStyle(color: vida.color, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: vida.usado, minHeight: 5, backgroundColor: Colors.black12, color: vida.color),
          ),
        ] else
          const Text('Sin fecha de compra registrada', style: TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: AppColors.rojo,
        foregroundColor: Colors.white,
        title: Text(widget.puedeEditar ? widget.nombre : 'Mi equipo'),
      ),
      floatingActionButton: widget.puedeEditar
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.rojo,
              foregroundColor: Colors.white,
              onPressed: () => _dialogoEquipo(),
              icon: const Icon(Icons.add),
              label: const Text('Agregar equipo'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refrescar,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.rojo));
            }
            if (snap.hasError) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error: ${snap.error}', style: const TextStyle(color: AppColors.rojoAlerta)),
                ),
              ]);
            }
            final items = snap.data ?? [];
            if (items.isEmpty) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    widget.puedeEditar
                        ? '${widget.nombre} aún no tiene equipo registrado. Usa "Agregar equipo".'
                        : 'Aún no tienes equipo registrado. Un oficial puede cargarlo.',
                    style: const TextStyle(color: AppColors.textoSecundario),
                  ),
                ),
              ]);
            }

            var vencidos = 0;
            var porVencer = 0;
            final porCategoria = <String, List<Map<String, dynamic>>>{};
            for (final i in items) {
              final c = (i['categoria'] ?? 'OTRO').toString();
              porCategoria.putIfAbsent(c, () => []).add(i);
              final v = calcularVidaUtil(i['fecha_compra'], i['vida_util_anios']);
              if (v != null) {
                if (v.vencido) {
                  vencidos++;
                } else if (v.porVencer) {
                  porVencer++;
                }
              }
            }
            final orden = [
              ..._categorias.where(porCategoria.containsKey),
              ...porCategoria.keys.where((k) => !_categorias.contains(k)),
            ];

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: decoracionTarjeta(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _dato('Equipos', '${items.length}', AppColors.textoPrincipal),
                      _dato('Por vencer', '$porVencer', Colors.orange.shade700),
                      _dato('Vencidos', '$vencidos', AppColors.rojoAlerta),
                    ],
                  ),
                ),
                ...orden.map((cat) {
                  final lista = porCategoria[cat]!;
                  return Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: decoracionTarjeta(),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        title: Text(cat, style: const TextStyle(color: AppColors.textoPrincipal, fontWeight: FontWeight.bold)),
                        subtitle: Text('${lista.length} equipo${lista.length == 1 ? '' : 's'}',
                            style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
                        iconColor: AppColors.rojo,
                        collapsedIconColor: AppColors.textoSecundario,
                        children: lista.map((item) {
                          final estado = (item['estado'] ?? 'BUENO').toString();
                          return ListTile(
                            dense: true,
                            title: Text((item['nombre'] ?? '').toString(), style: const TextStyle(color: AppColors.textoPrincipal)),
                            subtitle: _subtitulo(item),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: _colorEstado(estado), borderRadius: BorderRadius.circular(4)),
                              child: Text(estado, style: const TextStyle(color: Colors.white, fontSize: 11)),
                            ),
                            onTap: widget.puedeEditar ? () => _dialogoEquipo(item: item) : null,
                          );
                        }).toList(),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 80),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dato(String etiqueta, String valor, Color color) => Column(
        children: [
          Text(valor, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(etiqueta, style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
        ],
      );
}
