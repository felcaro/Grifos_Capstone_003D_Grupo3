import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/supabase_service.dart';
import '../services/auth_service.dart';
import '../screens/tesoreria_screen.dart'; // Si está en lib/ ajusta la ruta

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

  // Controlador de texto para el buscador
  final TextEditingController _controladorBusqueda = TextEditingController();

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
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
              // NUEVO: Al tocar el pin, guardamos su ID para saber cuál editar
              onTap: () {
                setState(() {
                  _grifoSeleccionadoId = grifo['id'].toString();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Grifo seleccionado. Ya puedes editarlo.'),
                    duration: Duration(seconds: 2),
                  ),
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
            TextField(
              controller: latController,
              decoration: const InputDecoration(labelText: 'Latitud'),
            ),
            TextField(
              controller: lngController,
              decoration: const InputDecoration(labelText: 'Longitud'),
            ),
            TextField(
              controller: dirController,
              decoration: const InputDecoration(
                labelText: 'Dirección Referencial',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('¡Grifo subido! 🚒')),
                  );
                  _cargarGrifos();
                }
              } catch (e) {
                if (context.mounted){
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
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
    final grifoActual = _listaGrifos.firstWhere(
      (g) => g['id'].toString() == _grifoSeleccionadoId,
    );

    final latController = TextEditingController(
      text: grifoActual['latitud'].toString(),
    );
    final lngController = TextEditingController(
      text: grifoActual['longitud'].toString(),
    );
    final dirController = TextEditingController(
      text: grifoActual['direccion_referencial']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modificar Grifo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latController,
              decoration: const InputDecoration(labelText: 'Latitud'),
            ),
            TextField(
              controller: lngController,
              decoration: const InputDecoration(labelText: 'Longitud'),
            ),
            TextField(
              controller: dirController,
              decoration: const InputDecoration(
                labelText: 'Dirección Referencial',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('¡Grifo actualizado! 🛠️')),
                  );
                  setState(
                    () => _grifoSeleccionadoId = null,
                  ); // Limpiamos la selección
                  _cargarGrifos(); // Recargamos el mapa
                }
              } catch (e) {
                if (context.mounted){
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  // Función para abrir Google Maps / Waze con la ruta hacia el grifo
  Future<void> _abrirRutaEnMaps() async {
    if (_grifoSeleccionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero selecciona un grifo en el mapa para ir'),
        ),
      );
      return;
    }

    // Buscamos las coordenadas del grifo que está seleccionado actualmente
    final grifoActual = _listaGrifos.firstWhere(
      (g) => g['id'].toString() == _grifoSeleccionadoId,
    );
    final lat = grifoActual['latitud'];
    final lng = grifoActual['longitud'];

    // Esta URL es universal: en web abre una pestaña nueva y en celular abre la app de Google Maps
    final Uri url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );

    try {
      if (await canLaunchUrl(url)) {
        // externalApplication fuerza a que salga de tu app y abra el Maps nativo
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir la ruta';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir Google Maps en este dispositivo'),
          ),
        );
      }
    }
  }

  // ===========================================================================
  // 1. FUNCIONES DEL PERFIL Y CONFIRMACIÓN DE CIERRE DE SESIÓN
  // ===========================================================================

  // Función para mostrar el panel de perfil inferior (ModalBottomSheet)
  void _mostrarMenuPerfil() {
    // Obtenemos el correo del usuario con el que se inició sesión (desde Supabase Auth o modo demo)
    final String emailUsuario = AuthService.currentEmail ?? 'test@gmail.com';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Se adapta al contenido
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: Colors.red,
                child: Icon(Icons.local_fire_department, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 15),
              // Mostramos el usuario/correo con el que se conectó
              Text(
                emailUsuario,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text('Bombero - Melipilla', style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 20),
              const Divider(),
              // ============================================================================
              // ELEMENTO DE MENÚ: Acceso al módulo de Tesorería
              // ============================================================================
              ListTile(
                leading: const Icon(Icons.account_balance_wallet, color: Colors.red),
                title: const Text('Tesorería'),
                subtitle: const Text('Rendición de cuentas e ingresos/gastos'),
                onTap: () {
                  // 1. Cierra el menú lateral (Drawer)
                  Navigator.pop(context); 

                  // 2. Navega hacia la pantalla de Tesorería
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TesoreriaScreen()),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Cerrar Sesión', 
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
                ),
                onTap: () async {
                  Navigator.pop(context); // Cierra el modal
                  await AuthService.signOut(); // o Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    // Redirige al Login
                    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                },
              ),

              // ============================================================================
            ],
          ),
        );
      },
    );
  }

  // Alerta de confirmación para salir
  void confirmarCerrarSesion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Cancela la acción
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              // Cierra el diálogo de confirmación
              Navigator.pop(context); 
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sesión cerrada correctamente')),
              );
              // Cierra la sesión en Supabase y redirige a Login automáticamente vía AuthGate
              await AuthService.signOut();
            },
            child: const Text('Salir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildItemInferior({
    required IconData icono,
    required Color colorIcono,
    required String etiqueta,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: colorIcono, size: 26),
            const SizedBox(height: 4),
            Text(
              etiqueta,
              style: TextStyle(
                color: colorIcono == Colors.blueAccent
                    ? Colors.blueAccent
                    : Colors.grey.shade300,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
          // 2. LA BARRA DE BÚSQUEDA Y EL PERFIL
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // El buscador ocupa todo el espacio que sobra
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
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
                        onSubmitted: (valor) async {
                          if (valor.trim().isEmpty) return;
                          final resultados = await _dbService.buscarGrifoPorDireccion(valor);
                          if (!context.mounted) return;
                          if (resultados.isNotEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Grifo encontrado en: ${resultados.first['direccion_referencial']}',
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No se encontraron grifos')),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10), // Espacio entre el buscador y la foto
                  // NUEVO: Ícono del perfil del Bombero (abre el menú inferior)
                  GestureDetector(
                    onTap: _mostrarMenuPerfil,
                    child: const CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.red,
                      child: Icon(Icons.person, color: Colors.white, size: 30),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // Barra inferior con diseño moderno, bordes redondeados superiores, sombra y texto descriptivo
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Botón Agregar
                _buildItemInferior(
                  icono: Icons.add_location_alt_rounded,
                  colorIcono: Colors.white,
                  etiqueta: 'Agregar',
                  onTap: _mostrarFormularioGrifo,
                ),
                // Botón Editar
                _buildItemInferior(
                  icono: Icons.edit_location_alt_rounded,
                  colorIcono: Colors.white,
                  etiqueta: 'Editar',
                  onTap: () {
                    if (_grifoSeleccionadoId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Primero toca un grifo en el mapa'),
                        ),
                      );
                    } else {
                      _mostrarFormularioEdicion();
                    }
                  },
                ),
                // Botón para Ir al grifo (Ruta)
                _buildItemInferior(
                  icono: Icons.directions_car_rounded,
                  colorIcono: Colors.blueAccent,
                  etiqueta: 'Ruta',
                  onTap: _abrirRutaEnMaps,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
