import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';

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

  @override
  void initState() {
    super.initState();
    _cargar();
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
      await _dbService.agregarCarro(nombreController.text, tipoController.text);
      await _refrescar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: AppColors.rojo,
        foregroundColor: Colors.white,
        title: const Text('Inventario de Carros'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.rojo,
        foregroundColor: Colors.white,
        onPressed: _agregarCarro,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Carro'),
      ),
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
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: carros.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final carro = carros[i];
                return Container(
                  decoration: _decoracionTarjeta(),
                  child: ListTile(
                    leading: const Icon(Icons.fire_truck, color: AppColors.rojo),
                    title: Text(carro['nombre'] ?? '', style: const TextStyle(color: AppColors.textoPrincipal, fontWeight: FontWeight.bold)),
                    subtitle: Text(carro['tipo'] ?? '', style: const TextStyle(color: AppColors.textoSecundario)),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textoSecundario),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CompartimentosScreen(carroId: carro['id'], nombreCarro: carro['nombre'] ?? '')),
                    ),
                  ),
                );
              },
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

class _CompartimentosScreenState extends State<CompartimentosScreen> {
  final _dbService = SupabaseService();
  late Future<List<Map<String, dynamic>>> _compartimentosFuture;

  @override
  void initState() {
    super.initState();
    _cargar();
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

  Future<void> _agregarItem(String compartimentoId) async {
    final nombreController = TextEditingController();
    final cantidadController = TextEditingController(text: '1');
    String estadoSeleccionado = 'BUENO';

    final crear = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Nuevo ítem', style: TextStyle(color: AppColors.textoPrincipal)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nombreController, decoration: _decoracionClara('Nombre del ítem')),
              const SizedBox(height: 10),
              TextField(controller: cantidadController, keyboardType: TextInputType.number, decoration: _decoracionClara('Cantidad')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: estadoSeleccionado,
                decoration: _decoracionClara('Estado'),
                items: _estados.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setDialogState(() => estadoSeleccionado = v ?? estadoSeleccionado),
              ),
            ],
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
      await _dbService.agregarItem(compartimentoId, nombreController.text, int.tryParse(cantidadController.text) ?? 1, estadoSeleccionado);
      await _refrescar();
    }
  }

  Future<void> _editarItem(Map<String, dynamic> item) async {
    final cantidadController = TextEditingController(text: '${item['cantidad'] ?? 1}');
    final observacionController = TextEditingController(text: item['observacion'] ?? '');
    String estadoSeleccionado = item['estado'] ?? 'BUENO';

    final guardar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text(item['nombre'] ?? '', style: const TextStyle(color: AppColors.textoPrincipal)),
          content: Column(
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

    if (guardar == true) {
      await _dbService.actualizarItem(
        item['id'],
        cantidad: int.tryParse(cantidadController.text),
        estado: estadoSeleccionado,
        observacion: observacionController.text,
      );
      await _refrescar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(backgroundColor: AppColors.rojo, foregroundColor: Colors.white, title: Text(widget.nombreCarro)),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.rojo,
        foregroundColor: Colors.white,
        onPressed: _agregarCompartimento,
        icon: const Icon(Icons.add),
        label: const Text('Compartimento'),
      ),
      body: RefreshIndicator(
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
                            subtitle: (item['observacion'] ?? '').toString().isNotEmpty
                                ? Text(item['observacion'], style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12))
                                : null,
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
                            onTap: () => _editarItem(item),
                          );
                        }),
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
    );
  }
}
