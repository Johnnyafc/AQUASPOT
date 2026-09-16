import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/GenerarCotizacionPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../features/tickets/presentation/bloc/ticket_bloc.dart';
import '../../../../features/tickets/domain/entities/ticket_entity.dart';
import '../widgets/tiempo_en_curso_widget.dart';
import '../../../../core/theme/ticket_visual_theme.dart';

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
                key: ValueKey(ticket.id),
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                child: ListTile(
                  leading: const AvatarSuave(color: kTicketAcento, icono: Icons.monetization_on),
                  title: Text("Ticket: ${ticket.id}"),
                  // 🆕 Tiempo en vivo en el estado actual (sin backend: se
                  // recalcula contra la hora real del dispositivo).
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🆕 Cliente (empresa/camaronera) y Contacto (persona) son
                      // datos distintos — se muestran ambos.
                      Text(
                        "${ticket.clienteId.trim().isNotEmpty ? 'Cliente: ${ticket.clienteId} | ' : ''}"
                        "Contacto: ${ticket.nombreContacto} | Equipo: ${ticket.equipo.name.toUpperCase()} • Marca: ${ticket.marca.toUpperCase()}",
                      ),
                      if (ticket.noRequiereCompras) ...[
                        const SizedBox(height: 4),
                        const InsigniaSuave(
                          color: Colors.deepOrange,
                          icono: Icons.remove_shopping_cart,
                          texto: 'NO REQUIERE COMPRAS',
                        ),
                      ],
                      const SizedBox(height: 4),
                      TiempoEnCursoWidget(
                        desde: ticket.fechaInicioEstadoActual,
                        builder: (context, texto) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.hourglass_bottom, size: 12, color: kTicketIcono),
                            const SizedBox(width: 4),
                            Text(texto, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTicketTextoSecundario)),
                          ],
                        ),
                      ),
                    ],
                  ),
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