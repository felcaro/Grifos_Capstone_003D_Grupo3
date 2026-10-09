import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/entrega_epp_pdf_service.dart';
import '../theme/app_colors.dart';

/// Formulario digital del "Registro de entrega — Equipo de protección
/// personal". Al guardar, genera el PDF con el mismo formato del papel
/// y sube solo esa referencia a Supabase.
class EntregaEppFormScreen extends StatefulWidget {
  const EntregaEppFormScreen({super.key});

  @override
  State<EntregaEppFormScreen> createState() => _EntregaEppFormScreenState();
}

class _ItemControlado {
  final String nombre;
  bool entregado = true;
  final TextEditingController observacion = TextEditingController();
  _ItemControlado(this.nombre);
}

InputDecoration _decoracion(String label) => InputDecoration(
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

class _EntregaEppFormScreenState extends State<EntregaEppFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dbService = SupabaseService();

  final _companiaController = TextEditingController(text: 'Cuerpo de Bomberos');
  final _nombreController = TextEditingController();
  final _runController = TextEditingController();
  final _nRegistroController = TextEditingController();
  final _fechaController = TextEditingController();
  final _capitanController = TextEditingController();

  DateTime? _fechaSeleccionada;
  bool _guardando = false;

  late final Map<String, List<_ItemControlado>> _items = {
    for (final entry in catalogoEpp.entries) entry.key: entry.value.map((n) => _ItemControlado(n)).toList(),
  };

  @override
  void dispose() {
    _companiaController.dispose();
    _nombreController.dispose();
    _runController.dispose();
    _nRegistroController.dispose();
    _fechaController.dispose();
    _capitanController.dispose();
    for (final lista in _items.values) {
      for (final item in lista) {
        item.observacion.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final fecha = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (fecha != null) {
      setState(() {
        _fechaSeleccionada = fecha;
        _fechaController.text = '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona la fecha')));
      return;
    }

    setState(() => _guardando = true);
    try {
      final itemsParaPdf = {
        for (final entry in _items.entries)
          entry.key: entry.value.map((i) => ItemEntregaEpp(i.nombre, i.entregado, i.observacion.text)).toList(),
      };

      final pdfBytes = await EntregaEppPdfService.generar(
        companiaNombre: _companiaController.text,
        voluntarioNombre: _nombreController.text,
        run: _runController.text,
        nRegistro: _nRegistroController.text,
        fecha: _fechaController.text,
        itemsPorCategoria: itemsParaPdf,
        nombreCapitan: _capitanController.text,
      );

      final fechaIso = _fechaSeleccionada!.toIso8601String().substring(0, 10);
      final nombreArchivo = 'epp_${_runController.text.replaceAll(RegExp(r'[^0-9kK]'), '')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final url = await _dbService.subirRegistroEpp(pdfBytes, nombreArchivo);

      final companiaId = await _dbService.obtenerCompaniaIdUsuarioActual();
      await _dbService.insertarEntregaEpp(
        voluntarioNombre: _nombreController.text,
        voluntarioRun: _runController.text,
        nRegistro: _nRegistroController.text,
        fecha: fechaIso,
        archivoUrl: url,
        companiaId: companiaId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Registro de entrega guardado! 🧰')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(backgroundColor: AppColors.rojo, foregroundColor: Colors.white, title: const Text('Registro de Entrega — EPP')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: _decoracionTarjeta(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextFormField(
                  controller: _companiaController,
                  decoration: _decoracion('Compañía de Bomberos'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nombreController,
                  decoration: _decoracion('Nombre voluntario'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _runController,
                      decoration: _decoracion('R.U.N.'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _nRegistroController,
                      decoration: _decoracion('N° de registro'),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _fechaController,
                  readOnly: true,
                  onTap: _elegirFecha,
                  decoration: _decoracion('Fecha'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
              ]),
            ),
            const SizedBox(height: 16),

            ..._items.entries.map((entry) => Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: _decoracionTarjeta(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(entry.key, style: const TextStyle(color: AppColors.textoPrincipal, fontWeight: FontWeight.bold)),
                      ),
                      ...entry.value.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(child: Text(item.nombre, style: const TextStyle(color: AppColors.textoPrincipal, fontSize: 13))),
                                Text(item.entregado ? 'SI' : 'NO', style: TextStyle(color: item.entregado ? AppColors.verde : AppColors.rojoAlerta, fontSize: 12)),
                                Switch(
                                  value: item.entregado,
                                  activeColor: AppColors.verde,
                                  onChanged: (v) => setState(() => item.entregado = v),
                                ),
                              ]),
                              TextFormField(
                                controller: item.observacion,
                                style: const TextStyle(fontSize: 13),
                                decoration: _decoracion('Observación (opcional)'),
                              ),
                              const SizedBox(height: 4),
                            ]),
                          )),
                      const SizedBox(height: 6),
                    ],
                  ),
                )),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: _decoracionTarjeta(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text(
                  'COMPROMISO: Me comprometo a cuidar y mantener en buen estado el equipo de protección personal. '
                  'Cualquier pérdida o imprevisto no justificado, deberé comunicarlo, quedando a disposición y decisión '
                  'de los oficiales operativos la devolución de los implementos de seguridad.',
                  style: TextStyle(color: AppColors.textoSecundario, fontSize: 12),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _capitanController,
                  decoration: _decoracion('Nombre del Capitán (firma)'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
              ]),
            ),

            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_guardando ? 'Guardando...' : 'Guardar Registro'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.rojo, padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
