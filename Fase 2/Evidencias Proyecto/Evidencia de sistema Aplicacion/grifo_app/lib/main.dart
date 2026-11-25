import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'screens/home_screen.dart'; // Pantalla de inicio (después del login)
import 'widgets/auth_gate.dart'; // Compuerta de autenticación

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ¿Se abrió desde el enlace de "recuperar contraseña"? Hay que verlo ANTES de
  // inicializar Supabase: el evento passwordRecovery se emite durante la
  // inicialización y la interfaz aún no lo escucha.
  final recuperacion = kIsWeb && Uri.base.toString().contains('type=recovery');

  // Flujo implícito: el enlace del correo funciona aunque se abra en otro
  // navegador o dispositivo (con PKCE solo sirve en el que lo pidió).
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.implicit),
  );

  runApp(MyApp(recuperacion: recuperacion));
}

class MyApp extends StatelessWidget {
  final bool recuperacion;
  const MyApp({super.key, this.recuperacion = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GrifoApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
      ),
      home: AuthGate(home: const HomeScreen(), recuperacionInicial: recuperacion),
    );
  }
}
