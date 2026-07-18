// lib/features/tickets/presentation/pages/main_menu_page.dart

import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/BandejaCostosPage.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/BandejaProformasEnviadasPage.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/bandeja_comercial_Page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../domain/entities/usuario_entity.dart';
import '../../../tickets/presentation/pages/creacion_ticket_page.dart';
import '../../../tickets/presentation/pages/historial_tickets_page.dart';
import '../../../tickets/presentation/pages/bandeja_evaluaciones_page.dart';
import '../../../tickets/presentation/pages/bandeja_recepcion_page.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../pages/registro_usuario_page.dart';

class MainMenuPage extends StatefulWidget {
  const MainMenuPage({super.key});

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  int _selectedIndex = 0;

  void _logout() {
    context.read<AuthBloc>().add(CerrarSesionEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      },
      builder: (context, state) {
        if (state is! Authenticated) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final operador = state.usuario;

        // ✅ EL MULTIPLEXOR DE VISTAS 
        // Aquí conectamos los módulos independientes
        final List<Widget> modulosHMI = [
          _InicioView(operador: operador),
          const HistorialTicketsPage(), // ✅ SEÑAL CONECTADA AL PUERTO 2
        ];

        return Scaffold(
          backgroundColor: const Color(0xFFF4F7F6),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text("Aquaspot", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            actions: [
              IconButton(icon: const Icon(Icons.notifications_none, color: Colors.black), onPressed: () {}),
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: CircleAvatar(
                  backgroundColor: const Color(0xFF005A9C),
                  child: Text(operador.email.isNotEmpty ? operador.email[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
          // ✅ EL CONMUTADOR
          // IndexedStack mantiene el estado (scroll, inputs) de las vistas inactivas
          body: IndexedStack(
            index: _selectedIndex,
            children: modulosHMI,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            selectedItemColor: const Color(0xFF005A9C),
            unselectedItemColor: Colors.grey,
            onTap: (index) {
              // El índice 2 es el botón de salir. No es una vista.
              if (index == 2) {
                _logout();
              } else {
                setState(() => _selectedIndex = index);
              }
              if (index == 1) {
    // DISPARO DE ORDEN DE RECARGA GLOBAL
    // Usamos 'ninguno' para abrir la válvula de filtrado en el DataSource
              context.read<TicketBloc>().add(
              const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.ninguno)
                );
                 }
                 setState(() => _selectedIndex = index);
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
              BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historial'),
              BottomNavigationBarItem(icon: Icon(Icons.exit_to_app), label: 'Salir'),
            ],
          ),
        );
      },
    );
  }
}

// =====================================================================
// SUB-RUTINA 1: PANEL DE INICIO (El Dashboard principal)
// =====================================================================
class _InicioView extends StatelessWidget {
  final UsuarioEntity operador;

  const _InicioView({required this.operador});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Hola, ${operador.rol.name.toUpperCase()}", 
               style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ..._getModules(context, operador),
        ],
      ),
    );
  }

  List<Widget> _getModules(BuildContext context, UsuarioEntity operador) {
    List<Widget> modules = [];
    
    if (operador.rol == RolUsuario.requerimiento || operador.rol == RolUsuario.supervisor) {
      modules.add(_buildCardOption(
        title: 'Crear Ticket',
        icon: Icons.add_box,
        color: Colors.blue,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreacionTicketPage())),
      ));
    }

    // 2. MÓDULO DE RECEPCIÓN (Fase Beta - Restringido temporalmente)
    // Cuando el comisionamiento termine, agregaremos el rol de 'recepcion' o 'requerimiento' aquí.
    if (operador.rol == RolUsuario.supervisor || operador.rol == RolUsuario.recepcion ) {
      modules.add(_buildCardOption(
        title: 'Tickets',
        icon: Icons.inventory_outlined, // Ícono industrial de inventario/recepción
        color: Colors.teal, 
        onTap: () {
          // TODO: Descomentar cuando la vista BandejaRecepcionPage esté creada
           Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BandejaRecepcionPage()));
        },
      ));
    }

    if (operador.rol == RolUsuario.tecnico || operador.rol == RolUsuario.supervisor) {
      modules.add(_buildCardOption(
        title: 'Evaluaciones Técnicas',
        icon: Icons.handyman,
        color: Colors.orange,
       onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BandejaEvaluacionesPage())),
      ));
    }

// 🔒 ACCESO EXCLUSIVO PARA SUPER ADMINISTRADORES
    if (operador.rol == RolUsuario.admin) {
      modules.add(_buildCardOption(
        title: 'Gestión de Operarios',
        icon: Icons.admin_panel_settings,
        color: Colors.blueGrey, // Color sobrio para módulos administrativos
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RegistroUsuarioPage())
        ),
      ));
    }
    if (operador.rol == RolUsuario.comercial) {
      modules.add(_buildCardOption(
        title: 'Crear proforma',
        icon: Icons.business_center,
        color: Colors.green, // Color asociado a transacciones comerciales
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BandejaComercialPage())
        ),
      ));
            modules.add(_buildCardOption(
        title: 'Proformas enviadas',
        icon: Icons.access_alarm,
        color: Colors.blue, // Color asociado a transacciones comerciales
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BandejaProformasEnviadasPage())
        ),
      ));
    }

    if (operador.rol == RolUsuario.costos) {
    modules.add(_buildCardOption(
    title: 'Crear proyecto',
    icon: Icons.account_balance_wallet, // Ícono financiero
    color: Colors.orange[800]!, // Color industrial de alerta/gestión
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BandejaCostosPage())
    ),
  ));
}

    return modules;
  } 

  Widget _buildCardOption({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon, color: color, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}