import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/subir_evidencia_trabajo_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BandejaTrabajosPage extends StatefulWidget {
  const BandejaTrabajosPage({super.key});

  @override
  State<BandejaTrabajosPage> createState() => _BandejaTrabajosPageState();
}

class _BandejaTrabajosPageState extends State<BandejaTrabajosPage> {
  @override
  void initState() {
    super.initState();
    // 🚀 DISPARO CRÍTICO: Solicitamos los tickets al montar la estación.
    context.read<TicketBloc>().add(
      ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.ninguno)
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Línea de Trabajo - Operaciones', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey.shade800, // Color distintivo del Taller
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: BlocBuilder<TicketBloc, TicketState>(
          builder: (context, state) {
            // 1. Diagnóstico del bus de datos
            if (state.status == TicketStatus.loading) {
              return Center(child: CircularProgressIndicator(color: Colors.blueGrey.shade800));
            } else if (state.status == TicketStatus.error) {
              return Center(
                child: Text(
                  'Falla de telemetría: ${state.message}',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              );
            }

            // 2. Selección segura de la lista
            final listaAProcesar = state.tickets.isNotEmpty ? state.tickets : (state.historial ?? []);

            // 3. Filtro del multiplexor (Solo Proceso de Trabajo)
            final ticketsTrabajo = listaAProcesar
                .where((t) => t.estadoActual == EstadoTicket.procesoTrabajo)
                .toList();

            // 4. Sensor de presencia (Cola vacía)
            if (ticketsTrabajo.isEmpty) {
              return _buildEmptyState();
            }

            // 🖥️ 5. CHÁSIS ESTRUCTURAL REFORZADO (Contención Web/Móvil)
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        color: Colors.blueGrey,
                        onRefresh: () async {
                          // Recarga manual forzada por el operario
                          context.read<TicketBloc>().add(
                            ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.ninguno)
                          );
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: ticketsTrabajo.length,
                          itemBuilder: (context, index) {
                            final ticket = ticketsTrabajo[index];
                            return _buildTicketCard(context, ticket);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ⚙️ SUBRUTINA: Tarjeta del Ticket (Refactorizada)
  Widget _buildTicketCard(BuildContext context, dynamic ticket) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.blueGrey.shade200),
        borderRadius: BorderRadius.circular(12),
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
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF003057)),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text('Proyecto: ${ticket.codigoProyecto ?? "Sin Asignar"}', style: TextStyle(color: Colors.grey.shade800)),
            // 🛠️ CORRECCIÓN CRÍTICA: Llamada segura usando toString() en lugar de .name
            Text('Equipo: ${ticket.equipo.toString().toUpperCase()}', style: TextStyle(color: Colors.grey.shade800)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Falla: ${ticket.fallaReportada}', 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            )
          ],
        ),
        trailing: ElevatedButton.icon(
          icon: const Icon(Icons.camera_alt, size: 18),
          label: const Text('Subir evidencia'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey.shade700,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            // 🚀 ENRUTAMIENTO HACIA LA ESTACIÓN DE RECOLECCIÓN DE EVIDENCIA
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SubirEvidenciaTrabajoPage(ticket: ticket),
              ),
            );
          },
        ),
      ),
    );
  }

  // ⚙️ SUBRUTINA: Estado Vacío de Taller
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.precision_manufacturing_outlined, size: 80, color: Colors.blueGrey.shade300),
          const SizedBox(height: 16),
          Text(
            'Línea Despejada',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            'No hay equipos en proceso de trabajo en este momento.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.blueGrey.shade500),
          ),
        ],
      ),
    );
  }
}