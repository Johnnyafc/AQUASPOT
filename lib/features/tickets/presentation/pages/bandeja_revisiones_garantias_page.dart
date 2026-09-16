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
import '../../domain/entities/ticket_entity.dart'; // ⚙️ Necesario para el extension getter fechaInicioEstadoActual
import '../widgets/tiempo_en_curso_widget.dart';
import 'detalle_ticket_page.dart'; // O la página de dictamen de garantía correspondiente
import '../../../../core/theme/ticket_visual_theme.dart';

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
                // 🎨 Antes: borde Y avatar en naranja sólido (la misma señal
                // repetida dos veces). Ahora una sola insignia suave.
                return Card(
                  key: ValueKey(ticket.id),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                  child: ListTile(
                    leading: const AvatarSuave(color: kTicketAlerta, icono: Icons.gavel),
                    title: Text(ticket.id, style: const TextStyle(fontWeight: FontWeight.bold)),
                    // 🆕 Tiempo en vivo en el estado actual (sin backend: se
                    // recalcula contra la hora real del dispositivo).
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 🆕 Cliente (empresa/camaronera) y Contacto (persona) son
                        // datos distintos — se muestran ambos.
                        Text(
                          'Equipo: ${ticket.equipo.name.toUpperCase()} • Marca: ${ticket.marca.toUpperCase()}'
                          '${ticket.clienteId.trim().isNotEmpty ? '\nCliente: ${ticket.clienteId}' : ''}'
                          '\nContacto: ${ticket.nombreContacto}'
                          '\nResponsable Fact.: ${ticket.responsableFacturacionLegible}',
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