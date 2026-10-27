import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  void _mostrarFormularioEdicion([Map<String, dynamic>? grifo]) {
    // Buscamos los datos del grifo seleccionado para rellenar los campos de texto
    final grifoActual = grifo ?? _listaGrifos.firstWhere(
      (g) => g['id'].toString() == _grifoSeleccionadoId,
    );
    final idGrifo = grifoActual['id'].toString();


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
                  idGrifo,
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

                // Puedes poner esto dentro del Column() de tu diseño de detalles
                const Text('Estado Actual:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                FutureBuilder<String>(
                  future: obtenerEstadoGrifo(grifoData['id'].toString()), // Asegúrate de pasarle el ID del grifo
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      // Mientras carga desde Supabase, muestra un circulito pequeño
                      return const SizedBox(
                        width: 16, 
                        height: 16, 
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    
                    final estadoActual = snapshot.data ?? 'Desconocido';
                    
                    // Aquí puedes cambiar el color del texto dependiendo del estado si quieres
                    Color colorEstado = Colors.black;
                    if (estadoActual == 'operativo') colorEstado = Colors.green;
                    if (estadoActual == 'con_falla' || estadoActual == 'inhabilitado') colorEstado = Colors.red;
                    if (estadoActual == 'obstruido') colorEstado = Colors.orange;

                    return Text(
                      estadoActual.toUpperCase(), 
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        color: colorEstado,
                        fontSize: 16,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16), // Espacio antes del siguiente elemento

                // 5. Botones de acción (Ir ruta, Modificar, Reporte)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 1. Botón Ir ruta
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          final lat = grifoData['latitud'];
                          final lng = grifoData['longitud'];
                          if (lat != null && lng != null) {
                            final Uri url = Uri.parse(
                              'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
                            );
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          } else {
                            _abrirRutaEnMaps();
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Colors.black, width: 2), // Borde negro grueso como en el diseño
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        child: const Text('Ir ruta', style: TextStyle(color: Colors.black, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8), // Espaciador central
                    
                    // 2. Botón Modificar (Para el grifo)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context); // Cierra el bottom sheet
                          _mostrarFormularioEdicion(grifoData); // Lógica para editar la información base del grifo
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Colors.black, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        child: const Text('Modificar', style: TextStyle(color: Colors.black, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8), // Espaciador central
                    
                    // 3. Botón Reporte (Crear falla con foto)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context); // Cierra el bottom sheet
                          // Conectamos la función para subir la foto y el detalle del reporte
                          mostrarModalReporte(
                            context,
                            (grifoData['nodo_osm'] ?? grifoData['direccion_referencial'] ?? grifoData['id']).toString(),
                            grifoData['id'].toString(),
                            onActualizado: _cargarGrifos,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Colors.black, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        child: const Text('Reporte', style: TextStyle(color: Colors.black, fontSize: 13)),
                      ),
                    ),

                  ],
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
    mostrarModalReporte(
      context,
      (grifoData['nodo_osm'] ?? grifoData['direccion_referencial'] ?? grifoData['id']).toString(),
      grifoData['id'].toString(),
      onActualizado: _cargarGrifos,
    );
  }

  // Diálogo para ver el detalle o historial del reporte
  void _mostrarDetalleReporte(Map<String, dynamic> grifo) {
    final estadoActual = grifo['estado'] ?? 'operativo';
    final ultimaRevision = grifo['ultima_revision'] != null 
        ? DateTime.tryParse(grifo['ultima_revision'].toString())?.toLocal().toString().split('.')[0] ?? 'Sin revisión'
        : 'Sin revisión registrada';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF5E6E6),
          title: Text(
            'Nodo OSM: ${grifo['nodo_osm'] ?? grifo['id'] ?? ''}', 
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder(
              future: Supabase.instance.client
                  .from('reporte_falla')
                  .select()
                  .eq('grifo_id', grifo['id'])
                  .order('fecha_creacion', ascending: false)
                  .limit(1)
                  .maybeSingle(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
                }

                if (snapshot.hasError) {
                  return Text('Error al cargar reporte: ${snapshot.error}', style: const TextStyle(color: Colors.red));
                }

                final reporte = snapshot.data;

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estado actual: ${estadoActual.toString().toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Divider(),

                      if (estadoActual == 'operativo') ...[
                        Text('Última revisión: $ultimaRevision', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (reporte != null) ...[
                          const Text('Falla anterior solucionada:', style: TextStyle(color: Colors.grey)),
                          Text('Tipo: ${reporte['tipo_falla']}'),
                        ] else 
                          const Text('No tiene fallas históricas registradas.'),
                      ] else ...[
                        if (reporte != null) ...[
                          const Text('Detalle de la falla actual:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Tipo: ${reporte['tipo_falla']}'),
                          Text('Observación: ${reporte['detalle'] ?? 'Sin detalle'}'),
                          const SizedBox(height: 12),
                          
                          if (reporte['foto_url'] != null) ...[
                            const Text('Fotografía del problema:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                reporte['foto_url'].toString().startsWith('http')
                                    ? reporte['foto_url'].toString()
                                    : Supabase.instance.client.storage.from('fotos_reportes').getPublicUrl(reporte['foto_url']),
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ] else
                            const Text('No se adjuntó fotografía en este reporte.', style: TextStyle(color: Colors.red)),
                        ] else
                          const Text('El grifo está marcado con falla pero no tiene reporte asociado.'),
                      ]
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar', style: TextStyle(color: Colors.black)),
            )
          ],
        );
      },
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

  Future<void> _mostrarMenuPerfil() async {
    // Obtenemos el correo del usuario con el que se inició sesión en Supabase
    final String emailUsuario = AuthService.currentEmail ?? 'Usuario';

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

void mostrarModalReporte(
  BuildContext context,
  String nodoOsm,
  String grifoId, {
  VoidCallback? onActualizado,
}) {
  String estadoSeleccionado = 'operativo'; 
  final TextEditingController detalleController = TextEditingController();
  XFile? fotoSeleccionada;
  final ImagePicker picker = ImagePicker();
  bool guardando = false;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFF5E6E6),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Modificar Estado / Reportar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Text('Grifo: Nodo OSM: $nodoOsm', style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nuevo Estado:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: estadoSeleccionado,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'operativo', child: Text('Operativo')),
                      DropdownMenuItem(value: 'con_falla', child: Text('Con Falla')),
                      DropdownMenuItem(value: 'obstruido', child: Text('Obstruido')),
                      DropdownMenuItem(value: 'inhabilitado', child: Text('Inhabilitado')),
                    ],
                    onChanged: (val) => setState(() => estadoSeleccionado = val!),
                  ),
                  const SizedBox(height: 16),
                  
                  const Text('Detalle del trabajo / reporte:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: detalleController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Describe el trabajo realizado o la falla...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botones para la foto
                  const Text('Adjuntar fotografía:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('Cámara'),
                        onPressed: () async {
                          final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                          if (image != null) {
                            setState(() => fotoSeleccionada = image);
                          }
                        },
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: const Text('Galería'),
                        onPressed: () async {
                          final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                          if (image != null) {
                            setState(() => fotoSeleccionada = image);
                          }
                        },
                      ),
                    ],
                  ),
                  
                  // Indicador visual si la foto se cargó
                  if (fotoSeleccionada != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text('Foto adjunta', style: TextStyle(color: Colors.green)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => setState(() => fotoSeleccionada = null),
                        )
                      ],
                    )
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: guardando ? null : () => Navigator.pop(context),
                child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: guardando ? null : () async {
                  setState(() => guardando = true);
                  
                  try {
                    await actualizarEstadoYReportar(
                      grifoId: grifoId,
                      nuevoEstado: estadoSeleccionado,
                      detalle: detalleController.text,
                      fotoXFile: fotoSeleccionada,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      onActualizado?.call();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('¡Estado y reporte actualizados con éxito! ✅')),
                      );
                    }
                  } catch (e) {
                    setState(() => guardando = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al guardar: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: guardando 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Guardar', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      );
    },
  );
}

