import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/services/estado_despacho_service.dart';
import '../../domain/services/flujo_venta_repuesto_service.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import 'despacho_ticket_bodega_page.dart';
import 'validacion_simple_despacho_page.dart';

typedef _Estado = EstadoDespachoService;

class BandejaDespachoBodegaPage extends StatefulWidget {
  const BandejaDespachoBodegaPage({super.key});

  @override
  State<BandejaDespachoBodegaPage> createState() => _BandejaDespachoBodegaPageState();
}

class _BandejaDespachoBodegaPageState extends State<BandejaDespachoBodegaPage> {
  // Tickets cuyo estado de despacho ya se mandó a escribir en esta sesión.
  final Set<String> _sincronizados = {};
  // Solo esta pantalla muestra el resultado de Iniciar / Finalizar picking
  // (evita repetir los avisos de la ventana de despacho que está encima).
  bool _esperandoPicking = false;

  ({String nombre, String rol}) _usuario() {
    final auth = context.read<AuthBloc>().state;
    if (auth is Authenticated) {
      return (nombre: auth.usuario.nombre, rol: auth.usuario.rol.name.toUpperCase());
    }
    return (nombre: 'BODEGA', rol: 'BODEGA');
  }

  /// 🛒 Textos de Venta de Repuesto (preparar pedido / pasar a entrega);
  /// reparación queda igual que antes.
  String _t(TicketEntity t, String reparacion, String venta) =>
      FlujoVentaRepuestoService.esVenta(t) ? venta : reparacion;

  void _iniciarPicking(TicketEntity ticket) {
    final u = _usuario();
    setState(() => _esperandoPicking = true);
    context.read<TicketBloc>().add(IniciarPickingEvent(ticket: ticket, nombreUsuario: u.nombre, rolUsuario: u.rol));
  }

