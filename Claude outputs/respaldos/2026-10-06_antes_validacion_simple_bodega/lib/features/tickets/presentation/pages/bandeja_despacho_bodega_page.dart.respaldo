import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_state.dart';
import 'despacho_ticket_bodega_page.dart';

class BandejaDespachoBodegaPage extends StatelessWidget {
  const BandejaDespachoBodegaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Despachar Repuestos - Bodega',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF005A9C),
        foregroundColor: Colors.white,
      ),
      body: BlocBuilder<TicketBloc, TicketState>(
        builder: (context, state) {
          if (state.status == TicketStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Filtro: Tickets con repuestos registrados para despacho en Bodega (Caracol)
          // Se muestran en paralelo al asignarse código de proyecto (para despachar lo que haya en stock)
          // o cuando Compras haya validado al menos un ítem o esté formalmente en Bodega,
          // y que aún no estén despachados al 100%
          final ticketsDespacho = state.historial.where((t) {
            // Repuestos registrados para despacho en bodega
            final bool tieneRepuestos = t.itemsDespachoBodega.isNotEmpty ||
                (t.evaluacionTecnica?.repuestosTaller.isNotEmpty ?? false);
            if (!tieneRepuestos) return false;

            // Si ya pasó a etapas posteriores al taller
            if (t.estadoActual == EstadoTicket.validacionFacturacion ||
                t.estadoActual == EstadoTicket.entrega ||
                t.estadoActual == EstadoTicket.finalizado ||
                t.estadoActual == EstadoTicket.anulado) {
              return false;
            }

            // Si ya completó el 100% de despacho Y no tiene evidencias pendientes, ya concluyó su ciclo en bodega
            if (t.bodegaDespachoCompleto && !t.tieneDespachoPendienteDeEvidencia) {
              return false;
            }

            final tieneProyecto = t.codigoProyecto != null && t.codigoProyecto!.trim().isNotEmpty;
            final enEstadoBodega = t.estadoActual == EstadoTicket.bodega;
            final visiblePorCompras = t.tieneAlMenosUnCheckCompras;

            return tieneProyecto || enEstadoBodega || visiblePorCompras;
          }).toList();

          if (ticketsDespacho.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 72, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay requerimientos pendientes de despacho en Bodega.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aparecerán automáticamente cuando Compras valide los repuestos que vayan llegando.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ticketsDespacho.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final ticket = ticketsDespacho[index];
              final items = ticket.itemsDespachoBodega;
              final validadosCompras = items.where((i) => i.validadoPorCompras).length;
              final despachados = ticket.itemsDespachados.length;
              final total = items.length;
              final tieneParcial = ticket.tieneAlMenosUnDespachoBodega;

              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: tieneParcial
                        ? Colors.orange.shade300
                        : Colors.blue.shade200,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DespachoTicketBodegaPage(ticket: ticket),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                ticket.id,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D47A1),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${ticket.equipo.name.toUpperCase()} • ${ticket.marca.toUpperCase()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: ticket.tieneDespachoPendienteDeEvidencia
                                    ? Colors.amber.shade100
                                    : tieneParcial
                                        ? Colors.orange.shade50
                                        : const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: ticket.tieneDespachoPendienteDeEvidencia
                                      ? Colors.amber.shade800
                                      : tieneParcial
                                          ? Colors.orange
                                          : const Color(0xFF2E7D32),
                                ),
                              ),
                              child: Text(
                                ticket.tieneDespachoPendienteDeEvidencia
                                    ? '⚠️ Bloqueado: Falta Evidencia'
                                    : tieneParcial
                                        ? 'Despacho Parcial'
                                        : '$validadosCompras Ítems Listos',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: ticket.tieneDespachoPendienteDeEvidencia
                                      ? Colors.amber.shade900
                                      : tieneParcial
                                          ? Colors.orange.shade900
                                          : const Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Cliente / Campamento: ${ticket.campamento.isNotEmpty ? ticket.campamento : ticket.clienteId}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (ticket.numeroSerie != null &&
                            ticket.numeroSerie!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Serie: ${ticket.numeroSerie}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 16, color: const Color(0xFF2E7D32)),
                            const SizedBox(width: 4),
                            Text(
                              'Habilitados por compras: $validadosCompras de $total',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '($despachados despachados)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const Spacer(),
                            const Text(
                              'Gestionar Despacho >',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF005A9C),
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
