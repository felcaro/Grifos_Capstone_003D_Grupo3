import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/acta_pdf_service.dart';
import '../theme/app_colors.dart';
import '../widgets/firma_dialog.dart';

/// Formulario para digitalizar el "libro de actas" del Directorio.
/// Reemplaza el acta manuscrita: mismo formulario funciona en la app
/// (Android/iOS) y en la versión web, porque es el mismo código Flutter.
class ActaFormScreen extends StatefulWidget {
  const ActaFormScreen({super.key});

  @override
  State<ActaFormScreen> createState() => _ActaFormScreenState();
}

/// Un asistente a la reunión (nombre + cargo), igual a cada línea
/// de la lista de asistencia del acta manuscrita.
class _Asistente {
  final TextEditingController nombre = TextEditingController();
  final TextEditingController cargo = TextEditingController();

  void dispose() {
    nombre.dispose();
    cargo.dispose();
  }
}

/// Un tema/acuerdo tratado en la reunión (título + detalle),
/// igual a cada bloque de "El detalle es el siguiente..." del acta.
class _Acuerdo {
  final TextEditingController tema = TextEditingController();
  final TextEditingController detalle = TextEditingController();

  void dispose() {
    tema.dispose();
    detalle.dispose();
  }
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

class _ActaFormScreenState extends State<ActaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dbService = SupabaseService();

  final _tituloController = TextEditingController();
  final _companiaNombreController = TextEditingController(text: 'Cuerpo de Bomberos');
  final _lugarController = TextEditingController(text: 'Cuartel de la Primera Compañía');
  final _presididaPorController = TextEditingController();
  final _fechaController = TextEditingController();
  final _horaInicioController = TextEditingController();
  final _horaTerminoController = TextEditingController();
  FirmaData? _firmaSuperintendente;
  FirmaData? _firmaSecretario;

  String _tipoReunion = 'Ordinaria';
  DateTime? _fechaSeleccionada;
  TimeOfDay? _horaInicioSeleccionada;
  TimeOfDay? _horaTerminoSeleccionada;

  final List<_Asistente> _asistentes = [_Asistente()];
  final List<_Acuerdo> _acuerdos = [_Acuerdo()];

  bool _guardando = false;

