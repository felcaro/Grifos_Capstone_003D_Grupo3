import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class ListaGrifosScreen extends StatefulWidget {
  const ListaGrifosScreen({super.key});

  @override
  State<ListaGrifosScreen> createState() => _ListaGrifosScreenState();
}

class _ListaGrifosScreenState extends State<ListaGrifosScreen> {
  final SupabaseService supabaseService = SupabaseService();

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
                        await supabaseService.actualizarEstadoGrifo(
                          grifoData['id'].toString(),
                          estadoSeleccionado,
                          detalleController.text.trim(),
                        );
                        if (mounted) {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('¡Estado y reporte actualizados con éxito! ✅')),
                          );
                          setState(() {}); // Recarga las listas de grifos
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Dos pestañas: Operativos e Inhabilitados
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Estado de Grifos'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.check_circle, color: Colors.green), text: 'Operativos'),
              Tab(icon: Icon(Icons.cancel, color: Colors.red), text: 'Inhabilitados'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Pestaña 1: Operativos
            FutureBuilder<List<dynamic>>(
              future: supabaseService.obtenerGrifosOperativos(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No hay grifos operativos'));
                }
                final grifos = snapshot.data!;
                return ListView.builder(
                  itemCount: grifos.length,
                  itemBuilder: (context, index) {
                    final item = grifos[index] as Map<String, dynamic>;
                    final direccion = item['direccion_referencial'];
                    return ListTile(
                      title: Text('Grifo: ${item['id']}'),
                      subtitle: Text(direccion != null && direccion.toString().isNotEmpty
                          ? 'Estado: Operativo • $direccion'
                          : 'Estado: Operativo'),
                      leading: const Icon(Icons.water_drop, color: Colors.green),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () => _mostrarDetalleGrifo(item),
                    );
                  },
                );
              },
            ),

            // Pestaña 2: Inhabilitados
            FutureBuilder<List<dynamic>>(
              future: supabaseService.obtenerGrifosInhabilitados(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No hay grifos inhabilitados'));
                }
                final grifos = snapshot.data!;
                return ListView.builder(
                  itemCount: grifos.length,
                  itemBuilder: (context, index) {
                    final item = grifos[index] as Map<String, dynamic>;
                    final direccion = item['direccion_referencial'];
                    return ListTile(
                      title: Text('Grifo: ${item['id']}'),
                      subtitle: Text(direccion != null && direccion.toString().isNotEmpty
                          ? 'Estado: Inhabilitado • $direccion'
                          : 'Estado: Inhabilitado'),
                      leading: const Icon(Icons.water_drop, color: Colors.red),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () => _mostrarDetalleGrifo(item),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
