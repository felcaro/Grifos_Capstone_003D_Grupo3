import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  runApp(const MiApp());
}

class MiApp extends StatelessWidget {
  const MiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mapa Táctico',
      home: const MapaPrincipal(),
    );
  }
}

class MapaPrincipal extends StatefulWidget {
  const MapaPrincipal({super.key});

  @override
  State<MapaPrincipal> createState() => _MapaPrincipalState();
}

class _MapaPrincipalState extends State<MapaPrincipal> {
  // Coordenadas iniciales del mapa
  static const CameraPosition _posicionInicial = CameraPosition(
    target: LatLng(-33.6890, -71.2150),
    zoom: 16.5,
  );

  // Controlador para manejar lo que se escribe en la barra
  final TextEditingController _controladorBusqueda = TextEditingController(
    text: 'Ortúzar',
  );

  @override
  void dispose() {
    _controladorBusqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. EL MAPA
          const GoogleMap(
            initialCameraPosition: _posicionInicial,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // 2. LA BARRA DE BÚSQUEDA
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black, // Fondo negro como en tu imagen
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _controladorBusqueda,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: const InputDecoration(
                    hintText: 'Buscar...',
                    hintStyle: TextStyle(color: Colors.grey),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.white,
                    ), // Ícono de lupa
                    border: InputBorder
                        .none, // Quita la línea de abajo que viene por defecto
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 15,
                      horizontal: 15,
                    ),
                  ),
                  onSubmitted: (valor) {
                    // Aquí a futuro pondremos la lógica para buscar la calle en el mapa
                    print("Buscando: $valor");
                  },
                ),
              ),
            ),
          ),
        ],
      ),

      // 3. LA BARRA INFERIOR NEGRA (Vacía por ahora)
      bottomNavigationBar: Container(
        height: 60,
        color: const Color(0xFF1E1E1E),
      ),
    );
  }
}
