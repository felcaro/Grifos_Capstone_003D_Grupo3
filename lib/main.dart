import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/mapa_screen.dart'; // Importamos tu pantalla del mapa

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://sqttbicwettzdjypgitxq.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNxdHRiaWN3ZXR0emRqeXBnaXR4cSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzU3NTE4NTQxLCJleHAiOjIwNzMwOTQ1NDF9.P56o00n6Qx-0-M24-b99Y-f7j0zX8k6V90tVpP5k2Jg',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GrifoApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
      ),
      home: const MapaPrincipal(), // Aquí mandamos al usuario directo al mapa
    );
  }
}