import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/AsignacionCostosPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BandejaCostosPage extends StatefulWidget {
  const BandejaCostosPage({super.key});

  @override
  State<BandejaCostosPage> createState() => _BandejaCostosPageState();
}

class _BandejaCostosPageState extends State<BandejaCostosPage> {
  @override
  void initState() {
    super.initState();
    // 🚀 DISPARO CRÍTICO: Solicitamos los tickets al entrar a la bandeja.
    // VERIFICA: Asegúrate de que el nombre de tu evento sea 'LoadTicketsEvent'. 
    // Si se llama diferente (ej: FetchTicketsEvent), cámbialo aquí.
   context.read<TicketBloc>().add(
  ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.ninguno)
);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bandeja de Costos')),
      body: BlocBuilder<TicketBloc, TicketState>(
        builder: (context, state) {
          // 1. Diagnóstico de estado y campos


          if (state.status == TicketStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. ¿A qué lista le vamos a hacer caso?
          // Si el BLoC usa 'historial', debemos usar 'historial'.
          final listaAProcesar = state.tickets.isNotEmpty ? state.tickets : state.historial;
          
          if (listaAProcesar == null || listaAProcesar.isEmpty) {
            return const Center(child: Text('Lista vacía: Ni tickets ni historial llegaron.'));
          }

          // 3. Filtro industrial
          final ticketsPendientes = listaAProcesar.where((t) {
            final esCostos = t.estadoActual == EstadoTicket.costos;
            return esCostos;
          }).toList();

          if (ticketsPendientes.isEmpty) {
            return const Center(child: Text('Datos cargados, pero el filtro no encontró nada.'));
          }

          return ListView.builder(
            itemCount: ticketsPendientes.length,
            itemBuilder: (context, index) {
              final ticket = ticketsPendientes[index];
              return ListTile(
                leading: const Icon(Icons.assignment_ind, color: Colors.orange),
                title: Text('Ticket: ${ticket.id}'),
                subtitle: Text('Cliente: ${ticket.clienteId} | Máquina: ${ticket.equipo}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AsignacionCostosPage(ticket: ticket),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}