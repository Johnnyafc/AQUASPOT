// lib/features/tickets/presentation/pages/creacion_codigos_mantenimiento_page.dart
//
// 🧾 Costos: "Creación de códigos" de un MANTENIMIENTO INTERNO con repuestos
// SIN CÓDIGO. Muestra la ficha que llenó el técnico (cada campo con copiar);
// Costos escribe el código oficial y la descripción con la que lo creó en el
// ERP. Al guardar, esos repuestos pasan a Compras / Bodega. Solo dibuja: el
// envío está en CreacionCodigosMantenimientoCubit.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart' as di;
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/mantenimiento_interno_entity.dart';
import '../../domain/entities/repuesto_por_codificar_entity.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/services/creacion_codigos_mantenimiento_service.dart';
import '../bloc/creacion_codigos_mantenimiento_cubit.dart';
import '../widgets/copy_icon_button_widget.dart';

typedef _C = CreacionCodigosMantenimientoService;

class CreacionCodigosMantenimientoPage extends StatelessWidget {
  final TicketEntity ticket;

  const CreacionCodigosMantenimientoPage({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<CreacionCodigosMantenimientoCubit>(),
      child: _Vista(ticket: ticket),
    );
  }
}

class _Vista extends StatefulWidget {
  final TicketEntity ticket;

  const _Vista({required this.ticket});

  @override
  State<_Vista> createState() => _VistaState();
}

class _VistaState extends State<_Vista> {
  late final List<int> _indices;
  final Map<int, TextEditingController> _codigo = {};
  final Map<int, TextEditingController> _descripcion = {};

  List<RepuestoPorCodificarEntity> get _lista => widget.ticket.mantenimientoInterno?.repuestosPorCodificar ?? const [];

  @override
  void initState() {
    super.initState();
    _indices = _C.indicesPendientes(widget.ticket);
    for (final i in _indices) {
      _codigo[i] = TextEditingController();
      _descripcion[i] = TextEditingController(text: _lista[i].ficha.nombre.isNotEmpty ? _lista[i].ficha.nombre : _lista[i].descripcion);
    }
  }

  @override
  void dispose() {
    for (final c in [..._codigo.values, ..._descripcion.values]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _completo =>
      _indices.isNotEmpty &&
      _indices.every((i) => _codigo[i]!.text.trim().isNotEmpty && _descripcion[i]!.text.trim().isNotEmpty);

  void _guardar() {
    final auth = context.read<AuthBloc>().state;
    context.read<CreacionCodigosMantenimientoCubit>().guardar(
          ticketId: widget.ticket.id,
          codigos: [
            for (final i in _indices)
              CodigoCreadoMantenimiento(indice: i, codigo: _codigo[i]!.text.trim(), descripcion: _descripcion[i]!.text.trim()),
          ],
          usuarioNombre: auth is Authenticated ? auth.usuario.nombre : 'DESCONOCIDO',
          usuarioRol: auth is Authenticated ? auth.usuario.rol.name.toUpperCase() : 'SIN_ROL',
        );
  }

  String _cantidad(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    final m = t.mantenimientoInterno;
    return BlocConsumer<CreacionCodigosMantenimientoCubit, CreacionCodigosMantenimientoState>(
      listener: (context, s) {
        if (s.envio == EnvioCodigosMantenimiento.guardado) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.mensaje), backgroundColor: Colors.green));
          Navigator.pop(context, true);
        } else if (s.envio == EnvioCodigosMantenimiento.error) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.mensaje), backgroundColor: Colors.red));
        }
      },
      builder: (context, s) {
        final enviando = s.envio == EnvioCodigosMantenimiento.enviando;
        return Scaffold(
          appBar: AppBar(
            title: Text('Creación de códigos: ${t.id}'),
            backgroundColor: Colors.teal.shade800,
            foregroundColor: Colors.white,
          ),
          body: SelectionArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Mantenimiento interno — repuestos sin código',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 6),
                        Text('Máquina: ${m?.tipoActivo.etiqueta ?? t.equipo.name} · '
                            '${m?.placa != null ? 'Placa: ${m!.placa}' : 'Serie: ${t.numeroSerie ?? 'S/N'}'}'),
                        const SizedBox(height: 6),
                        Text(
                          'Cree cada código en el ERP con los datos de la ficha y regístrelo aquí con la descripción con la '
                          'que lo creó. Al guardar, los repuestos pasan a Compras / Bodega y se agregan al inventario con stock 0.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_indices.isEmpty)
                  const Text('No hay repuestos pendientes de código.', style: TextStyle(color: Colors.grey)),
                for (final i in _indices) _tarjeta(i, _lista[i]),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: !_completo || enviando ? null : _guardar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: enviando
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: Text(_completo ? 'GUARDAR CÓDIGOS' : 'Ingrese el código y la descripción de cada repuesto',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tarjeta(int i, RepuestoPorCodificarEntity r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.teal.shade300, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${r.descripcion} × ${_cantidad(r.cantidad)} ${r.unidad}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(height: 20),
            const Text('Ficha de creación de código', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            for (final (etiqueta, valor) in r.ficha.campos)
              Row(
                children: [
                  SizedBox(width: 150, child: Text('$etiqueta:', style: const TextStyle(fontWeight: FontWeight.w600))),
                  Expanded(child: Text(valor.isEmpty ? '—' : valor)),
                  if (valor.isNotEmpty) CopyIconButtonWidget(etiqueta: etiqueta, valor: valor),
                ],
              ),
            const Divider(height: 24),
            const Text('Código creado en el ERP', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
            const SizedBox(height: 8),
            TextField(
              controller: _codigo[i],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Código oficial *', border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descripcion[i],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Descripción con la que se creó *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