  @override
  void dispose() {
    _tituloController.dispose();
    _companiaNombreController.dispose();
    _lugarController.dispose();
    _presididaPorController.dispose();
    _fechaController.dispose();
    _horaInicioController.dispose();
    _horaTerminoController.dispose();
    for (final a in _asistentes) {
      a.dispose();
    }
    for (final a in _acuerdos) {
      a.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (fecha != null) {
      setState(() {
        _fechaSeleccionada = fecha;
        _fechaController.text = '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
      });
    }
  }

  Future<void> _elegirHora(bool esInicio) async {
    final hora = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (hora != null) {
      setState(() {
        final texto = '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
        if (esInicio) {
          _horaInicioSeleccionada = hora;
          _horaInicioController.text = texto;
        } else {
          _horaTerminoSeleccionada = hora;
          _horaTerminoController.text = texto;
        }
      });
    }
  }

  void _agregarAsistente() => setState(() => _asistentes.add(_Asistente()));

  void _quitarAsistente(int index) {
    if (_asistentes.length == 1) return;
    setState(() {
      _asistentes[index].dispose();
      _asistentes.removeAt(index);
    });
  }

  void _agregarAcuerdo() => setState(() => _acuerdos.add(_Acuerdo()));

  void _quitarAcuerdo(int index) {
    if (_acuerdos.length == 1) return;
    setState(() {
      _acuerdos[index].dispose();
      _acuerdos.removeAt(index);
    });
  }

  Future<void> _guardarActa() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaSeleccionada == null || _horaInicioSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona la fecha y la hora de inicio')),
      );
      return;
    }
    if (_firmaSuperintendente == null || _firmaSecretario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faltan firmas por confirmar (Superintendente y Secretario/a)')),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      final horaInicioTexto = '${_horaInicioSeleccionada!.hour.toString().padLeft(2, '0')}:${_horaInicioSeleccionada!.minute.toString().padLeft(2, '0')}';
      final horaTerminoTexto = _horaTerminoSeleccionada != null
          ? '${_horaTerminoSeleccionada!.hour.toString().padLeft(2, '0')}:${_horaTerminoSeleccionada!.minute.toString().padLeft(2, '0')}'
          : null;
      final fechaIso = _fechaSeleccionada!.toIso8601String().substring(0, 10);

      final pdfBytes = await ActaPdfService.generar(
        tituloReunion: _tituloController.text,
        companiaNombre: _companiaNombreController.text,
        fecha: _fechaController.text,
        horaInicio: horaInicioTexto,
        horaTermino: horaTerminoTexto,
        lugar: _lugarController.text,
        tipoReunion: _tipoReunion,
        presididaPor: _presididaPorController.text,
        asistentes: _asistentes.map((a) => ActaAsistente(a.nombre.text, a.cargo.text)).toList(),
        acuerdos: _acuerdos.map((a) => ActaAcuerdo(a.tema.text, a.detalle.text)).toList(),
        firmaSuperintendente: _firmaSuperintendente,
        firmaSecretario: _firmaSecretario,
      );

      final nombreArchivo = 'acta_${fechaIso}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final url = await _dbService.subirActaPdf(pdfBytes, nombreArchivo);

      final companiaId = await _dbService.obtenerCompaniaIdUsuarioActual();
      await _dbService.insertarActa(
        titulo: _tituloController.text.isNotEmpty ? _tituloController.text : 'Acta $_tipoReunion - ${_fechaController.text}',
        fechaReunion: fechaIso,
        archivoUrl: url,
        companiaId: companiaId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Acta generada y guardada como PDF! 📖')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _tarjeta({required String titulo, required List<Widget> children, VoidCallback? onAgregar, String? textoAgregar}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: _decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: const TextStyle(color: AppColors.textoPrincipal, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...children,
          if (onAgregar != null) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: onAgregar,
              icon: const Icon(Icons.add, color: AppColors.rojo),
              label: Text(textoAgregar ?? 'Agregar', style: const TextStyle(color: AppColors.rojo)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _botonFirma({required String cargo, required FirmaData? firma, required VoidCallback onTap}) {
    final confirmada = firma != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: confirmada ? AppColors.verde : AppColors.bordeCampo),
          borderRadius: BorderRadius.circular(8),
          color: confirmada ? AppColors.verde.withOpacity(0.08) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(confirmada ? Icons.verified : Icons.draw_outlined, color: confirmada ? AppColors.verde : AppColors.textoSecundario),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Firma — $cargo', style: const TextStyle(color: AppColors.textoPrincipal, fontWeight: FontWeight.bold)),
                  Text(
                    confirmada ? '${firma.nombreVerificado} (verificado ✓)' : 'Toca para firmar',
                    style: TextStyle(color: confirmada ? AppColors.verde : AppColors.textoSecundario, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (confirmada) const Icon(Icons.edit, size: 18, color: AppColors.textoSecundario),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: AppColors.rojo,
        foregroundColor: Colors.white,
        title: const Text('Acta de Reunión de Directorio'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _tarjeta(
              titulo: 'Datos generales',
              children: [
                TextFormField(
                  controller: _tituloController,
                  decoration: _decoracion('Título del acta (ej: Reunión Ordinaria 09/10/2025)'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _companiaNombreController,
                  decoration: _decoracion('Compañía de Bomberos'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fechaController,
                        readOnly: true,
                        onTap: _elegirFecha,
                        decoration: _decoracion('Fecha'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _horaInicioController,
                        readOnly: true,
                        onTap: () => _elegirHora(true),
                        decoration: _decoracion('Hora inicio'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _horaTerminoController,
                        readOnly: true,
                        onTap: () => _elegirHora(false),
                        decoration: _decoracion('Hora término'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lugarController,
                  decoration: _decoracion('Lugar (dependencias del cuartel)'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _tipoReunion,
                  decoration: _decoracion('Tipo de reunión'),
                  items: const [
                    DropdownMenuItem(value: 'Ordinaria', child: Text('Ordinaria')),
                    DropdownMenuItem(value: 'Extraordinaria', child: Text('Extraordinaria')),
                  ],
                  onChanged: (v) => setState(() => _tipoReunion = v ?? 'Ordinaria'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _presididaPorController,
                  decoration: _decoracion('Presidida por (nombre y cargo)'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
              ],
            ),

            _tarjeta(
              titulo: 'Asistentes',
              onAgregar: _agregarAsistente,
              textoAgregar: 'Agregar asistente',
              children: _asistentes.asMap().entries.map((entry) {
                final i = entry.key;
                final a = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: a.nombre,
                          decoration: _decoracion('Nombre'),
                          validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: a.cargo,
                          decoration: _decoracion('Cargo'),
                          validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: AppColors.textoSecundario),
                        onPressed: () => _quitarAsistente(i),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            _tarjeta(
              titulo: 'Temas tratados / Acuerdos',
              onAgregar: _agregarAcuerdo,
              textoAgregar: 'Agregar acuerdo',
              children: _acuerdos.asMap().entries.map((entry) {
                final i = entry.key;
                final a = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: a.tema,
                              decoration: _decoracion('Tema (ej: Aprobación de presupuesto...)'),
                              validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: AppColors.textoSecundario),
                            onPressed: () => _quitarAcuerdo(i),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: a.detalle,
                        maxLines: 3,
                        decoration: _decoracion('Detalle del acuerdo'),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            _tarjeta(
              titulo: 'Cierre y firmas',
              children: [
                _botonFirma(
                  cargo: 'Superintendente',
                  firma: _firmaSuperintendente,
                  onTap: () async {
                    final resultado = await mostrarDialogoFirma(context, tituloFirmante: 'Superintendente');
                    if (resultado != null) setState(() => _firmaSuperintendente = resultado);
                  },
                ),
                const SizedBox(height: 12),
                _botonFirma(
                  cargo: 'Secretario/a General',
                  firma: _firmaSecretario,
                  onTap: () async {
                    final resultado = await mostrarDialogoFirma(context, tituloFirmante: 'Secretario/a General');
                    if (resultado != null) setState(() => _firmaSecretario = resultado);
                  },
                ),
              ],
            ),

            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _guardando ? null : _guardarActa,
              icon: _guardando
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_guardando ? 'Guardando...' : 'Guardar Acta'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.rojo, padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
