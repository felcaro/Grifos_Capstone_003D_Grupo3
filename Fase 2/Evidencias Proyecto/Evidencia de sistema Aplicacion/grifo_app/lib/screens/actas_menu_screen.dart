import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../utils/permisos.dart';
import 'acta_form_screen.dart';
import 'parte_servicio_form_screen.dart';

/// Punto de entrada del módulo Actas: elegir qué documento rellenar
/// y ver los ya guardados.
class ActasMenuScreen extends StatefulWidget {
  const ActasMenuScreen({super.key});

  @override
  State<ActasMenuScreen> createState() => _ActasMenuScreenState();
}

class _ActasMenuScreenState extends State<ActasMenuScreen> {
  final _db = SupabaseService();
  late Future<List<Map<String, dynamic>>> _actasFuture;
  Permisos _permisos = Permisos.deRol(null); // restringido hasta cargar el rol real

  @override
  void initState() {
    super.initState();
    _actasFuture = _db.obtenerActas();
    Permisos.cargar().then((p) {
      if (mounted) setState(() => _permisos = p);
    });
  }

  void _recargar() => setState(() => _actasFuture = _db.obtenerActas());

  Future<void> _abrir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    if (mounted) _recargar(); // al volver, refresca la lista
  }

  Future<void> _abrirPdf(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el PDF')));
    }
  }

  Widget _opcion({required IconData icono, required String titulo, required String detalle, required VoidCallback onTap}) {
    return Card(
      color: AppColors.tarjeta,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(backgroundColor: AppColors.rojo, child: Icon(icono, color: Colors.white)),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textoPrincipal)),
        subtitle: Text(detalle, style: const TextStyle(color: AppColors.textoSecundario)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textoSecundario),
        onTap: onTap,
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
        title: const Text('Actas'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _recargar(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(_permisos.verActaDirectorio ? '¿Qué acta quieres rellenar?' : 'Parte de servicio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textoPrincipal)),
            const SizedBox(height: 10),
            _opcion(
              icono: Icons.description,
              titulo: 'Parte de Servicio',
              detalle: 'Registro de una emergencia o servicio',
              onTap: () => _abrir(const ParteServicioFormScreen()),
            ),
            if (_permisos.verActaDirectorio) ...[
              const SizedBox(height: 10),
              _opcion(
                icono: Icons.menu_book,
                titulo: 'Acta de Reunión de Directorio',
                detalle: 'Asistentes, acuerdos y firmas',
                onTap: () => _abrir(const ActaFormScreen()),
              ),
            ],
            const SizedBox(height: 24),
            const Text('Actas guardadas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textoPrincipal)),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _actasFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: AppColors.rojo)));
                }
                if (snapshot.hasError) {
                  return Text('No se pudieron cargar las actas: ${snapshot.error}', style: const TextStyle(color: AppColors.rojoAlerta));
                }
                var actas = snapshot.data ?? [];
                if (!_permisos.verTodasLasActas) {
                  // El bombero solo ve los partes de servicio
                  actas = actas.where((a) => (a['titulo'] ?? '').toString().startsWith('Parte de Servicio')).toList();
                }
                if (actas.isEmpty) {
                  return const Text('Aún no hay actas guardadas.', style: TextStyle(color: AppColors.textoSecundario));
                }
                return Column(
                  children: actas.map((a) {
                    final url = a['archivo_url']?.toString() ?? '';
                    return Card(
                      color: Colors.white,
                      child: ListTile(
                        leading: const Icon(Icons.picture_as_pdf, color: AppColors.rojo),
                        title: Text(a['titulo']?.toString() ?? 'Sin título'),
                        subtitle: Text(a['fecha_reunion']?.toString() ?? ''),
                        trailing: const Icon(Icons.open_in_new, size: 18),
                        onTap: url.isEmpty ? null : () => _abrirPdf(url),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
