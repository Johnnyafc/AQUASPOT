import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/estacion_bodega_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Asegúrese de importar sus entidades, BLoC y rutas correctamente
// import 'ruta_hacia_su_ticket_bloc.dart';
// import 'ruta_hacia_su_estado_ticket.dart';

class BandejaBodegaPage extends StatelessWidget {
  const BandejaBodegaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bandeja de Entrada - Bodega'),
        backgroundColor: Colors.blue.shade800, // Color distintivo para la estación Bodega
      ),
      body: BlocBuilder<TicketBloc, TicketState>(
        builder: (context, state) {
          // 1. Verificación de estado de línea (Cargando o Error)
          if (state.status == TicketStatus.loading) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.brown),
            );
          } else if (state.status == TicketStatus.error) {
            return Center(
              child: Text(
                'Falla de telemetría: ${state.message}',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            );
          }

          // ==========================================
          // 2. FILTRO DEL MÚLTIPLEXOR (Solo tickets en Bodega)
          // ==========================================
          // ⚠️ NOTA TÉCNICA: En producción, esto debe venir filtrado desde Firestore.
          final ticketsBodega = state.historial
              .where((t) => t.estadoActual == EstadoTicket.bodega)
              .toList();

          // 3. Verificación de cola vacía
          if (ticketsBodega.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Línea despejada.\nNo hay requerimientos pendientes en Bodega.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          // ==========================================
          // 4. RENDERIZADO DE LA BANDA TRANSPORTADORA (ListView)
          // ==========================================
          return RefreshIndicator(
            onRefresh: () async {
              // Aquí debería inyectar su evento para refrescar la lista desde Firestore
              // context.read<TicketBloc>().add(ObtenerTicketsBodegaEvent());
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: ticketsBodega.length,
              itemBuilder: (context, index) {
                final ticket = ticketsBodega[index];
                
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12.0),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.brown.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    leading: CircleAvatar(
                      backgroundColor: Colors.brown.shade100,
                      child: const Icon(Icons.inventory_2, color: Colors.brown),
                    ),
                    title: Text(
                      'Ticket: ${ticket.id}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Proyecto: ${ticket.codigoProyecto ?? "Sin Asignar"}'),
                        Text('Equipo: ${ticket.equipo}'),
                        // Si desea mostrar la fecha en que llegó a bodega, extraigala del historial de eventos
                      ],
                    ),
                    trailing: ElevatedButton.icon(
  icon: const Icon(Icons.settings_suggest, size: 18),
  label: const Text('PROCESAR'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.brown.shade700,
    foregroundColor: Colors.white,
  ),
  onPressed: () {
    // 🚀 ENRUTAMIENTO ACTIVADO: De la bandeja de entrada a la estación de trabajo
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EstacionBodegaPage(ticket: ticket), // Le pasamos la telemetría del ticket actual
      ),
    );
  },
),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}