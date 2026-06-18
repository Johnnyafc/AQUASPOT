// lib/features/tickets/presentation/pages/main_menu_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_event.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../features/auth/domain/entities/usuario_entity.dart';
import '../../../auth/presentation/pages/login_page.dart';
import 'creacion_ticket_page.dart';

class MainMenuPage extends StatefulWidget {
  final UsuarioEntity operador;

  const MainMenuPage({super.key, required this.operador});

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  int _selectedIndex = 0;

  // Lógica para cerrar sesión
  void _logout() {
    context.read<AuthBloc>().add(CerrarSesionEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7F6),
        // BARRA SUPERIOR (PERFIL Y NOTIFICACIONES)
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
                child: Text(widget.operador.email[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
        // CUERPO (EL FEED DE OPCIONES)
        body: _buildBody(),
        // BARRA DE NAVEGACIÓN INFERIOR
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFF005A9C),
          unselectedItemColor: Colors.grey,
          onTap: (index) {
            if (index == 2) _logout(); // Acción rápida de logout
            setState(() => _selectedIndex = index);
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historial'),
            BottomNavigationBarItem(icon: Icon(Icons.exit_to_app), label: 'Salir'),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Hola, ${widget.operador.rol.name.toUpperCase()}", 
               style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ..._getModules(context),
        ],
      ),
    );
  }

  List<Widget> _getModules(BuildContext context) {
    List<Widget> modules = [];
    
    if (widget.operador.rol == RolUsuario.requerimiento || widget.operador.rol == RolUsuario.supervisor) {
      modules.add(_buildCardOption(
        title: 'Ingreso de Equipo',
        icon: Icons.add_box,
        color: Colors.blue,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreacionTicketPage())),
      ));
    }

    if (widget.operador.rol == RolUsuario.tecnico || widget.operador.rol == RolUsuario.supervisor) {
      modules.add(_buildCardOption(
        title: 'Evaluaciones Técnicas',
        icon: Icons.handyman,
        color: Colors.orange,
        onTap: () {},
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