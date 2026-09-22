import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/enum/segmento_operativo.dart';
import '../../data/models/ticket_model.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/entities/orden_recepcion_repuestos_entity.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

class MaterialesRecibidosTallerPage extends StatelessWidget {
  final TicketEntity ticket;

  const MaterialesRecibidosTallerPage({super.key, required this.ticket});

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) return '';
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  void _intentarValidarMateriales(BuildContext context, TicketEntity liveTicket) {
    if (!liveTicket.puedeSupervisorValidarMateriales) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('Validación Bloqueada'),
            ],
          ),
          content: const Text(
            'Hay repuestos en bodega aún.\n\n'
            'No se puede certificar la recepción completa en taller mientras existan '
            'repuestos pendientes de ser alistados por Bodega o recogidos por los técnicos.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF005A9C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified, color: Color(0xFF2E7D32), size: 28),
            SizedBox(width: 8),
            Text('Certificar Materiales'),
          ],
        ),
        content: const Text(
          '¿Certifica que el 100% de los repuestos requeridos se encuentran físicamente en el taller?\n\n'
          'Esta acción habilitará la finalización y liberación formal del trabajo.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final authState = context.read<AuthBloc>().state;
              String supervisor = 'SUPERVISOR';
              String rolSupervisor = 'SUPERVISOR';
              if (authState is Authenticated) {
                supervisor = authState.usuario.nombre;
                rolSupervisor = authState.usuario.rol.name.toUpperCase();
              }
              context.read<TicketBloc>().add(
                    ValidarMaterialesRecibidosSupervisorEvent(
                      ticket: liveTicket,
                      nombreSupervisor: supervisor,
                      rolSupervisor: rolSupervisor,
                    ),
                  );
            },
            child: const Text('Certificar 100% Recibido'),
          ),
        ],
      ),
    );
  }

  void _confirmarValidacionOrden(BuildContext context, TicketEntity liveTicket, OrdenRecepcionRepuestosEntity ord) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified, color: Color(0xFF2E7D32), size: 28),
            SizedBox(width: 8),
            Text('Validar Consumo de Lote'),
          ],
        ),
        content: Text(
          '¿Confirma que los repuestos entregados en la orden ${ord.id} por el técnico ${ord.tecnicoNombre} fueron efectivamente consumidos e instalados en el trabajo?\n\n'
          'Esta acción certifica el consumo de este lote para el ticket.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final authState = context.read<AuthBloc>().state;
              String supervisor = 'SUPERVISOR';
              String rolSupervisor = 'SUPERVISOR';
              if (authState is Authenticated) {
                supervisor = authState.usuario.nombre;
                rolSupervisor = authState.usuario.rol.name.toUpperCase();
              }
              context.read<TicketBloc>().add(
                    ValidarConsumoOrdenTallerEvent(
                      ticket: liveTicket,
                      ordenId: ord.id,
                      nombreSupervisor: supervisor,
                      rolSupervisor: rolSupervisor,
                    ),
                  );
            },
            child: const Text('Confirmar Consumo'),
          ),
        ],
      ),
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
              .doc(ticket.id)
              .snapshots(),
          builder: (context, snapshot) {
            TicketEntity liveTicket;
            if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
              final data = Map<String, dynamic>.from(snapshot.data!.data()!);
              data['id'] = snapshot.data!.id;
              liveTicket = TicketModel.fromJson(data);
            } else {
              liveTicket = state.tickets.firstWhere(
                (t) => t.id == ticket.id,
                orElse: () => ticket,
              );
            }

            final items = liveTicket.itemsDespachoBodega;
            final ordenes = liveTicket.ordenesRecepcion;
            final bool estaValidado = liveTicket.materialesValidadosEnTaller;
            final bool algunLoteValidado = liveTicket.tieneConsumoValidadoEnTaller;
            final bool todoEnTaller = liveTicket.puedeSupervisorValidarMateriales;

            return Scaffold(
              backgroundColor: const Color(0xFFF4F6F9),
              appBar: AppBar(
                title: Text(
                  'Materiales Recibidos en Taller - ${liveTicket.id}',
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
                backgroundColor: const Color(0xFF003057),
                foregroundColor: Colors.white,
              ),
          body: SafeArea(
            child: Column(
              children: [
                // BANNER DE ESTADO
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: (estaValidado || algunLoteValidado)
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFF3E0),
                  child: Row(
                    children: [
                      Icon(
                        (estaValidado || algunLoteValidado)
                            ? Icons.verified_user
                            : Icons.rule_folder_outlined,
                        color: (estaValidado || algunLoteValidado)
                            ? const Color(0xFF2E7D32)
                            : Colors.orange.shade900,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              todoEnTaller && estaValidado
                                  ? '100% MATERIALES CERTIFICADOS EN TALLER'
                                  : algunLoteValidado
                                      ? 'CONSUMO PARCIAL CERTIFICADO EN TALLER'
                                      : 'PENDIENTE VALIDACIÓN DEL SUPERVISOR',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: (estaValidado || algunLoteValidado)
                                    ? const Color(0xFF2E7D32)
                                    : Colors.orange.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              algunLoteValidado
                                  ? 'Certificado por: ${liveTicket.supervisorValidoMateriales ?? 'Supervisor'}. Puede validar cada lote conforme ingresa al taller.'
                                  : 'Valide el consumo físico de los lotes entregados por los técnicos para habilitar el reporte de trabajo.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // CUERPO: LISTA DE REPUESTOS Y ÓRDENES
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // SECCIÓN 1: BALANCE DE REPUESTOS
                      Row(
                        children: [
                          const Icon(Icons.handyman_outlined, size: 18, color: Color(0xFF003057)),
                          const SizedBox(width: 8),
                          const Text(
                            'Estado Físico en Taller por Repuesto',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF003057),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${items.length} ítems requeridos',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (items.isEmpty)
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Center(
                              child: Text(
                                'Este ticket no requiere repuestos de bodega.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                        )
                      else
                        ...items.map((item) {
                          final recibido =
                              liveTicket.cantidadTotalRecibidaEnTaller(item.codigo);
                          final esCompleto = recibido >= item.cantidadSolicitada;
                          final faltante = item.cantidadSolicitada - recibido;

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: esCompleto
                                    ? Colors.green.shade200
                                    : Colors.orange.shade200,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
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
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: esCompleto
                                              ? const Color(0xFFE8F5E9)
                                              : const Color(0xFFFFF3E0),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          esCompleto ? '100% EN TALLER' : 'FALTA $faltante',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: esCompleto
                                                ? const Color(0xFF2E7D32)
                                                : Colors.orange.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Requerido: ${item.cantidadSolicitada} ${item.unidad}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      Text(
                                        'Alistado Bodega: ${item.cantidadDespachada} ${item.unidad}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      Text(
                                        'En Taller: $recibido ${item.unidad}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: esCompleto
                                              ? const Color(0xFF2E7D32)
                                              : Colors.orange.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                      const SizedBox(height: 20),

                      // SECCIÓN 2: HISTORIAL DE RETIROS POR TÉCNICOS
                      Row(
                        children: [
                          const Icon(Icons.history_edu_outlined, size: 18, color: Color(0xFF003057)),
                          const SizedBox(width: 8),
                          const Text(
                            'Entregas Físicas por Técnicos de Retiro',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF003057),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (ordenes.isEmpty)
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: Text(
                                'Aún no se han registrado recepciones por parte de los técnicos.',
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ),
                          ),
                        )
                      else
                        ...ordenes.map((ord) {
                          final bool isCompleta =
                              ord.estado == EstadoOrdenRecepcion.recibidoTotal;

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        ord.id,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Técnico: ${ord.tecnicoNombre}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF005A9C),
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isCompleta
                                              ? const Color(0xFFE8F5E9)
                                              : const Color(0xFFFFF3E0),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isCompleta ? 'RECIBIDO TOTAL' : 'RECIBIDO PARCIAL',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isCompleta
                                                ? const Color(0xFF2E7D32)
                                                : Colors.orange.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (ord.fechaRecepcion != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Entregado en taller: ${_formatearFecha(ord.fechaRecepcion)}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  ...ord.items.map((item) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(
                                        children: [
                                          Icon(
                                            item.validado ? Icons.check : Icons.close,
                                            size: 14,
                                            color: item.validado ? Colors.green : Colors.red,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            item.codigo,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
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
                                            '${item.cantidadRecibidaTecnico} ${item.unidad}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                   }),
                                  const SizedBox(height: 10),
                                  if (ord.validadoSupervisor)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.green.shade300),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.check_circle,
                                              color: Color(0xFF2E7D32), size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'CONSUMO CERTIFICADO POR ${ord.supervisorValida ?? 'SUPERVISOR'}'
                                              '${ord.fechaValidadoSupervisor != null ? '\n${_formatearFecha(ord.fechaValidadoSupervisor)}' : ''}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF2E7D32),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (ord.estaCompletada)
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.fact_check_outlined,
                                            size: 18),
                                        label: const Text(
                                          'Validar Consumo de este Lote',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2E7D32),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8)),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10),
                                        ),
                                        onPressed: () =>
                                            _confirmarValidacionOrden(
                                                context, liveTicket, ord),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),

                // BOTÓN DE ACCIÓN: VALIDAR MATERIALES
                if (!estaValidado)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.verified),
                        label: const Text(
                          'Validar Materiales en Taller',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => _intentarValidarMateriales(context, liveTicket),
                      ),
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
}
