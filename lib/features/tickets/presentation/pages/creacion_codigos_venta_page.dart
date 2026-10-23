// lib/features/tickets/presentation/pages/creacion_codigos_venta_page.dart
//
// 🧾 Costos: "Creación de códigos" de una Venta de Repuesto con repuestos que
// no están en el sistema. Muestra la ficha que llenó el supervisor (cada
// campo con copiar) y la cotización del proveedor; Costos escribe el código
// oficial y la descripción con la que lo creó en el ERP. Al guardar, el
// requerimiento regresa a Proformas enviadas para que Comercial registre la OV.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/linea_repuesto_venta_entity.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/services/creacion_codigos_venta_service.dart';
import '../../domain/usecases/registrar_codigos_creados_usecase.dart' show CodigoCreado;
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../widgets/copy_icon_button_widget.dart';

class CreacionCodigosVentaPage extends StatefulWidget {
  final TicketEntity ticket;

  const CreacionCodigosVentaPage({super.key, required this.ticket});

  @override
  State<CreacionCodigosVentaPage> createState() => _CreacionCodigosVentaPageState();
}

class _CreacionCodigosVentaPageState extends State<CreacionCodigosVentaPage> {
  late final List<int> _indices;
  final Map<int, TextEditingController> _codigo = {};
  final Map<int, TextEditingController> _descripcion = {};
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _indices = CreacionCodigosVentaService.indicesPendientes(widget.ticket);
    for (final i in _indices) {
      final l = widget.ticket.lineasRepuestoVenta[i];
      _codigo[i] = TextEditingController();
      _descripcion[i] = TextEditingController(text: l.fichaCreacion?.nombre ?? l.descripcion);
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
    final nombre = auth is Authenticated ? auth.usuario.nombre : 'DESCONOCIDO';
    final rol = auth is Authenticated ? auth.usuario.rol.name.toUpperCase() : 'SIN_ROL';
    setState(() => _enviando = true);
    context.read<TicketBloc>().add(RegistrarCodigosCreadosEvent(
          ticketId: widget.ticket.id,
          codigos: [
            for (final i in _indices)
              CodigoCreado(indiceLinea: i, codigo: _codigo[i]!.text.trim(), descripcion: _descripcion[i]!.text.trim()),
          ],
          nombreUsuario: nombre,
          rolUsuario: rol,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    return Scaffold(
      appBar: AppBar(
        title: Text('Creación de códigos: ${t.id}'),
        backgroundColor: Colors.teal.shade800,
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
        child: SelectionArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Venta de Repuesto — repuestos que no están en el sistema',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 6),
                      Text('Cliente: ${t.clienteId} · Repuesto de: ${t.equipo.name.toUpperCase()}'),
                      const SizedBox(height: 6),
                      Text(
                        'Cree cada código en el ERP con los datos de la ficha y regístrelo aquí con la descripción con la '
                        'que lo creó. Al guardar, el requerimiento regresa a Proformas enviadas para la OV y el repuesto '
                        'se agrega al inventario con stock 0.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_indices.isEmpty)
                const Text('No hay repuestos pendientes de código.', style: TextStyle(color: Colors.grey)),
              for (final i in _indices) _tarjeta(i, t.lineasRepuestoVenta[i]),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: !_completo || _enviando ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _enviando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: Text(_completo ? 'GUARDAR CÓDIGOS' : 'Ingrese el código y la descripción de cada repuesto',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjeta(int i, LineaRepuestoVentaEntity l) {
    final ficha = l.fichaCreacion;
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
            Text(
              '${ficha?.nombre ?? l.descripcionVisible} × ${l.cantidad % 1 == 0 ? l.cantidad.toStringAsFixed(0) : l.cantidad}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (l.descripcionCliente.isNotEmpty)
              Text('Pedido del cliente: "${l.descripcionCliente}"',
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade700)),
            if (l.codigo.isNotEmpty) Text('Código del proveedor: ${l.codigo}', style: const TextStyle(fontSize: 12)),
            const Divider(height: 20),
            const Text('Ficha de creación de código', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (ficha == null)
              const Text('Sin ficha registrada.', style: TextStyle(color: Colors.grey))
            else
              for (final (etiqueta, valor) in ficha.campos)
                Row(
                  children: [
                    SizedBox(width: 150, child: Text('$etiqueta:', style: const TextStyle(fontWeight: FontWeight.w600))),
                    Expanded(child: Text(valor.isEmpty ? '—' : valor)),
                    if (valor.isNotEmpty) CopyIconButtonWidget(etiqueta: etiqueta, valor: valor),
                  ],
                ),
            if (l.urlsCotizacionProveedor.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (int k = 0; k < l.urlsCotizacionProveedor.length; k++)
                InkWell(
                  onTap: () => launchUrl(Uri.parse(l.urlsCotizacionProveedor[k]), mode: LaunchMode.externalApplication),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('📎 Ver cotización del proveedor ${k + 1}',
                        style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                  ),
                ),
            ],
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
