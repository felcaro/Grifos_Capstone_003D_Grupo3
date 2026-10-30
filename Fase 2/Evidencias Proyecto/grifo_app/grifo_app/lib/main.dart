import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'screens/home_screen.dart'; // Pantalla de inicio (después del login)
import 'widgets/auth_gate.dart'; // Compuerta de autenticación

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializamos Supabase usando nuestra configuración segura
  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);

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
      home: const AuthGate(home: HomeScreen()),
    );
  }
}
