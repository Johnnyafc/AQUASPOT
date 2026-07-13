import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/GenerarCotizacionPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../features/tickets/presentation/bloc/ticket_bloc.dart';
import '../../../../features/tickets/domain/entities/ticket_entity.dart';

class BandejaComercialPage extends StatelessWidget {
  const BandejaComercialPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión Comercial"),
        backgroundColor: Colors.green,
      ),
      // ⚙️ CONSUMO DEL ESTADO CENTRAL (TicketBloc)
      body: BlocBuilder<TicketBloc, TicketState>(
        builder: (context, state) {
          if (state.status == TicketStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == TicketStatus.error) {
            return Center(child: Text("Fallo de telemetría: ${state.message}"));
          }

          // 🛡️ FILTRADO PROVISIONAL: Solo tickets evaluados listos para comercial
          // Nota: Si esto crece, mueve esta lógica al BLoC o al Repositorio.
        final ticketsComerciales = state.ticketsComerciales;

          if (ticketsComerciales.isEmpty) {
            return const Center(child: Text("No hay tickets pendientes de gestión comercial."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: ticketsComerciales.length,
            itemBuilder: (context, index) {
              final ticket = ticketsComerciales[index];
              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.monetization_on, color: Colors.white),
                  ),
                  title: Text("Ticket: ${ticket.id}"),
                  subtitle: Text("Cliente: ${ticket.clienteId} | Equipo: ${ticket.equipo}"),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // 🚀 Ruteo hacia la celda de cotización inyectando la entidad del ticket
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GenerarCotizacionPage(ticket: ticket),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}