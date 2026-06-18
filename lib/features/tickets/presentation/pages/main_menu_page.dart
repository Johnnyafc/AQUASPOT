// lib/features/tickets/presentation/pages/main_menu_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_event.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../features/auth/domain/entities/usuario_entity.dart';
import 'creacion_ticket_page.dart';
import 'historial_tickets_page.dart';
import 'bandeja_evaluaciones_page.dart';

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
        title: 'Ingreso de Equipo',
        icon: Icons.add_box,
        color: Colors.blue,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreacionTicketPage())),
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