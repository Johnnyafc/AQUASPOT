// lib/features/tickets/presentation/pages/historial_tickets_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../domain/entities/ticket_enums.dart';
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
    // Arranque del sensor: Pedimos los datos al PLC apenas se energiza la pantalla
    context.read<TicketBloc>().add(ObtenerHistorialTicketsEvent());
  }

  // Indicadores visuales (LEDs) según el estado del proceso
// Indicadores visuales (LEDs) según el estado del proceso
  Color _getColorPorEstado(EstadoTicket estado) {
    switch (estado) {
      case EstadoTicket.creado: 
        return Colors.orange; // Etapa 1: Comercial/Operaciones
      case EstadoTicket.evaluacionTecnica: 
        return Colors.blue;   // Etapa 2: Taller/Mantenimiento
      case EstadoTicket.recepcionFisica: 
        return Colors.green;  // Etapa 3: Generación de Acta
      default: 
        return Colors.grey;   // Fallback de seguridad por si entra basura en la señal
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TicketBloc, TicketState>(
      // Filtramos para que la lista no se desaparezca si entra un evento de "OperationSuccess" de otra pestaña
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
                  onPressed: () => context.read<TicketBloc>().add(ObtenerHistorialTicketsEvent()),
                  child: const Text('REINTENTAR CONEXIÓN'),
                )
              ],
            ),
          );
        } 
        
        if (state is TicketHistorialCargado) {
          final tickets = state.tickets;
          
          if (tickets.isEmpty) {
            return const Center(child: Text("Base de datos en blanco. Sin registros.", style: TextStyle(color: Colors.grey)));
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<TicketBloc>().add(ObtenerHistorialTicketsEvent());
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: tickets.length,
              itemBuilder: (context, index) {
                final ticket = tickets[index];
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
                      // Salto a la vista de detalle
                      Navigator.push(context, MaterialPageRoute(builder: (_) => DetalleTicketPage(ticket: ticket)));
                    },
                  ),
                );
              },
            ),
          );
        }
        
        return const SizedBox.shrink();
      },
    );
  }
}