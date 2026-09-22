import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/acceso_temporal_bodega_service.dart';
import '../../data/models/ticket_model.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/entities/item_despacho_bodega_entity.dart';
import '../../domain/entities/orden_recepcion_repuestos_entity.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../tecnicos/data/datasources/tecnico_remote_datasource.dart';
import '../../../tecnicos/domain/entities/tecnico_entity.dart';
import '../../../../core/enum/segmento_operativo.dart';

typedef MaterialesEnBodegaPage = MaterialesDespachadosTallerPage;

class MaterialesDespachadosTallerPage extends StatefulWidget {
  final TicketEntity ticket;

  const MaterialesDespachadosTallerPage({super.key, required this.ticket});

  @override
  State<MaterialesDespachadosTallerPage> createState() =>
      _MaterialesDespachadosTallerPageState();
}

class _MaterialesDespachadosTallerPageState
    extends State<MaterialesDespachadosTallerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TecnicoRemoteDataSource _tecnicoDataSource = TecnicoRemoteDataSource();
  final AccesoTemporalBodegaService _accesoService = AccesoTemporalBodegaService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _copiarTexto(BuildContext context, String texto, String mensaje) {
    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: const Color(0xFF005A9C),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) return '';
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  void _confirmarValidacionConsumoSupervisor(
    BuildContext context,
    TicketEntity ticket,
    OrdenRecepcionRepuestosEntity orden,
  ) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified, color: Color(0xFF2E7D32), size: 26),
            SizedBox(width: 8),
            Text('Certificar Consumo en Taller', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          '¿Certifica que los repuestos retirados en la orden ${orden.id} por el técnico ${orden.tecnicoNombre} fueron efectivamente consumidos e instalados en el equipo en Taller?\n\n'
          'Esta validación registra el consumo parcial y habilita al supervisor a continuar el avance o liberar el trabajo.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dlgCtx);
              final authState = context.read<AuthBloc>().state;
              String supNombre = 'SUPERVISOR';
              String supRol = 'SUPERVISOR';
              if (authState is Authenticated) {
                supNombre = authState.usuario.nombre;
                supRol = authState.usuario.rol.name.toUpperCase();
              }

              context.read<TicketBloc>().add(
                    ValidarConsumoOrdenTallerEvent(
                      ticket: ticket,
                      ordenId: orden.id,
                      nombreSupervisor: supNombre,
                      rolSupervisor: supRol,
                    ),
                  );
            },
            child: const Text('Certificar Consumo'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoCompartirEnlace({
    required BuildContext context,
    required String urlAcceso,
    required String tecnicoNombre,
    required String ordenId,
    required String ticketId,
  }) {
    showDialog(
      context: context,
      builder: (dlgContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.share_outlined, color: Colors.orange.shade800, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Acceso Técnico Externo',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ORDEN $ordenId',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Se generó el enlace de retiro temporal para el técnico externo $tecnicoNombre.',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'El técnico podrá acceder directamente desde su celular sin iniciar sesión, verificar los repuestos y confirmar el retiro. Al confirmar, el enlace se invalidará automáticamente.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 14),
                // Contenedor con la URL
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          urlAcceso,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Color(0xFF005A9C),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18, color: Color(0xFF005A9C)),
                        tooltip: 'Copiar enlace',
                        onPressed: () {
                          _copiarTexto(context, urlAcceso, 'Enlace de acceso copiado al portapapeles');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Botón WhatsApp
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chat, color: Colors.white, size: 18),
                    label: const Text(
                      'Enviar por WhatsApp',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      final mensaje =
                          'Hola $tecnicoNombre, se te ha asignado el retiro de repuestos para el Ticket $ticketId en Bodega Aquaspot.\n\nPuedes revisar los repuestos y confirmar la recepción ingresando aquí:\n$urlAcceso\n\n(Nota: Este enlace es de un solo uso).';
                      final waUrl = Uri.parse(
                          'https://api.whatsapp.com/send?text=${Uri.encodeComponent(mensaje)}');
                      if (await canLaunchUrl(waUrl)) {
                        await launchUrl(waUrl, mode: LaunchMode.externalApplication);
                      } else {
                        if (context.mounted) {
                          _copiarTexto(context, urlAcceso, 'No se pudo abrir WhatsApp. Enlace copiado.');
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // Botón Copiar Link
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copiar Enlace'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF005A9C),
                      side: const BorderSide(color: Color(0xFF005A9C)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      _copiarTexto(context, urlAcceso, 'Enlace de acceso copiado al portapapeles');
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgContext),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _compartirOReenviarLinkOrden(
    BuildContext context,
    TicketEntity ticket,
    OrdenRecepcionRepuestosEntity orden,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final tokenModel = await _accesoService.obtenerOGenerarTokenParaOrden(
        ticketId: ticket.id,
        ordenId: orden.id,
        tecnicoNombre: orden.tecnicoNombre,
        tecnicoId: orden.tecnicoId,
        creadoPor: orden.supervisorAsigna,
      );

      if (context.mounted) {
        Navigator.pop(context); // cerrar spinner
        final urlAcceso = AccesoTemporalBodegaService.construirUrlAcceso(tokenModel.token);
        _mostrarDialogoCompartirEnlace(
          context: context,
          urlAcceso: urlAcceso,
          tecnicoNombre: orden.tecnicoNombre,
          ordenId: orden.id,
          ticketId: ticket.id,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // cerrar spinner
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al obtener enlace temporal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarModalAsignarTecnico(BuildContext context, TicketEntity ticket) {
    final itemsPorRecoger = ticket.itemsPendientesDeRecogerEnBodega;
    if (itemsPorRecoger.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay materiales pendientes de recoger en bodega.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    TecnicoEntity? tecnicoSeleccionado;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_pin_outlined,
                            color: Color(0xFF005A9C), size: 26),
                        const SizedBox(width: 8),
                        const Text(
                          'Asignar Técnico de Retiro',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF003057),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(modalContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Seleccione al técnico responsable que se acercará a Bodega para verificar físicamente y retirar los repuestos.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 16),

                    // Resumen de ítems pendientes de retiro
                    const Text(
                      'Repuestos alistados en bodega por retirar:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF003057),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 140),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: itemsPorRecoger.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = itemsPorRecoger[index];
                          final cant = ticket.cantidadDisponibleParaAsignarRetiro(item.codigo);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Row(
                              children: [
                                Text(
                                  item.codigo,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Color(0xFF005A9C),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.descripcion,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$cant ${item.unidad}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dropdown de Técnicos
                    const Text(
                      'Técnico Responsable:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<TecnicoEntity>>(
                      stream: _tecnicoDataSource.escucharTecnicos(soloActivos: true),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: LinearProgressIndicator());
                        }
                        final tecnicos = snapshot.data ?? [];
                        if (tecnicos.isEmpty) {
                          return const Text(
                            'No hay técnicos activos registrados en el catálogo.',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          );
                        }

                        return DropdownButtonFormField<TecnicoEntity>(
                          isExpanded: true,
                          value: tecnicoSeleccionado,
                          decoration: InputDecoration(
                            hintText: 'Seleccionar técnico...',
                            prefixIcon: const Icon(Icons.engineering_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: tecnicos.map((t) {
                            return DropdownMenuItem<TecnicoEntity>(
                              value: t,
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Expanded(
                                    child: Text(
                                      t.nombre,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: t.esExterno
                                          ? const Color(0xFFFFF3E0)
                                          : const Color(0xFFE3F2FD),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: t.esExterno
                                            ? Colors.orange.shade300
                                            : Colors.blue.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      t.esExterno ? 'EXTERNO' : 'ENROLADO',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: t.esExterno
                                            ? Colors.orange.shade900
                                            : const Color(0xFF0D47A1),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setModalState(() {
                              tecnicoSeleccionado = val;
                            });
                          },
                        );
                      },
                    ),
                    if (tecnicoSeleccionado != null && tecnicoSeleccionado!.esExterno) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Este técnico es EXTERNO. Se creará un enlace de acceso temporal para enviarlo por WhatsApp o copiarlo.',
                                style: TextStyle(fontSize: 11, color: Colors.brown.shade800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Botón Confirmar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.send_rounded),
                        label: const Text(
                          'Generar Orden de Retiro',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF005A9C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: tecnicoSeleccionado == null
                            ? null
                            : () async {
                                final authState = context.read<AuthBloc>().state;
                                String supervisorNombre = 'SUPERVISOR';
                                if (authState is Authenticated) {
                                  supervisorNombre = authState.usuario.nombre;
                                }

                                final ordenId = 'REC-${DateTime.now().millisecondsSinceEpoch}';

                                String rolSupervisor = 'SUPERVISOR';
                                if (authState is Authenticated) {
                                  rolSupervisor = authState.usuario.rol.name.toUpperCase();
                                }
                                context.read<TicketBloc>().add(
                                      AsignarTecnicoRecepcionBodegaEvent(
                                        ticket: ticket,
                                        tecnicoId: tecnicoSeleccionado!.id,
                                        tecnicoNombre: tecnicoSeleccionado!.nombre,
                                        nombreSupervisor: supervisorNombre,
                                        rolSupervisor: rolSupervisor,
                                        ordenId: ordenId,
                                      ),
                                    );

                                final bool esExterno = tecnicoSeleccionado!.esExterno;
                                final tecNombre = tecnicoSeleccionado!.nombre;
                                final tecId = tecnicoSeleccionado!.id;

                                Navigator.pop(modalContext);

                                if (esExterno) {
                                  try {
                                    final tokenModel = await _accesoService.generarTokenParaOrden(
                                      ticketId: ticket.id,
                                      ordenId: ordenId,
                                      tecnicoNombre: tecNombre,
                                      tecnicoId: tecId,
                                      creadoPor: supervisorNombre,
                                    );
                                    if (context.mounted) {
                                      final urlAcceso = AccesoTemporalBodegaService.construirUrlAcceso(tokenModel.token);
                                      _mostrarDialogoCompartirEnlace(
                                        context: context,
                                        urlAcceso: urlAcceso,
                                        tecnicoNombre: tecNombre,
                                        ordenId: ordenId,
                                        ticketId: ticket.id,
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Orden creada, pero falló enlace temporal: $e'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Orden $ordenId asignada a $tecNombre para retiro en Bodega.',
                                      ),
                                      backgroundColor: const Color(0xFF2E7D32),
                                    ),
                                  );
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TicketBloc, TicketState>(
      listener: (context, state) {
        if (state.status == TicketStatus.operationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: const Color(0xFF2E7D32),
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
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('tickets')
              .doc(widget.ticket.id)
              .snapshots(),
          builder: (context, snapshot) {
            TicketEntity ticket;
            if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
              final data = Map<String, dynamic>.from(snapshot.data!.data()!);
              data['id'] = snapshot.data!.id;
              ticket = TicketModel.fromJson(data);
            } else {
              ticket = state.tickets.firstWhere(
                (t) => t.id == widget.ticket.id,
                orElse: () => widget.ticket,
              );
            }

            final enviados = ticket.itemsDespachados;
            final faltantes = ticket.itemsFaltantesDespacho;
            final ordenes = ticket.ordenesRecepcion;
            final bool hayPendientesRecoger = ticket.hayMaterialesDespachadosPorAsignar;

            return Scaffold(
              backgroundColor: const Color(0xFFF4F6F9),
              appBar: AppBar(
                title: Text(
                  'Materiales en bodega - ${ticket.id}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refrescar datos',
                    onPressed: () {
                      context.read<TicketBloc>().add(
                            const ObtenerHistorialTicketsEvent(
                              segmento: SegmentoOperativo.ninguno,
                            ),
                          );
                    },
                  ),
                ],
                backgroundColor: const Color(0xFF005A9C),
                foregroundColor: Colors.white,
                bottom: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.warehouse_outlined, size: 18),
                      text: 'En Bodega (${enviados.length})',
                    ),
                    Tab(
                      icon: const Icon(Icons.assignment_ind_outlined, size: 18),
                      text: 'Órdenes Retiro (${ordenes.length})',
                    ),
                    Tab(
                      icon: const Icon(Icons.pending_actions_outlined, size: 18),
                      text: 'Faltantes Bodega (${faltantes.length})',
                    ),
                  ],
                ),
              ),
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildTablaEnBodega(context, ticket, enviados),
                  _buildTablaOrdenesRetiro(context, ticket, ordenes),
                  _buildTablaFaltantes(context, faltantes),
                ],
              ),
              bottomNavigationBar: hayPendientesRecoger
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: SafeArea(
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text(
                              'Asignar Técnico para Recoger en Bodega',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF005A9C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => _mostrarModalAsignarTecnico(context, ticket),
                          ),
                        ),
                      ),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildTablaEnBodega(
      BuildContext context, TicketEntity ticket, List<ItemDespachoBodegaEntity> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Aún no se han despachado repuestos desde Bodega para este ticket.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFFE8F5E9),
          child: Row(
            children: [
              const Icon(Icons.local_shipping_outlined, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              Text(
                'Total repuestos alistados por Bodega: ${items.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copiar Enviados', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  final text = items
                      .map((i) => '${i.codigo} - ${i.descripcion}: ${i.cantidadDespachada} ${i.unidad}')
                      .join('\n');
                  _copiarTexto(context, text, 'Listado de repuestos de bodega copiado');
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              final pendienteRecoger = ticket.cantidadPendienteRecogerEnBodega(item.codigo);
              final recibidaEnTaller = ticket.cantidadTotalRecibidaEnTaller(item.codigo);

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: pendienteRecoger > 0
                        ? Colors.amber.shade300
                        : Colors.green.shade200,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: pendienteRecoger > 0
                        ? const Color(0xFFFFF3E0)
                        : const Color(0xFFE8F5E9),
                    child: Icon(
                      pendienteRecoger > 0 ? Icons.schedule : Icons.check,
                      color: pendienteRecoger > 0 ? Colors.orange.shade800 : const Color(0xFF2E7D32),
                    ),
                  ),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.codigo,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.descripcion,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alistado Bodega: ${item.cantidadDespachada} ${item.unidad} | Recibido Taller: $recibidaEnTaller ${item.unidad}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                        if (pendienteRecoger > 0)
                          Text(
                            'Pendiente por retirar: $pendienteRecoger ${item.unidad}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                      ],
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: pendienteRecoger == 0
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      pendienteRecoger == 0 ? 'EN TALLER' : 'POR RETIRAR',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: pendienteRecoger == 0
                            ? const Color(0xFF2E7D32)
                            : Colors.orange.shade900,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTablaOrdenesRetiro(
      BuildContext context,
      TicketEntity ticket,
      List<OrdenRecepcionRepuestosEntity> ordenes) {
    if (ordenes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_ind_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Aún no se han generado órdenes de recogida para los técnicos.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: ordenes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final orden = ordenes[index];
        final bool isPendiente = orden.estado == EstadoOrdenRecepcion.pendienteRecoger;
        final bool isTotal = orden.estado == EstadoOrdenRecepcion.recibidoTotal;

        Color badgeBg = const Color(0xFFFFF3E0);
        Color badgeFg = Colors.orange.shade900;
        String badgeText = 'PENDIENTE RETIRO';

        if (isTotal) {
          badgeBg = const Color(0xFFE8F5E9);
          badgeFg = const Color(0xFF2E7D32);
          badgeText = 'RECIBIDO 100%';
        } else if (!isPendiente) {
          badgeBg = const Color(0xFFE3F2FD);
          badgeFg = const Color(0xFF0D47A1);
          badgeText = 'RECIBIDO PARCIAL';
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: badgeBg,
              child: Icon(
                isTotal ? Icons.check_circle : Icons.directions_walk,
                color: badgeFg,
              ),
            ),
            title: Row(
              children: [
                Text(
                  orden.id,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeFg,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              'Técnico: ${orden.tecnicoNombre} • Asignó: ${orden.supervisorAsigna}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: orden.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            item.validado ? Icons.check_box : Icons.check_box_outline_blank,
                            size: 16,
                            color: item.validado ? const Color(0xFF2E7D32) : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.codigo,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.descripcion,
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'Recibido: ${item.cantidadRecibidaTecnico} / ${item.cantidadDespachadaBodega} ${item.unidad}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (isPendiente) ...[
                const Divider(height: 1),
                Container(
                  color: Colors.orange.shade50.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.link_rounded, size: 18, color: Colors.orange.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Enlace temporal de acceso:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.share_outlined, size: 14),
                        label: const Text('Compartir / Copiar', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF005A9C),
                          side: const BorderSide(color: Color(0xFF005A9C)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _compartirOReenviarLinkOrden(context, ticket, orden),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const Divider(height: 1),
                Container(
                  color: orden.validadoSupervisor
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFF8E1),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            orden.validadoSupervisor
                                ? Icons.verified
                                : Icons.pending_actions,
                            size: 22,
                            color: orden.validadoSupervisor
                                ? const Color(0xFF2E7D32)
                                : Colors.amber.shade900,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  orden.validadoSupervisor
                                      ? 'CONSUMO EN TALLER CERTIFICADO'
                                      : 'RETIRADO DE BODEGA — PENDIENTE CERTIFICAR CONSUMO',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: orden.validadoSupervisor
                                        ? const Color(0xFF2E7D32)
                                        : Colors.amber.shade900,
                                  ),
                                ),
                                Text(
                                  orden.validadoSupervisor
                                      ? 'Certificado por: ${orden.supervisorValida ?? "SUPERVISOR"} (${_formatearFecha(orden.fechaValidadoSupervisor)})'
                                      : 'Retirado por técnico: ${orden.tecnicoNombre} el ${_formatearFecha(orden.fechaRecepcion)}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                                ),
                              ],
                            ),
                          ),
                          if (!orden.validadoSupervisor) ...[
                            ElevatedButton.icon(
                              icon: const Icon(Icons.verified, size: 16),
                              label: const Text(
                                'Validar Consumo',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _confirmarValidacionConsumoSupervisor(
                                context,
                                ticket,
                                orden,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (orden.observacion != null &&
                          orden.observacion!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.comment_outlined, size: 14, color: Colors.blueGrey),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Nota del técnico: ${orden.observacion}',
                                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTablaFaltantes(BuildContext context, List<ItemDespachoBodegaEntity> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF2E7D32)),
            const SizedBox(height: 12),
            const Text(
              '¡Todos los materiales requeridos han sido entregados por Bodega!',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFFFFF3E0),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade900),
              const SizedBox(width: 8),
              Text(
                'Repuestos pendientes de entrega por Bodega: ${items.length}',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copiar Faltantes', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  final text = items
                      .map((i) => '${i.codigo} - ${i.descripcion}: Falta ${i.cantidadFaltante} ${i.unidad}')
                      .join('\n');
                  _copiarTexto(context, text, 'Listado de repuestos faltantes copiado');
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.orange.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF3E0),
                    child: Icon(Icons.pending, color: Colors.orange),
                  ),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.codigo,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.descripcion,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Falta: ${item.cantidadFaltante} ${item.unidad} (Solicitado: ${item.cantidadSolicitada}, Despachado: ${item.cantidadDespachada})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Text(
                      'Pendiente Bodega',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
