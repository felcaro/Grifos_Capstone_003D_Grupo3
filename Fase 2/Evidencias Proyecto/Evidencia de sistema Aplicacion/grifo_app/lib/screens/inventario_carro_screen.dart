import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../utils/permisos.dart';
import '../utils/mantencion_util.dart';
import 'mantencion_carro_panel.dart';

const _estados = ['BUENO', 'REGULAR', 'MALO'];

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

InputDecoration _decoracionClara(String label) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textoSecundario),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bordeCampo)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.bordeCampo)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.rojo)),
    );

BoxDecoration _decoracionTarjeta() => BoxDecoration(
      color: AppColors.tarjeta,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
    );


// ---------- Vida útil (ej: trajes de bombero, 10 años desde la compra) ----------

String _plural(int n, String singular, String plural) => '$n ${n == 1 ? singular : plural}';

String _fechaIso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _fechaVisible(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class _VidaUtil {
  final String texto;
  final Color color;
  final double usado; // 0.0 (nuevo) a 1.0 (vencido)
  _VidaUtil(this.texto, this.color, this.usado);
}

/// Calcula cuánto le queda de vida útil a un ítem desde su fecha de compra.
/// Devuelve null si el ítem no tiene fecha de compra registrada.
_VidaUtil? _calcularVidaUtil(dynamic fechaCompraRaw, dynamic aniosRaw) {
  if (fechaCompraRaw == null) return null;
  final compra = DateTime.tryParse(fechaCompraRaw.toString());
  if (compra == null) return null;
  final anios = aniosRaw is int ? aniosRaw : (int.tryParse('${aniosRaw ?? 10}') ?? 10);

  final hoy = DateTime.now();
  final vence = DateTime(compra.year + anios, compra.month, compra.day);
  final totalDias = vence.difference(compra).inDays;
  final usadoDias = hoy.difference(compra).inDays;
  final usado = totalDias <= 0 ? 1.0 : (usadoDias / totalDias).clamp(0.0, 1.0).toDouble();

  if (!vence.isAfter(hoy)) {
    final diasVencido = hoy.difference(vence).inDays;
    return _VidaUtil('Vida útil vencida hace ${_plural(diasVencido, 'día', 'días')}', AppColors.rojoAlerta, 1.0);
  }

  var meses = (vence.year - hoy.year) * 12 + (vence.month - hoy.month);
  if (vence.day < hoy.day) meses -= 1;
  final diasRestantes = vence.difference(hoy).inDays;
  final a = meses ~/ 12;
  final m = meses % 12;

  String texto;
  if (a > 0) {
    texto = m > 0 ? '${_plural(a, 'año', 'años')} y ${_plural(m, 'mes', 'meses')}' : _plural(a, 'año', 'años');
  } else if (m > 0) {
    texto = _plural(m, 'mes', 'meses');
  } else {
    texto = _plural(diasRestantes, 'día', 'días');
  }

  // Verde: más de 2 años · Naranja: entre 1 y 2 años · Rojo: menos de 1 año
  final color = diasRestantes > 730
      ? AppColors.verde
      : (diasRestantes > 365 ? Colors.orange.shade700 : AppColors.rojoAlerta);
  return _VidaUtil('Le quedan $texto de vida útil', color, usado);
}

/// Subtítulo de cada ítem: observación + cuenta regresiva de vida útil con barra.
Widget? _subtituloItem(Map<String, dynamic> item) {
  final obs = (item['observacion'] ?? '').toString();
  final vida = _calcularVidaUtil(item['fecha_compra'], item['vida_util_anios']);
  if (obs.isEmpty && vida == null) return null;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (obs.isNotEmpty) Text(obs, style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
      if (vida != null) ...[
        const SizedBox(height: 4),
        Text(vida.texto, style: TextStyle(color: vida.color, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: vida.usado, minHeight: 5, backgroundColor: Colors.black12, color: vida.color),
        ),
      ],
    ],
  );
}

