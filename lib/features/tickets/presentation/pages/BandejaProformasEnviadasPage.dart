import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/detalle_proforma_page.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart'; // 🔌 Inyección de módulo de seguridad
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart'; // 🔌 Inyección de módulo de seguridad
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BandejaProformasEnviadasPage extends StatelessWidget {
  const BandejaProformasEnviadasPage({super.key});

  // ⚙️ SUBRUTINA 1: Modal de acción segura (Aprobar/Rechazar/Anular)
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
                // 🚀 AQUÍ DISPARAREMOS EL EVENTO AL BLOC DE ESTADO FINAL
                print('Acción: $accion, Ticket: ${ticket.id}, Obs: $observacion');
                Navigator.pop(contextDialog);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accion == 'ANULAR' ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('CONFIRMAR $accion'),
            ),
          ],
        );
      }
    );
  }

  // 🚨 SUBRUTINA 2: Modal de Reporte de Anomalías (Cordón Andon Comercial)
  void _mostrarDialogoReporte(BuildContext context, TicketEntity ticket) {
    final TextEditingController reporteController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (contextDialog) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.report_problem, color: Colors.orange),
              const SizedBox(width: 8),
              Text('Reportar Anomalía: ${ticket.id}', style: const TextStyle(fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Registre el motivo del retraso (Ej: Cliente no contesta, en revisión gerencial).',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reporteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Detalle del reporte comercial',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.comment),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contextDialog),
              child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final reporte = reporteController.text.trim();
                
                // 🛑 Bloqueo físico: No se permite reporte vacío
                if (reporte.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ El reporte no puede estar vacío.'), backgroundColor: Colors.red)
                  );
                  return; 
                }

                // 🔌 EXTRACCIÓN DE IDENTIDAD PARA AUDITORÍA
                final authState = context.read<AuthBloc>().state;
                String operador = 'DESCONOCIDO';
                String rol = 'SIN_ROL';
                
                if (authState is Authenticated) {
                  operador = authState.usuario.nombre;
                  rol = authState.usuario.rol.name.toUpperCase();
                }

                // 🚀 DISPARO FÍSICO AL BLoC
                context.read<TicketBloc>().add(
                  ReportarIncidenciaComercialEvent(
                    ticket: ticket,
                    reporteComercial: reporte,
                    nombreUsuario: operador,
                    rolUsuario: rol,
                  )
                );
                
                Navigator.pop(contextDialog);
              },
              icon: const Icon(Icons.send, size: 16),
              label: const Text('REGISTRAR REPORTE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proformas Enviadas', style: TextStyle(fontWeight: FontWeight.bold)), 
        backgroundColor: const Color(0xFF005A9C),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF4F7F6),
      // ⚙️ Reemplazamos BlocBuilder por BlocConsumer para escuchar la confirmación del reporte
      body: BlocConsumer<TicketBloc, TicketState>(
        listener: (context, state) {
          if (state.status == TicketStatus.operationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.green)
            );
          } else if (state.status == TicketStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red)
            );
          }
        },
        builder: (context, state) {
          // 🔌 Nos conectamos a la válvula de proformas
          final tickets = state.proformasEnviadas;

          if (state.status == TicketStatus.loading && tickets.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF005A9C)));
          }

          if (tickets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_turned_in, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No hay proformas pendientes de respuesta.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

         return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              
              // 🧠 Lógica de visualización para facturación
              final String responsable = (ticket.responsableFacturacion ?? 'NO DEFINIDO').toUpperCase();
              final bool esGarantia = ticket.tipoRequerimiento == TipoRequerimiento.reclamoGarantia;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300, width: 1)
                ),
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
                        Text('Equipo: ${ticket.equipo.toString().toUpperCase()}'),
                        const SizedBox(height: 4),
                        Text('Falla: ${ticket.fallaReportada}', maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 12),
                        
                        // ==========================================
                        // 🏷️ BALIZA DE DESTINO Y ACTUADOR DE ALARMA
                        // ==========================================
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 1. BALIZA DE FACTURACIÓN
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
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

                            // 2. 🚨 ACTUADOR: REPORTE COMERCIAL
                            TextButton.icon(
                              onPressed: () => _mostrarDialogoReporte(context, ticket),
                              icon: const Icon(Icons.report_problem, size: 18, color: Colors.orange),
                              label: const Text('REPORTAR', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                          ],
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