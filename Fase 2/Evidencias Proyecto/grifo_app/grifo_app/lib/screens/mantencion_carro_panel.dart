import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../utils/mantencion_util.dart';
import '../utils/vida_util.dart' show fechaIso, fechaVisible;

int? _entero(dynamic v) => v == null ? null : int.tryParse(v.toString());

/// Pestaña "Mantención y vencimientos" de un carro: fechas de revisión técnica,
/// permiso y SOAP, kilometraje, próxima mantención (por fecha o por km) e
/// historial de talleres. Avisa cuando algo está vencido o por vencer.
class MantencionCarroPanel extends StatefulWidget {
  final String carroId;
  final String nombreCarro;
  final bool puedeEditar; // false = solo lectura
  const MantencionCarroPanel({super.key, required this.carroId, required this.nombreCarro, this.puedeEditar = false});

  @override
  State<MantencionCarroPanel> createState() => _MantencionCarroPanelState();
}

class _MantencionCarroPanelState extends State<MantencionCarroPanel> {
  final _db = SupabaseService();

  Map<String, dynamic>? _carro;
  List<Map<String, dynamic>> _historial = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (mounted) {
      setState(() {
        _cargando = _carro == null;
        _error = null;
      });
    }
    try {
      final carro = await _db.obtenerCarro(widget.carroId);
      final historial = await _db.obtenerHistorialMantencion(widget.carroId);
      if (!mounted) return;
      setState(() {
        _carro = carro;
        _historial = historial;
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

  void _aviso(String texto) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  String _mensajeError(Object e) => e is PostgrestException ? e.message : '$e';

  // ---------------------------------------------------------------- documentos

  Future<void> _editarDocumento(DocumentoCarro doc) async {
    final actual = DateTime.tryParse('${_carro?[doc.campo] ?? ''}');
    final accion = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(doc.nombre, style: const TextStyle(color: AppColors.textoPrincipal)),
        content: Text(
          actual == null ? 'Aún no hay fecha de vencimiento registrada.' : 'Vence el ${fechaVisible(actual)}.',
          style: const TextStyle(color: AppColors.textoSecundario),
        ),
        actions: [
          if (actual != null)
            TextButton(
              onPressed: () => Navigator.pop(c, 'quitar'),
              child: const Text('Quitar fecha', style: TextStyle(color: AppColors.rojoAlerta)),
            ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rojo),
            onPressed: () => Navigator.pop(c, 'elegir'),
            child: Text(actual == null ? 'Elegir fecha' : 'Cambiar fecha'),
          ),
        ],
      ),
    );
    if (accion == null || !mounted) return;

    try {
      if (accion == 'quitar') {
        await _db.actualizarCarro(widget.carroId, {doc.campo: null});
      } else {
        final f = await showDatePicker(
          context: context,
          initialDate: actual ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 365 * 15)),
          helpText: 'Vencimiento: ${doc.nombre}',
        );
        if (f == null) return;
        await _db.actualizarCarro(widget.carroId, {doc.campo: fechaIso(f)});
      }
      await _cargar();
    } catch (e) {
      _aviso('No se pudo guardar: ${_mensajeError(e)}');
    }
  }

  // ----------------------------------------------------------------- kilometraje

  Future<void> _actualizarKm() async {
    final actual = _entero(_carro?['km_actual']);
    final ctrl = TextEditingController(text: actual?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Kilometraje actual', style: TextStyle(color: AppColors.textoPrincipal)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: decoracionCampo('Kilómetros que marca el carro'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rojo),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final nuevo = int.tryParse(ctrl.text.replaceAll('.', '').trim());
    if (nuevo == null || nuevo < 0) {
      _aviso('Ingresa un número válido');
      return;
    }
    if (actual != null && nuevo < actual) {
      _aviso('El kilometraje no puede ser menor al actual (${km(actual)})');
      return;
    }
    try {
      await _db.actualizarCarro(widget.carroId, {'km_actual': nuevo});
      await _cargar();
    } catch (e) {
      _aviso('No se pudo guardar: ${_mensajeError(e)}');
    }
  }

  // ------------------------------------------------------------------- mantención

  Future<void> _registrarMantencion() async {
    DateTime fecha = DateTime.now();
    final fechaCtrl = TextEditingController(text: fechaVisible(fecha));
    final kmCtrl = TextEditingController(text: _carro?['km_actual']?.toString() ?? '');
    final tallerCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String tipo = 'Preventiva';

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Registrar mantención', style: TextStyle(color: AppColors.textoPrincipal)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: fechaCtrl,
                  readOnly: true,
                  decoration: decoracionCampo('Fecha de la mantención', suffixIcon: const Icon(Icons.calendar_today, size: 18)),
                  onTap: () async {
                    final f = await showDatePicker(
                      context: c,
                      initialDate: fecha,
                      firstDate: DateTime(2000),
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
                  controller: kmCtrl,
                  keyboardType: TextInputType.number,
                  decoration: decoracionCampo('Kilometraje en ese momento'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: tipo,
                  decoration: decoracionCampo('Tipo'),
                  items: const ['Preventiva', 'Correctiva', 'Revisión']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setD(() => tipo = v ?? tipo),
                ),
                const SizedBox(height: 10),
                TextField(controller: tallerCtrl, decoration: decoracionCampo('Taller (opcional)')),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, maxLines: 2, decoration: decoracionCampo('Qué se hizo (opcional)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.rojo),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final kmValor = int.tryParse(kmCtrl.text.replaceAll('.', '').trim());
    if (kmValor == null || kmValor < 0) {
      _aviso('Ingresa el kilometraje del carro en esa mantención');
      return;
    }
    try {
      await _db.registrarMantencion(
        carroId: widget.carroId,
        fecha: fechaIso(fecha),
        km: kmValor,
        tipo: tipo,
        taller: tallerCtrl.text.trim().isEmpty ? null : tallerCtrl.text.trim(),
        descripcion: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      );
      _aviso('Mantención registrada');
      await _cargar();
    } catch (e) {
      _aviso('No se pudo registrar: ${_mensajeError(e)}');
    }
  }

  Future<void> _configurarIntervalos() async {
    final mesesCtrl = TextEditingController(text: '${_entero(_carro?['mantencion_cada_meses']) ?? 12}');
    final kmCtrl = TextEditingController(text: '${_entero(_carro?['mantencion_cada_km']) ?? 10000}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Cada cuánto va a taller', style: TextStyle(color: AppColors.textoPrincipal)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Se avisa cuando se cumple lo primero que ocurra: el tiempo o los kilómetros.',
              style: TextStyle(color: AppColors.textoSecundario, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(controller: mesesCtrl, keyboardType: TextInputType.number, decoration: decoracionCampo('Cada cuántos meses')),
            const SizedBox(height: 10),
            TextField(controller: kmCtrl, keyboardType: TextInputType.number, decoration: decoracionCampo('Cada cuántos kilómetros')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rojo),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final meses = int.tryParse(mesesCtrl.text.trim());
    final kmIntervalo = int.tryParse(kmCtrl.text.replaceAll('.', '').trim());
    if (meses == null || meses < 1 || kmIntervalo == null || kmIntervalo < 1) {
      _aviso('Ingresa números válidos (mayores a 0)');
      return;
    }
    try {
      await _db.actualizarCarro(widget.carroId, {'mantencion_cada_meses': meses, 'mantencion_cada_km': kmIntervalo});
      await _cargar();
    } catch (e) {
      _aviso('No se pudo guardar: ${_mensajeError(e)}');
    }
  }

  // ------------------------------------------------------------------------ UI

  Widget _tarjeta({required String titulo, required List<Widget> hijos}) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: decoracionTarjeta(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: const TextStyle(color: AppColors.textoPrincipal, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...hijos,
          ],
        ),
      );

  Widget _filaDato(String etiqueta, String valor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 140, child: Text(etiqueta, style: const TextStyle(color: AppColors.textoSecundario, fontSize: 13))),
            Expanded(child: Text(valor, style: const TextStyle(color: AppColors.textoPrincipal, fontSize: 13))),
          ],
        ),
      );

  Widget _filaAlerta(AlertaCarro a) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              a.nivel == NivelAlerta.ok ? Icons.check_circle_outline : (a.nivel == NivelAlerta.sinDato ? Icons.help_outline : Icons.warning_amber_rounded),
              color: a.color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.titulo, style: const TextStyle(color: AppColors.textoPrincipal, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(a.detalle, style: TextStyle(color: a.color, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator(color: AppColors.rojo));

    if (_error != null || _carro == null) {
      return ListView(children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error != null
                ? 'No se pudo cargar la mantención: $_error\n\n¿Ya ejecutaste mantencion_carros.sql en Supabase?'
                : 'No se encontró el carro.',
            style: const TextStyle(color: AppColors.rojoAlerta),
          ),
        ),
      ]);
    }

    final carro = _carro!;
    final activas = alertasActivas(carro);
    final mantencion = evaluarMantencion(carro);
    final ultimaFecha = DateTime.tryParse('${carro['mantencion_ultima_fecha'] ?? ''}');
    final ultimoKm = _entero(carro['mantencion_ultimo_km']);
    final kmActual = _entero(carro['km_actual']);
    final cadaMeses = _entero(carro['mantencion_cada_meses']) ?? 12;
    final cadaKm = _entero(carro['mantencion_cada_km']) ?? 10000;

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: activas.isEmpty ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: activas.isEmpty ? Colors.green.shade200 : Colors.red.shade200),
            ),
            child: activas.isEmpty
                ? Row(children: [
                    const Icon(Icons.verified_outlined, color: AppColors.verde),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Sin alertas: documentos y mantención al día.',
                        style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${activas.length} aviso${activas.length == 1 ? '' : 's'} para ${widget.nombreCarro}',
                        style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      ...activas.map(_filaAlerta),
                    ],
                  ),
          ),
          _tarjeta(
            titulo: 'Documentos del carro',
            hijos: documentosCarro.map((doc) {
              final a = evaluarDocumento(doc.nombre, carro[doc.campo]);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(doc.nombre, style: const TextStyle(color: AppColors.textoPrincipal, fontWeight: FontWeight.w600)),
                subtitle: Text(a.detalle, style: TextStyle(color: a.color, fontSize: 12)),
                trailing: widget.puedeEditar ? const Icon(Icons.edit, size: 18, color: AppColors.textoSecundario) : null,
                onTap: widget.puedeEditar ? () => _editarDocumento(doc) : null,
              );
            }).toList(),
          ),
          _tarjeta(
            titulo: 'Mantención (taller)',
            hijos: [
              _filaDato(
                'Última mantención',
                ultimaFecha == null && ultimoKm == null
                    ? 'Sin registrar'
                    : '${ultimaFecha == null ? 'fecha sin registrar' : fechaVisible(ultimaFecha)}${ultimoKm == null ? '' : ' · ${km(ultimoKm)}'}',
              ),
              _filaDato('Kilometraje actual', kmActual == null ? 'Sin registrar' : km(kmActual)),
              _filaDato('Va a taller cada', '$cadaMeses meses o ${km(cadaKm)}'),
              const SizedBox(height: 6),
              ...mantencion.map(_filaAlerta),
              const SizedBox(height: 8),
              if (widget.puedeEditar)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.rojo),
                    onPressed: _registrarMantencion,
                    icon: const Icon(Icons.build, size: 18),
                    label: const Text('Registrar mantención'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _actualizarKm,
                    icon: const Icon(Icons.speed, size: 18),
                    label: const Text('Actualizar km'),
                  ),
                  TextButton.icon(
                    onPressed: _configurarIntervalos,
                    icon: const Icon(Icons.tune, size: 18, color: AppColors.rojo),
                    label: const Text('Intervalos', style: TextStyle(color: AppColors.rojo)),
                  ),
                ],
              ),
            ],
          ),
          _tarjeta(
            titulo: 'Historial de mantenciones',
            hijos: _historial.isEmpty
                ? [const Text('Aún no hay mantenciones registradas.', style: TextStyle(color: AppColors.textoSecundario, fontSize: 13))]
                : _historial.map((h) {
                    final f = DateTime.tryParse('${h['fecha'] ?? ''}');
                    final kmH = _entero(h['km']);
                    final detalle = [
                      if ((h['taller'] ?? '').toString().isNotEmpty) h['taller'].toString(),
                      if ((h['descripcion'] ?? '').toString().isNotEmpty) h['descripcion'].toString(),
                    ].join(' · ');
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.build_circle_outlined, color: AppColors.rojo),
                      title: Text(
                        '${f == null ? '' : fechaVisible(f)} · ${h['tipo'] ?? ''}${kmH == null ? '' : ' · ${km(kmH)}'}',
                        style: const TextStyle(color: AppColors.textoPrincipal, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: detalle.isEmpty ? null : Text(detalle, style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
                    );
                  }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
