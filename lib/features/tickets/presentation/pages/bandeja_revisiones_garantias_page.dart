// lib/features/tickets/presentation/pages/bandeja_revisiones_garantias_page.dart

import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/RevisionGarantiaPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../../../core/enum/ticket_enums.dart';
import 'detalle_ticket_page.dart'; // O la página de dictamen de garantía correspondiente

class BandejaRevisionesGarantiasPage extends StatefulWidget {
  const BandejaRevisionesGarantiasPage({super.key});

  @override
  State<BandejaRevisionesGarantiasPage> createState() => _BandejaRevisionesGarantiasPageState();
}

class _BandejaRevisionesGarantiasPageState extends State<BandejaRevisionesGarantiasPage> {
  @override
  void initState() {
    super.initState();

    // 1. EXTRAEMOS LA CONFIGURACIÓN DEL USUARIO (Auth Context)
    final authState = context.read<AuthBloc>().state;
    SegmentoOperativo segmentoActivo = SegmentoOperativo.ninguno;

    if (authState is Authenticated) {
      segmentoActivo = authState.usuario.segmento;
    } else {
      debugPrint("⚠️ ALERTA: Intento de acceso sin autenticación en panel de garantías.");
    }

    // 2. DISPARAMOS EL EVENTO CON EL SEGMENTO ASIGNADO
    context.read<TicketBloc>().add(ObtenerHistorialTicketsEvent(segmento: segmentoActivo));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Revisión de Garantías"),
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
                  Text(state.message.isNotEmpty ? state.message : 'Sincronizando cola de garantías...', style: const TextStyle(color: Colors.grey)),
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
            
            // ✅ FILTRO DE HARDWARE ESPECÍFICO PARA GARANTÍAS
            final garantiasPendientes = state.historial.where((t) => 
              t.estadoActual == EstadoTicket.revisionGarantia
            ).toList();

            if (garantiasPendientes.isEmpty) {
              return const Center(child: Text("Bandeja de garantías limpia.", style: TextStyle(color: Colors.grey)));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: garantiasPendientes.length,
              itemBuilder: (context, index) {
                final ticket = garantiasPendientes[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.orange, width: 1), // Distintivo visual de garantía
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.gavel, color: Colors.white)),
                    title: Text(ticket.id, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Equipo: ${ticket.equipo.name}\nCliente: ${ticket.clienteId}\nResponsable Fact.: ${ticket.responsableFacturacion ?? "Sin definir"}'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // 🚀 Aquí se enruta a la pantalla donde se procesa el dictamen final (Aprobar/Rechazar garantía)
                       Navigator.push(context, MaterialPageRoute(builder: (_) => RevisionGarantiaPage(ticket: ticket)));
                    },
                  ),
                );
              },
            );
          }
          
          return const SizedBox.shrink();
        },
      ),
    );
  }
}