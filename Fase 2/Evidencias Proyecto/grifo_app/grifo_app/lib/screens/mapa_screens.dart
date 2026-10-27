import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/supabase_service.dart';
import '../services/auth_service.dart';
import '../screens/tesoreria_screen.dart'; // Si está en lib/ ajusta la ruta
import '../screens/acta_form_screen.dart';
import '../screens/inventario_carro_screen.dart';
import '../screens/lista_grifos_screen.dart';
import '../screens/personal_screen.dart';
import '../screens/admin_usuarios_screen.dart';
// [MODULO_EPP_COMENTADO] Descomentar la siguiente línea cuando se implemente lib/services/entrega_epp_pdf_service.dart
// import '../screens/entrega_epp_form_screen.dart';

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

  // Controlador de Google Maps para mover la cámara y centrar el grifo encontrado
  GoogleMapController? _mapController;

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
              infoWindow: InfoWindow.noText,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
              // Al tocar el pin, guardamos su ID y abrimos el panel de detalle
              onTap: () {
                setState(() {
                  _grifoSeleccionadoId = grifo['id'].toString();
                });
                _mostrarDetalleGrifo(grifo);
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
                // CAMBIO AQUÍ: Llamando al nuevo nombre insertarGrifo
                await _dbService.insertarGrifo(
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

  // Panel inferior con el diseño moderno del detalle del grifo
  void _mostrarDetalleGrifo(Map<String, dynamic> grifoData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            // Bordes redondeados arriba si es un BottomSheet
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min, // Para que ocupe solo lo necesario
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Encabezado con título y botón de cerrar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Detalle del Grifo',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context), // Cierra la ventana
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 10),

                // 2. Dirección con ícono
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, color: Colors.blueGrey, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        // Asegúrate de usar la variable correcta de tu base de datos
                        grifoData['direccion_referencial'] ?? 'Dirección no especificada',
                        style: const TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 3. Nodo OSM con ícono
                Row(
                  children: [
                    const Icon(Icons.map, color: Colors.blueGrey, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Nodo OSM: ${grifoData['nodo_osm'] ?? 'Sin nodo'}',
                      style: const TextStyle(fontSize: 15, color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 4. Estado convertido en un "Badge" (Pastilla visual)
                Row(
                  children: [
                    const Text(
                      'Estado actual:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        // Fondo clarito dependiendo del estado
                        color: (grifoData['estado'] == 'operativo' ? Colors.green : Colors.red).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        // Borde del color principal
                        border: Border.all(
                          color: grifoData['estado'] == 'operativo' ? Colors.green : Colors.red,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        (grifoData['estado'] ?? 'DESCONOCIDO').toString().toUpperCase(),
                        style: TextStyle(
                          color: grifoData['estado'] == 'operativo' ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // 5. Botón modernizado
                SizedBox(
                  width: double.infinity,
                  height: 55, // Más alto para que se vea premium
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.build_circle_outlined, size: 24),
                    label: const Text(
                      'Reportar / Modificar Estado',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent, // Un azul confiable en vez del rojo peligroso
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Cierra el bottom sheet
                      _mostrarDialogReporteEstado(grifoData); // Abre el diálogo para reportar
                    },
                  ),
                ),
                const SizedBox(height: 10), // Margen inferior
              ],
            ),
          ),
        );
      },
    );
  }

  // Diálogo para escribir el detalle del reporte y modificar estado del grifo
  void _mostrarDialogReporteEstado(Map<String, dynamic> grifoData) {
    String estadoSeleccionado = (grifoData['estado'] == 'inhabilitado') ? 'inhabilitado' : 'operativo';
    final detalleController = TextEditingController();
    bool guardando = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Modificar Estado / Reportar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grifo: ${grifoData['direccion_referencial'] ?? grifoData['id']}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Text('Nuevo Estado:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: estadoSeleccionado,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'operativo',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Text('Operativo'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'inhabilitado',
                      child: Row(
                        children: [
                          Icon(Icons.cancel, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Inhabilitado'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => estadoSeleccionado = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text('Detalle del trabajo / reporte:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                TextField(
                  controller: detalleController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Describe el trabajo realizado o la falla...',
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: guardando ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: guardando
                  ? null
                  : () async {
                      if (detalleController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Por favor escribe un detalle')),
                        );
                        return;
                      }
                      setDialogState(() => guardando = true);
                      try {
                        await _dbService.actualizarEstadoGrifo(
                          grifoData['id'].toString(),
                          estadoSeleccionado,
                          detalleController.text.trim(),
                        );
                        if (mounted) {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('¡Estado y reporte actualizados con éxito! ✅')),
                          );
                          await _cargarGrifos();
                        }
                      } catch (e) {
                        setDialogState(() => guardando = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error al actualizar: $e')),
                          );
                        }
                      }
                    },
              child: guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
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
  Future<void> _mostrarMenuPerfil() async {
    // Obtenemos el correo del usuario con el que se inició sesión (desde Supabase Auth o modo demo)
    final String emailUsuario = AuthService.currentEmail ?? 'test@gmail.com';

    // Perfil real (nombre y rol) para mostrarlo y decidir si ve la administración
    Map<String, dynamic>? perfil;
    try {
      perfil = await SupabaseService().obtenerMiPerfil();
    } catch (_) {
      perfil = null;
    }
    if (!mounted) return;
    final String rolPerfil = (perfil?['rol'] ?? '').toString().toLowerCase();
    final bool esAdmin = rolPerfil == 'administrador';
    final String nombrePerfil = (perfil?['nombre'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // permite que el panel crezca y se pueda desplazar
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            child: SingleChildScrollView(
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
              Text(
                perfil == null
                    ? 'Bombero - Melipilla'
                    : '${nombrePerfil.isNotEmpty ? nombrePerfil : 'Usuario'} · ${etiquetaRol(rolPerfil)}',
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
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
              // ============================================================================
              // ELEMENTO DE MENÚ: Acceso al módulo de Actas
              // ============================================================================
              ListTile(
                leading: const Icon(Icons.menu_book, color: Colors.red),
                title: const Text('Actas'),
                subtitle: const Text('Registrar acta de reunión de Directorio'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ActaFormScreen()),
                  );
                },
              ),
              // ============================================================================
              // ELEMENTO DE MENÚ: Acceso al módulo de Inventario de Carros
              // ============================================================================
              ListTile(
                leading: const Icon(Icons.fire_truck, color: Colors.red),
                title: const Text('Inventario de Carros'),
                subtitle: const Text('Material menor por compartimento'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const InventarioCarrosScreen()),
                  );
                },
              ),
              // ============================================================================
              // ELEMENTO DE MENÚ: Equipo del Personal (trajes y cosas personales)
              // ============================================================================
              ListTile(
                leading: const Icon(Icons.badge, color: Colors.red),
                title: const Text('Equipo del Personal'),
                subtitle: const Text('Trajes y equipo personal de cada bombero'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PersonalScreen()),
                  );
                },
              ),
              // ============================================================================
              // ELEMENTO DE MENÚ: Administración de usuarios (solo administradores)
              // ============================================================================
              if (esAdmin)
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings, color: Colors.red),
                  title: const Text('Administración'),
                  subtitle: const Text('Usuarios y roles de la compañía'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminUsuariosScreen()),
                    );
                  },
                ),
              // ============================================================================
              // ELEMENTO DE MENÚ: Acceso a Lista y Estado de Grifos
              // ============================================================================
              ListTile(
                leading: const Icon(Icons.water_drop, color: Colors.red),
                title: const Text('Estado de Grifos'),
                subtitle: const Text('Ver grifos operativos e inhabilitados'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ListaGrifosScreen()),
                  );
                },
              ),
              // ============================================================================
              // [MODULO_EPP_COMENTADO] Descomentar este bloque para reactivar la pantalla de EPP:
              // ============================================================================
              /*
              ListTile(
                leading: const Icon(Icons.checklist, color: Colors.red),
                title: const Text('Entrega de EPP'),
                subtitle: const Text('Registro de entrega de equipo de protección personal'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EntregaEppFormScreen()),
                  );
                },
              ),
              */
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
            ),
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

  // Mueve la cámara suavemente al grifo y lo deja seleccionado para acciones rápidas
  void _moverCamaraYSeleccionar(Map<String, dynamic> grifo) {
    final lat = double.parse(grifo['latitud'].toString());
    final lng = double.parse(grifo['longitud'].toString());
    final id = grifo['id'].toString();

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat, lng), 18.0),
    );

    setState(() {
      _grifoSeleccionadoId = id;
    });

    _mostrarDetalleGrifo(grifo);
  }

  // Despliega un panel inferior con la lista de resultados cuando hay 2 o más coincidencias
  void _mostrarListaResultados(List<Map<String, dynamic>> resultados) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Se adapta al contenido
            children: [
              const Text(
                'Grifos encontrados',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              // Flexible evita que la lista desborde la pantalla en caso de muchas coincidencias
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: resultados.length,
                  itemBuilder: (context, index) {
                    final grifo = resultados[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on, color: Colors.red),
                      title: Text(grifo['direccion_referencial'] ?? 'Sin dirección'),
                      subtitle: Text('Lat: ${grifo['latitud']} - Lng: ${grifo['longitud']}'),
                      onTap: () {
                        Navigator.pop(context); // Cerramos el panel
                        _moverCamaraYSeleccionar(grifo); // Viajamos al grifo tocado
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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
            // Capturamos el controlador apenas el mapa termina de cargar
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
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
                          
                          if (resultados.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No se encontraron grifos con esa dirección')),
                            );
                            return;
                          }

                          if (resultados.length == 1) {
                            // Si es solo uno, viajamos directo para ahorrar tiempo en la emergencia
                            _moverCamaraYSeleccionar(resultados.first);
                          } else {
                            // Si hay 2 o más, mostramos el panel para que el bombero elija
                            _mostrarListaResultados(resultados);
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
