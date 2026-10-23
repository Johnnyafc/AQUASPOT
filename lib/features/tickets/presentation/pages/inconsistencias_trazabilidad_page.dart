// lib/features/tickets/presentation/pages/inconsistencias_trazabilidad_page.dart
//
// 🔎 "Inconsistencias de Trazabilidad" (solo cuenta administradora maestra,
// tarjeta del menú principal): tickets cuya auditoría tiene algo raro según
// las reglas de InconsistenciasTrazabilidadService. Se puede abrir el ticket
// para revisar su auditoría y marcar cada hallazgo como "Revisado".

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/enum/segmento_operativo.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/services/inconsistencias_trazabilidad_service.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import 'detalle_ticket_page.dart';

class InconsistenciasTrazabilidadPage extends StatefulWidget {
  const InconsistenciasTrazabilidadPage({super.key});

  @override
  State<InconsistenciasTrazabilidadPage> createState() => _InconsistenciasTrazabilidadPageState();
}

class _InconsistenciasTrazabilidadPageState extends State<InconsistenciasTrazabilidadPage> {
  // Marcadas como revisadas en esta sesión ("ticket|clave"), para ocultarlas
  // al instante mientras se guarda en Firestore.
  final Set<String> _revisadasLocal = {};

  // Cálculo en memoria: solo se rehace cuando cambia la lista de tickets.
  List<TicketEntity>? _ticketsCalculados;
  List<InconsistenciaTicket> _hallazgos = const [];

  @override
  void initState() {
    super.initState();
    if (context.read<TicketBloc>().state.historial.isEmpty) {
      context.read<TicketBloc>().add(const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.ninguno));
    }
  }

  List<InconsistenciaTicket> _calcular(List<TicketEntity> tickets) {
    if (!identical(tickets, _ticketsCalculados)) {
      _ticketsCalculados = tickets;
      _hallazgos = InconsistenciasTrazabilidadService.detectarEnTickets(tickets);
    }
    return _hallazgos;
  }

  void _marcarRevisada(InconsistenciaTicket i) {
    setState(() => _revisadasLocal.add('${i.ticketId}|${i.clave}'));
    context.read<TicketBloc>().add(MarcarInconsistenciaRevisadaEvent(ticketId: i.ticketId, clave: i.clave));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Inconsistencias de Trazabilidad'),
        backgroundColor: Colors.amber.shade800,
        foregroundColor: Colors.white,
      ),
      body: BlocBuilder<TicketBloc, TicketState>(
        builder: (context, state) {
          final porId = {for (final t in state.historial) t.id: t};
          final todas = _calcular(state.historial);
          final visibles = todas.where((i) {
            final t = porId[i.ticketId];
            if (t == null || t.inconsistenciasRevisadas.contains(i.clave)) return false;
            return !_revisadasLocal.contains('${i.ticketId}|${i.clave}');
          }).toList()
            ..sort((a, b) => a.regla != b.regla ? a.regla.compareTo(b.regla) : a.ticketId.compareTo(b.ticketId));
          final revisadas = todas.length - visibles.length;
          final porRegla = <String, int>{};
          for (final i in visibles) {
            porRegla[i.regla] = (porRegla[i.regla] ?? 0) + 1;
          }
          final ticketsDistintos = visibles.map((i) => i.ticketId).toSet().length;

          if (state.historial.isEmpty && state.status == TicketStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${visibles.length} hallazgo(s) en $ticketsDistintos ticket(s)'
                '${revisadas > 0 ? ' · $revisadas revisado(s) oculto(s)' : ''}. '
                'Toque el número de ticket para ver su auditoría; marque "Revisado" si es correcto.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 10),
              if (visibles.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Sin inconsistencias pendientes.', style: TextStyle(color: Colors.grey.shade600))),
                )
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final e in porRegla.entries)
                      Chip(visualDensity: VisualDensity.compact, label: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 11))),
                  ],
                ),
                const SizedBox(height: 10),
                for (final i in visibles) _fila(i, porId[i.ticketId]!),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _fila(InconsistenciaTicket i, TicketEntity t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF1D9A0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD9A441)),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetalleTicketPage(ticket: t))),
            child: Text(t.id,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF2B5B86), decoration: TextDecoration.underline)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.regla, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text(i.detalle, style: const TextStyle(fontSize: 11.5, color: Colors.black87)),
                Text('Estado: ${t.estadoActual.nombreLegible} · ${t.equipo.name}',
                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _marcarRevisada(i),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Revisado'),
          ),
        ],
      ),
    );
  }
}
