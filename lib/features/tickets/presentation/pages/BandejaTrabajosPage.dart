import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/subir_evidencia_trabajo_page.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/materiales_despachados_taller_page.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/ticket_entity.dart';
import '../widgets/copy_icon_button_widget.dart';
import '../widgets/tiempo_en_curso_widget.dart';
import '../../../../core/theme/ticket_visual_theme.dart';

class BandejaTrabajosPage extends StatefulWidget {
  const BandejaTrabajosPage({super.key});

  @override
  State<BandejaTrabajosPage> createState() => _BandejaTrabajosPageState();
}

class _BandejaTrabajosPageState extends State<BandejaTrabajosPage> {
  @override
  void initState() {
    super.initState();
    context.read<TicketBloc>().add(
      const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.ninguno),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Línea de Trabajo - Operaciones', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: BlocConsumer<TicketBloc, TicketState>(
          listener: (context, state) {
            if (state.status == TicketStatus.operationSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green,
                ),
              );
            } else if (state.status == TicketStatus.error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: ${state.message}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state.status == TicketStatus.loading && state.tickets.isEmpty && state.historial.isEmpty) {
              return Center(child: CircularProgressIndicator(color: Colors.blueGrey.shade800));
            } else if (state.status == TicketStatus.error && state.tickets.isEmpty && state.historial.isEmpty) {
              return Center(
                child: Text(
                  'Falla de telemetría: ${state.message}',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final listaAProcesar = state.tickets.isNotEmpty ? state.tickets : state.historial;

            final ticketsTrabajo = listaAProcesar.where((t) {
              final enEstadoTrabajo = t.estadoActual == EstadoTicket.procesoTrabajo;
              final tieneDespachoTemprano = t.tieneAlMenosUnDespachoBodega;
              return enEstadoTrabajo || tieneDespachoTemprano;
            }).toList();

            if (ticketsTrabajo.isEmpty) {
              return _buildEmptyState();
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        color: Colors.blueGrey,
                        onRefresh: () async {
                          context.read<TicketBloc>().add(
                            const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.ninguno),
                          );
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: ticketsTrabajo.length,
                          itemBuilder: (context, index) {
                            final ticket = ticketsTrabajo[index];
                            return _buildTicketCard(context, ticket);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTicketCard(BuildContext context, TicketEntity ticket) {
    final bool estaEnProceso = ticket.trabajoIniciado;
    final colorEstadoTrabajo = estaEnProceso ? kTicketAcento : Colors.grey.shade400;

    return Card(
      key: ValueKey(ticket.id),
      elevation: estaEnProceso ? 3 : 2,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- ENCABEZADO: ICONO, ID Y TESTIGO ---
            Row(
              children: [
                AvatarSuave(color: colorEstadoTrabajo, icono: Icons.build_circle, radio: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ticket: ${ticket.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF003057)),
                  ),
                ),
                CopyIconButtonWidget(etiqueta: 'Ticket', valor: ticket.id),
                if (estaEnProceso)
                  const InsigniaSuave(color: kTicketAcento, icono: Icons.settings, texto: 'EN PROCESO'),
                if (ticket.noRequiereCompras) ...[
                  const SizedBox(width: 6),
                  const InsigniaSuave(color: Colors.deepOrange, texto: 'SIN COMPRAS'),
                ],
                if (ticket.tieneAlMenosUnDespachoBodega && ticket.estadoActual != EstadoTicket.procesoTrabajo) ...[
                  const SizedBox(width: 6),
                  const InsigniaSuave(color: Colors.amber, icono: Icons.local_shipping, texto: 'DESPACHO PARCIAL'),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // --- CUERPO: DATOS TÉCNICOS ---
            Row(
              children: [
                Expanded(
                  child: Text('Proyecto: ${ticket.codigoProyecto ?? "Sin Asignar"}', style: TextStyle(color: Colors.grey.shade800)),
                ),
                CopyIconButtonWidget(etiqueta: 'Proyecto', valor: ticket.codigoProyecto ?? 'Sin Asignar'),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text('Equipo: ${ticket.equipo.name.toUpperCase()} • Marca: ${ticket.marca.toUpperCase()}', style: TextStyle(color: Colors.grey.shade800)),
                ),
                CopyIconButtonWidget(etiqueta: 'Equipo', valor: '${ticket.equipo.name.toUpperCase()} - ${ticket.marca.toUpperCase()}'),
              ],
            ),
            if (ticket.clienteId.trim().isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: Text('Cliente: ${ticket.clienteId}', style: TextStyle(color: Colors.grey.shade800)),
                  ),
                  CopyIconButtonWidget(etiqueta: 'Cliente', valor: ticket.clienteId),
                ],
              ),
            Row(
              children: [
                Expanded(
                  child: Text('Contacto: ${ticket.nombreContacto}', style: TextStyle(color: Colors.grey.shade800)),
                ),
                CopyIconButtonWidget(etiqueta: 'Contacto', valor: ticket.nombreContacto),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: kTicketAlerta),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Falla: ${ticket.fallaReportada}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
                CopyIconButtonWidget(etiqueta: 'Falla', valor: ticket.fallaReportada),
              ],
            ),

            // Tiempo en curso
            const SizedBox(height: 6),
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

            // 👥 TÉCNICOS ASIGNADOS VISUALES
            if (ticket.tecnicosAsignados.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.engineering_outlined, size: 16, color: Color(0xFF005A9C)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: ticket.tecnicosAsignados.map((tec) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF005A9C).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF005A9C).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            tec,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF005A9C)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],

            // 🔍 DIAGNÓSTICO DE FALLAS VISUAL
            if (ticket.diagnosticoFallas.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.troubleshoot, size: 16, color: Colors.deepOrange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: ticket.diagnosticoFallas.map((falla) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            falla.subcategoria.isNotEmpty
                                ? '${falla.categoria} > ${falla.subcategoria}: ${falla.falla}'
                                : '${falla.categoria}: ${falla.falla}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.deepOrange),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],

            // 📄 INFORME TÉCNICO ENLACE VISUAL
            if (ticket.urlInformeTecnico != null && ticket.urlInformeTecnico!.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final uri = Uri.parse(ticket.urlInformeTecnico!);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade600),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.picture_as_pdf, size: 16, color: Colors.green),
                      SizedBox(width: 6),
                      Text(
                        'Ver Informe Técnico',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.open_in_new, size: 14, color: Colors.green),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // --- PIE DE PÁGINA: BANCO DE ACCIONAMIENTO ---
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // 1. ACTUADOR DE INICIO (Se oculta o cambia si ya está activo)
                if (!estaEnProceso)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Iniciar Trabajo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey.shade700,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      final authState = context.read<AuthBloc>().state;
                      String operador = 'DESCONOCIDO';
                      String rol = 'SIN_ROL';

                      if (authState is Authenticated) {
                        operador = authState.usuario.nombre;
                        rol = authState.usuario.rol.name.toUpperCase();
                      }

                      context.read<TicketBloc>().add(
                        IniciarTrabajoFisicoEvent(
                          ticket: ticket,
                          nombreUsuario: operador,
                          rolUsuario: rol,
                        ),
                      );
                    },
                  ),

                // 5. MATERIALES DESPACHADOS DE BODEGA
                ElevatedButton.icon(
                  icon: const Icon(Icons.warehouse_outlined, size: 18),
                  label: const Text('Materiales Bodega'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF005A9C),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MaterialesDespachadosTallerPage(ticket: ticket),
                      ),
                    );
                  },
                ),

                // 6. SUBIR EVIDENCIA
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Subir evidencia'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey.shade700,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubirEvidenciaTrabajoPage(ticket: ticket),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.precision_manufacturing_outlined, size: 80, color: Colors.blueGrey.shade300),
          const SizedBox(height: 16),
          Text(
            'Línea Despejada',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            'No hay equipos en proceso de trabajo en este momento.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.blueGrey.shade500),
          ),
        ],
      ),
    );
  }
}
