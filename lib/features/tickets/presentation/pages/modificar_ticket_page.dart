// lib/features/tickets/presentation/pages/modificar_ticket_page.dart
//
// 🛠️ "Modificar Ticket" (solo cuenta administradora maestra, ver
// correoAdministradorMaestro): busca un ticket y cambia su estado con un
// motivo obligatorio. Usa ForzarCambioEstadoAdminEvent, que deja en la
// auditoría 'ADMIN: CAMBIO FORZADO A "..." -- Motivo: ...' (fuera de los
// promedios de tiempo; la etapa destino cuenta desde el cambio).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/enum/segmento_operativo.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/ticket_entity.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';

class ModificarTicketPage extends StatefulWidget {
  const ModificarTicketPage({super.key});

  @override
  State<ModificarTicketPage> createState() => _ModificarTicketPageState();
}

class _ModificarTicketPageState extends State<ModificarTicketPage> {
  final TextEditingController _busqueda = TextEditingController();
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    if (context.read<TicketBloc>().state.historial.isEmpty) {
      context.read<TicketBloc>().add(const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.ninguno));
    }
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  String _dd(int v) => v.toString().padLeft(2, '0');
  String _fecha(DateTime d) => '${_dd(d.day)}/${_dd(d.month)}/${d.year} ${_dd(d.hour)}:${_dd(d.minute)}';

  /// Estados anteriores a Costos/Compras: al volver a ellos se sugiere
  /// reiniciar los indicadores de esos departamentos.
  bool _esAnteriorACostos(EstadoTicket e) => const {
        EstadoTicket.creado,
        EstadoTicket.enCamino,
        EstadoTicket.recepcionFisica,
        EstadoTicket.revisionGarantia,
        EstadoTicket.cotizandoRepuesto,
        EstadoTicket.comercial,
        EstadoTicket.cotizado,
      }.contains(e);

  Future<void> _abrirCambio(TicketEntity ticket) async {
    EstadoTicket? destino;
    final motivo = TextEditingController();
    var resetearCostos = false;
    var resetearCompras = false;

    final confirmado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final eventos = [...ticket.historialEventos]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
          final puedeGuardar = destino != null && motivo.text.trim().length >= 5;
          return Padding(
            padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Modificar ${ticket.id}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${ticket.clienteId} · ${ticket.equipo.name} · Estado actual: ${ticket.estadoActual.nombreLegible}',
                      style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 12),
                  const Text('Últimos movimientos', style: TextStyle(fontWeight: FontWeight.w600)),
                  for (final e in eventos.take(3))
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text('• ${_fecha(e.timestamp)} — ${e.accion}',
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    ),
                  const Divider(height: 24),
                  DropdownButtonFormField<EstadoTicket>(
                    initialValue: destino,
                    decoration: const InputDecoration(labelText: 'Nuevo estado', border: OutlineInputBorder()),
                    items: [
                      for (final e in EstadoTicket.values)
                        if (e != ticket.estadoActual) DropdownMenuItem(value: e, child: Text(e.nombreLegible)),
                    ],
                    onChanged: (v) => setLocal(() {
                      destino = v;
                      final reiniciar = v != null && _esAnteriorACostos(v);
                      resetearCostos = reiniciar;
                      resetearCompras = reiniciar;
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: motivo,
                    maxLines: 3,
                    onChanged: (_) => setLocal(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Motivo (obligatorio)',
                      hintText: 'Ej.: Se abrió el motor y estaba dañado; se re-cotiza motor nuevo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: resetearCostos,
                    onChanged: (v) => setLocal(() => resetearCostos = v ?? false),
                    title: const Text('Reiniciar Costos'),
                    subtitle: const Text('Costos deberá procesar el ticket otra vez'),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: resetearCompras,
                    onChanged: (v) => setLocal(() => resetearCompras = v ?? false),
                    title: const Text('Reiniciar Compras'),
                    subtitle: const Text('Compras deberá procesar el ticket otra vez'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: puedeGuardar ? () => Navigator.pop(ctx, true) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.save),
                    label: const Text('CAMBIAR ESTADO'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (confirmado != true || destino == null || !mounted) return;

    final seguro = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar cambio'),
        content: Text(
          '${ticket.id} pasará de «${ticket.estadoActual.nombreLegible}» a «${destino!.nombreLegible}».\n\n'
          'Motivo: ${motivo.text.trim()}\n\n'
          'Quedará registrado en la auditoría con su nombre.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (seguro != true || !mounted) return;

    final auth = context.read<AuthBloc>().state;
    final nombre = auth is Authenticated ? auth.usuario.nombre : 'ADMIN';
    final rol = auth is Authenticated ? auth.usuario.rol.name.toUpperCase() : 'ADMIN';

    setState(() => _enviando = true);
    context.read<TicketBloc>().add(ForzarCambioEstadoAdminEvent(
      ticket: ticket,
      nuevoEstado: destino!,
      motivo: motivo.text.trim(),
      nombreAdmin: nombre,
      rolAdmin: rol,
      resetearCostos: resetearCostos,
      resetearCompras: resetearCompras,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modificar Ticket'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: BlocConsumer<TicketBloc, TicketState>(
        listener: (context, state) {
          if (!_enviando) return;
          if (state.status == TicketStatus.operationSuccess) {
            setState(() => _enviando = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.green));
          } else if (state.status == TicketStatus.error) {
            setState(() => _enviando = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          }
        },
        builder: (context, state) {
          final q = _busqueda.text.trim().toLowerCase();
          final lista = state.historial
              .where((t) => q.isEmpty || t.id.toLowerCase().contains(q) || t.clienteId.toLowerCase().contains(q))
              .toList()
            ..sort((a, b) => b.id.compareTo(a.id));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _busqueda,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Buscar por número de ticket o cliente',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (_enviando || state.status == TicketStatus.loading) const LinearProgressIndicator(),
              Expanded(
                child: lista.isEmpty
                    ? Center(child: Text('Sin tickets', style: TextStyle(color: Colors.grey.shade600)))
                    : ListView.separated(
                        itemCount: lista.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final t = lista[i];
                          return ListTile(
                            title: Text(t.id, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${t.clienteId} · ${t.equipo.name}'),
                            trailing: Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(t.estadoActual.nombreLegible, style: const TextStyle(fontSize: 11)),
                            ),
                            onTap: _enviando ? null : () => _abrirCambio(t),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
