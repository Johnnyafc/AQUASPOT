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

          // ⚙️ FILTRO SCADA: Capturamos los tickets en tránsito (Costos) y los listos (Compras)
          final ticketsCompras = state.historial.where((t) {
            // Reemplace 'costos' y 'compras' por los valores reales de su enum EstadoTicket
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
              
              // 🔒 Lógica de Enclavamiento
              // Si está en compras O el flag de costos está activo, se libera el seguro.
              final bool estaHabilitado = ticket.estadoActual == EstadoTicket.compras || 
                                          ticket.isCostosCompletado;

              return Card(
                elevation: estaHabilitado ? 4 : 1, // Resalta los que requieren acción
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: estaHabilitado ? Colors.teal : Colors.grey.shade300, 
                    width: estaHabilitado ? 1.5 : 1
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: estaHabilitado ? Colors.teal.shade100 : Colors.grey.shade200,
                    child: Icon(
                      estaHabilitado ? Icons.shopping_cart_checkout : Icons.lock_clock,
                      color: estaHabilitado ? Colors.teal.shade800 : Colors.grey.shade600,
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
                      // 🚦 Semáforo de Estado
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: estaHabilitado ? Colors.green.shade50 : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: estaHabilitado ? Colors.green : Colors.amber),
                        ),
                        child: Text(
                          estaHabilitado 
                              ? '🟢 HABILITADO PARA COMPRA' 
                              : '🟡 ESPERANDO A COSTOS',
                          style: TextStyle(
                            fontSize: 12, 
                            fontWeight: FontWeight.bold,
                            color: estaHabilitado ? Colors.green.shade700 : Colors.amber.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    if (estaHabilitado) {
                      // 🚀 Válvula abierta: Transición a la estación de compras
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GestionComprasPage(ticket: ticket),
                        ),
                      );
                    } else {
                      // 🛑 Válvula cerrada: Enclavamiento de seguridad
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('ACCESO DENEGADO: El departamento de Costos aún no genera el proyecto.'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        )
                      );
                    }
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