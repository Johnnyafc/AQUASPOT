// lib/features/tickets/presentation/pages/bandeja_compras_page.dart

import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/GestionComprasPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_state.dart';
import '../../domain/entities/ticket_entity.dart';
// import 'gestion_compras_page.dart'; // La pantalla que haremos en el siguiente paso

class BandejaComprasPage extends StatelessWidget {
  const BandejaComprasPage({Key? key}) : super(key: key);

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bandeja de Compras', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal.shade700, // Color industrial para Compras
      ),
      body: BlocBuilder<TicketBloc, TicketState>(
        builder: (context, state) {
          if (state.status == TicketStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          // ⚙️ FILTRO SCADA: Capturamos los tickets en tránsito o listos
          final ticketsCompras = state.historial.where((t) {
            return t.estadoActual == EstadoTicket.costos || 
                   t.estadoActual == EstadoTicket.compras;
          }).toList();

          if (ticketsCompras.isEmpty) {
            return const Center(
              child: Text(
                'Línea despejada. No hay requerimientos de compra.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: ticketsCompras.length,
            itemBuilder: (context, index) {
              final ticket = ticketsCompras[index];
              
              // 🔍 LECTURA DE ESTADO (Solo para HMI visual, sin enclavamiento de navegación)
              final bool procesadoPorCostos = ticket.estadoActual == EstadoTicket.compras || 
                                              ticket.isCostosCompletado;

              return Card(
                elevation: procesadoPorCostos ? 4 : 2, 
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: procesadoPorCostos ? Colors.teal : Colors.red.shade300, 
                    width: 1.5
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: procesadoPorCostos ? Colors.teal.shade100 : Colors.red.shade50,
                    child: Icon(
                      procesadoPorCostos ? Icons.shopping_cart_checkout : Icons.warning_amber_rounded, 
                      color: procesadoPorCostos ? Colors.teal.shade800 : Colors.red.shade700
                    ),
                  ),
                  title: Text(
                    'Ticket: ${ticket.id}', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text('Proyecto: ${ticket.codigoProyecto ?? 'PENDIENTE DE CREACIÓN'}', 
                        style: TextStyle(
                          color: ticket.codigoProyecto != null ? Colors.black87 : Colors.red,
                          fontWeight: ticket.codigoProyecto != null ? FontWeight.normal : FontWeight.bold
                        )
                      ),
                      const SizedBox(height: 8),
                      
                      // 🚦 SEMÁFORO DE ESTADO LOGÍSTICO
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: procesadoPorCostos ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: procesadoPorCostos ? Colors.green : Colors.red.shade400),
                        ),
                        child: Text(
                          procesadoPorCostos 
                              ? '🟢 HABILITADO PARA COMPRA' 
                              : '🔴 COSTOS NO PROCESADO',
                          style: TextStyle(
                            fontSize: 12, 
                            fontWeight: FontWeight.bold,
                            color: procesadoPorCostos ? Colors.green.shade700 : Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // 🚀 Válvula de inspección abierta: Acceso a detalles sin restricción
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GestionComprasPage(ticket: ticket),
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