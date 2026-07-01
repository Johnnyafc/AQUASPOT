// lib/features/tickets/presentation/pages/bandeja_recepcion_page.dart

import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../domain/entities/ticket_enums.dart';

import 'formulario_recepcion_page.dart'; // TODO: Crear esta vista en el siguiente paso

class BandejaRecepcionPage extends StatefulWidget {
  const BandejaRecepcionPage({super.key});

  @override
  State<BandejaRecepcionPage> createState() => _BandejaRecepcionPageState();
}

class _BandejaRecepcionPageState extends State<BandejaRecepcionPage> {
 @override
  void initState() {
    super.initState();

    // 1. EXTRAEMOS LA CONFIGURACIÓN DEL USUARIO (Auth Context)
    final authState = context.read<AuthBloc>().state;
    SegmentoOperativo segmentoActivo = SegmentoOperativo.ninguno;

    if (authState is Authenticated) {
      segmentoActivo = authState.usuario.segmento;
    } else {
      // Manejo de emergencia: Si no hay usuario, no cargamos nada o mandamos a login
      debugPrint("⚠️ ALERTA: Intento de acceso sin autenticación.");
    }

    // 2. DISPARAMOS EL EVENTO CON EL SEGMENTO ASIGNADO
    // Ahora el BLoC sabe exactamente qué datos filtrar desde Firestore
    context.read<TicketBloc>().add(ObtenerHistorialTicketsEvent(segmento: segmentoActivo));
  }

@override
  Widget build(BuildContext context) {
    // ⚙️ Usamos BlocListener para vigilar el estado de autenticación en todo momento
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) => previous != current && current is Authenticated,
      listener: (context, state) {
        // Si el estado cambia a autenticado, forzamos recarga
        if (state is Authenticated) {
          context.read<TicketBloc>().add(ObtenerHistorialTicketsEvent(segmento: state.usuario.segmento));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Recepción Física", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
        ),
        backgroundColor: const Color(0xFFF4F7F6),
        body: BlocBuilder<TicketBloc, TicketState>(
          builder: (context, state) {
            
            if (state is TicketLoading) {
              return const Center(child: CircularProgressIndicator(color: Colors.teal));
            }
            
            if (state is TicketHistorialCargado) {
              // ⚙️ FILTRO DE ESTADO: Solo equipos en estado 'creado' (pendientes de recepción)
              final pendientes = state.tickets
                  .where((t) => t.estadoActual == EstadoTicket.creado)
                  .toList();

              if (pendientes.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async => _solicitarTelemetria(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: const Center(child: Text("Sin equipos pendientes de ingreso.", style: TextStyle(color: Colors.grey))),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                color: Colors.teal,
                onRefresh: () async => _solicitarTelemetria(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: pendientes.length,
                  itemBuilder: (context, index) {
                    final ticket = pendientes[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.teal,
                          child: Icon(Icons.inventory_outlined, color: Colors.white),
                        ),
                        title: Text(ticket.id, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Equipo: ${ticket.equipo.name.toUpperCase()}\nCliente: ${ticket.clienteId}'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => FormularioRecepcionPage(ticket: ticket)),
                          );
                        },
                      ),
                    );
                  },
                ),
              );
            }
            
            if (state is TicketError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(state.message, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: () => _solicitarTelemetria(),
                      child: const Text('REINTENTAR'),
                    )
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
  
  void _solicitarTelemetria() {
  final authState = context.read<AuthBloc>().state;
  
  if (authState is Authenticated) {
    // Si el usuario está autenticado, disparamos la petición
    context.read<TicketBloc>().add(
      ObtenerHistorialTicketsEvent(segmento: authState.usuario.segmento)
    );
  } else {
    // Si no, registramos el error sin intentar cargar nada
    debugPrint("⚠️ ALERTA: No se puede solicitar telemetría sin usuario autenticado.");
  }
}

}