import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ListaGrifosScreen extends StatefulWidget {
  const ListaGrifosScreen({super.key});

  @override
  State<ListaGrifosScreen> createState() => _ListaGrifosScreenState();
}

class _ListaGrifosScreenState extends State<ListaGrifosScreen> {
  // Variables de control para los filtros
  String estadoFiltro = 'todos'; 
  String ordenFiltro = 'nuevos'; // 'nuevos' o 'viejos'
  bool _modalAbierto = false;

  // --- FUNCIÓN DEL MODAL (Queda igual, ya funciona perfecto) ---
  Future<void> mostrarDetalleReporte(BuildContext context, Map<String, dynamic> grifo) async {
    if (_modalAbierto) return;
    _modalAbierto = true;
    try {
      final estadoActual = grifo['estado'] ?? 'operativo';
      final ultimaRevision = grifo['ultima_revision'] != null 
          ? DateTime.tryParse(grifo['ultima_revision'].toString())?.toLocal().toString().split('.')[0] ?? 'Sin revisión'
          : 'Sin revisión registrada';

      final direccionRaw = grifo['direccion_referencial']?.toString() ?? 'Sin dirección';
      final direccionLimpia = direccionRaw.replaceAll('Nodo OSM: ', '').trim();

      await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF5E6E6),
          title: Text(
            direccionLimpia, 
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
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
  } finally {
    if (mounted) _modalAbierto = false;
  }
}

  // --- FUNCIÓN PARA ARMAR LA CONSULTA A SUPABASE DINÁMICAMENTE ---
  Future<List<dynamic>> _obtenerGrifosFiltrados() {
    // 1. Iniciamos la consulta base
    var query = Supabase.instance.client.from('grifo').select();
    
    // 2. Si el filtro no es 'todos', aplicamos el filtro de estado
    if (estadoFiltro != 'todos') {
      query = query.eq('estado', estadoFiltro);
    }
    
    // 3. Aplicamos el orden. 
    // NOTA: Usa 'id' si tus IDs son números (1, 2, 3...). 
    // Si tus IDs son textos raros (UUID), cambia 'id' por 'created_at'
    return query.order('id', ascending: ordenFiltro == 'viejos');
  }

  // --- DISEÑO DE LA PANTALLA PRINCIPAL ---
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
          // ZONA DE FILTROS SUPERIORES
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Filtro 1: ESTADO (Ocupa más espacio)
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: estadoFiltro,
                    isExpanded: true, // Evita errores si el texto es muy largo
                    decoration: InputDecoration(
                      labelText: 'Estado',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'todos', child: Text('Todos')),
                      DropdownMenuItem(value: 'operativo', child: Text('✅ Operativos')),
                      DropdownMenuItem(value: 'con_falla', child: Text('⚠️ Con Falla')),
                      DropdownMenuItem(value: 'obstruido', child: Text('🚧 Obstruidos')),
                      DropdownMenuItem(value: 'inhabilitado', child: Text('❌ Inhabilitados')),
                    ],
                    onChanged: (valor) {
                      if (valor != null) setState(() => estadoFiltro = valor);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Filtro 2: ORDEN (Nuevos vs Viejos)
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: ordenFiltro,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Orden',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'nuevos', child: Text('Nuevos')),
                      DropdownMenuItem(value: 'viejos', child: Text('Viejos')),
                    ],
                    onChanged: (valor) {
                      if (valor != null) setState(() => ordenFiltro = valor);
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // ZONA DE LA LISTA
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _obtenerGrifosFiltrados(), // Llamamos a nuestra nueva función
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
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
                    
                    final direccionRaw = grifo['direccion_referencial']?.toString() ?? 'Sin dirección';
                    final direccionLimpia = direccionRaw.replaceAll('Nodo OSM: ', '').trim();
                    final estadoGrifo = grifo['estado']?.toString() ?? 'desconocido';
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        // AQUÍ AGREGAMOS EL NÚMERO (INDEX) AL LADO DEL ÍCONO
                        leading: Row(
                          mainAxisSize: MainAxisSize.min, // Vital para no romper el diseño
                          children: [
                            Text(
                              '${index + 1}', // Sumamos 1 porque index parte en 0
                              style: const TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.bold, 
                                color: Colors.grey
                              )
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              Icons.water_drop, 
                              color: estadoGrifo == 'operativo' ? Colors.green : Colors.red
                            ),
                          ],
                        ),
                        title: Text(
                          direccionLimpia, 
                          style: const TextStyle(fontWeight: FontWeight.w500)
                        ),
                        subtitle: Text('Estado: ${estadoGrifo.toUpperCase()}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => mostrarDetalleReporte(context, grifo),
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