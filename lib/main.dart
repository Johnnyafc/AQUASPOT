// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'injection_container.dart' as di;

// Importamos los microcontroladores (BLoCs), Eventos y pantallas
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/tickets/presentation/bloc/ticket_bloc.dart';
import 'features/catalogo/presentation/bloc/catalogo_bloc.dart';
import 'features/inventario/presentation/bloc/inventario_bloc.dart';
import 'features/inventario/presentation/bloc/inventario_event.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/main_menu_page.dart';
import 'core/services/notification_service.dart';

// ============================================================================
// 🔌 RELÉ GLOBAL: Bus de control para accionar la interfaz gráfica desde el backend
// ============================================================================
final GlobalKey<ScaffoldMessengerState> actuadorVisualGlobal = GlobalKey<ScaffoldMessengerState>();

void main() async {
  // Asegura que los motores gráficos estén listos antes de arrancar la nube
  WidgetsFlutterBinding.ensureInitialized();
  
  // Arranque del motor SCADA (Firebase)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 🚀 ARRANQUE LIMPIO: Desacoplamos la inicialización pesada.
  // Solo enlazamos el oyente de fondo estático (no bloquea el hilo).
  NotificationService.inicializarBackgroundHandler();
  
  // Energizamos la bornera principal de Inyección de Dependencias
  await di.init(); 

  runApp(const AquaspotApp());
}

class AquaspotApp extends StatelessWidget {
  const AquaspotApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiBlocProvider actúa como un bus de datos global
    return MultiBlocProvider(
      providers: [
        // ⚡ CHISPAZO INICIAL: Energiza el sistema e interroga la memoria caché
        BlocProvider(
          create: (_) => di.sl<AuthBloc>()..add(const VerificarSesionEvent()),
        ),
        BlocProvider(create: (_) => di.sl<TicketBloc>()),
        BlocProvider(create: (_) => di.sl<CatalogoBloc>()),
        BlocProvider(
          create: (_) => di.sl<InventarioBloc>()..add(const CargarInventarioEvent()),
        ),
      ],
      child: MaterialApp(
        title: 'Aquaspot Postventa',
        // ⚠️ ENCLAVAMIENTO CRÍTICO: Conectamos el relé al lienzo gráfico
        scaffoldMessengerKey: actuadorVisualGlobal, 
        debugShowCheckedModeBanner: false, 
        theme: ThemeData(
          primaryColor: const Color(0xFF005A9C),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF005A9C)),
          useMaterial3: true,
        ),

        // 📋 SELECCIÓN DE TEXTO: Habilita copiar/pegar con mouse en TODO texto
        // de la app (tickets, clientes, etc.) sin tocar cada widget uno por uno.
        // Nota: SelectionArea necesita un Overlay como ancestro. El builder de
        // MaterialApp se ejecuta POR FUERA del Navigator (donde vive su propio
        // Overlay), así que le damos uno propio aquí para que funcione.
        builder: (context, child) {
          return Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (context) => SelectionArea(child: child!),
              ),
            ],
          );
        },

        // ✅ TABLA DE ENRUTAMIENTO INDUSTRIAL
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginPage(), 
          '/': (context) => const MainMenuPage(), 
        },
      ),
    );
  }
}