import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/validacion_bodega_compras_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/widgets/tiempo_en_curso_widget.dart';
import 'package:aquaspot_postventa/core/theme/ticket_visual_theme.dart';

class BandejaBodegaPage extends StatelessWidget {
  const BandejaBodegaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validación Bodega (Compras)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: BlocBuilder<TicketBloc, TicketState>(
        builder: (context, state) {
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

          // =========================================================================
          // FILTRO VALIDACIÓN BODEGA (COMPRAS)
          // Muestra los tickets en etapa de compras pendientes de validar en bodega.
          // - Caracol: Compras valida repuestos que van llegando (salen a Despacho Bodega).
          // - Otros equipos: Compras valida en bodega y se transfieren directo a Proceso de Trabajo.
          // =========================================================================
          final ticketsValidacion = state.historial.where((t) {
            // Si ya fue transferido a Proceso de Trabajo o superior, ya salió de validación
            final yaEnTallerOSuperior = t.estadoActual == EstadoTicket.procesoTrabajo ||
                t.estadoActual == EstadoTicket.validacionFacturacion ||
                t.estadoActual == EstadoTicket.entrega ||
                t.estadoActual == EstadoTicket.finalizado ||
                t.estadoActual == EstadoTicket.anulado;

            if (yaEnTallerOSuperior) return false;

            // Requiere que la OC ya haya sido gestionada por Compras
            final ocGestionada = t.gestionCompras != null || t.isComprasCompletado;
            if (!ocGestionada) return false;

            final esCaracol = t.equipo == TipoEquipo.Caracol ||
                t.equipo.name.toLowerCase().contains('caracol');

            if (esCaracol) {
              // En Caracol permanece en Validación Bodega hasta que Compras complete la validación o se transfiera a Bodega
              final yaTransferidoABodega = t.estadoActual == EstadoTicket.bodega;
              return !yaTransferidoABodega && !t.comprasValidacionCompleta;
            } else {
              // Para otros equipos, Compras valida que todo esté en bodega y de allí va directo a taller
              // Permanece aquí mientras no haya sido transferido a taller
              return true;
            }
          }).toList();

          if (ticketsValidacion.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fact_check_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No hay requerimientos pendientes de validación en bodega.\nLos tickets completados han avanzado a sus siguientes estaciones.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // Refrescar lista
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: ticketsValidacion.length,
              itemBuilder: (context, index) {
                final ticket = ticketsValidacion[index];
                final esCaracol = ticket.equipo == TipoEquipo.Caracol ||
                    ticket.equipo.name.toLowerCase().contains('caracol');
                final validados = ticket.itemsDespachoBodega.where((i) => i.validadoPorCompras).length;
                final total = ticket.itemsDespachoBodega.isNotEmpty
                    ? ticket.itemsDespachoBodega.length
                    : (ticket.evaluacionTecnica?.repuestosTaller.length ?? 0);

                return Card(
                  key: ValueKey(ticket.id),
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12.0),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    leading: const AvatarSuave(color: kTicketAcento, icono: Icons.fact_check),
                    title: Text(
                      'Ticket: ${ticket.id}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Equipo: ${ticket.equipo.name.toUpperCase()} • Marca: ${ticket.marca.toUpperCase()}'),
                        if (ticket.clienteId.trim().isNotEmpty) Text('Cliente: ${ticket.clienteId}'),
                        Text('Contacto: ${ticket.nombreContacto}'),
                        const SizedBox(height: 6),
                        if (esCaracol)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: validados > 0 ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: validados > 0 ? const Color(0xFF81C784) : Colors.orange.shade300,
                              ),
                            ),
                            child: Text(
                              validados > 0
                                  ? '✓ $validados de $total validados (Visible en Bodega)'
                                  : '⏳ 0 de $total validados (Pendiente)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: validados > 0 ? const Color(0xFF2E7D32) : Colors.orange.shade900,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE1F5FE),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF0288D1),
                              ),
                            ),
                            child: const Text(
                              '📦 OC Registrada • Pendiente Validación en Bodega',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF01579B),
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
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
                    trailing: ElevatedButton.icon(
                      icon: const Icon(Icons.checklist, size: 18),
                      label: const Text('VALIDAR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF005A9C),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ValidacionBodegaComprasPage(ticket: ticket),
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
