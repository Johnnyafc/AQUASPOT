import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Asegúrese de importar sus modelos, enums y blocs

class BandejaRecepcionGuaboPage extends StatelessWidget {
  const BandejaRecepcionGuaboPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bandeja de Tránsito - EL GUABO', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey[900], // Color industrial clásico
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200), // ⚙️ Restricción de chasis
            child: BlocBuilder<TicketBloc, TicketState>(
              builder: (context, state) {
                if (state.status == TicketStatus.loading && state.historial.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                // =========================================================
                // 🧠 FILTRO LÓGICO DE PRESENTACIÓN
                // Nota: Idealmente, el BLoC ya le entrega esta lista limpia
                // desde un query optimizado de Firestore.
                // =========================================================
                final ticketsEnTransito = state.historial.where((t) {
                  final esGuabo = t.sede.toString().toUpperCase().contains('EL_GUABO');
                  final estaEnCamino = t.estadoActual == EstadoTicket.enCamino;
                  return esGuabo && estaEnCamino;
                }).toList();

                if (ticketsEnTransito.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                        SizedBox(height: 16),
                        Text(
                          'Bandeja limpia. No hay equipos en tránsito.',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // =========================================================
                // 📐 HMI RESPONSIVO (Tablet vs Desktop)
                // =========================================================
                return LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 800) {
                      return _buildGridView(ticketsEnTransito, context);
                    } else {
                      return _buildListView(ticketsEnTransito, context);
                    }
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------
  // 📱 VISTA COMPACTA (Tablets / Móviles)
  // -----------------------------------------------------
  Widget _buildListView(List<TicketEntity> tickets, BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tickets.length,
      itemBuilder: (context, index) {
        return _TicketCard(ticket: tickets[index]);
      },
    );
  }

  // -----------------------------------------------------
  // 🖥️ VISTA EXPANDIDA (Monitores de Sala de Control)
  // -----------------------------------------------------
  Widget _buildGridView(List<TicketEntity> tickets, BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 columnas
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.5, // Ajuste según la cantidad de datos que muestre
      ),
      itemCount: tickets.length,
      itemBuilder: (context, index) {
        return _TicketCard(ticket: tickets[index]);
      },
    );
  }
}

// =========================================================
// 🎫 COMPONENTE AISLADO: TARJETA DE TICKET
// =========================================================
class _TicketCard extends StatelessWidget {
  final TicketEntity ticket;

  const _TicketCard({Key? key, required this.ticket}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Evita RenderFlex exceptions
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ID: ${ticket.id}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Text(
                    'EN CAMINO',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const Divider(),
            Text('Equipo: ${ticket.equipo.name} - ${ticket.marca}', style: const TextStyle(fontSize: 14)),
            Text('Falla: ${ticket.fallaReportada}', maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),// Aquí es seguro usar Spacer porque el Card tiene tamaño definido por el padre
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // 🚀 DISPARADOR DE TRANSICIÓN DE ESTADO
                  _confirmarRecepcion(context, ticket);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.download_done, color: Colors.white),
                label: const Text('CONFIRMAR RECEPCIÓN EN TALLER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

void _confirmarRecepcion(BuildContext context, TicketEntity ticket) {
    // ⚡ 1. Lectura de los sensores de identidad (AuthBloc)
    final authState = context.read<AuthBloc>().state;
    String nombreOperario = 'OPERARIO_DESCONOCIDO';
    String rolOperario = 'SISTEMA';

    if (authState is Authenticated) { 
      nombreOperario = authState.usuario.nombre; 
      rolOperario = authState.usuario.rol.name; 
    }

    // 🚀 2. Disparo del actuador hacia el bus de datos
    context.read<TicketBloc>().add(
      ActualizarEstadoTicketEvent(
        ticket: ticket, 
        nuevoEstado: EstadoTicket.recepcionFisica,
        accionAuditoria: 'EQUIPO ENVIADO DESDE EL GUABO RECIBIDO EN TALLER',
        nombreUsuario: nombreOperario, 
        rolUsuario: rolOperario,       
      )
    );
    
    // 🔔 3. Feedback visual local
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Comando de recepción enviado para ${ticket.id}'),
        backgroundColor: Colors.blueAccent, // Color estándar para acciones de proceso
        duration: const Duration(seconds: 2),
      ),
    );
  }
}