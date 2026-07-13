// lib/features/tickets/presentation/pages/historial_tickets_page.dart

import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart'; // ⚙️ El estado unificado
import '../../../../core/enum/ticket_enums.dart';
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
      const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.ninguno)
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
              Tab(icon: Icon(Icons.assignment_late_outlined), text: 'NUEVOS'),
              Tab(icon: Icon(Icons.build_circle_outlined), text: 'EN TALLER '),
            ],
          ),
        ),
        body: BlocBuilder<TicketBloc, TicketState>(
          // ⚙️ ESTÁNDAR INDUSTRIAL: Escuchamos cambios en la variable de estado, no en tipos de clase
          buildWhen: (previous, current) => previous.status != current.status,
          builder: (context, state) {
            
            // 1. ESTADO DE TRABAJO
            if (state.status == TicketStatus.loading) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF005A9C)));
            } 
            
            // 2. ESTADO DE ALARMA
            if (state.status == TicketStatus.error) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 50, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(state.message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    TextButton(
                      onPressed: () => context.read<TicketBloc>().add(const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.general)),
                      child: const Text('REINTENTAR CONEXIÓN'),
                    )
                  ],
                ),
              );
            } 
            
            // 3. ESTADO DE LECTURA EXITOSA
            if (state.status == TicketStatus.loaded || state.status == TicketStatus.operationSuccess) {
              // 🗄️ LÓGICA DE FILTRADO (Separación de buffers desde state.historial)
              final ticketsCreados = state.historial.where((t) => t.estadoActual == EstadoTicket.creado).toList();
              final ticketsRecepcionados = state.historial.where((t) => t.estadoActual == EstadoTicket.recepcionFisica).toList();
              
              // 🚀 Renderizado de las vistas acopladas al TabBar
              return TabBarView(
                children: [
                  _buildListaTickets(ticketsCreados, "No hay requerimientos nuevos pendientes."),
                  _buildListaTickets(ticketsRecepcionados, "No hay equipos confirmados en taller."),
                ],
              );
            }
            
            // 4. ESTADO INICIAL
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  // =========================================================================
  // ⚙️ WIDGET HELPER: Recicla el código de la lista y el RefreshIndicator
  // =========================================================================
  // =========================================================================
  // ⚙️ WIDGET HELPER: Recicla el código de la lista y el RefreshIndicator
  // =========================================================================
  Widget _buildListaTickets(List<TicketEntity> ticketsFiltrados, String mensajeVacio) {
    if (ticketsFiltrados.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => context.read<TicketBloc>().add(const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.general)),
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
      onRefresh: () async => context.read<TicketBloc>().add(const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.general)),
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
              
              // ⚙️ EL SUBTÍTULO MODIFICADO (Falla + Lead Time)
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cliente: ${ticket.clienteId}\nFalla: ${ticket.fallaReportada}', 
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    
                    // ⏱️ INDICADOR DE TIEMPO (Solo visible en la pestaña "EN TALLER")
                    if (ticket.estadoActual == EstadoTicket.recepcionFisica) ...[
                      const SizedBox(height: 8),
                      Text(
                        ticket.tiempoDePasoARecepcion != null
                            ? '⏱️ TIEMPO EN CAMBIAR DE ESTADO: ${ticket.tiempoDePasoARecepcion!.inDays}d ${ticket.tiempoDePasoARecepcion!.inHours.remainder(24)}h ${ticket.tiempoDePasoARecepcion!.inMinutes.remainder(60)}m'
                            : '⏱️ TIEMPO EN CABIAR DE ESTADO: Faltan datos',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: Colors.green, 
                          fontSize: 12,
                        ),
                      ),
                    ]
                  ],
                ),
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