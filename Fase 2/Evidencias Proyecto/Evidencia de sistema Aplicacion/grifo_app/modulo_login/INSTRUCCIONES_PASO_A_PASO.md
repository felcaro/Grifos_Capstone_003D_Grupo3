# Módulo de Autenticación con Supabase para Flutter

Este paquete contiene todo lo necesario para integrar inicio de sesión, registro de cuentas, validación de sesiones y cierre de sesión en cualquier proyecto Flutter.

---

## 📁 Contenido del Módulo

* `lib/screens/login_screen.dart`: Pantalla de Login y Registro (con validación de campos, spinner de carga, captura de errores y personalización de título/icono/color).
* `lib/widgets/auth_gate.dart`: Compuerta reactiva que decide si mostrar la pantalla principal o el login según si hay sesión iniciada.
* `lib/services/auth_service.dart`: Utilidades rápidas (`AuthService.signOut()`, `AuthService.currentEmail`, etc.).
* `.env.example`: Plantilla para tus claves de Supabase.

---

## 🚀 Pasos para integrarlo en tu otro proyecto

### Paso 1: Agregar las dependencias en `pubspec.yaml`
Abre el archivo `pubspec.yaml` de tu proyecto y agrega:

```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.17.2
  flutter_dotenv: ^5.2.1
```

Y más abajo, en la sección `flutter:`, registra el archivo `.env`:

```yaml
flutter:
  uses-material-design: true
  assets:
    - .env
```

Luego ejecuta en la terminal:
```bash
flutter pub get
```

---

### Paso 2: Configurar las claves en `.env`
1. Crea un archivo llamado `.env` en la **raíz** de tu proyecto Flutter (junto a `pubspec.yaml`).
2. Agrega tus credenciales obtenidas desde el panel de Supabase (*Project Settings -> API*):

```env
SUPABASE_URL=https://TU_PROYECTO.supabase.co
SUPABASE_ANON_KEY=TU_ANON_KEY_DE_SUPABASE
```

*(Opcional: agrega `.env` a tu archivo `.gitignore` para no subir tus claves a repositorios públicos).*

---

### Paso 3: Copiar los archivos Dart a tu proyecto
Copia la carpeta `lib/` de este módulo dentro de la carpeta `lib/` de tu proyecto:
* `lib/screens/login_screen.dart`
* `lib/widgets/auth_gate.dart`
* `lib/services/auth_service.dart`

---

### Paso 4: Inicializar en `main.dart`
En tu `lib/main.dart`, inicializa Supabase y utiliza `AuthGate`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widgets/auth_gate.dart';
// Importa tu pantalla principal existente:
import 'screens/mi_pantalla_principal.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno
  await dotenv.load(fileName: ".env");

  // Inicializar cliente Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Proyecto',
      theme: ThemeData(useMaterial3: true),
      // AuthGate redirige automáticamente al login o a tu pantalla principal
      home: const AuthGate(
        home: MiPantallaPrincipal(),
      ),
    );
  }
}
```

---

### Paso 5: ¿Cómo cerrar sesión (Logout) desde cualquier parte?
Para cerrar sesión desde un botón o menú en tu app, simplemente llama:

```dart
import 'services/auth_service.dart';

// En un onPressed de un botón:
onPressed: () async {
  await AuthService.signOut();
}
```
Al cerrarse la sesión, `AuthGate` detectará automáticamente el cambio y enviará al usuario a la pantalla de Login.
