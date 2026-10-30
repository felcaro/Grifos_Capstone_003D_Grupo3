import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../utils/mantencion_util.dart';
import '../utils/permisos.dart';
import 'actas_menu_screen.dart';
import 'admin_usuarios_screen.dart';
import 'inventario_carro_screen.dart';
import 'lista_grifos_screen.dart';
import 'mapa_screens.dart';
import 'personal_screen.dart';
import 'tesoreria_screen.dart';

/// Pantalla de inicio que aparece después del login: desde aquí se elige
/// ir al mapa de grifos o a las demás funciones de la aplicación.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _Opcion {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final Widget Function() destino;
  final int badge;
  const _Opcion(this.icono, this.titulo, this.subtitulo, this.destino, {this.badge = 0});
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = SupabaseService();

  Map<String, dynamic>? _perfil;
  int _alertasCarros = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    Map<String, dynamic>? perfil;
    var alertas = 0;
    try {
      perfil = await _db.obtenerMiPerfil();
    } catch (_) {
      perfil = null;
    }
    try {
      final carros = await _db.obtenerCarros();
      alertas = carros.where((c) => alertasActivas(c).isNotEmpty).length;
    } catch (_) {
      alertas = 0; // sin sesión real o sin las columnas nuevas todavía
    }
    if (!mounted) return;
    setState(() {
      _perfil = perfil;
      _alertasCarros = alertas;
    });
  }

  Future<void> _abrir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    if (mounted) _cargar(); // al volver, se actualizan los avisos
  }

  void _confirmarSalir() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Cerrar sesión', style: TextStyle(color: AppColors.textoPrincipal)),
        content: const Text('¿Seguro que quieres salir de tu cuenta?', style: TextStyle(color: AppColors.textoSecundario)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rojo),
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.signOut(); // AuthGate muestra el login solo
            },
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }

  Permisos get _permisos => Permisos.deRol(_perfil?['rol']);

  List<_Opcion> get _opciones => [
        if (_permisos.verGrifos)
          _Opcion(Icons.list_alt, 'Lista de grifos', 'Estado y trabajos realizados', () => const ListaGrifosScreen()),
        if (_permisos.verCarros)
          _Opcion(
          Icons.fire_truck,
          'Carros',
          'Inventario, revisión técnica y mantención',
          () => const InventarioCarrosScreen(),
          badge: _alertasCarros,
        ),
        if (_permisos.verEquipoPersonal)
          _Opcion(
            Icons.badge,
            _permisos.verTodoElPersonal ? 'Equipo del personal' : 'Mi equipo',
            _permisos.verTodoElPersonal ? 'Trajes y equipo de cada bombero' : 'Tu traje e implementos',
            () => const PersonalScreen(),
          ),
        _Opcion(
          Icons.menu_book,
          'Actas',
          _permisos.verActaDirectorio ? 'Parte de servicio y acta de Directorio' : 'Parte de servicio',
          () => const ActasMenuScreen(),
        ),
        if (_permisos.verTesoreria)
          _Opcion(Icons.account_balance_wallet, 'Tesorería', 'Ingresos, egresos y rendiciones', () => const TesoreriaScreen()),
        if (_permisos.verAdministracion)
          _Opcion(Icons.admin_panel_settings, 'Administración', 'Usuarios y roles', () => const AdminUsuariosScreen()),
      ];

  @override
  Widget build(BuildContext context) {
    final email = AuthService.currentEmail ?? '';
    final nombre = (_perfil?['nombre'] ?? '').toString();
    final rol = (_perfil?['rol'] ?? '').toString();
    final saludo = nombre.isNotEmpty ? nombre : (email.isNotEmpty ? email.split('@').first : 'Bombero');

    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: AppColors.rojo,
        foregroundColor: Colors.white,
        title: const Text('GrifoApp'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Cerrar sesión', onPressed: _confirmarSalir),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ---- saludo ----
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: decoracionTarjeta(),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.rojo,
                        child: Icon(Icons.local_fire_department, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hola, $saludo',
                                style: const TextStyle(color: AppColors.textoPrincipal, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              rol.isNotEmpty ? '${etiquetaRol(rol)} · $email' : (email.isNotEmpty ? email : 'Modo de prueba'),
                              style: const TextStyle(color: AppColors.textoSecundario, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ---- avisos de carros ----
                if (_alertasCarros > 0)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _abrir(const InventarioCarrosScreen()),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$_alertasCarros carro${_alertasCarros == 1 ? '' : 's'} con revisión técnica o mantención por atender',
                              style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.red.shade700),
                        ],
                      ),
                    ),
                  ),

                // ---- acceso principal: el mapa ----
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _abrir(const MapaPrincipal()),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.rojo,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.map, color: Colors.white, size: 44),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Mapa de grifos', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                              SizedBox(height: 2),
                              Text('Ubicar el grifo más cercano y ver su estado',
                                  style: TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Otras funciones',
                    style: TextStyle(color: AppColors.textoPrincipal, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                // ---- resto de funciones ----
                LayoutBuilder(
                  builder: (context, c) {
                    final columnas = c.maxWidth >= 640 ? 3 : 2;
                    const espacio = 12.0;
                    final ancho = (c.maxWidth - espacio * (columnas - 1)) / columnas;
                    return Wrap(
                      spacing: espacio,
                      runSpacing: espacio,
                      children: _opciones.map((o) => SizedBox(width: ancho, child: _tarjetaOpcion(o))).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tarjetaOpcion(_Opcion o) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _abrir(o.destino()),
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(14),
        decoration: decoracionTarjeta(),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.rojo.withOpacity(0.12), shape: BoxShape.circle),
                  child: Icon(o.icono, color: AppColors.rojo, size: 24),
                ),
                const Spacer(),
                Text(o.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textoPrincipal, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(o.subtitulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12)),
              ],
            ),
            if (o.badge > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.rojoAlerta, borderRadius: BorderRadius.circular(10)),
                  child: Text('${o.badge}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
