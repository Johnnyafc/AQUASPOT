// lib/features/tickets/presentation/pages/bandeja_compras_page.dart

import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/GestionComprasPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_state.dart';
import '../../domain/entities/ticket_entity.dart';
import '../widgets/tiempo_en_curso_widget.dart';
import '../../../../core/theme/ticket_visual_theme.dart';
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

          // ⚙️ FILTRO SCADA: Capturamos los tickets en etapa de compras pendientes de subir OC
          final ticketsCompras = state.historial.where((t) {
            final enCompras = t.estadoActual == EstadoTicket.costos || 
                              t.estadoActual == EstadoTicket.compras;
            final pendienteOC = t.gestionCompras == null;
            return enCompras && pendienteOC;
          }).toList();

          if (ticketsCompras.isEmpty) {
            return const Center(
              child: Text(
                'Línea despejada. No hay requerimientos de compra pendientes de OC.',
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

              // 🎨 Antes esta misma señal (¿ya se procesó por costos?) se
              // repetía 4 veces con color (borde de la tarjeta, avatar,
              // caja de semáforo y emoji 🟢/🔴) — mucha redundancia visual
              // para un solo dato. Ahora un único color con significado
              // (kTicketExito/kTicketAlerta) y una sola insignia lo dicen.
              final colorEstadoCompra = procesadoPorCostos ? kTicketExito : kTicketAlerta;
              return Card(
                key: ValueKey(ticket.id),
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade300, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: AvatarSuave(
                    color: colorEstadoCompra,
                    icono: procesadoPorCostos ? Icons.shopping_cart_checkout : Icons.warning_amber_rounded,
                  ),
                  title: Text(
                    'Ticket: ${ticket.id}', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        'Equipo: ${ticket.equipo.name.toUpperCase()} • Marca: ${ticket.marca.toUpperCase()}'
                        '${ticket.clienteId.trim().isNotEmpty ? ' | Cliente: ${ticket.clienteId}' : ''}'
                        ' | Contacto: ${ticket.nombreContacto}',
                      ),
                      const SizedBox(height: 4),
                      Text('Proyecto: ${ticket.codigoProyecto ?? 'PENDIENTE DE CREACIÓN'}',
                        style: TextStyle(
                          color: ticket.codigoProyecto != null ? kTicketTextoPrincipal : kTicketAlerta,
                          fontWeight: ticket.codigoProyecto != null ? FontWeight.normal : FontWeight.bold
                        )
                      ),
                      const SizedBox(height: 8),

                      // 🚦 UNA sola insignia (antes: caja + emoji, redundante con el
                      // avatar y el borde que ya se quitaron arriba).
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          InsigniaSuave(
                            color: colorEstadoCompra,
                            texto: procesadoPorCostos ? 'HABILITADO PARA COMPRA' : 'COSTOS NO PROCESADO',
                          ),
                          if (ticket.noRequiereCompras)
                            InsigniaSuave(
                              color: Colors.deepOrange.shade900,
                              texto: 'NO REQUIERE COMPRAS',
                            ),
                        ],
                      ),
                      // 🆕 Tiempo en vivo en el estado actual (sin backend: se
                      // recalcula contra la hora real del dispositivo).
                      const SizedBox(height: 8),
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