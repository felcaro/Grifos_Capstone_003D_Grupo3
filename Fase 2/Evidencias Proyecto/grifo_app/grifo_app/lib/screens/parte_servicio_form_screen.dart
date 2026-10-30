import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/parte_servicio.dart';
import '../services/parte_servicio_pdf_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';

/// Formulario digital del "Parte de Servicio" (libro físico de la compañía).
/// Obligatorio: todo salvo N° OBAC, 6-0 y la sección de testigos.
/// La asistencia se arma con los usuarios registrados en la app.
class ParteServicioFormScreen extends StatefulWidget {
  const ParteServicioFormScreen({super.key});

  @override
  State<ParteServicioFormScreen> createState() => _ParteServicioFormScreenState();
}

class _FilaInstitucion {
  final institucion = TextEditingController();
  final movil = TextEditingController();
  final aCargo = TextEditingController();
  void dispose() {
    institucion.dispose();
    movil.dispose();
    aCargo.dispose();
  }
}

class _FilaTestigo {
  final nombre = TextEditingController();
  final rut = TextEditingController();
  void dispose() {
    nombre.dispose();
    rut.dispose();
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

String? _requerido(String? v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null;

class _ParteServicioFormScreenState extends State<ParteServicioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = SupabaseService();

  // Datos del servicio
  final _fecha = TextEditingController();
  final _unidad = TextEditingController();
  final _servicio = TextEditingController();
  final _direccion = TextEditingController();
  final _nombre = TextEditingController();
  final _rut = TextEditingController();
  final _nroObac = TextEditingController(); // opcional
  final _horaSalida = TextEditingController();
  final _horaLlegada = TextEditingController();
  final _odoInicial = TextEditingController();
  final _odoFinal = TextEditingController();
  final _clave60 = TextEditingController(); // opcional

  // Cuerpo del parte
  final _relato = TextEditingController();
  final _afectados = TextEditingController();
  final _declaracion = TextEditingController(); // opcional

  DateTime? _fechaSeleccionada;
  final List<_FilaInstitucion> _instituciones = [_FilaInstitucion()];
  final List<_FilaTestigo> _testigos = []; // opcional: empieza vacío
  final List<Uint8List> _croquis = []; // opcional: varias fotos

  // Asistencia
  bool _cargandoAsistencia = true;
  String? _errorAsistencia;
  List<Map<String, dynamic>> _usuarios = [];
  List<Map<String, dynamic>> _carros = [];
  final Set<String> _presentes = {};
  final Map<String, String> _carroPorUsuario = {}; // id usuario -> nombre carro
  String _busqueda = '';

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    for (final c in [
      _fecha, _unidad, _servicio, _direccion, _nombre, _rut, _nroObac,
      _horaSalida, _horaLlegada, _odoInicial, _odoFinal, _clave60,
      _relato, _afectados, _declaracion,
    ]) {
      c.dispose();
    }
    for (final i in _instituciones) {
      i.dispose();
    }
    for (final t in _testigos) {
      t.dispose();
    }
    super.dispose();
  }

  // ---- helpers para leer la fila de "usuario" sin depender de nombres exactos de columna ----
  String _nombreDe(Map<String, dynamic> u) => (u['nombre'] ?? u['nombre_completo'] ?? u['email'] ?? 'Sin nombre').toString();
  String _numeroDe(Map<String, dynamic> u) => (u['numero_voluntario'] ?? u['n_voluntario'] ?? u['numero'] ?? '').toString();
  String _maquinistaDe(Map<String, dynamic> u) => (u['numero_maquinista'] ?? '').toString();
  /// "114-105 A" como en la hoja física (voluntario - maquinista, si tiene).
  String _numeroCompletoDe(Map<String, dynamic> u) {
    final v = _numeroDe(u);
    final m = _maquinistaDe(u);
    return m.isEmpty ? v : (v.isEmpty ? m : '$v-$m');
  }
  String _rutDe(Map<String, dynamic> u) => (u['rut'] ?? u['run'] ?? '').toString();

  Future<void> _cargarDatosIniciales() async {
    // Perfil: autocompleta nombre y RUT de quien llena el parte (editable)
    try {
      final perfil = await _db.obtenerPerfilActual();
      if (perfil != null && mounted) {
        final nombrePerfil = _nombreDe(perfil);
        if (nombrePerfil != 'Sin nombre') _nombre.text = nombrePerfil;
        _rut.text = _rutDe(perfil);
      }
    } catch (_) {}

    try {
      final resultados = await Future.wait([_db.obtenerUsuariosCompania(), _db.obtenerCarros()]);
      final usuarios = List<Map<String, dynamic>>.from(resultados[0]);
      usuarios.sort((a, b) => _nombreDe(a).toLowerCase().compareTo(_nombreDe(b).toLowerCase()));
      if (!mounted) return;
      setState(() {
        _usuarios = usuarios;
        _carros = List<Map<String, dynamic>>.from(resultados[1]);
        _cargandoAsistencia = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorAsistencia = '$e';
        _cargandoAsistencia = false;
      });
    }
  }

  Future<void> _elegirFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (fecha != null) {
      setState(() {
        _fechaSeleccionada = fecha;
        _fecha.text = '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
      });
    }
  }

