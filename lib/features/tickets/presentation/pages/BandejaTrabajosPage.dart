import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// ⚠️ Conecte sus buses de datos correctamente
// import 'ruta_hacia_su_ticket_bloc.dart';
// import 'ruta_hacia_su_estado_ticket.dart';

class BandejaTrabajosPage extends StatelessWidget {
  const BandejaTrabajosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Línea de Trabajo - Operaciones'),
        backgroundColor: Colors.blueGrey.shade800, // Color distintivo para la estación de Taller
        foregroundColor: Colors.white,
      ),
      body: BlocBuilder<TicketBloc, TicketState>(
        builder: (context, state) {
          // 1. Verificación del estado del bus de datos
          if (state.status == TicketStatus.loading) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueGrey),
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
          // 2. FILTRO DEL MÚLTIPLEXOR (Solo tickets en Proceso de Trabajo)
          // ==========================================
          // ⚠️ Le recuerdo su deuda técnica: En producción, este filtro debe ejecutarse
          // mediante un query nativo en Firestore, no saturando la RAM del dispositivo local.
          final ticketsTrabajo = state.historial
              .where((t) => t.estadoActual == EstadoTicket.procesoTrabajo)
              .toList();

          // 3. Sensor de presencia (Cola vacía)
          if (ticketsTrabajo.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.precision_manufacturing_outlined, size: 80, color: Colors.blueGrey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Línea de ensamblaje inactiva.\nNo hay equipos en proceso de trabajo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.blueGrey.shade600),
                  ),
                ],
              ),
            );
          }

          // ==========================================
          // 4. RENDERIZADO DE LA LÍNEA DE TALLER (ListView)
          // ==========================================
          return RefreshIndicator(
            color: Colors.blueGrey,
            onRefresh: () async {
              // context.read<TicketBloc>().add(ObtenerTicketsTrabajoEvent());
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: ticketsTrabajo.length,
              itemBuilder: (context, index) {
                final ticket = ticketsTrabajo[index];
                
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 12.0),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.blueGrey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    leading: CircleAvatar(
                      backgroundColor: Colors.blueGrey.shade100,
                      radius: 24,
                      child: const Icon(Icons.build_circle, color: Colors.blueGrey, size: 28),
                    ),
                    title: Text(
                      'Ticket: ${ticket.id}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text('Proyecto: ${ticket.codigoProyecto ?? "Sin Asignar"}'),
                        Text('Equipo: ${ticket.equipo.name.toUpperCase()}'),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Falla: ${ticket.fallaReportada}', 
                                maxLines: 1, 
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                    trailing: ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt, size: 18), // Icono preparatorio para su próxima HMI
                      label: const Text('Subir evidencia'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey.shade700,
                        foregroundColor: Colors.white,
                        elevation: 2,
                      ),
                      onPressed: () {
                        // 🚀 ENRUTAMIENTO HACIA LA ESTACIÓN DE RECOLECCIÓN DE EVIDENCIA
                        // Navigator.push(
                        //   context,
                        //   MaterialPageRoute(
                        //     builder: (_) => EstacionEjecucionTrabajoPage(ticket: ticket),
                        //   ),
                        // );
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