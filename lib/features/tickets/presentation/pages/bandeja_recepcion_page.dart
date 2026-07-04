// lib/features/tickets/presentation/pages/bandeja_recepcion_page.dart

import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart'; // ⚙️ Tu estado unificado
import '../../domain/entities/ticket_enums.dart';

import 'formulario_recepcion_page.dart';

class BandejaRecepcionPage extends StatefulWidget {
  const BandejaRecepcionPage({super.key});

  @override
  State<BandejaRecepcionPage> createState() => _BandejaRecepcionPageState();
}

class _BandejaRecepcionPageState extends State<BandejaRecepcionPage> {
  
  @override
  void initState() {
    super.initState();
    // ⚙️ Disparo inicial unificado
    _solicitarTelemetria(); 
  }

  // ⚙️ LÓGICA DE CONTROL CENTRALIZADA
  void _solicitarTelemetria() {
    final authState = context.read<AuthBloc>().state;
    
    if (authState is Authenticated) {
      context.read<TicketBloc>().add(
        ObtenerHistorialTicketsEvent(segmento: authState.usuario.segmento)
      );
      String segmento= authState.usuario.segmento.name;
    } else {
      debugPrint("⚠️ ALERTA: No se puede solicitar datos sin usuario autenticado.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) => previous != current && current is Authenticated,
      listener: (context, state) {
        if (state is Authenticated) {
          _solicitarTelemetria();
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
            
            // 1. ESTADO DE TRABAJO (Carga)
            if (state.status == TicketStatus.loading) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.teal),
                    const SizedBox(height: 16),
                    Text(state.message.isNotEmpty ? state.message : 'Sincronizando telemetría...', style: const TextStyle(color: Colors.grey)),
                  ],
                )
              );
            }
            
            // 2. ESTADO DE ALARMA (Error)
            if (state.status == TicketStatus.error) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(state.message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => _solicitarTelemetria(), // ⚙️ Reintento seguro
                      child: const Text('REINTENTAR', style: TextStyle(color: Colors.teal)),
                    )
                  ],
                ),
              );
            }

            // 3. ESTADO DE LECTURA EXITOSA
            if (state.status == TicketStatus.loaded || state.status == TicketStatus.operationSuccess) {
              // ⚙️ FILTRO DE HARDWARE: Leemos de state.historial
              final pendientes = state.historial
                  .where((t) => t.estadoActual == EstadoTicket.creado)
                  .toList();

              return RefreshIndicator(
                color: Colors.teal,
                onRefresh: () async => _solicitarTelemetria(),
                child: pendientes.isEmpty 
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: const Center(child: Text("Sin equipos pendientes de ingreso.", style: TextStyle(color: Colors.grey))),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      physics: const AlwaysScrollableScrollPhysics(),
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

            // 4. ESTADO DE REPOSO
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}