  Future<void> _finalizarPicking(TicketEntity ticket) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t(ticket, '¿Finalizar picking?', '¿Pasar a entrega?')),
        content: Text(
          '${_t(ticket, 'Todos los repuestos de ${ticket.id} están despachados y con evidencia ', 'Todos los repuestos de ${ticket.id} están preparados ')}'
          '(${ticket.historialDespachos.length} despacho(s)).\n\n'
          '${_t(ticket, '', 'La guía firmada se sube después, como último paso antes de finalizar.\n\n')}'
          '${_t(ticket, 'Al finalizar, el ticket pasa a Proceso de Trabajo y sale de esta bandeja.', 'El ticket pasa a Entrega y se avisa a Comercial que los repuestos están listos para retiro. La tarjeta queda aquí hasta subir la guía firmada.')}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t(ticket, 'Sí, finalizar picking', 'Sí, pasar a entrega')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final u = _usuario();
    setState(() => _esperandoPicking = true);
    context.read<TicketBloc>().add(FinalizarPickingEvent(ticket: ticket, nombreUsuario: u.nombre, rolUsuario: u.rol));
  }

  /// Escribe en Firestore el estado deducido de los tickets que aún no
  /// tienen `estadoDespacho` (una sola vez por ticket y sesión). Los que
  /// requieren Validación simple no se tocan: siguen por ese camino.
  void _sincronizarEstados(List<TicketEntity> tickets) {
    final pendientes = <String, String>{
      for (final t in tickets)
        if (t.estadoDespacho == null && !t.requiereValidacionSimpleBodega && !_sincronizados.contains(t.id))
          t.id: _Estado.deducido(t),
    };
    if (pendientes.isEmpty) return;
    _sincronizados.addAll(pendientes.keys);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TicketBloc>().add(SincronizarEstadoDespachoEvent(pendientes));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Despachar Repuestos - Bodega',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF005A9C),
        foregroundColor: Colors.white,
      ),
      body: BlocConsumer<TicketBloc, TicketState>(
        listener: (context, state) {
          if (!_esperandoPicking) return;
          if (state.status == TicketStatus.operationSuccess || state.status == TicketStatus.error) {
            setState(() => _esperandoPicking = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.message),
              backgroundColor: state.status == TicketStatus.error ? Colors.red : const Color(0xFF2E7D32),
            ));
          }
        },
        builder: (context, state) {
          if (state.status == TicketStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Filtro: Tickets con repuestos registrados para despacho en Bodega (Caracol)
          // Se muestran en paralelo al asignarse código de proyecto (para despachar lo que haya en stock)
          // o cuando Compras haya validado al menos un ítem o esté formalmente en Bodega,
          // y que aún no hayan finalizado el picking.
          final ticketsDespacho = state.historial.where((t) {
            // 📦 En bodega pero sin despacho por ítems posible: validación simple.
            if (t.requiereValidacionSimpleBodega) return true;

            // Repuestos registrados para despacho en bodega
            final bool tieneRepuestos = t.itemsDespachoBodega.isNotEmpty ||
                (t.evaluacionTecnica?.repuestosTaller.isNotEmpty ?? false);
            if (!tieneRepuestos) return false;

            // 🛒 Venta en Entrega: sigue aquí hasta subir la guía firmada.
            if (FlujoVentaRepuestoService.esperaGuiaFirmada(t)) return true;

            // Si ya pasó a etapas posteriores al taller
            if (t.estadoActual == EstadoTicket.validacionFacturacion ||
                t.estadoActual == EstadoTicket.entrega ||
                t.estadoActual == EstadoTicket.finalizado ||
                t.estadoActual == EstadoTicket.anulado) {
              return false;
            }

            // 📦 Picking finalizado: el ticket ya está solo en Proceso de Trabajo.
            if (_Estado.efectivo(t) == _Estado.pickingFinalizado) return false;

            final tieneProyecto = t.codigoProyecto != null && t.codigoProyecto!.trim().isNotEmpty;
            final enEstadoBodega = t.estadoActual == EstadoTicket.bodega;
            final visiblePorCompras = t.tieneAlMenosUnCheckCompras;

            return tieneProyecto || enEstadoBodega || visiblePorCompras;
          }).toList();

          _sincronizarEstados(ticketsDespacho);

          if (ticketsDespacho.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 72, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay requerimientos pendientes de despacho en Bodega.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aparecerán automáticamente cuando Compras valide los repuestos que vayan llegando.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ticketsDespacho.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _tarjeta(ticketsDespacho[index]),
          );
        },
      ),
    );
  }

  /// 🧾 "Guía": indicador del estado del despacho (no es un botón).
  ({String texto, Color color, Color fondo}) _guia(TicketEntity ticket) {
    if (ticket.requiereValidacionSimpleBodega) {
      return (texto: 'VALIDACIÓN SIMPLE', color: const Color(0xFF0D47A1), fondo: const Color(0xFFE3F2FD));
    }
    if (FlujoVentaRepuestoService.esperaGuiaFirmada(ticket)) {
      return (texto: '⏳ En entrega · falta guía firmada', color: Colors.deepOrange.shade800, fondo: Colors.orange.shade50);
    }
    // En ventas la evidencia (guía firmada) va al final: no es un faltante aquí.
    if (ticket.tieneDespachoPendienteDeEvidencia && !FlujoVentaRepuestoService.esVenta(ticket)) {
      return (texto: '⚠️ Falta evidencia', color: Colors.amber.shade900, fondo: Colors.amber.shade100);
    }
    String dosDigitos(int n) => n.toString().padLeft(2, '0');
    switch (_Estado.efectivo(ticket)) {
      case _Estado.pickingEnCurso:
        final quien = ticket.pickingIniciadoPor;
        final cuando = ticket.pickingIniciadoEn;
        final detalle = [
          if (quien != null && quien.isNotEmpty) quien,
          if (cuando != null)
            '${dosDigitos(cuando.day)}/${dosDigitos(cuando.month)} ${dosDigitos(cuando.hour)}:${dosDigitos(cuando.minute)}',
        ].join(' · ');
        return (
          texto: detalle.isEmpty
              ? _t(ticket, '🔵 Picking en curso', '🔵 Preparación en curso')
              : '${_t(ticket, '🔵 Picking en curso', '🔵 Preparación en curso')} · $detalle',
          color: const Color(0xFF0D47A1),
          fondo: const Color(0xFFE3F2FD),
        );
      case _Estado.despachoParcial:
        final guias = ticket.historialDespachos.length;
        final pct = _Estado.porcentajeDespachado(ticket).round();
        return (
          texto: _t(ticket, '🟠 Picking parcial · $guias picking(s) · $pct % listo',
              '🟠 Preparación parcial · $guias preparación(es) · $pct % listo'),
          color: Colors.orange.shade900,
          fondo: Colors.orange.shade50,
        );
      case _Estado.pickingFinalizado:
        return (
          texto: _t(ticket, '🟢 Picking finalizado', '🟢 Pedido preparado'),
          color: const Color(0xFF2E7D32),
          fondo: const Color(0xFFE8F5E9),
        );
      default:
        return (
          texto: _t(ticket, '⚪ Pendiente de picking', '⚪ Pendiente de preparar'),
          color: Colors.grey.shade800,
          fondo: Colors.grey.shade100,
        );
    }
  }

  Widget _tarjeta(TicketEntity ticket) {
    final items = ticket.itemsDespachoBodega;
    final validadosCompras = items.where((i) => i.validadoPorCompras).length;
    final despachados = ticket.itemsDespachados.length;
    final total = items.length;
    final tieneParcial = ticket.tieneAlMenosUnDespachoBodega;
    final esValidacionSimple = ticket.requiereValidacionSimpleBodega;
    final guia = _guia(ticket);
    final motivoNoFinaliza = _Estado.motivoNoFinaliza(ticket);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: tieneParcial ? Colors.orange.shade300 : Colors.blue.shade200,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // La ventana de despacho solo se abre con el picking iniciado.
          if (!esValidacionSimple && !_Estado.pickingIniciado(ticket)) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(_t(ticket, 'Inicie el picking primero.', 'Inicie la preparación primero.')),
              backgroundColor: Colors.orange,
            ));
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => esValidacionSimple
                  ? ValidacionSimpleDespachoPage(ticket: ticket)
                  : DespachoTicketBodegaPage(ticket: ticket),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ticket.id,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${ticket.equipo.name.toUpperCase()} • ${ticket.marca.toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Cliente / Campamento: ${ticket.campamento.isNotEmpty ? ticket.campamento : ticket.clienteId}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              if (ticket.numeroSerie != null && ticket.numeroSerie!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Serie: ${ticket.numeroSerie}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              const SizedBox(height: 10),
              // 🧾 GUÍA: estado del despacho (indicador, no se toca).
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: guia.fondo,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: guia.color.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 16, color: guia.color),
                    const SizedBox(width: 6),
                    Text('Guía: ', style: TextStyle(fontSize: 12, color: guia.color)),
                    Expanded(
                      child: Text(
                        guia.texto,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: guia.color),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 4),
                  Text(
                    'Habilitados por compras: $validadosCompras de $total',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '($despachados recolectados)',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  Text(
                    FlujoVentaRepuestoService.esperaGuiaFirmada(ticket)
                        ? 'Subir guía firmada >'
                        : _t(ticket, 'Gestionar picking >', 'Preparar pedido >'),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF005A9C)),
                  ),
                ],
              ),
              // ▶️ / ✅ Botones de picking (no aplican a Validación simple).
              if (!esValidacionSimple) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: Text(_t(ticket, 'Iniciar picking', 'Iniciar preparación')),
                        onPressed: _Estado.puedeIniciarPicking(ticket) ? () => _iniciarPicking(ticket) : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Tooltip(
                        message: motivoNoFinaliza ?? _t(ticket, 'Todo despachado y con evidencia', 'Todo preparado'),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: Text(_t(ticket, 'Finalizar picking', 'Pasar a entrega')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            disabledForegroundColor: Colors.grey.shade600,
                          ),
                          onPressed: _Estado.puedeFinalizarPicking(ticket) ? () => _finalizarPicking(ticket) : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
