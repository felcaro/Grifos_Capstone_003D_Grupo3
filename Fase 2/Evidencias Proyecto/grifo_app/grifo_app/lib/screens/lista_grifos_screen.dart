import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ListaGrifosScreen extends StatefulWidget {
  const ListaGrifosScreen({super.key});

  @override
  State<ListaGrifosScreen> createState() => _ListaGrifosScreenState();
}

class _ListaGrifosScreenState extends State<ListaGrifosScreen> {
  // Aquí controlamos qué estado se está filtrando en la lista
  String estadoFiltro = 'operativo'; 

  // --- ESTA ES LA FUNCIÓN DEL MODAL QUE SE ABRE AL TOCAR UN GRIFO ---
  void mostrarDetalleReporte(BuildContext context, Map<String, dynamic> grifo) {
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
          ),
          // ENVOLVEMOS EL CONTENIDO EN UN TAMAÑO MÁXIMO PARA QUE NO COLAPSE
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


  // --- ESTE ES EL DISEÑO DE LA PANTALLA PRINCIPAL ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estado de Grifos'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. El menú desplegable para elegir el estado
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Text('Filtrar por: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: estadoFiltro,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'operativo', child: Text('✅ Operativos')),
                      DropdownMenuItem(value: 'con_falla', child: Text('⚠️ Con Falla')),
                      DropdownMenuItem(value: 'obstruido', child: Text('🚧 Obstruidos')),
                      DropdownMenuItem(value: 'inhabilitado', child: Text('❌ Inhabilitados')),
                    ],
                    onChanged: (valor) {
                      if (valor != null) {
                        setState(() => estadoFiltro = valor); // Esto recarga la lista
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // 2. La lista que trae los grifos desde Supabase usando FutureBuilder
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: Supabase.instance.client
                  .from('grifo')
                  .select()
                  .eq('estado', estadoFiltro), // Filtra por el estado seleccionado
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                // Si hay un error de permisos o de conexión, lo mostrará en pantalla
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                }
                
                final grifos = snapshot.data ?? [];

                if (grifos.isEmpty) {
                  return const Center(child: Text('No hay grifos en este estado.'));
                }

                return ListView.builder(
                  itemCount: grifos.length,
                  itemBuilder: (context, index) {
                    final grifo = grifos[index] as Map<String, dynamic>;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          Icons.water_drop, 
                          color: estadoFiltro == 'operativo' ? Colors.green : Colors.red
                        ),
                        title: Text('Nodo OSM: ${grifo['nodo_osm'] ?? grifo['direccion_referencial'] ?? 'Sin ID'}'),
                        subtitle: Text('Estado: ${grifo['estado']}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // Al tocar la fila, se abre el modal
                          mostrarDetalleReporte(context, grifo);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
