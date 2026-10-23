import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/entities/orden_recepcion_repuestos_entity.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../../core/enum/segmento_operativo.dart';
import '../../../../core/enum/rol_usuario.dart';
import 'recepcion_repuestos_tecnico_page.dart';

class BandejaRecepcionBodegaPage extends StatefulWidget {
  const BandejaRecepcionBodegaPage({super.key});

  @override
  State<BandejaRecepcionBodegaPage> createState() =>
      _BandejaRecepcionBodegaPageState();
}

class _BandejaRecepcionBodegaPageState extends State<BandejaRecepcionBodegaPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<TicketBloc>().add(
          const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.ninguno),
        );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _coincideTecnico(OrdenRecepcionRepuestosEntity orden, String uid, String nombreUser) {
    if (uid.isNotEmpty && orden.tecnicoId == uid) return true;

    String norm(String s) => s
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');

    final nOrden = norm(orden.tecnicoNombre);
    final nUser = norm(nombreUser);

    if (nOrden.isEmpty || nUser.isEmpty) return false;
    if (nOrden == nUser) return true;
    if (nOrden.contains(nUser) || nUser.contains(nOrden)) return true;

    final tokensOrden = nOrden.split(RegExp(r'\s+')).where((t) => t.length >= 3);
    final tokensUser = nUser.split(RegExp(r'\s+')).where((t) => t.length >= 3);
    for (final to in tokensOrden) {
      if (tokensUser.contains(to)) return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    String nombreUsuario = '';
    String uidUsuario = '';
    bool esSupervisorOAdmin = false;

    if (authState is Authenticated) {
      nombreUsuario = authState.usuario.nombre.toLowerCase();
      uidUsuario = authState.usuario.uid;
      esSupervisorOAdmin = authState.usuario.rol == RolUsuario.admin ||
          authState.usuario.rol == RolUsuario.supervisor;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Recepción de Repuestos en Bodega',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF00796B),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.pending_actions, size: 18),
              text: 'Pendientes Retiro',
            ),
            Tab(
              icon: Icon(Icons.check_circle_outline, size: 18),
              text: 'Recibidos',
            ),
          ],
        ),
      ),
      body: BlocBuilder<TicketBloc, TicketState>(
        builder: (context, state) {
          if (state.status == TicketStatus.loading &&
              state.tickets.isEmpty &&
              state.historial.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00796B)));
          }

          final todosTickets =
              state.tickets.isNotEmpty ? state.tickets : state.historial;

          // Aplanar todas las órdenes asociadas con su ticket
          final List<_OrdenConTicket> todasOrdenes = [];
          for (final t in todosTickets) {
            for (final ord in t.ordenesRecepcion) {
              todasOrdenes.add(_OrdenConTicket(ticket: t, orden: ord));
            }
          }

          // Ordenar cronológicamente (más recientes primero)
          todasOrdenes.sort((a, b) =>
              b.orden.fechaAsignacion.compareTo(a.orden.fechaAsignacion));

          final pendientes = todasOrdenes.where((item) {
            final esPendiente =
                item.orden.estado == EstadoOrdenRecepcion.pendienteRecoger;
            if (!esPendiente) return false;
            if (esSupervisorOAdmin) return true;
            return _coincideTecnico(item.orden, uidUsuario, nombreUsuario);
          }).toList();

          final completadas = todasOrdenes.where((item) {
            final esCompletada =
                item.orden.estado != EstadoOrdenRecepcion.pendienteRecoger;
            if (!esCompletada) return false;
            if (esSupervisorOAdmin) return true;
            return _coincideTecnico(item.orden, uidUsuario, nombreUsuario);
          }).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildListaOrdenes(context, pendientes, isPendiente: true),
              _buildListaOrdenes(context, completadas, isPendiente: false),
            ],
          );
        },
      ),
    );
  }

  Widget _buildListaOrdenes(
      BuildContext context, List<_OrdenConTicket> lista,
      {required bool isPendiente}) {
    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPendiente
                  ? Icons.task_alt_outlined
                  : Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              isPendiente
                  ? 'No hay órdenes de retiro pendientes en bodega.'
                  : 'Aún no hay órdenes completadas.',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF00796B),
      onRefresh: () async {
        context.read<TicketBloc>().add(
              const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.ninguno),
            );
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: lista.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = lista[index];
          final ticket = item.ticket;
          final orden = item.orden;

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isPendiente ? Colors.orange.shade300 : Colors.green.shade300,
                width: 1.2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2F1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ticket.id,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Color(0xFF00796B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          orden.id,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isPendiente
                              ? const Color(0xFFFFF3E0)
                              : const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isPendiente ? 'PENDIENTE' : 'RECIBIDO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isPendiente
                                ? Colors.orange.shade900
                                : const Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    ticket.equipoDetalle ?? ticket.equipo.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF003057),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cliente: ${ticket.nombreContacto} (${ticket.sede.name})',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.person_pin, size: 16, color: Colors.blueGrey),
                      const SizedBox(width: 4),
                      Text(
                        'Técnico: ${orden.tecnicoNombre}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      Text(
                        '${orden.items.length} repuestos',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00796B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(
                        isPendiente
                            ? Icons.verified_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                      ),
                      label: Text(
                        isPendiente
                            ? 'Validar y Recibir Repuestos'
                            : 'Ver Detalle de Recepción',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPendiente
                            ? const Color(0xFF00796B)
                            : Colors.blueGrey.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecepcionRepuestosTecnicoPage(
                              ticket: ticket,
                              orden: orden,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrdenConTicket {
  final TicketEntity ticket;
  final OrdenRecepcionRepuestosEntity orden;

  const _OrdenConTicket({required this.ticket, required this.orden});
}
