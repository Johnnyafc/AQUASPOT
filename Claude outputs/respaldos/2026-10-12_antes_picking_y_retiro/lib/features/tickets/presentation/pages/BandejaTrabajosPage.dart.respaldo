import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/subir_evidencia_trabajo_page.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/materiales_despachados_taller_page.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/materiales_recibidos_taller_page.dart';
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
  // NUEVO: segmento real del supervisor logueado. Cada supervisor solo
  // debe ver los requerimientos de su propio equipo (contador, cosechadora
  // o caracol) -- antes esta pantalla mandaba SegmentoOperativo.ninguno
  // fijo, que el datasource trata como "sin filtro" (ve todo).
  SegmentoOperativo _segmentoUsuario = SegmentoOperativo.ninguno;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      _segmentoUsuario = authState.usuario.segmento;
    }
    context.read<TicketBloc>().add(
      ObtenerHistorialTicketsEvent(segmento: _segmentoUsuario),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar tickets',
            onPressed: () {
              context.read<TicketBloc>().add(
                    ObtenerHistorialTicketsEvent(segmento: _segmentoUsuario),
                  );
            },
          ),
        ],
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

            final listaAProcesar = state.historial.isNotEmpty ? state.historial : state.tickets;

            final ticketsTrabajo = listaAProcesar.where((t) {
              if (t.estadoActual == EstadoTicket.validacionFacturacion ||
                  t.estadoActual == EstadoTicket.entrega ||
                  t.estadoActual == EstadoTicket.finalizado ||
                  t.estadoActual == EstadoTicket.anulado) {
                return false;
              }

              final tieneProyecto = t.codigoProyecto != null && t.codigoProyecto!.trim().isNotEmpty;
              final enEstadoTrabajo = t.estadoActual == EstadoTicket.procesoTrabajo;
              final tieneDespachoTemprano = t.tieneAlMenosUnDespachoBodega;
              return enEstadoTrabajo || tieneDespachoTemprano || tieneProyecto;
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
                            ObtenerHistorialTicketsEvent(segmento: _segmentoUsuario),
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

  void _mostrarModalDisponibilidadRepuestos(BuildContext context, TicketEntity ticket) {
    final items = ticket.itemsDespachoBodega;
    final enStockList = items.where((i) => i.stockDisponibleAlEvaluar > 0 || i.validadoPorCompras).toList();
    final sinStockList = items.where((i) => i.stockDisponibleAlEvaluar <= 0 && !i.validadoPorCompras).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF4F6F9),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.analytics_outlined, color: Color(0xFF003057), size: 26),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Disponibilidad de Repuestos - ${ticket.id}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF003057)),
                              ),
                              Text(
                                'Proyecto: ${ticket.codigoProyecto ?? "S/N"} • ${ticket.equipo.name.toUpperCase()}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle, size: 16, color: Color(0xFF2E7D32)),
                                const SizedBox(width: 6),
                                Text(
                                  '${enStockList.length} en Stock / Listos',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2E7D32)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shopping_cart_outlined, size: 16, color: Colors.orange.shade900),
                                const SizedBox(width: 6),
                                Text(
                                  '${sinStockList.length} en Compras',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange.shade900),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      children: [
                        if (enStockList.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF2E7D32)),
                              const SizedBox(width: 6),
                              Text(
                                'REPUESTOS EN STOCK (Bodega puede despachar)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green.shade900),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...enStockList.map((item) {
                            final enTaller = ticket.cantidadTotalRecibidaEnTaller(item.codigo);
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Colors.green.shade300),
                              ),
                              child: ListTile(
                                dense: true,
                                title: Text('${item.codigo} - ${item.descripcion}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text(
                                  'Requerido: ${item.cantidadSolicitada} ${item.unidad} | Despachado Bodega: ${item.cantidadDespachada} | En Taller: $enTaller ${item.unidad}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.validadoPorCompras
                                        ? 'COMPRAS VALIDÓ'
                                        : 'STOCK: ${item.stockDisponibleAlEvaluar.toString().replaceAll(RegExp(r'\.0$'), '')}',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                        ],
                        if (sinStockList.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(Icons.pending_actions_outlined, size: 18, color: Colors.orange.shade900),
                              const SizedBox(width: 6),
                              Text(
                                'REPUESTOS A LA ESPERA DE COMPRAS (Sin Stock)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange.shade900),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...sinStockList.map((item) {
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Colors.orange.shade300),
                              ),
                              child: ListTile(
                                dense: true,
                                title: Text('${item.codigo} - ${item.descripcion}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text(
                                  'Requerido: ${item.cantidadSolicitada} ${item.unidad} | Stock en bodega: 0',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'EN GESTIÓN COMPRAS',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
                if (ticket.comprasYBodegaTotalmenteCompletados) ...[
                  const SizedBox(width: 6),
                  const InsigniaSuave(
                    color: Colors.green,
                    icono: Icons.verified_user,
                    texto: 'BODEGA Y COMPRAS 100%',
                  ),
                ] else if (ticket.hayMaterialesDespachadosPorAsignar) ...[
                  const SizedBox(width: 6),
                  const InsigniaSuave(
                    color: Colors.teal,
                    icono: Icons.local_shipping,
                    texto: 'REPUESTOS EN BODEGA',
                  ),
                ] else if (ticket.tieneAlMenosUnDespachoBodega) ...[
                  const SizedBox(width: 6),
                  if (ticket.materialesValidadosEnTaller)
                    const InsigniaSuave(color: Colors.teal, icono: Icons.verified, texto: 'MATERIALES EN TALLER')
                  else if (ticket.bodegaDespachoCompleto)
                    const InsigniaSuave(color: Colors.green, icono: Icons.check_circle, texto: 'MATERIALES COMPLETOS')
                  else
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

                // DISPONIBILIDAD DE REPUESTOS (STOCK vs COMPRAS)
                if (ticket.itemsDespachoBodega.isNotEmpty)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.analytics_outlined, size: 18),
                    label: const Text('Disponibilidad de repuestos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.shade700,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _mostrarModalDisponibilidadRepuestos(context, ticket),
                  ),

                // 5. MATERIALES EN BODEGA
                ElevatedButton.icon(
                  icon: const Icon(Icons.warehouse_outlined, size: 18),
                  label: const Text('Materiales en bodega'),
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
                    ).then((_) {
                      if (context.mounted) {
                        context.read<TicketBloc>().add(
                              ObtenerHistorialTicketsEvent(segmento: _segmentoUsuario),
                            );
                      }
                    });
                  },
                ),

                // 6. MATERIALES RECIBIDOS EN TALLER
                ElevatedButton.icon(
                  icon: const Icon(Icons.inventory_outlined, size: 18),
                  label: const Text('Materiales recibidos'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ticket.materialesValidadosEnTaller
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFF00796B),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MaterialesRecibidosTallerPage(ticket: ticket),
                      ),
                    ).then((_) {
                      if (context.mounted) {
                        context.read<TicketBloc>().add(
                              ObtenerHistorialTicketsEvent(segmento: _segmentoUsuario),
                            );
                      }
                    });
                  },
                ),

                // 7. SUBIR EVIDENCIA (ENCLAVADO CON INICIAR TRABAJO)
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
                    if (!ticket.trabajoIniciado) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                              SizedBox(width: 8),
                              Text('Trabajo no iniciado'),
                            ],
                          ),
                          content: const Text(
                            'El sistema exige iniciar formalmente el trabajo físico en taller antes de ingresar a registrar evidencias.',
                            style: TextStyle(fontSize: 14, height: 1.4),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Iniciar Trabajo Ahora'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF005A9C),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
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
                          ],
                        ),
                      );
                      return;
                    }

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
