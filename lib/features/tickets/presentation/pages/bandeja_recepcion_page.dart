// lib/features/tickets/presentation/pages/bandeja_recepcion_page.dart

import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart'; 
import '../../../../core/enum/ticket_enums.dart';
import '../../domain/entities/ticket_entity.dart'; // ⚙️ Importación necesaria para el tipado de la subrutina

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

  // ⚙️ LÓGICA DE CONTROL CENTRALIZADA (Válvula Maestra de Segmento)
  void _solicitarTelemetria() {
    final authState = context.read<AuthBloc>().state;
    
    if (authState is Authenticated) {
      // 🚀 NOTA DE ARQUITECTURA: La segmentación ya ocurre aquí. 
      // El backend solo te envía los tickets del segmento de este usuario.
      context.read<TicketBloc>().add(
        ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.ninguno)
      );
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
      // ⚙️ INSTALAMOS EL CONTACTOR DE PESTAÑAS
      child: DefaultTabController(
        length: 2, // Dos carriles: Incompletos y Completos
        child: Scaffold(
          appBar: AppBar(
            title: const Text("Bandeja de Recepción", style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 1,
            // ⚙️ PANEL INDICADOR DE CARRILES
            bottom: const TabBar(
              indicatorColor: Color(0xFF005A9C),
              labelColor: Color(0xFF005A9C),
              unselectedLabelColor: Colors.grey,
              indicatorWeight: 3,
              tabs: [
                Tab(icon: Icon(Icons.warning_amber_rounded), text: "INCOMPLETOS"),
                Tab(icon: Icon(Icons.check_circle_outline), text: "COMPLETOS"),
              ],
            ),
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
                        onPressed: () => _solicitarTelemetria(),
                        child: const Text('REINTENTAR', style: TextStyle(color: Colors.teal)),
                      )
                    ],
                  ),
                );
              }

// 3. ESTADO DE LECTURA EXITOSA
              if (state.status == TicketStatus.loaded || state.status == TicketStatus.operationSuccess) {
                
                // ⚙️ SEPARADOR DE FLUJO LÓGICO (Clasificador Industrial)
                
                // Carril 1 (INCOMPLETOS): Tickets que nacieron en campo pero les falta revisión, fotos o serie.
                // Se quedaron retenidos en la etapa de creación.
                final incompletos = state.historial
                    .where((t) => t.estadoActual == EstadoTicket.creado)
                    .toList();

                // Carril 2 (COMPLETOS): Tickets que ya pasaron por el taller (o nacieron completos) 
                // y tienen su acta generada.
                final completos = state.historial
                    .where((t) => t.estadoActual == EstadoTicket.recepcionFisica)
                    .toList();

                // 🚀 ENRUTAMIENTO HACIA LAS PESTAÑAS (HMI)
                return TabBarView(
                  children: [
                    _buildBandaTickets(incompletos, context), // Carril 1: Pendientes de acción
                    _buildBandaTickets(completos, context),   // Carril 2: Ya procesados
                  ],
                );
              }

              // 4. ESTADO DE REPOSO
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  // =========================================================
  // ⚙️ SUBRUTINA DE DIBUJADO (DRY - Don't Repeat Yourself)
  // =========================================================
  // Extraemos la lista aquí para no duplicar código en ambas pestañas
  Widget _buildBandaTickets(List<TicketEntity> tickets, BuildContext context) {
    return RefreshIndicator(
      color: Colors.teal,
      onRefresh: () async => _solicitarTelemetria(),
      child: tickets.isEmpty 
        ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: const Center(
                  child: Text("Sin equipos en este carril.", style: TextStyle(color: Colors.grey, fontSize: 16))
                ),
              ),
            ],
          )
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  // 🚀 Añadimos un borde de color sutil según su estado para refuerzo visual
                  side: BorderSide(
                    color: ticket.esRegistroCompleto ? Colors.green.shade200 : Colors.orange.shade200,
                    width: 1.5
                  )
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: ticket.esRegistroCompleto ? Colors.green[700] : Colors.orange[700],
                    child: Icon(
                      ticket.esRegistroCompleto ? Icons.check_circle : Icons.warning_amber, 
                      color: Colors.white
                    ),
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
}