// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'injection_container.dart' as di;

// Importamos los microcontroladores (BLoCs) y pantallas
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/tickets/presentation/bloc/ticket_bloc.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/tickets/presentation/pages/main_menu_page.dart'; // ✅ El colector principal
import 'core/services/notification_service.dart';

void main() async {
  // Asegura que los motores gráficos estén listos antes de arrancar la nube
  WidgetsFlutterBinding.ensureInitialized();
  
  // Arranque del motor SCADA (Firebase)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // ⚠️ ENCENDIDO DEL RECEPTOR DE TELEMETRÍA (FCM)
  await NotificationService.inicializar();
  
  // Energizamos la bornera principal de Inyección de Dependencias
  await di.init(); 

  runApp(const AquaspotApp());
}

class AquaspotApp extends StatelessWidget {
  const AquaspotApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiBlocProvider actúa como un bus de datos global
    // Reparte la señal de los BLoCs a todas las pantallas por igual
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl<AuthBloc>()),
        BlocProvider(create: (_) => di.sl<TicketBloc>()),
      ],
      child: MaterialApp(
        title: 'Aquaspot Postventa',
        debugShowCheckedModeBanner: false, // Pantalla limpia
        theme: ThemeData(
          primaryColor: const Color(0xFF005A9C),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF005A9C)),
          useMaterial3: true,
        ),
        
        // ✅ TABLA DE ENRUTAMIENTO INDUSTRIAL
        initialRoute: '/login', // Punto de arranque por defecto (Garita)
        routes: {
          '/login': (context) => const LoginPage(), 
          '/': (context) => const MainMenuPage(), // Destino de los saltos de éxito
        },
      ),
    );
  }
}