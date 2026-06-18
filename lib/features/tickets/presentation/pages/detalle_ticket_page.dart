// lib/features/tickets/presentation/pages/detalle_ticket_page.dart

import 'package:flutter/material.dart';
import '../../domain/entities/ticket_entity.dart';

class DetalleTicketPage extends StatelessWidget {
  final TicketEntity ticket;

  const DetalleTicketPage({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: Text(ticket.id, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Datos del Requerimiento", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF003366))),
            const SizedBox(height: 12),
            _buildDataCard(),
            const SizedBox(height: 24),
            const Text("Trazabilidad y Auditoría", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF003366))),
            const SizedBox(height: 12),
            _buildTimelineCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDatoRow('Estado Actual:', ticket.estadoActual.name.toUpperCase()),
            const Divider(),
            _buildDatoRow('Equipo:', ticket.equipo.name.toUpperCase()),
            _buildDatoRow('Sede Operativa:', ticket.sede.name.toUpperCase()),
            const Divider(),
            _buildDatoRow('Cliente:', ticket.clienteId),
            _buildDatoRow('Campamento:', ticket.campamento),
            _buildDatoRow('Contacto:', '${ticket.nombreContacto} (${ticket.telefonoContacto})'),
            const Divider(),
            const Text('Falla Reportada:', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text(ticket.fallaReportada, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: ticket.historialEventos.map((evento) {
            // Formateo rápido de fecha tipo SCADA (YYYY-MM-DD HH:MM)
            final fechaStr = evento.timestamp.toString().substring(0, 16);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.adjust, color: Color(0xFF005A9C), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(evento.accion, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Operador: ${evento.usuarioNombre} [${evento.usuarioRol}]', style: const TextStyle(fontSize: 13)),
                        Text('Marca de tiempo: $fechaStr', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDatoRow(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(etiqueta, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(flex: 3, child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }
}