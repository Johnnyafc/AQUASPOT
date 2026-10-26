// lib/features/tickets/presentation/pages/bandeja_fallas_pendientes_page.dart
//
// 🆕 Tarjeta de supervisión: lista los tickets que aún NO tienen su
// diagnóstico de fallas completo -- ya sea porque no tienen ninguna
// categoría/falla registrada (ticket.diagnosticoFallas vacío), o porque
// tienen fallas diagnosticadas a las que todavía les falta registrar al
// menos una razón del problema -- para que el supervisor lo complete
// retroactivamente. Filtrado por el mismo segmento operativo del supervisor
// logueado (caracol/cosechadora/contador), igual que el resto de bandejas
// de supervisión (ver bandeja_revisiones_garantias_page.dart).

import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/core/utils/constants.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../../../core/theme/ticket_visual_theme.dart';
import '../../domain/entities/ticket_entity.dart';
import 'agregar_diagnostico_falla_page.dart';

class BandejaFallasPendientesPage extends StatefulWidget {
  const BandejaFallasPendientesPage({super.key});

  @override
  State<BandejaFallasPendientesPage> createState() => _BandejaFallasPendientesPageState();
}

class _BandejaFallasPendientesPageState extends State<BandejaFallasPendientesPage> {
  @override
  void initState() {
    super.initState();

    // 1. EXTRAEMOS EL SEGMENTO DEL SUPERVISOR LOGUEADO
    final authState = context.read<AuthBloc>().state;
    SegmentoOperativo segmentoActivo = SegmentoOperativo.ninguno;

    if (authState is Authenticated) {
      segmentoActivo = authState.usuario.segmento;
    } else {
      debugPrint("⚠️ ALERTA: Intento de acceso sin autenticación en panel de fallas pendientes.");
    }

    // 2. DISPARAMOS EL EVENTO CON EL SEGMENTO ASIGNADO (misma partición que el resto de bandejas de supervisión)
    context.read<TicketBloc>().add(ObtenerHistorialTicketsEvent(segmento: segmentoActivo));
  }

  // Motivo por el que el ticket sigue en la bandeja, o null si ya está completo.
  String? _motivoPendiente(TicketEntity t) {
    if (t.diagnosticoFallas.isEmpty) return 'Sin fallas registradas';
    if (t.diagnosticoFallas.any((d) => d.razonesProblema.isEmpty)) return 'Faltan razones del problema';
    if (t.rondaDiagnosticoFallas < rondaRevisionDiagnosticoFallas) return 'Revisar diagnóstico';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fallas Pendientes por Diagnosticar"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: BlocBuilder<TicketBloc, TicketState>(
        builder: (context, state) {
          if (state.status == TicketStatus.loading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(state.message.isNotEmpty ? state.message : 'Consultando tickets pendientes...', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          if (state.status == TicketStatus.error) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text("Falla de sistema:\n${state.message}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              ),
            );
          }

          if (state.status == TicketStatus.loaded || state.status == TicketStatus.operationSuccess) {
            // ✅ FILTRO: tickets sin ninguna falla diagnosticada todavía, con
            // fallas a las que les falta al menos una razón, o cuyo diagnóstico
            // no se ha guardado en la ronda de revisión vigente
            // (rondaRevisionDiagnosticoFallas). Solo sale de esta bandeja cuando
            // se guarda en la ronda vigente con todas sus fallas con razón.
            // Ventas de repuesto y anulados no llevan diagnóstico de fallas.
            final pendientes = state.historial.where((t) {
              if (t.tipoRequerimiento == TipoRequerimiento.ventaRepuesto) return false;
              if (t.esMantenimientoInterno) return false; // aún sin flujo de diagnóstico
              if (t.estadoActual == EstadoTicket.anulado) return false;
              return _motivoPendiente(t) != null;
            }).toList();

            if (pendientes.isEmpty) {
              return const Center(child: Text("No hay tickets pendientes de diagnóstico de fallas.", style: TextStyle(color: Colors.grey)));
            }

            return Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: const Color(0xFFF1F5F9),
                  child: Text(
                    'Quedan ${pendientes.length} por revisar',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF003057)),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: pendientes.length,
                    itemBuilder: (context, index) {
                      final ticket = pendientes[index];
                      return Card(
                        key: ValueKey(ticket.id),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300, width: 1),
                        ),
                        child: ListTile(
                          leading: const AvatarSuave(color: kTicketAlerta, icono: Icons.troubleshoot),
                          title: Text(ticket.id, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'Equipo: ${ticket.equipo.name.toUpperCase()} • Marca: ${ticket.marca.toUpperCase()}'
                            '${ticket.clienteId.trim().isNotEmpty ? '\nCliente: ${ticket.clienteId}' : ''}'
                            '\nContacto: ${ticket.nombreContacto}'
                            '\nEstado: ${ticket.estadoActual.nombreLegible}'
                            '\nPendiente: ${_motivoPendiente(ticket)}',
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => AgregarDiagnosticoFallaPage(ticket: ticket)));
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
