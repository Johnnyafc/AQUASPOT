// lib/features/tickets/presentation/widgets/codigos_creados_costos_widget.dart
//
// 🧾 Venta de Repuesto con repuestos que no estaban en el sistema. En
// Proformas enviadas muestra:
// - antes de Costos: aviso de que, cuando el cliente acepte, Costos debe
//   crear los códigos (la OV aún no se registra);
// - después de Costos: recuadro grande "EL CÓDIGO DEL REPUESTO ES: …" con
//   lo que registró Costos, para usarlo en la OV.

import 'package:flutter/material.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/services/creacion_codigos_venta_service.dart';
import 'copy_icon_button_widget.dart';

class CodigosCreadosCostosWidget extends StatelessWidget {
  final TicketEntity ticket;
  final bool compacto; // en la tarjeta de la bandeja

  const CodigosCreadosCostosWidget({super.key, required this.ticket, this.compacto = false});

  String _fecha(DateTime? f) => f == null
      ? ''
      : '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} '
          '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (CreacionCodigosVentaService.requiereCreacionCodigos(ticket)) {
      final n = CreacionCodigosVentaService.indicesPendientes(ticket).length;
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.shade400, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.qr_code_2, color: Colors.orange.shade900),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$n repuesto(s) no están en el sistema. Cuando el cliente acepte la proforma, '
                'Costos debe crear los códigos antes de registrar la OV.',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange.shade900),
              ),
            ),
          ],
        ),
      );
    }

    if (!CreacionCodigosVentaService.tieneCodigosCreados(ticket)) return const SizedBox.shrink();

    final creados = ticket.lineasRepuestoVenta.where((l) => l.codigoCreadoPorCostos).toList();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(compacto ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade600, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified, color: Colors.green.shade800, size: compacto ? 22 : 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CÓDIGOS CREADOS POR COSTOS — use estos códigos en la OV',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: compacto ? 14 : 17,
                    color: Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final l in creados)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: 'El código del repuesto es: ',
                              style: TextStyle(fontSize: compacto ? 14 : 16, color: Colors.green.shade900),
                            ),
                            TextSpan(
                              text: l.codigo,
                              style: TextStyle(
                                fontSize: compacto ? 16 : 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ]),
                        ),
                        Text('${l.descripcion} · ${l.unidad} · Cantidad: ${l.cantidad % 1 == 0 ? l.cantidad.toStringAsFixed(0) : l.cantidad}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          'Creado por ${l.codigoCreadoPor ?? 'Costos'}${l.codigoCreadoEn != null ? ' el ${_fecha(l.codigoCreadoEn)}' : ''}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  CopyIconButtonWidget(etiqueta: 'Código', valor: l.codigo),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
