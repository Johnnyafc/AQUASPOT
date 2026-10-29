// lib/features/tickets/presentation/pages/bandeja_evaluaciones_page.dart

import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import '../widgets/resumen_mantenimiento_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart'; // ⚙️ Tu nuevo estado unificado
import '../../../../core/enum/ticket_enums.dart';
import '../../domain/entities/ticket_entity.dart'; // ⚙️ Necesario para el extension getter fechaInicioEstadoActual
import '../../domain/services/grupo_requerimiento_service.dart';
import '../widgets/tiempo_en_curso_widget.dart';
import 'detalle_ticket_page.dart';
import 'evaluacion_mantenimiento_page.dart';
import 'evaluacion_tecnica_page.dart';
import 'evaluacion_venta_repuesto_page.dart';
import '../../../../core/theme/ticket_visual_theme.dart';

/// Evaluaciones técnicas pendientes de un grupo: requerimientos u OT
/// (GrupoRequerimientoService), cada uno en su tarjeta del menú.
class BandejaEvaluacionesPage extends StatefulWidget {
  final GrupoRequerimiento grupo;

  const BandejaEvaluacionesPage({super.key, required this.grupo});

  @override
  State<BandejaEvaluacionesPage> createState() => _BandejaEvaluacionesPageState();
}

class _BandejaEvaluacionesPageState extends State<BandejaEvaluacionesPage> {
  @override
  void initState() {
    super.initState(); // ⚙️ Corregido: Un solo ciclo de inicialización.
    _recargar();
  }

  /// Carga (o recarga) los tickets del segmento del usuario. Se llama al
  /// abrir y al volver de una evaluación: la de mantenimiento interno guarda
  /// por su propio camino y sin recargar el ticket seguiría en la lista.
  void _recargar() {
    // 1. EXTRAEMOS LA CONFIGURACIÓN DEL USUARIO (Auth Context)
    final authState = context.read<AuthBloc>().state;
    SegmentoOperativo segmentoActivo = SegmentoOperativo.ninguno;

    if (authState is Authenticated) {
      segmentoActivo = authState.usuario.segmento;
    } else {
      debugPrint("⚠️ ALERTA: Intento de acceso sin autenticación en panel operativo.");
    }

    // 2. DISPARAMOS EL EVENTO CON EL SEGMENTO ASIGNADO
    context.read<TicketBloc>().add(ObtenerHistorialTicketsEvent(segmento: segmentoActivo));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.grupo == GrupoRequerimiento.ordenesTrabajo ? 'Evaluaciones de OT' : 'Evaluaciones técnicas'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: BlocBuilder<TicketBloc, TicketState>(
        builder: (context, state) {
          
          // ⚙️ ESTÁNDAR INDUSTRIAL: Evaluamos el status de la máquina, no el tipo de clase.
          if (state.status == TicketStatus.loading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(state.message.isNotEmpty ? state.message : 'Sincronizando telemetría...', style: const TextStyle(color: Colors.grey)),
                ],
              )
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

          // Si el estado es loaded o viene de un operationSuccess, mostramos la bandeja
          if (state.status == TicketStatus.loaded || state.status == TicketStatus.operationSuccess) {
            
            // ✅ FILTRO DE HARDWARE: Leemos de state.historial (la matriz que configuramos en el BLoC)
            final pendientes = state.historial.where((t) => 
              t.estadoActual == EstadoTicket.recepcionFisica && 
              t.esRegistroCompleto == true &&
              GrupoRequerimientoService.pertenece(widget.grupo, t)
            ).toList();

            if (pendientes.isEmpty) {
              return const Center(child: Text("Bandeja vacía. Todo al día.", style: TextStyle(color: Colors.grey)));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: pendientes.length,
              itemBuilder: (context, index) {
                final ticket = pendientes[index];
                return Card(
                  key: ValueKey(ticket.id),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                  child: ListTile(
                    leading: const AvatarSuave(color: kTicketAlerta, icono: Icons.pending_actions),
                    title: Text(ticket.id, style: const TextStyle(fontWeight: FontWeight.bold)),
                    // 🆕 Tiempo en vivo en el estado actual (sin backend: se
                    // recalcula contra la hora real del dispositivo).
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 🆕 Cliente (empresa/camaronera) y Contacto (persona) son
                        // datos distintos — se muestran ambos.
                        // 🛠️ Mantenimiento interno: todos los datos de la creación (sin fotos).
                        if (ticket.esMantenimientoInterno)
                          DatosMantenimientoTarjetaWidget(ticket: ticket)
                        else
                          Text(
                            'Equipo: ${ticket.equipo.name.toUpperCase()} • Marca: ${ticket.marca.toUpperCase()}'
                            '${ticket.clienteId.trim().isNotEmpty ? '\nCliente: ${ticket.clienteId}' : ''}'
                            '\nContacto: ${ticket.nombreContacto}',
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
                    onTap: () async {
                      // 🔧 Venta de Repuesto con líneas → evaluación de venta (supervisor).
                      // Ventas antiguas sin líneas siguen con la evaluación anterior.
                      // 🛠️ Mantenimiento interno → su propia evaluación técnica.
                      final esVentaConLineas = ticket.tipoRequerimiento == TipoRequerimiento.ventaRepuesto &&
                          ticket.lineasRepuestoVenta.isNotEmpty;
                      final guardada = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ticket.esMantenimientoInterno
                              ? EvaluacionMantenimientoPage(ticket: ticket)
                              : esVentaConLineas
                                  ? EvaluacionVentaRepuestoPage(ticket: ticket)
                                  : EvaluacionTecnicaPage(ticket: ticket),
                        ),
                      );
                      if (guardada == true && context.mounted) _recargar();
                    },
                  ),
                );
              },
            );
          }
          
          // Estado inicial (Máquina energizada pero sin orden de marcha)
          return const SizedBox.shrink();
        },
      ),
    );
  }
}