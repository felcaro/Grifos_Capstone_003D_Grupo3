import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/movimiento_tesoreria.dart';
import '../services/supabase_service.dart';
import '../models/campana_economica.dart';

class TesoreriaScreen extends StatefulWidget {
  const TesoreriaScreen({super.key});

  @override
  State<TesoreriaScreen> createState() => _TesoreriaScreenState();
}

class _TesoreriaScreenState extends State<TesoreriaScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _db = SupabaseService();
  final ScrollController _scrollController = ScrollController();
  List<MovimientoTesoreria> _movimientos = [];
  bool _cargando = true;
  bool _cargandoMas = false;
  bool _hayMasDatos = true;

  static const int _limitePorPagina = 15;
  int _offsetActual = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _cargarPrimeraPagina();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Dispara la carga adicional cuando el usuario está cerca del final de la lista
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_cargandoMas &&
        _hayMasDatos) {
      _cargarMasMovimientos();
    }
  }
  Future<void> _cargarPrimeraPagina() async {
    setState(() {
      _isLoading = true;
      _offsetActual = 0;
      _hayMasDatos = true;
    });

    try {
      final nuevos = await _db.obtenerMovimientosTesoreriaPaginados(
        offset: 0,
        limite: _limitePorPagina,
      );
      final campanas = await _db.obtenerCampanasEconomicas();

      if (!mounted) return;
      setState(() {
        _movimientos = nuevos;
        _campanas = campanas;
        _offsetActual = nuevos.length;
        if (nuevos.length < _limitePorPagina) {
          _hayMasDatos = false;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar movimientos: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarMasMovimientos() async {
    setState(() => _cargandoMas = true);

    try {
      final nuevos = await _db.obtenerMovimientosTesoreriaPaginados(
        offset: _offsetActual,
        limite: _limitePorPagina,
      );

      if (!mounted) return;
      setState(() {
        _movimientos.addAll(nuevos);
        _offsetActual += nuevos.length;
        if (nuevos.length < _limitePorPagina) {
          _hayMasDatos = false;
        }
      });
    } catch (e) {
      print('Error al cargar más filas: $e');
    } finally {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  String _busquedaQuery = '';
  String _filtroTipo = 'todos'; 
  String? _filtroCampanaId; // null = Incluye todas las campañas y movimientos generales

  bool _isLoading = true;
  List<CampanaEconomica> _campanas = [];

  double _totalIngresos = 0;
  double _totalEgresos = 0;
  double get _saldoTotal => _totalIngresos - _totalEgresos;

  List<MovimientoTesoreria> get _movimientosFiltrados {
  return _movimientos.where((m) {
    // 1. Filtro por Tipo (Ingreso / Egreso / Todos)
    if (_filtroTipo != 'todos' && m.tipo.toLowerCase() != _filtroTipo) {
      return false;
    }

    // 2. Filtro por Campaña Económica
    if (_filtroCampanaId != null && m.campanaId != _filtroCampanaId) {
      return false;
    }

    // 3. Filtro por texto en la Descripción
    if (_busquedaQuery.isNotEmpty) {
      final query = _busquedaQuery.toLowerCase();
      if (!m.descripcion.toLowerCase().contains(query)) {
        return false;
      }
    }

    return true;
  }).toList();
}

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final movimientos = await _supabaseService.obtenerMovimientosTesoreria();
      final campanas = await _supabaseService.obtenerCampanasEconomicas();

      double ingresos = 0;
      double egresos = 0;

      for (var m in movimientos) {
        if (m.tipo.toLowerCase() == 'ingreso') {
          ingresos += m.monto;
        } else {
          egresos += m.monto;
        }
      }

      setState(() {
        _movimientos = movimientos;
        _campanas = campanas;
        _totalIngresos = ingresos;
        _totalEgresos = egresos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar tesorería: $e')),
        );
      }
    }
  }

  Widget _buildBarraBusquedaYFiltros() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
    child: Column(
      children: [
        // 1. Campo de texto para la búsqueda
        TextField(
          decoration: InputDecoration(
            hintText: 'Buscar por descripción...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _busquedaQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _busquedaQuery = ''),
                  )
                : null,
            filled: true,
            fillColor: Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (val) => setState(() => _busquedaQuery = val),
        ),
        const SizedBox(height: 10),

        // 2. Chips de selección por Tipo (Ingreso / Egreso / Todos)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('Todos'),
                selected: _filtroTipo == 'todos',
                onSelected: (_) => setState(() => _filtroTipo = 'todos'),
                selectedColor: Colors.red.shade100,
                checkmarkColor: Colors.red.shade800,
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Solo Ingresos'),
                avatar: const Icon(Icons.arrow_downward, color: Colors.green, size: 16),
                selected: _filtroTipo == 'ingreso',
                onSelected: (selected) => setState(() => _filtroTipo = selected ? 'ingreso' : 'todos'),
                selectedColor: Colors.green.shade100,
                checkmarkColor: Colors.green.shade800,
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Solo Egresos'),
                avatar: const Icon(Icons.arrow_upward, color: Colors.red, size: 16),
                selected: _filtroTipo == 'egreso',
                onSelected: (selected) => setState(() => _filtroTipo = selected ? 'egreso' : 'todos'),
                selectedColor: Colors.red.shade100,
                checkmarkColor: Colors.red.shade800,
              ),
            ],
          ),
        ),

        // 3. Desplegable opcional por Campaña Económica
        if (_campanas.isNotEmpty) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            value: _filtroCampanaId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Filtrar por Campaña Económica',
              prefixIcon: const Icon(Icons.campaign),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todas las campañas / General'),
              ),
              ..._campanas.map((c) => DropdownMenuItem<String?>(
                    value: c.id,
                    child: Text(c.nombre, overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: (val) => setState(() => _filtroCampanaId = val),
          ),
        ],
      ],
    ),
  );
}

  void _abrirModalEdicion(MovimientoTesoreria m) {
    final montoCtrl = TextEditingController(text: m.monto.toStringAsFixed(0));
    final descCtrl = TextEditingController(text: m.descripcion);
    String tipoSel = m.tipo;
    String? campanaSelId = m.campanaId;
    String? boletaUrlActual = m.boletaUrl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Editar Movimiento',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'ingreso', label: Text('Ingreso')),
                        ButtonSegment(value: 'egreso', label: Text('Egreso')),
                      ],
                      selected: {tipoSel},
                      onSelectionChanged: (newSel) {
                        setModalState(() => tipoSel = newSel.first);
                      },
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: montoCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monto (\$)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Descripción / Motivo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String?>(
                      initialValue: campanaSelId,
                      decoration: const InputDecoration(
                        labelText: 'Campaña Económica (Opcional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Ninguna / Movimiento General'),
                        ),
                        ..._campanas.map((c) => DropdownMenuItem<String?>(
                              value: c.id,
                              child: Text(c.nombre),
                            )),
                      ],
                      onChanged: (val) => setModalState(() => campanaSelId = val),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade800,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        final montoText = montoCtrl.text.trim();
                        final desc = descCtrl.text.trim();

                        if (montoText.isEmpty || desc.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Completa todos los campos requeridos')),
                          );
                          return;
                        }

                        final monto = double.tryParse(montoText);
                        if (monto == null || monto <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ingresa un monto válido')),
                          );
                          return;
                        }

                        Navigator.pop(ctx);
                        try {
                          await _supabaseService.actualizarMovimientoTesoreria(
                            id: m.id,
                            tipo: tipoSel,
                            monto: monto,
                            descripcion: desc,
                            campanaId: campanaSelId,
                            boletaUrl: boletaUrlActual,
                          );
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Movimiento actualizado')),
                            );
                            _cargarDatos();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al actualizar: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('Guardar Cambios', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmarEliminacion(MovimientoTesoreria m) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar movimiento?'),
        content: Text(
          'Se eliminará de forma permanente el registro "${m.descripcion}" por \$${m.monto.toStringAsFixed(0)} y su comprobante adjunto si existe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _supabaseService.eliminarMovimientoTesoreria(
                  id: m.id,
                  boletaUrl: m.boletaUrl,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Registro eliminado correctamente')),
                  );
                  _cargarDatos();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al eliminar: $e')),
                  );
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _mostrarComprobanteDialog(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Comprobante / Boleta', style: TextStyle(fontSize: 16)),
              backgroundColor: Colors.red.shade800,
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                )
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('No se pudo cargar la imagen del comprobante.'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirModalRegistro() {
    final montoController = TextEditingController();
    final descripcionController = TextEditingController();
    String tipoSeleccionado = 'ingreso';
    Uint8List? imagenBytes;
    String extensionImagen = 'jpg';
    String? campanaSeleccionadaId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) { 
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> seleccionarImagen(ImageSource origen) async {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(
                source: origen,
                imageQuality: 70,
              );

              if (pickedFile != null) {
                final bytes = await pickedFile.readAsBytes();
                final ext = pickedFile.name.split('.').last;
                setModalState(() {
                  imagenBytes = bytes;
                  extensionImagen = ext.isNotEmpty ? ext : 'jpg';
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Registrar Movimiento',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Ingreso')),
                            selected: tipoSeleccionado == 'ingreso',
                            selectedColor: Colors.green.shade100,
                            onSelected: (val) {
                              if (val) setModalState(() => tipoSeleccionado = 'ingreso');
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Egreso / Gasto')),
                            selected: tipoSeleccionado == 'egreso',
                            selectedColor: Colors.red.shade100,
                            onSelected: (val) {
                              if (val) setModalState(() => tipoSeleccionado = 'egreso');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: montoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Monto (\$)',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descripcionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción / Motivo *',
                        hintText: 'Ej: Compra repuesto Carro B-1',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: campanaSeleccionadaId,
                      decoration: const InputDecoration(
                        labelText: 'Campaña Económica (Opcional)',
                        prefixIcon: Icon(Icons.campaign),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Ninguna / Movimiento General'),
                        ),
                        ..._campanas.map((c) {
                          return DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(c.nombre),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setModalState(() {
                          campanaSeleccionadaId = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => seleccionarImagen(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Cámara'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () => seleccionarImagen(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Galería'),
                        ),
                      ],
                    ),
                    if (imagenBytes != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              imagenBytes!,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Comprobante adjuntado',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => setModalState(() => imagenBytes = null),
                          )
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade800,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          final montoText = montoController.text.trim();
                          final descripcion = descripcionController.text.trim();

                          if (montoText.isEmpty || descripcion.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Ingresa el monto y la descripción')),
                            );
                            return;
                          }

                          final monto = double.tryParse(montoText);
                          if (monto == null || monto <= 0) return;

                          Navigator.pop(ctx);
                          setState(() => _isLoading = true);

                          try {
                            String? boletaUrl;

                            if (imagenBytes != null) {
                              boletaUrl = await _supabaseService.subirComprobanteBoleta(
                                imagenBytes!,
                                extensionImagen,
                              );
                            }

                            await _supabaseService.registrarMovimientoTesoreria(
                              tipo: tipoSeleccionado,
                              monto: monto,
                              descripcion: descripcion,
                              campanaId: campanaSeleccionadaId,
                              boletaUrl: boletaUrl,
                            );

                            _cargarDatos();
                          } catch (e) {
                            setState(() => _isLoading = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error al guardar registro: $e')),
                              );
                            }
                          }
                        },
                        child: const Text('Guardar Registro',
                            style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Saldo Disponible',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 5),
            Text(
              '\$${_saldoTotal.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _saldoTotal >= 0 ? Colors.green.shade800 : Colors.red.shade800,
              ),
            ),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Row(
                  children: [
                    const Icon(Icons.arrow_circle_down, color: Colors.green),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ingresos', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('\$${_totalIngresos.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    )
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.arrow_circle_up, color: Colors.red),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Egresos', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('\$${_totalEgresos.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      ],
                    )
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _movimientosFiltrados;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Tesorería'),
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarPrimeraPagina,
            tooltip: 'Actualizar',
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirModalRegistro,
        backgroundColor: Colors.red.shade800,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nuevo Movimiento', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildBalanceCard(),
                ),
                _buildBarraBusquedaYFiltros(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _cargarPrimeraPagina,
                    child: _movimientosFiltrados.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 60),
                              Center(
                                child: Text(
                                  _busquedaQuery.isNotEmpty || _filtroTipo != 'todos'
                                      ? 'No se encontraron resultados con los filtros aplicados'
                                      : 'No hay movimientos registrados',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            controller: _scrollController,
                            itemCount: filtrados.length + (_cargandoMas ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == filtrados.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16.0),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              final m = _movimientosFiltrados[index];

                              final esIngreso = m.tipo.toLowerCase() == 'ingreso';

                              String? nombreCampana;
                              if (m.campanaId != null && m.campanaId!.isNotEmpty) {
                                final campanaEncontrada = _campanas.firstWhere(
                                  (c) => c.id == m.campanaId,
                                  orElse: () => CampanaEconomica(id: '', companiaId: '', nombre: 'Campaña'),
                                );
                                if (campanaEncontrada.id.isNotEmpty) {
                                  nombreCampana = campanaEncontrada.nombre;
                                }
                              }

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  onTap: () {
                                    if (m.boletaUrl != null && m.boletaUrl!.isNotEmpty) {
                                      _mostrarComprobanteDialog(m.boletaUrl!);
                                    }
                                  },
                                  leading: CircleAvatar(
                                    backgroundColor: esIngreso
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                    child: Icon(
                                      esIngreso ? Icons.arrow_downward : Icons.arrow_upward,
                                      color: esIngreso ? Colors.green : Colors.red,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          m.descripcion,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (m.boletaUrl != null && m.boletaUrl!.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Tooltip(
                                          message: 'Tiene comprobante adjunto',
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                              Icons.receipt_long,
                                              size: 16,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${m.fecha.day}/${m.fecha.month}/${m.fecha.year}'
                                    '${nombreCampana != null ? " • $nombreCampana" : ""}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${m.tipo == 'ingreso' ? '+' : '-'}\$${m.monto.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: m.tipo == 'ingreso'
                                              ? Colors.green.shade700
                                              : Colors.red.shade700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert),
                                        onSelected: (opcion) {
                                          if (opcion == 'editar') {
                                            _abrirModalEdicion(m);
                                          } else if (opcion == 'eliminar') {
                                            _confirmarEliminacion(m);
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(
                                            value: 'editar',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit, color: Colors.blue, size: 20),
                                                SizedBox(width: 8),
                                                Text('Editar'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'eliminar',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete, color: Colors.red, size: 20),
                                                SizedBox(width: 8),
                                                Text('Eliminar'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}