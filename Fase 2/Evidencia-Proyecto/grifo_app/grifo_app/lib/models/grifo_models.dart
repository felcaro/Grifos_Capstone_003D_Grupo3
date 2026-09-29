import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/supabase_service.dart';

class MapaPrincipal extends StatefulWidget {
  const MapaPrincipal({super.key});

  @override
  State<MapaPrincipal> createState() => _MapaPrincipalState();
}

class _MapaPrincipalState extends State<MapaPrincipal> {
  final SupabaseService _dbService = SupabaseService();
  
  static const CameraPosition _posicionInicial = CameraPosition(
    target: LatLng(-33.6890, -71.2150),
    zoom: 16.5,
  );

  final TextEditingController _controladorBusqueda = TextEditingController(text: 'Ortúzar');

  Set<Marker> _marcadores = {};
  
  // NUEVO: Guardamos los datos crudos y el ID del grifo que el usuario toque
  List<Map<String, dynamic>> _listaGrifos = [];
  String? _grifoSeleccionadoId;

  @override
  void initState() {
    super.initState();
    _cargarGrifos();
  }

  @override
  void dispose() {
    _controladorBusqueda.dispose();
    super.dispose();
  }

  Future<void> _cargarGrifos() async {
    try {
      final grifos = await _dbService.obtenerGrifos();
      final Set<Marker> nuevosMarcadores = {};

      for (var grifo in grifos) {
        if (grifo['latitud'] != null && grifo['longitud'] != null) {
          nuevosMarcadores.add(
            Marker(
              markerId: MarkerId(grifo['id'].toString()),
              position: LatLng(
                double.parse(grifo['latitud'].toString()),
                double.parse(grifo['longitud'].toString()),
              ),
              infoWindow: InfoWindow(
                title: 'Grifo',
                snippet: grifo['direccion_referencial'] ?? 'Sin dirección',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              // NUEVO: Al tocar el pin, guardamos su ID para saber cuál editar
              onTap: () {
                setState(() {
                  _grifoSeleccionadoId = grifo['id'].toString();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Grifo seleccionado. Ya puedes editarlo.'), duration: Duration(seconds: 2)),
                );
              },
            ),
          );
        }
      }

      setState(() {
        _listaGrifos = grifos;
        _marcadores = nuevosMarcadores;
      });
    } catch (e) {
      print('Error al cargar grifos: $e');
    }
  }

  void _mostrarFormularioGrifo() {
    final latController = TextEditingController(text: '-33.6890');
    final lngController = TextEditingController(text: '-71.2150');
    final dirController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Nuevo Grifo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: latController, decoration: const InputDecoration(labelText: 'Latitud')),
            TextField(controller: lngController, decoration: const InputDecoration(labelText: 'Longitud')),
            TextField(controller: dirController, decoration: const InputDecoration(labelText: 'Dirección Referencial')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _dbService.insertarGrifoPrueba(
                  double.parse(latController.text),
                  double.parse(lngController.text),
                  dirController.text,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Grifo subido! 🚒')));
                  _cargarGrifos(); 
                }
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // NUEVO: Formulario para editar un grifo existente
  void _mostrarFormularioEdicion() {
    // Buscamos los datos del grifo seleccionado para rellenar los campos de texto
    final grifoActual = _listaGrifos.firstWhere((g) => g['id'].toString() == _grifoSeleccionadoId);
    
    final latController = TextEditingController(text: grifoActual['latitud'].toString());
    final lngController = TextEditingController(text: grifoActual['longitud'].toString());
    final dirController = TextEditingController(text: grifoActual['direccion_referencial']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modificar Grifo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: latController, decoration: const InputDecoration(labelText: 'Latitud')),
            TextField(controller: lngController, decoration: const InputDecoration(labelText: 'Longitud')),
            TextField(controller: dirController, decoration: const InputDecoration(labelText: 'Dirección Referencial')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _dbService.actualizarGrifo(
                  _grifoSeleccionadoId!,
                  double.parse(latController.text),
                  double.parse(lngController.text),
                  dirController.text,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Grifo actualizado! 🛠️')));
                  setState(() => _grifoSeleccionadoId = null); // Limpiamos la selección
                  _cargarGrifos(); // Recargamos el mapa
                }
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _posicionInicial,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: _marcadores,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _controladorBusqueda,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: const InputDecoration(
                    hintText: 'Buscar...',
                    hintStyle: TextStyle(color: Colors.grey),
                    prefixIcon: Icon(Icons.search, color: Colors.white),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      
      // NUEVO: La barra inferior ahora tiene los botones funcionales
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF1E1E1E),
        height: 60,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Botón Agregar
            IconButton(
              icon: const Icon(Icons.add_location_alt, color: Colors.white, size: 28),
              onPressed: _mostrarFormularioGrifo,
            ),
            // Botón Editar
            IconButton(
              icon: const Icon(Icons.edit_location_alt, color: Colors.white, size: 28),
              onPressed: () {
                if (_grifoSeleccionadoId == null) {
                  // Si no ha tocado un pin, le avisamos
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Primero toca un grifo en el mapa para seleccionarlo')),
                  );
                } else {
                  // Si ya seleccionó uno, abrimos el formulario
                  _mostrarFormularioEdicion();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}