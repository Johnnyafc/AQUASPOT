// lib/features/tickets/presentation/pages/validacion_simple_despacho_page.dart
//
// 📦 Despacho Bodega -- validación simple. Para tickets en estado bodega que
// no pueden seguir el despacho por ítems (ver
// TicketEntity.requiereValidacionSimpleBodega): Bodega revisa los datos y
// confirma, y el ticket pasa a Proceso de Trabajo. No descuenta stock.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/ticket_entity.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';

class ValidacionSimpleDespachoPage extends StatefulWidget {
  final TicketEntity ticket;

  const ValidacionSimpleDespachoPage({super.key, required this.ticket});

  @override
  State<ValidacionSimpleDespachoPage> createState() => _ValidacionSimpleDespachoPageState();
}

class _ValidacionSimpleDespachoPageState extends State<ValidacionSimpleDespachoPage> {
  bool _enviando = false;

  String _fmt(num v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  Future<void> _confirmar() async {
    final ticket = widget.ticket;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar despacho'),
        content: Text('${ticket.id} pasará a Proceso de Trabajo. Esta acción no descuenta stock del inventario.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    final authState = context.read<AuthBloc>().state;
    String nombre = 'SISTEMA';
    String rol = 'DESCONOCIDO';
    if (authState is Authenticated) {
      nombre = authState.usuario.nombre;
      rol = authState.usuario.rol.name.toUpperCase();
    }

    setState(() => _enviando = true);
    context.read<TicketBloc>().add(ValidarDespachoSimpleBodegaEvent(
      ticket: ticket,
      nombreUsuario: nombre,
      rolUsuario: rol,
    ));
  }

  Widget _dato(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(TextSpan(children: [
        TextSpan(text: '$etiqueta: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        TextSpan(text: valor),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final sinRepuestos = ticket.itemsDespachoBodega.isEmpty;
    final itemsCompra = ticket.itemsCompra ?? const [];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text('Validar Despacho: ${ticket.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF005A9C),
        foregroundColor: Colors.white,
      ),
      body: BlocListener<TicketBloc, TicketState>(
        listener: (context, state) {
          if (!_enviando) return;
          if (state.status == TicketStatus.operationSuccess) {
            _enviando = false;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.green));
            Navigator.pop(context);
          } else if (state.status == TicketStatus.error) {
            setState(() => _enviando = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          }
        },
        child: BlocBuilder<TicketBloc, TicketState>(
          builder: (context, state) {
            final cargando = _enviando && state.status == TicketStatus.loading;
            return AbsorbPointer(
              absorbing: cargando,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ℹ️ Por qué este ticket va por validación simple
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF90CAF9)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFF0D47A1)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sinRepuestos
                                ? 'Este requerimiento no tiene repuestos registrados para despacho por ítems. Verifique que el material esté listo y confirme para pasarlo a Proceso de Trabajo.'
                                : 'Este requerimiento ya tiene su despacho completo con evidencias, pero no pasó a Proceso de Trabajo. Confirme para completar el traspaso.',
                            style: const TextStyle(color: Color(0xFF0D47A1)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _dato('Cliente / Campamento', ticket.campamento.isNotEmpty ? ticket.campamento : ticket.clienteId),
                          _dato('Equipo', '${ticket.equipo.name.toUpperCase()} • ${ticket.marca.toUpperCase()}'),
                          if (ticket.numeroSerie != null && ticket.numeroSerie!.isNotEmpty) _dato('Serie', ticket.numeroSerie!),
                          _dato('Proyecto', ticket.codigoProyecto?.trim().isNotEmpty == true ? ticket.codigoProyecto! : 'Sin código'),
                          if (ticket.codigoOrdenCompra.isNotEmpty) _dato('Orden(es) de compra', ticket.codigoOrdenCompra.join(', ')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 📋 Referencia: repuestos registrados en compras / despachos previos
                  if (itemsCompra.isNotEmpty || ticket.itemsDespachoBodega.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ticket.itemsDespachoBodega.isNotEmpty ? 'Repuestos despachados' : 'Repuestos registrados en compras',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const Divider(),
                            if (ticket.itemsDespachoBodega.isNotEmpty)
                              ...ticket.itemsDespachoBodega.map((i) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3),
                                    child: Text('${i.codigo} — ${i.descripcion} • ${_fmt(i.cantidadDespachada)}/${_fmt(i.cantidadSolicitada)} ${i.unidad}'),
                                  ))
                            else
                              ...itemsCompra.map((i) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3),
                                    child: Text('${i.sku} — ${i.descripcion} • Cant: ${i.cantidad}'),
                                  )),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: cargando ? null : _confirmar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: cargando
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.local_shipping_outlined),
                      label: Text(cargando ? state.message : 'CONFIRMAR DESPACHO Y PASAR A PROCESO DE TRABAJO',
                          textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
