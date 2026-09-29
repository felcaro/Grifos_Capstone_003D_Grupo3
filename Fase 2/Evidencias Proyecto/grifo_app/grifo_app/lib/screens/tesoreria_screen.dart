import 'package:flutter/material.dart';
import '../models/movimiento_tesoreria.dart';
import '../services/supabase_service.dart';

class TesoreriaScreen extends StatefulWidget {
  const TesoreriaScreen({super.key});

  @override
  State<TesoreriaScreen> createState() => _TesoreriaScreenState();
}

class _TesoreriaScreenState extends State<TesoreriaScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  bool _isLoading = true;
  List<MovimientoTesoreria> _movimientos = [];

  double _totalIngresos = 0;
  double _totalEgresos = 0;

  double get _saldoTotal => _totalIngresos - _totalEgresos;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final movimientos = await _supabaseService.obtenerMovimientosTesoreria();

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
        _totalIngresos = ingresos;
        _totalEgresos = egresos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar tesorería: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _abrirModalRegistro() {
    final montoController = TextEditingController();
    final descripcionController = TextEditingController();
    final campanaController = TextEditingController();
    String tipoSeleccionado = 'ingreso';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (builderContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(builderContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Registrar Movimiento',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),

                  // Tipo
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

                  // Monto (Obligatorio)
                  TextField(
                    controller: montoController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Monto (\$)*',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Descripción / Motivo (Obligatorio)
                  TextField(
                    controller: descripcionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción / Motivo*',
                      hintText: 'Ej: Cuota mensual, Compra de insumos...',
                      prefixIcon: Icon(Icons.description),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Campaña UUID (Opcional)
                  TextField(
                    controller: campanaController,
                    decoration: const InputDecoration(
                      labelText: 'ID Campaña / Evento (Opcional)',
                      hintText: 'Dejar en blanco si no aplica',
                      prefixIcon: Icon(Icons.campaign),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Botón Guardar
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
                        final rawMonto = montoController.text.trim().replaceAll(',', '.');
                        final descripcion = descripcionController.text.trim();

                        if (rawMonto.isEmpty) {
                          ScaffoldMessenger.of(builderContext).showSnackBar(
                            const SnackBar(content: Text('Por favor ingresa un monto.')),
                          );
                          return;
                        }

                        final monto = double.tryParse(rawMonto);
                        if (monto == null || monto <= 0) {
                          ScaffoldMessenger.of(builderContext).showSnackBar(
                            const SnackBar(content: Text('Ingresa un monto válido mayor a 0.')),
                          );
                          return;
                        }

                        if (descripcion.isEmpty) {
                          ScaffoldMessenger.of(builderContext).showSnackBar(
                            const SnackBar(content: Text('La descripción es obligatoria.')),
                          );
                          return;
                        }

                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(modalContext);
                        setState(() => _isLoading = true);

                        try {
                          await _supabaseService.registrarMovimientoTesoreria(
                            tipo: tipoSeleccionado,
                            monto: monto,
                            descripcion: descripcion,
                            campanaId: campanaController.text.trim().isEmpty
                                ? null
                                : campanaController.text.trim(),
                          );

                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Movimiento registrado con éxito'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                          await _cargarDatos();
                        } catch (e) {
                          setState(() => _isLoading = false);
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Error al guardar en Supabase: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text(
                        'Guardar Registro',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Tesorería'),
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
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
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBalanceCard(),
                    const SizedBox(height: 20),

                    const Text(
                      'Historial de Movimientos',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    if (_movimientos.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            'No hay movimientos registrados.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _movimientos.length,
                        itemBuilder: (context, index) {
                          final m = _movimientos[index];
                          final esIngreso = m.tipo.toLowerCase() == 'ingreso';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: esIngreso
                                    ? Colors.green.shade100
                                    : Colors.red.shade100,
                                child: Icon(
                                  esIngreso
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color: esIngreso ? Colors.green : Colors.red,
                                ),
                              ),
                              title: Text(
                                m.descripcion.isNotEmpty ? m.descripcion : (esIngreso ? 'Ingreso' : 'Egreso'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${m.fecha.day}/${m.fecha.month}/${m.fecha.year}'
                                '${m.campanaId != null ? " • Campaña Vinculada" : ""}',
                              ),
                              trailing: Text(
                                '${esIngreso ? "+" : "-"}\$${m.monto.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: esIngreso ? Colors.green : Colors.red,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
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
}