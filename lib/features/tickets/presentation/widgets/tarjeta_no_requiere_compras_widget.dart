// lib/features/tickets/presentation/widgets/tarjeta_no_requiere_compras_widget.dart

import 'package:flutter/material.dart';
import '../../domain/entities/ticket_entity.dart';

class TarjetaNoRequiereComprasWidget extends StatelessWidget {
  final TicketEntity ticket;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onEditar;

  const TarjetaNoRequiereComprasWidget({
    super.key,
    required this.ticket,
    this.margin = const EdgeInsets.symmetric(vertical: 10),
    this.onEditar,
  });

  String _formatearFecha(DateTime dt) {
    final dia = dt.day.toString().padLeft(2, '0');
    final mes = dt.month.toString().padLeft(2, '0');
    final anio = dt.year;
    final hora = dt.hour.toString().padLeft(2, '0');
    final minuto = dt.minute.toString().padLeft(2, '0');
    return '$dia/$mes/$anio $hora:$minuto';
  }

  @override
  Widget build(BuildContext context) {
    if (!ticket.noRequiereCompras) {
      return const SizedBox.shrink();
    }

    final String? fechaFormateada = ticket.fechaNoRequiereCompras != null 
        ? _formatearFecha(ticket.fechaNoRequiereCompras!) 
        : null;

    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0), // Naranja suave premium
        border: Border.all(color: Colors.orange.shade800, width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.orange.shade800, width: 1.5),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange.shade900,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ESTE TICKET NO NECESITA COMPRAS',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (onEditar != null)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        color: Colors.orange.shade900,
                        tooltip: 'Editar excepción de compras',
                        onPressed: onEditar,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Declarado por el Supervisor de Equipos${ticket.supervisorNoRequiereCompras != null && ticket.supervisorNoRequiereCompras!.isNotEmpty ? ': ${ticket.supervisorNoRequiereCompras}' : ''}'
                  '${fechaFormateada != null ? ' ($fechaFormateada)' : ''}',
                  style: TextStyle(
                    color: Colors.orange.shade900.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (ticket.motivoNoRequiereCompras != null && ticket.motivoNoRequiereCompras!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Text(
                      'Motivo: ${ticket.motivoNoRequiereCompras!.trim()}',
                      style: TextStyle(
                        color: Colors.grey.shade900,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
