import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/entities/orden_recepcion_repuestos_entity.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

class RecepcionRepuestosTecnicoPage extends StatefulWidget {
  final TicketEntity ticket;
  final OrdenRecepcionRepuestosEntity orden;

  const RecepcionRepuestosTecnicoPage({
    super.key,
    required this.ticket,
    required this.orden,
  });

  @override
  State<RecepcionRepuestosTecnicoPage> createState() =>
      _RecepcionRepuestosTecnicoPageState();
}

class _RecepcionRepuestosTecnicoPageState
    extends State<RecepcionRepuestosTecnicoPage> {
  final Map<String, TextEditingController> _cantidadesControllers = {};

  @override
  void initState() {
    super.initState();
    for (final item in widget.orden.items) {
      final String initialText = widget.orden.estado == EstadoOrdenRecepcion.recibidoTotal || item.cantidadRecibidaTecnico > 0
          ? item.cantidadRecibidaTecnico.toString().replaceAll(RegExp(r'\.0$'), '')
          : '';
      _cantidadesControllers[item.codigo] = TextEditingController(text: initialText);
    }
  }

  @override
  void dispose() {
    for (final c in _cantidadesControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _hayExcesos {
    for (final item in widget.orden.items) {
      final ctrl = _cantidadesControllers[item.codigo];
      final val = double.tryParse(ctrl?.text.trim() ?? '');
      if (val != null && (val > item.cantidadDespachadaBodega || val < 0)) {
        return true;
      }
    }
    return false;
  }

  bool get _estanTodosContados {
    for (final item in widget.orden.items) {
      final ctrl = _cantidadesControllers[item.codigo];
      if (ctrl == null || ctrl.text.trim().isEmpty) return false;
      final val = double.tryParse(ctrl.text.trim());
      if (val == null || val < 0 || val > item.cantidadDespachadaBodega) return false;
    }
    return true;
  }

  bool get _esTotalmenteConforme {
    if (!_estanTodosContados || _hayExcesos) return false;
    for (final item in widget.orden.items) {
      final ctrl = _cantidadesControllers[item.codigo];
      final cant = double.tryParse(ctrl?.text.trim() ?? '') ?? 0.0;
      if (cant != item.cantidadDespachadaBodega) {
        return false;
      }
    }
    return true;
  }

  void _onConfirmarPresionado() {
    if (_hayExcesos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Una o más cantidades superan lo alistado por bodega.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!_estanTodosContados) return;

    if (_esTotalmenteConforme) {
      _guardarRecepcion(context, esCompleto: true);
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('Discrepancia en Conteo'),
            ],
          ),
          content: const Text(
            '⚠️ ¿Estás seguro que no está todo completo en bodega?\n\n'
            'Has contado una cantidad menor a la alistada por Bodega en uno o más repuestos. '
            'Si confirmas, se registrará una recepción parcial únicamente por lo que contaste físicamente, '
            'y la diferencia quedará disponible en bodega para posterior retiro.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Volver a contar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _guardarRecepcion(context, esCompleto: false);
              },
              child: const Text('Confirmar lo Contado'),
            ),
          ],
        ),
      );
    }
  }

  void _guardarRecepcion(BuildContext context, {required bool esCompleto}) {
    // 🛡️ Enclavamiento: Comprobar que ninguna cantidad sea negativa o exceda el tope de bodega
    for (final item in widget.orden.items) {
      final ctrl = _cantidadesControllers[item.codigo];
      final cant = double.tryParse(ctrl?.text.trim() ?? '') ?? 0.0;
      if (cant < 0 || cant > item.cantidadDespachadaBodega) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: La cantidad de ${item.codigo} excede el máximo alistado (${item.cantidadDespachadaBodega} ${item.unidad}).'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final authState = context.read<AuthBloc>().state;
    String nombreTecnico = widget.orden.tecnicoNombre;
    String rolTecnico = 'TECNICO';
    if (authState is Authenticated && authState.usuario.nombre.isNotEmpty) {
      nombreTecnico = authState.usuario.nombre;
      rolTecnico = authState.usuario.rol.name.toUpperCase();
    }

    final itemsActualizados = widget.orden.items.map((item) {
      final ctrl = _cantidadesControllers[item.codigo];
      final cant = double.tryParse(ctrl?.text.trim() ?? '') ?? 0.0;
      final bool val = cant == item.cantidadDespachadaBodega;
      return item.copyWith(
        cantidadRecibidaTecnico: cant,
        validado: val,
      );
    }).toList();

    context.read<TicketBloc>().add(
          ConfirmarRecepcionRepuestosTecnicoEvent(
            ticket: widget.ticket,
            ordenId: widget.orden.id,
            itemsValidados: itemsActualizados,
            nombreTecnico: nombreTecnico,
            rolTecnico: rolTecnico,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final bool yaFueRecibido =
        widget.orden.estado == EstadoOrdenRecepcion.recibidoTotal;

    return BlocListener<TicketBloc, TicketState>(
      listener: (context, state) {
        if (state.status == TicketStatus.operationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: const Color(0xFF2E7D32),
            ),
          );
          Navigator.pop(context);
        } else if (state.status == TicketStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${state.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: Text(
            'Recepción Bodega - ${widget.orden.id}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          backgroundColor: const Color(0xFF00796B),
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // ENCABEZADO INFORMATIVO
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2F1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.ticket.id,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF00796B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.ticket.equipoDetalle ?? widget.ticket.equipo.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF003057),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person_pin, size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 4),
                        Text(
                          'Técnico de Retiro: ${widget.orden.tecnicoNombre}',
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                        const Spacer(),
                        const Icon(Icons.supervisor_account, size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 4),
                        Text(
                          'Asignó: ${widget.orden.supervisorAsigna}',
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Text(
                      'Verifique físicamente cada repuesto entregado por Bodega. Confirme cantidades reales recibidas antes de trasladarlas al Taller.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),

              // LISTA DE REPUESTOS DE LA ORDEN
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.orden.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = widget.orden.items[index];
                    final ctrl = _cantidadesControllers[item.codigo];
                    final text = ctrl?.text.trim() ?? '';
                    final double? parsedVal = double.tryParse(text);
                    final bool tieneConteo = text.isNotEmpty && parsedVal != null;
                    final double cantidadContada = parsedVal ?? 0.0;
                    final bool excedeMaximo = tieneConteo && (cantidadContada > item.cantidadDespachadaBodega);
                    final bool esInvalido = tieneConteo && (cantidadContada < 0);
                    final bool esConforme = tieneConteo && !excedeMaximo && !esInvalido && (cantidadContada == item.cantidadDespachadaBodega);
                    final bool hayDiscrepancia = tieneConteo && !excedeMaximo && !esInvalido && (cantidadContada < item.cantidadDespachadaBodega);

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: !tieneConteo
                              ? Colors.grey.shade300
                              : (excedeMaximo || esInvalido)
                                  ? Colors.red.shade600
                                  : esConforme
                                      ? Colors.green.shade400
                                      : Colors.orange.shade400,
                          width: (excedeMaximo || esInvalido) ? 2.0 : 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2F1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item.codigo,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Color(0xFF00796B),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: !tieneConteo
                                        ? Colors.grey.shade100
                                        : (excedeMaximo || esInvalido)
                                            ? const Color(0xFFFFEBEE)
                                            : esConforme
                                                ? const Color(0xFFE8F5E9)
                                                : const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    !tieneConteo
                                        ? 'SIN CONTEO'
                                        : (excedeMaximo || esInvalido)
                                            ? 'EXCEDE MÁXIMO'
                                            : esConforme
                                                ? 'CONFORME'
                                                : 'DISCREPANCIA',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: !tieneConteo
                                          ? Colors.grey.shade600
                                          : (excedeMaximo || esInvalido)
                                              ? const Color(0xFFC62828)
                                              : esConforme
                                                  ? const Color(0xFF2E7D32)
                                                  : Colors.orange.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Alistado por Bodega:',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                                Text(
                                  '${item.cantidadDespachadaBodega} ${item.unidad}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF003057),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: ctrl,
                              enabled: !yaFueRecibido,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Conteo Físico Real (${item.unidad}) *',
                                hintText: 'Digita la cantidad que contaste',
                                helperText: 'Máximo alistado: ${item.cantidadDespachadaBodega} ${item.unidad}',
                                errorText: excedeMaximo
                                    ? 'No puede superar ${item.cantidadDespachadaBodega} ${item.unidad} (máx. alistado)'
                                    : esInvalido
                                        ? 'No puede ser un valor negativo'
                                        : null,
                                prefixIcon: Icon(
                                  (excedeMaximo || esInvalido) ? Icons.error_outline : Icons.pin,
                                  size: 18,
                                  color: (excedeMaximo || esInvalido) ? Colors.red : const Color(0xFF00796B),
                                ),
                                suffixText: item.unidad,
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: !tieneConteo
                                    ? Colors.amber.shade50.withValues(alpha: 0.3)
                                    : (excedeMaximo || esInvalido)
                                        ? Colors.red.shade50.withValues(alpha: 0.3)
                                        : Colors.white,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            if (excedeMaximo) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEBEE),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.red.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline, color: Colors.red.shade800, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Error: Ha digitado $cantidadContada ${item.unidad}. Bodega solo alistó un máximo de ${item.cantidadDespachadaBodega} ${item.unidad}. No puede recibir más de lo alistado.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.red.shade900,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (hayDiscrepancia) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.amber.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Discrepancia detectada: Bodega alistó ${item.cantidadDespachadaBodega} ${item.unidad}, pero contaste $cantidadContada ${item.unidad}. Faltante: ${(item.cantidadDespachadaBodega - cantidadContada).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} ${item.unidad}.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange.shade900,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // BOTÓN INFERIOR DE CONFIRMACIÓN
              if (!yaFueRecibido)
                Builder(
                  builder: (context) {
                    final bool puedeConfirmar = _estanTodosContados && !_hayExcesos;
                    final String textoBoton = _hayExcesos
                        ? 'HAY CANTIDADES QUE EXCEDEN EL MÁXIMO ALISTADO'
                        : !_estanTodosContados
                            ? 'Debe ingresar el conteo físico de todos los repuestos'
                            : _esTotalmenteConforme
                                ? 'Confirmar Recepción Conforme (100%)'
                                : 'Confirmar Recepción con Discrepancia';

                    final Color colorBoton = puedeConfirmar
                        ? (_esTotalmenteConforme ? const Color(0xFF00796B) : Colors.orange.shade800)
                        : Colors.grey.shade400;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(puedeConfirmar ? Icons.check_circle_outline : Icons.pending_actions),
                          label: Text(
                            textoBoton,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorBoton,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: puedeConfirmar ? _onConfirmarPresionado : null,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