/// Lista de carros (unidades) de la compañía. Al tocar uno, se abre
/// su inventario por compartimento (igual a las planillas RH-1 / BF-1).
class InventarioCarrosScreen extends StatefulWidget {
  const InventarioCarrosScreen({super.key});

  @override
  State<InventarioCarrosScreen> createState() => _InventarioCarrosScreenState();
}

class _InventarioCarrosScreenState extends State<InventarioCarrosScreen> {
  final _dbService = SupabaseService();
  late Future<List<Map<String, dynamic>>> _carrosFuture;
  bool _puedeEditar = false; // solo se activa si el rol lo permite

  @override
  void initState() {
    super.initState();
    _cargar();
    Permisos.cargar().then((p) {
      if (mounted) setState(() => _puedeEditar = p.editarCarros);
    });
  }

  void _cargar() {
    _carrosFuture = _dbService.obtenerCarros();
  }

  Future<void> _refrescar() async {
    setState(_cargar);
    await _carrosFuture;
  }

  Future<void> _agregarCarro() async {
    final nombreController = TextEditingController();
    final tipoController = TextEditingController();

    final crear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Nuevo carro', style: TextStyle(color: AppColors.textoPrincipal)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombreController, decoration: _decoracionClara('Nombre (ej: RH-1)')),
            const SizedBox(height: 10),
            TextField(controller: tipoController, decoration: _decoracionClara('Tipo (ej: Rescate Técnico Pesado)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rojo),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (crear == true && nombreController.text.isNotEmpty) {
      try {
        await _dbService.agregarCarro(nombreController.text, tipoController.text);
        await _refrescar();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo crear el carro: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: AppColors.rojo,
        foregroundColor: Colors.white,
        title: const Text('Carros'),
      ),
      floatingActionButton: _puedeEditar
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.rojo,
              foregroundColor: Colors.white,
              onPressed: _agregarCarro,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo Carro'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refrescar,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _carrosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.rojo));
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.textoPrincipal)));
            }
            final carros = snapshot.data ?? [];
            if (carros.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Aún no hay carros registrados.', style: TextStyle(color: AppColors.textoSecundario)),
                  ),
                ],
              );
            }
            final conAlertas = carros.where((c) => alertasActivas(c).isNotEmpty).length;
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (conAlertas > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$conAlertas carro${conAlertas == 1 ? '' : 's'} con revisión técnica o mantención por atender',
                            style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ...carros.map((carro) {
                  final alertas = alertasActivas(carro);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: _decoracionTarjeta(),
                    child: ListTile(
                      leading: Icon(Icons.fire_truck, color: tieneVencidas(alertas) ? AppColors.rojoAlerta : AppColors.rojo),
                      title: Text(carro['nombre'] ?? '', style: const TextStyle(color: AppColors.textoPrincipal, fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(carro['tipo'] ?? '', style: const TextStyle(color: AppColors.textoSecundario)),
                          if (alertas.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Wrap(spacing: 6, runSpacing: 4, children: alertas.map(chipAlerta).toList()),
                            ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.textoSecundario),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CompartimentosScreen(carroId: carro['id'], nombreCarro: carro['nombre'] ?? '')),
                        );
                        if (mounted) _refrescar();
                      },
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
}

/// Inventario de un carro específico: un bloque expandible por
/// compartimento (ej: "GABINETA N°1", "TECHO", "CABINA"), con sus ítems.
class CompartimentosScreen extends StatefulWidget {
  final String carroId;
  final String nombreCarro;
  const CompartimentosScreen({super.key, required this.carroId, required this.nombreCarro});

  @override
  State<CompartimentosScreen> createState() => _CompartimentosScreenState();
}

class _CompartimentosScreenState extends State<CompartimentosScreen> with SingleTickerProviderStateMixin {
  final _dbService = SupabaseService();
  late Future<List<Map<String, dynamic>>> _compartimentosFuture;
  late final TabController _tabs;
  bool _puedeEditar = false; // solo se activa si el rol lo permite

  @override
  void initState() {
    super.initState();
    Permisos.cargar().then((p) {
      if (mounted) setState(() => _puedeEditar = p.editarCarros);
    });
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (mounted) setState(() {}); // para mostrar u ocultar el botón flotante
    });
    _cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _cargar() {
    _compartimentosFuture = _dbService.obtenerCompartimentosConItems(widget.carroId);
  }

  Future<void> _refrescar() async {
    setState(_cargar);
    await _compartimentosFuture;
  }

  Future<void> _agregarCompartimento() async {
    final nombreController = TextEditingController();
    final crear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Nuevo compartimento', style: TextStyle(color: AppColors.textoPrincipal)),
        content: TextField(controller: nombreController, decoration: _decoracionClara('Nombre (ej: GABINETA N°1, TECHO, CABINA)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rojo),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (crear == true && nombreController.text.isNotEmpty) {
      await _dbService.agregarCompartimento(widget.carroId, nombreController.text, 0);
      await _refrescar();
    }
  }

  /// Campos de "fecha de compra" y "vida útil" compartidos por los diálogos de agregar y editar.
  List<Widget> _camposVidaUtil({
    required BuildContext dialogContext,
    required TextEditingController fechaController,
    required TextEditingController vidaUtilController,
    required void Function(DateTime) alElegirFecha,
  }) {
    return [
      const SizedBox(height: 10),
      TextField(
        controller: fechaController,
        readOnly: true,
        decoration: _decoracionClara('Fecha de compra (opcional)').copyWith(suffixIcon: const Icon(Icons.calendar_today, size: 18)),
        onTap: () async {
          final f = await showDatePicker(
            context: dialogContext,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
          );
          if (f != null) alElegirFecha(f);
        },
      ),
      const SizedBox(height: 10),
      TextField(
        controller: vidaUtilController,
        keyboardType: TextInputType.number,
        decoration: _decoracionClara('Vida útil (años)'),
      ),
    ];
  }

  Future<void> _agregarItem(String compartimentoId) async {
    final nombreController = TextEditingController();
    final cantidadController = TextEditingController(text: '1');
    final fechaController = TextEditingController();
    final vidaUtilController = TextEditingController(text: '10');
    DateTime? fechaCompra;
    String estadoSeleccionado = 'BUENO';

    final crear = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Nuevo ítem', style: TextStyle(color: AppColors.textoPrincipal)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nombreController, decoration: _decoracionClara('Nombre del ítem (ej: Traje encapsulado)')),
                const SizedBox(height: 10),
                TextField(controller: cantidadController, keyboardType: TextInputType.number, decoration: _decoracionClara('Cantidad')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: estadoSeleccionado,
                  decoration: _decoracionClara('Estado'),
                  items: _estados.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setDialogState(() => estadoSeleccionado = v ?? estadoSeleccionado),
                ),
                ..._camposVidaUtil(
                  dialogContext: context,
                  fechaController: fechaController,
                  vidaUtilController: vidaUtilController,
                  alElegirFecha: (f) => setDialogState(() {
                    fechaCompra = f;
                    fechaController.text = _fechaVisible(f);
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.rojo),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );

    if (crear == true && nombreController.text.isNotEmpty) {
      try {
        await _dbService.agregarItem(
          compartimentoId,
          nombreController.text,
          int.tryParse(cantidadController.text) ?? 1,
          estadoSeleccionado,
          fechaCompra: fechaCompra == null ? null : _fechaIso(fechaCompra!),
          vidaUtilAnios: int.tryParse(vidaUtilController.text) ?? 10,
        );
        await _refrescar();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo agregar: $e')));
      }
    }
  }

  Future<void> _editarItem(Map<String, dynamic> item) async {
    final cantidadController = TextEditingController(text: '${item['cantidad'] ?? 1}');
    final observacionController = TextEditingController(text: item['observacion'] ?? '');
    DateTime? fechaCompra = item['fecha_compra'] == null ? null : DateTime.tryParse(item['fecha_compra'].toString());
    final fechaController = TextEditingController(text: fechaCompra == null ? '' : _fechaVisible(fechaCompra));
    final vidaUtilController = TextEditingController(text: '${item['vida_util_anios'] ?? 10}');
    String estadoSeleccionado = item['estado'] ?? 'BUENO';

    final guardar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text(item['nombre'] ?? '', style: const TextStyle(color: AppColors.textoPrincipal)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: cantidadController, keyboardType: TextInputType.number, decoration: _decoracionClara('Cantidad')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: estadoSeleccionado,
                  decoration: _decoracionClara('Estado'),
                  items: _estados.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setDialogState(() => estadoSeleccionado = v ?? estadoSeleccionado),
                ),
                const SizedBox(height: 10),
                TextField(controller: observacionController, decoration: _decoracionClara('Observación')),
                ..._camposVidaUtil(
                  dialogContext: context,
                  fechaController: fechaController,
                  vidaUtilController: vidaUtilController,
                  alElegirFecha: (f) => setDialogState(() {
                    fechaCompra = f;
                    fechaController.text = _fechaVisible(f);
                  }),
                ),
              ],
            ),
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

    if (guardar == true) {
      try {
        await _dbService.actualizarItem(
          item['id'],
          cantidad: int.tryParse(cantidadController.text),
          estado: estadoSeleccionado,
          observacion: observacionController.text,
          fechaCompra: fechaCompra == null ? null : _fechaIso(fechaCompra!),
          vidaUtilAnios: int.tryParse(vidaUtilController.text),
        );
        await _refrescar();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: AppColors.rojo,
        foregroundColor: Colors.white,
        title: Text(widget.nombreCarro),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Inventario'),
            Tab(icon: Icon(Icons.build_outlined), text: 'Mantención y vencimientos'),
          ],
        ),
      ),
      floatingActionButton: (_tabs.index == 0 && _puedeEditar)
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.rojo,
              foregroundColor: Colors.white,
              onPressed: _agregarCompartimento,
              icon: const Icon(Icons.add),
              label: const Text('Compartimento'),
            )
          : null,
      body: TabBarView(
        controller: _tabs,
        children: [
          RefreshIndicator(
        onRefresh: _refrescar,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _compartimentosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.rojo));
            }
            final compartimentos = snapshot.data ?? [];
            if (compartimentos.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Este carro aún no tiene compartimentos cargados.', style: TextStyle(color: AppColors.textoSecundario)),
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(12),
              children: compartimentos.map((c) {
                final items = List<Map<String, dynamic>>.from(c['item_inventario'] ?? []);
                return Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: _decoracionTarjeta(),
                    child: ExpansionTile(
                      title: Text(c['nombre'] ?? '', style: const TextStyle(color: AppColors.textoPrincipal, fontWeight: FontWeight.bold)),
                      subtitle: Text('${items.length} ítems', style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
                      iconColor: AppColors.rojo,
                      collapsedIconColor: AppColors.textoSecundario,
                      children: [
                        ...items.map((item) {
                          final estado = item['estado'] ?? 'BUENO';
                          return ListTile(
                            dense: true,
                            title: Text(item['nombre'] ?? '', style: const TextStyle(color: AppColors.textoPrincipal)),
                            subtitle: _subtituloItem(item),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('x${item['cantidad'] ?? 1}', style: const TextStyle(color: AppColors.textoPrincipal)),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: _colorEstado(estado), borderRadius: BorderRadius.circular(4)),
                                  child: Text(estado, style: const TextStyle(color: Colors.white, fontSize: 11)),
                                ),
                              ],
                            ),
                            onTap: _puedeEditar ? () => _editarItem(item) : null,
                          );
                        }),
                        if (_puedeEditar)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 8),
                            child: TextButton.icon(
                              onPressed: () => _agregarItem(c['id']),
                              icon: const Icon(Icons.add, color: AppColors.rojo, size: 18),
                              label: const Text('Agregar ítem', style: TextStyle(color: AppColors.rojo)),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
          MantencionCarroPanel(carroId: widget.carroId, nombreCarro: widget.nombreCarro, puedeEditar: _puedeEditar),
        ],
      ),
    );
  }
}
