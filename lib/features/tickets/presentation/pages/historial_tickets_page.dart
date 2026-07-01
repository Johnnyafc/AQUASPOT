// lib/features/tickets/presentation/pages/historial_tickets_page.dart

import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../domain/entities/ticket_enums.dart';
import '../../domain/entities/ticket_entity.dart';
import 'detalle_ticket_page.dart';

class HistorialTicketsPage extends StatefulWidget {
  const HistorialTicketsPage({super.key});

  @override
  State<HistorialTicketsPage> createState() => _HistorialTicketsPageState();
}

class _HistorialTicketsPageState extends State<HistorialTicketsPage> {
 @override
  void initState() {
    super.initState();
    // ⚙️ LLAVE MAESTRA: Solicitamos telemetría GLOBAL (Sin filtros de segmento)
    context.read<TicketBloc>().add(
      const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.general)
    );
  }

  // Indicadores visuales (LEDs)
  Color _getColorPorEstado(EstadoTicket estado) {
    switch (estado) {
      case EstadoTicket.creado: 
        return Colors.orange; 
      case EstadoTicket.evaluacionTecnica: 
        return Colors.blue;   
      case EstadoTicket.recepcionFisica: 
        return Colors.green;  
      default: 
        return Colors.grey;   
    }
  }

  @override
  Widget build(BuildContext context) {
    // ⚙️ Envolvemos todo en un controlador de 2 pestañas
    return DefaultTabController(
      length: 2, 
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel de Mantenimiento', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF005A9C),
          foregroundColor: Colors.white,
          // 🗂️ Definición de las pestañas
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.orange,
            indicatorWeight: 4,
            tabs: [
              Tab(icon: Icon(Icons.assignment_late_outlined), text: 'NUEVOS (CREADO)'),
              Tab(icon: Icon(Icons.build_circle_outlined), text: 'EN TALLER (RECEPCIÓN)'),
            ],
          ),
        ),
        body: BlocBuilder<TicketBloc, TicketState>(
          buildWhen: (previous, current) => current is TicketLoading || current is TicketHistorialCargado || current is TicketError,
          builder: (context, state) {
            if (state is TicketLoading) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF005A9C)));
            } 
            
            if (state is TicketError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 50, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(state.message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    TextButton(
                      onPressed: () => context.read<TicketBloc>().add(ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.general)),
                      child: const Text('REINTENTAR CONEXIÓN'),
                    )
                  ],
                ),
              );
            } 
            
            if (state is TicketHistorialCargado) {
              // 🗄️ LÓGICA DE FILTRADO (Separación de buffers)
              final ticketsCreados = state.tickets.where((t) => t.estadoActual == EstadoTicket.creado).toList();
              final ticketsRecepcionados = state.tickets.where((t) => t.estadoActual == EstadoTicket.recepcionFisica).toList();
              
              // 🚀 Renderizado de las vistas acopladas al TabBar
              return TabBarView(
                children: [
                  _buildListaTickets(ticketsCreados, "No hay requerimientos nuevos pendientes."),
                  _buildListaTickets(ticketsRecepcionados, "No hay equipos confirmados en taller."),
                ],
              );
            }
            
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  // =========================================================================
  // ⚙️ WIDGET HELPER: Recicla el código de la lista y el RefreshIndicator
  // =========================================================================
  Widget _buildListaTickets(List<TicketEntity> ticketsFiltrados, String mensajeVacio) {
    if (ticketsFiltrados.isEmpty) {
      // RefreshIndicator también aquí para poder recargar si la lista está vacía
      return RefreshIndicator(
        onRefresh: () async => context.read<TicketBloc>().add(ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.general)),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Text(mensajeVacio, style: const TextStyle(color: Colors.grey, fontSize: 16)),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => context.read<TicketBloc>().add(ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.general)),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: ticketsFiltrados.length,
        itemBuilder: (context, index) {
          final ticket = ticketsFiltrados[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: _getColorPorEstado(ticket.estadoActual),
                child: const Icon(Icons.precision_manufacturing, color: Colors.white),
              ),
              title: Text('${ticket.id} | ${ticket.equipo.name.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Cliente: ${ticket.clienteId}\nFalla: ${ticket.fallaReportada}', 
                            maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              trailing: const Icon(Icons.chevron_right),
              isThreeLine: true,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => DetalleTicketPage(ticket: ticket)));
              },
            ),
          );
        },
      ),
    );
  }
}