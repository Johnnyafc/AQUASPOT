// lib/features/tickets/presentation/pages/bandeja_evaluaciones_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../domain/entities/ticket_enums.dart';
import 'detalle_ticket_page.dart';
import 'evaluacion_tecnica_page.dart';

class BandejaEvaluacionesPage extends StatefulWidget {
  const BandejaEvaluacionesPage({super.key});

  @override
  State<BandejaEvaluacionesPage> createState() => _BandejaEvaluacionesPageState();
}

class _BandejaEvaluacionesPageState extends State<BandejaEvaluacionesPage> {
  @override
  void initState() {
    super.initState();
    // Solicitamos la data al arrancar
    context.read<TicketBloc>().add(ObtenerHistorialTicketsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bandeja de Pendientes"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: BlocBuilder<TicketBloc, TicketState>(
        builder: (context, state) {
          if (state is TicketLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is TicketHistorialCargado) {
            // ✅ FILTRO DE HARDWARE: Solo requerimientos en estado 'creado'
            final pendientes = state.tickets.where((t) => t.estadoActual == EstadoTicket.creado).toList();

            if (pendientes.isEmpty) {
              return const Center(child: Text("Bandeja vacía. Todo al día.", style: TextStyle(color: Colors.grey)));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: pendientes.length,
              itemBuilder: (context, index) {
                final ticket = pendientes[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.pending_actions, color: Colors.white)),
                    title: Text(ticket.id, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Equipo: ${ticket.equipo.name}\nCliente: ${ticket.clienteId}'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => EvaluacionTecnicaPage(ticket: ticket)));
                    },
                  ),
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}