  Future<void> _elegirHora(TextEditingController destino) async {
    final hora = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (hora != null) {
      setState(() => destino.text = '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _elegirCroquis() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, color: AppColors.rojo),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.rojo),
              title: const Text('Elegir de la galería / archivos (puedes elegir varias)'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origen == null) return;
    try {
      final picker = ImagePicker();
      final List<XFile> archivos;
      if (origen == ImageSource.camera) {
        final foto = await picker.pickImage(source: origen, imageQuality: 80, maxWidth: 1600);
        archivos = foto == null ? [] : [foto];
      } else {
        archivos = await picker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
      }
      if (archivos.isEmpty) return;
      final nuevas = <Uint8List>[];
      for (final a in archivos) {
        nuevas.add(await a.readAsBytes());
      }
      if (mounted) setState(() => _croquis.addAll(nuevas));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo cargar la imagen: $e')));
    }
  }

  void _aviso(String mensaje) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) {
      _aviso('Revisa los campos marcados como requeridos');
      return;
    }
    if (_presentes.isEmpty) {
      _aviso('Marca al menos un voluntario en la asistencia');
      return;
    }
    final sinCarro = _presentes.where((id) => (_carroPorUsuario[id] ?? '').isEmpty).length;
    if (sinCarro > 0) {
      _aviso('Falta indicar el carro de $sinCarro voluntario(s) presente(s)');
      return;
    }

    setState(() => _guardando = true);
    try {
      final fechaIso = _fechaSeleccionada!.toIso8601String().substring(0, 10);

      final asistentes = _usuarios
          .where((u) => _presentes.contains(u['id'].toString()))
          .map((u) => ParteAsistente(
                numeroVoluntario: _numeroCompletoDe(u),
                nombre: _nombreDe(u),
                carro: _carroPorUsuario[u['id'].toString()] ?? '',
              ))
          .toList();

      final datos = ParteServicioData(
        companiaNombre: 'Primera Compañía de Bomberos Villa Alhué',
        fecha: _fecha.text,
        unidad: _unidad.text.trim(),
        servicio: _servicio.text.trim(),
        direccion: _direccion.text.trim(),
        nombre: _nombre.text.trim(),
        rut: _rut.text.trim(),
        nroObac: _nroObac.text.trim(),
        horaSalida: _horaSalida.text,
        horaLlegada: _horaLlegada.text,
        odometroInicial: _odoInicial.text.trim(),
        odometroFinal: _odoFinal.text.trim(),
        clave60: _clave60.text.trim(),
        instituciones: _instituciones
            .where((i) => i.institucion.text.trim().isNotEmpty)
            .map((i) => ParteInstitucion(i.institucion.text.trim(), i.movil.text.trim(), i.aCargo.text.trim()))
            .toList(),
        relato: _relato.text.trim(),
        afectados: _afectados.text.trim(),
        testigos: _testigos
            .where((t) => t.nombre.text.trim().isNotEmpty)
            .map((t) => ParteTestigo(t.nombre.text.trim(), t.rut.text.trim()))
            .toList(),
        declaracionTestigos: _declaracion.text.trim(),
        croquis: List<Uint8List>.from(_croquis),
        asistentes: asistentes,
      );

      final pdf = await ParteServicioPdfService.generar(datos);
      final nombreArchivo = 'parte_servicio_${fechaIso}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final url = await _db.subirActaPdf(pdf, nombreArchivo);

      final companiaId = await _db.obtenerCompaniaIdUsuarioActual();
      await _db.insertarActa(
        titulo: 'Parte de Servicio - ${datos.servicio} - ${datos.fecha}',
        fechaReunion: fechaIso,
        archivoUrl: url,
        companiaId: companiaId,
      );

      if (mounted) {
        _aviso('Parte de servicio guardado como PDF');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _aviso('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ---------------- widgets ----------------

  Widget _tarjeta({required String titulo, String? subtitulo, required List<Widget> children, VoidCallback? onAgregar, String? textoAgregar}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: _decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: const TextStyle(color: AppColors.textoPrincipal, fontSize: 16, fontWeight: FontWeight.bold)),
          if (subtitulo != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitulo, style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
            ),
          const SizedBox(height: 10),
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

  Widget _campo(TextEditingController c, String label, {bool requerido = true, TextInputType? tipo, int maxLineas = 1}) {
    return TextFormField(
      controller: c,
      keyboardType: tipo,
      maxLines: maxLineas,
      decoration: _decoracion(requerido ? '$label *' : label),
      validator: requerido ? _requerido : null,
    );
  }

  Widget _campoSeleccion(TextEditingController c, String label, VoidCallback onTap) {
    return TextFormField(
      controller: c,
      readOnly: true,
      onTap: onTap,
      decoration: _decoracion('$label *'),
      validator: _requerido,
    );
  }

  Widget _par(Widget a, Widget b) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: LayoutBuilder(builder: (context, caja) {
          // En pantallas angostas (celular) los campos se apilan
          if (caja.maxWidth < 480) {
            return Column(children: [a, const SizedBox(height: 12), b]);
          }
          return Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);
        }),
      );

  Widget _filaInstitucion(int i) {
    final f = _instituciones[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: TextFormField(controller: f.institucion, decoration: _decoracion('Institución *'), validator: i == 0 ? _requerido : null)),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: TextFormField(controller: f.movil, decoration: _decoracion('Móvil'))),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: TextFormField(controller: f.aCargo, decoration: _decoracion('A cargo de'))),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: AppColors.textoSecundario),
            onPressed: _instituciones.length == 1
                ? null
                : () => setState(() {
                      _instituciones[i].dispose();
                      _instituciones.removeAt(i);
                    }),
          ),
        ],
      ),
    );
  }

  Widget _filaTestigo(int i) {
    final t = _testigos[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(flex: 3, child: TextFormField(controller: t.nombre, decoration: _decoracion('Nombre'))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: TextFormField(controller: t.rut, decoration: _decoracion('RUT'))),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: AppColors.textoSecundario),
            onPressed: () => setState(() {
              _testigos[i].dispose();
              _testigos.removeAt(i);
            }),
          ),
        ],
      ),
    );
  }

  Widget _seccionCroquis() {
    return _tarjeta(
      titulo: 'Croquis (opcional)',
      subtitulo: 'Fotos del croquis: características clave de la situación, distribución del inmueble, posición de vehículos, imagen inicial y final. Puedes agregar varias.',
      children: [
        if (_croquis.isEmpty)
          Container(
            height: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: AppColors.bordeCampo), borderRadius: BorderRadius.circular(8)),
            child: const Text('Aún no hay fotos', style: TextStyle(color: AppColors.textoSecundario)),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < _croquis.length; i++)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(_croquis[i], width: 150, height: 150, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: InkWell(
                        onTap: () => setState(() => _croquis.removeAt(i)),
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                        child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _elegirCroquis,
          icon: const Icon(Icons.add_a_photo, color: AppColors.rojo),
          label: Text(_croquis.isEmpty ? 'Agregar fotos del croquis' : 'Agregar más fotos', style: const TextStyle(color: AppColors.rojo)),
        ),
      ],
    );
  }

  Widget _seccionAsistencia() {
    final filtro = _busqueda.trim().toLowerCase();
    final visibles = _usuarios.where((u) => filtro.isEmpty || _nombreDe(u).toLowerCase().contains(filtro) || _numeroDe(u).toLowerCase().contains(filtro)).toList();

    return _tarjeta(
      titulo: 'Asistencia *',
      subtitulo: 'Marca a los voluntarios que asistieron e indica en qué carro fue cada uno. Presentes: ${_presentes.length}',
      children: [
        if (_cargandoAsistencia)
          const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(color: AppColors.rojo)))
        else if (_errorAsistencia != null)
          Text('No se pudo cargar la lista de usuarios: $_errorAsistencia', style: const TextStyle(color: AppColors.rojoAlerta))
        else if (_usuarios.isEmpty)
          const Text('No hay usuarios registrados en tu compañía.', style: TextStyle(color: AppColors.textoSecundario))
        else ...[
          TextField(
            decoration: _decoracion('Buscar por nombre o N° de voluntario').copyWith(prefixIcon: const Icon(Icons.search)),
            onChanged: (v) => setState(() => _busqueda = v),
          ),
          const SizedBox(height: 8),
          if (_carros.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Aún no hay carros creados. Créalos en "Inventario de Carros" para poder asignarlos.', style: TextStyle(color: AppColors.rojoAlerta, fontSize: 12)),
            ),
          ...visibles.map((u) {
            final id = u['id'].toString();
            final presente = _presentes.contains(id);
            final numero = _numeroCompletoDe(u);
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: presente ? AppColors.verde.withOpacity(0.08) : Colors.white,
                border: Border.all(color: presente ? AppColors.verde : AppColors.bordeCampo),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  CheckboxListTile(
                    value: presente,
                    activeColor: AppColors.verde,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(_nombreDe(u), style: const TextStyle(color: AppColors.textoPrincipal)),
                    subtitle: numero.isEmpty ? null : Text('N° voluntario/maquinista: $numero', style: const TextStyle(fontSize: 12)),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _presentes.add(id);
                      } else {
                        _presentes.remove(id);
                        _carroPorUsuario.remove(id);
                      }
                    }),
                  ),
                  if (presente)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: DropdownButtonFormField<String>(
                        value: _carroPorUsuario[id],
                        decoration: _decoracion('Carro *'),
                        items: _carros
                            .map((c) => DropdownMenuItem<String>(value: c['nombre'].toString(), child: Text(c['nombre'].toString())))
                            .toList(),
                        onChanged: (v) => setState(() {
                          if (v != null) _carroPorUsuario[id] = v;
                        }),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
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
        title: const Text('Parte de Servicio'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Los campos con * son obligatorios.', style: TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
            ),

            _tarjeta(
              titulo: 'Datos del servicio',
              children: [
                _campoSeleccion(_fecha, 'Fecha', _elegirFecha),
                const SizedBox(height: 12),
                _par(_campo(_unidad, 'Unidad'), _campo(_nombre, 'Nombre')),
                _par(_campo(_servicio, 'Servicio'), _campo(_rut, 'RUT')),
                _par(_campo(_direccion, 'Dirección'), _campo(_nroObac, 'N° OBAC', requerido: false)),
                _par(_campo(_odoInicial, 'Odómetro inicial', tipo: TextInputType.number), _campo(_odoFinal, 'Odómetro final', tipo: TextInputType.number)),
                _par(_campoSeleccion(_horaSalida, 'Hora salida', () => _elegirHora(_horaSalida)), _campoSeleccion(_horaLlegada, 'Hora llegada', () => _elegirHora(_horaLlegada))),
                _campo(_clave60, '6-0', requerido: false),
              ],
            ),

            _tarjeta(
              titulo: 'En el lugar *',
              subtitulo: 'Instituciones presentes en la emergencia.',
              onAgregar: () => setState(() => _instituciones.add(_FilaInstitucion())),
              textoAgregar: 'Agregar institución',
              children: [for (var i = 0; i < _instituciones.length; i++) _filaInstitucion(i)],
            ),

            _tarjeta(
              titulo: 'Relato de la emergencia *',
              children: [_campo(_relato, 'Describe lo ocurrido', maxLineas: 8)],
            ),

            _tarjeta(
              titulo: 'Datos de afectados *',
              subtitulo: 'Nombres, RUT, patentes, número DIR, S.A. o AMB de traslado, etc. Si no hubo, escribe "Sin afectados".',
              children: [_campo(_afectados, 'Afectados', maxLineas: 4)],
            ),

            _tarjeta(
              titulo: 'Testigos voluntarios (opcional)',
              subtitulo: 'Recuerda: los testigos deben ser voluntarios, no pueden ser grabados sin su autorización directa, y si son menores de edad debe estar presente su tutor legal.',
              onAgregar: () => setState(() => _testigos.add(_FilaTestigo())),
              textoAgregar: 'Agregar testigo',
              children: [
                for (var i = 0; i < _testigos.length; i++) _filaTestigo(i),
                const SizedBox(height: 4),
                _campo(_declaracion, 'Declaración de testigos', requerido: false, maxLineas: 6),
              ],
            ),

            _seccionCroquis(),

            _seccionAsistencia(),

            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_guardando ? 'Guardando...' : 'Guardar Parte de Servicio'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.rojo, padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
