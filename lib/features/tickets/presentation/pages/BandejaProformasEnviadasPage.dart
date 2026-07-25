import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/detalle_proforma_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// ... tus importaciones (TicketBloc, TicketEntity, etc.)

class BandejaProformasEnviadasPage extends StatelessWidget {
  const BandejaProformasEnviadasPage({super.key});

  // ⚙️ SUBRUTINA: Modal de acción segura
  void _mostrarDialogoAccion(BuildContext context, TicketEntity ticket, String accion) {
    final TextEditingController observacionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (contextDialog) {
        return AlertDialog(
          title: Text('$accion Proforma: ${ticket.id}'),
          content: TextField(
            controller: observacionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Observación (Obligatoria/Opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contextDialog),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () {
                final observacion = observacionController.text;
                // 🚀 AQUÍ DISPARAREMOS EL EVENTO AL BLOC MÁS ADELANTE
                print('Acción: $accion, Ticket: ${ticket.id}, Obs: $observacion');
                Navigator.pop(contextDialog);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accion == 'ANULAR' ? Colors.red : Colors.green,
              ),
              child: Text('CONFIRMAR $accion'),
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Proformas Enviadas'), backgroundColor: Colors.blue),
      body: BlocBuilder<TicketBloc, TicketState>(
        builder: (context, state) {
          // 🔌 Nos conectamos a la válvula de proformas
          final tickets = state.proformasEnviadas;

          if (state.status == TicketStatus.loading && tickets.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (tickets.isEmpty) {
            return const Center(child: Text('No hay proformas pendientes de respuesta.'));
          }

         return ListView.builder(
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              
              // 🧠 Lógica de visualización para facturación
              final String responsable = (ticket.responsableFacturacion ?? 'NO DEFINIDO').toUpperCase();
              final bool esGarantia = ticket.tipoRequerimiento == TipoRequerimiento.reclamoGarantia;

              return Card(
                margin: const EdgeInsets.all(8.0),
                elevation: 3,
                clipBehavior: Clip.antiAlias, 
                child: InkWell(
                  onTap: () {
                    // 🔌 NAVEGACIÓN HACIA EL DETALLE COMPLETO
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DetalleProformaPage(ticket: ticket)),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Ticket: ${ticket.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const Icon(Icons.chevron_right, color: Colors.grey), 
                          ],
                        ),
                        const Divider(),
                        Text('Cliente: ${ticket.clienteId}'),
                        Text('Equipo: ${ticket.equipo.name}'),
                        const SizedBox(height: 4),
                        Text('Falla: ${ticket.fallaReportada}', maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 12),
                        
                        // ==========================================
                        // 🏷️ BALIZA DE DESTINO DE FACTURACIÓN
                        // ==========================================
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            // Conmutación de colores: Naranja si es garantía, Azul si es normal
                            color: esGarantia ? Colors.orange.shade50 : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: esGarantia ? Colors.orange.shade300 : Colors.blue.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.request_quote, 
                                size: 16, 
                                color: esGarantia ? Colors.orange.shade800 : Colors.blue.shade800
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Facturar a: $responsable',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: esGarantia ? Colors.orange.shade900 : Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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