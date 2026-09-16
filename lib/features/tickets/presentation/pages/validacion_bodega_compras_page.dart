import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/entities/item_despacho_bodega_entity.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../inventario/presentation/bloc/inventario_bloc.dart';
import '../../../inventario/presentation/bloc/inventario_state.dart';

class ValidacionBodegaComprasPage extends StatefulWidget {
  final TicketEntity ticket;

  const ValidacionBodegaComprasPage({super.key, required this.ticket});

  @override
  State<ValidacionBodegaComprasPage> createState() =>
      _ValidacionBodegaComprasPageState();
}

class _ValidacionBodegaComprasPageState
    extends State<ValidacionBodegaComprasPage> {
  late List<ItemDespachoBodegaEntity> _items;

  @override
  void initState() {
    super.initState();
    _inicializarItems();
  }

  void _inicializarItems() {
    final invState = context.read<InventarioBloc>().state;
    final mapaStock = invState is InventarioLoaded ? invState.mapaPorCodigo : {};

    if (widget.ticket.itemsDespachoBodega.isNotEmpty) {
      _items = widget.ticket.itemsDespachoBodega.map((i) {
        final codKey = i.codigo.trim().toUpperCase();
        final stock = mapaStock[codKey]?.stockDisponible ?? i.stockDisponibleAlEvaluar;
        final tieneStock = stock >= i.cantidadSolicitada;
        // Si tiene stock suficiente, se auto-marca como validado por compras
        return i.copyWith(
          stockDisponibleAlEvaluar: stock,
          validadoPorCompras: i.validadoPorCompras || tieneStock,
        );
      }).toList();
    } else {
      // Auto-inicializar desde repuestos sugeridos del taller
      final repuestosTaller = widget.ticket.evaluacionTecnica?.repuestosTaller ?? [];
      _items = repuestosTaller.map((r) {
        final codKey = r.codigo.trim().toUpperCase();
        final stock = mapaStock[codKey]?.stockDisponible ?? 0.0;
        final tieneStock = stock >= r.cantidad;

        final fechaSol = widget.ticket.historialEventos.isNotEmpty
            ? widget.ticket.historialEventos.first.timestamp
            : DateTime.now();

        return ItemDespachoBodegaEntity(
          codigo: r.codigo,
          descripcion: r.descripcion,
          unidad: r.unidad,
          cantidadSolicitada: r.cantidad,
          stockDisponibleAlEvaluar: stock,
          validadoPorCompras: tieneStock,
          cantidadDespachada: 0.0,
          fechaSolicitud: fechaSol,
        );
      }).toList();
    }
  }

  void _guardarValidacion({
    bool transferirABodega = false,
    bool transferirDirectoATaller = false,
  }) {
    final authState = context.read<AuthBloc>().state;
    String nombre = 'COMPRAS';
    String rol = 'COMPRAS';
    if (authState is Authenticated) {
      nombre = authState.usuario.nombre;
      rol = authState.usuario.rol.name.toUpperCase();
    }

    context.read<TicketBloc>().add(
          GuardarValidacionBodegaComprasEvent(
            ticket: widget.ticket,
            items: _items,
            transferirABodega: transferirABodega,
            transferirDirectoATaller: transferirDirectoATaller,
            nombreUsuario: nombre,
            rolUsuario: rol,
          ),
        );
  }

  void _copiarTexto(String texto, String mensaje) {
    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: const Color(0xFF005A9C),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _abrirUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el documento adjunto')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool esCaracol = widget.ticket.equipo == TipoEquipo.Caracol ||
        widget.ticket.equipo.name.toLowerCase().contains('caracol');

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text(
          'Validación Bodega: ${widget.ticket.id} (${widget.ticket.marca.toUpperCase()})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF005A9C),
        foregroundColor: Colors.white,
        actions: [
          if (esCaracol && _items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy_all),
              tooltip: 'Copiar Todos los Códigos',
              onPressed: () {
                final codigos = _items.map((i) => i.codigo).where((c) => c.isNotEmpty).join('\n');
                _copiarTexto(codigos, 'Códigos copiados al portapapeles');
              },
            ),
        ],
      ),
      body: BlocListener<TicketBloc, TicketState>(
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
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
        },
        child: esCaracol
            ? _buildVistaCaracol(context)
            : _buildVistaOtrosEquipos(context),
      ),
    );
  }

  // =========================================================================
  // 🚜 VISTA PARA OTROS EQUIPOS (Cosechadora, Contador, Otros)
  // Compras valida que todo esté en bodega y transfiere directo a Proceso de Trabajo.
  // =========================================================================
  Widget _buildVistaOtrosEquipos(BuildContext context) {
    final ticket = widget.ticket;
    final urlsOC = ticket.gestionCompras?.urlsOrdenCompra ?? [];
    final observacionOC = ticket.gestionCompras?.observacion ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tarjeta Resumen del Ticket
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.precision_manufacturing, color: Color(0xFF005A9C), size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ticket ${ticket.id}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                            ),
                            Text(
                              'Equipo: ${ticket.equipo.name.toUpperCase()} • Marca: ${ticket.marca.toUpperCase()}',
                              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF005A9C), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  if (ticket.clienteId.trim().isNotEmpty) ...[
                    _buildDatoRow('Cliente / Camaronera:', ticket.clienteId),
                    const SizedBox(height: 6),
                  ],
                  _buildDatoRow('Contacto:', ticket.nombreContacto),
                  const SizedBox(height: 6),
                  _buildDatoRow('Sede:', ticket.sede.name),
                  const SizedBox(height: 6),
                  _buildDatoRow('Proyecto:', ticket.codigoProyecto ?? 'Sin Asignar'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tarjeta de Órdenes de Compra Adjuntas
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_outlined, color: Colors.teal, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'Órdenes de Compra Registradas',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  if (observacionOC.trim().isNotEmpty) ...[
                    const Text('Observaciones de Compras:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(observacionOC, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 12),
                  ],
                  if (urlsOC.isEmpty)
                    const Text(
                      'No se adjuntaron archivos de OC externos (abastecimiento o repuestos locales).',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    )
                  else ...[
                    const Text('Documentos de Compra:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 6),
                    ...urlsOC.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final url = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2F1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.teal.shade300),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.picture_as_pdf, color: Colors.teal),
                          title: Text('Orden de Compra #$idx', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          trailing: ElevatedButton.icon(
                            icon: const Icon(Icons.open_in_new, size: 14),
                            label: const Text('Ver Archivo', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            onPressed: () => _abrirUrl(url),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Banner Explicativo del Flujo
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF81C784)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Validación Bodega por Compras',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20), fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Para el equipo ${ticket.equipo.name.toUpperCase()}, Compras valida que todo el material y equipo se encuentre listo en bodega.\n\nAl validar, este requerimiento se saltará la etapa de despacho en bodega y pasará DIRECTAMENTE A PROCESO DE TRABAJO para que los técnicos inicien labores.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32), height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Botón de Validación Directa a Proceso de Trabajo
          ElevatedButton.icon(
            icon: const Icon(Icons.send_rounded, size: 22),
            label: const Text(
              'VALIDAR EN BODEGA Y ENVIAR A TALLER',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 3,
            ),
            onPressed: () => _guardarValidacion(transferirDirectoATaller: true),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // =========================================================================
  // 🐌 VISTA PARA CARACOL
  // Muestra repuestos requeridos. Compras valida los ítems que NO tenían stock disponible.
  // A medida que Compras valida, se habilitan en Despacho Bodega.
  // =========================================================================
  Widget _buildVistaCaracol(BuildContext context) {
    // Filtramos los ítems que NO tenían stock inicial suficiente (los que requerían compra externa)
    final itemsSinStock = _items.where((i) => !i.tieneStockSuficiente).toList();
    final itemsConStock = _items.where((i) => i.tieneStockSuficiente).toList();

    final int totalSinStock = itemsSinStock.length;
    final int validadosSinStock = itemsSinStock.where((i) => i.validadoPorCompras).length;
    final bool todosSinStockValidados = totalSinStock == 0 || validadosSinStock == totalSinStock;
    final double progreso = totalSinStock > 0 ? (validadosSinStock / totalSinStock) : 1.0;

    return Column(
      children: [
        // Cabecera Resumen de Validación
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.fact_check_outlined, color: Color(0xFF005A9C)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Validación Bodega: Repuestos Caracol',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Marca: ${widget.ticket.marca.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF005A9C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: todosSinStockValidados
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: todosSinStockValidados
                            ? const Color(0xFF2E7D32)
                            : Colors.orange,
                      ),
                    ),
                    child: Text(
                      totalSinStock > 0
                          ? '$validadosSinStock / $totalSinStock Validados'
                          : '100% en Stock',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: todosSinStockValidados
                            ? const Color(0xFF2E7D32)
                            : Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Los repuestos sin stock previo deben ser validados a medida que compras confirme su ingreso a bodega. Con cada guardado parcial, los repuestos marcados estarán inmediatamente disponibles en Despacho Bodega.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progreso,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    todosSinStockValidados ? const Color(0xFF2E7D32) : const Color(0xFF005A9C),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Lista de Repuestos
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Sección 1: Repuestos que requieren validación por Compras (Sin stock previo)
              if (itemsSinStock.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, color: Colors.orange, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Repuestos Comprados / Por Validar en Bodega ($validadosSinStock/$totalSinStock)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._items.asMap().entries.where((e) => !e.value.tieneStockSuficiente).map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final bool check = item.validadoPorCompras;

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    color: check ? const Color(0xFFF1F8E9) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: check
                            ? const Color(0xFF81C784)
                            : Colors.grey.shade300,
                        width: check ? 1.5 : 1,
                      ),
                    ),
                    child: CheckboxListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      value: check,
                      activeColor: const Color(0xFF2E7D32),
                      onChanged: (bool? val) {
                        setState(() {
                          final isCheck = val ?? false;
                          final ahora = DateTime.now();
                          final fechaSol = item.fechaSolicitud ??
                              (widget.ticket.historialEventos.isNotEmpty
                                  ? widget.ticket.historialEventos.first.timestamp
                                  : ahora);

                          double? leadTime;
                          if (isCheck) {
                            final diff = ahora.difference(fechaSol).inMinutes / 60.0;
                            leadTime = double.parse(diff.toStringAsFixed(2));
                          }

                          _items[index] = item.copyWith(
                            validadoPorCompras: isCheck,
                            fechaSolicitud: fechaSol,
                            fechaValidadoCompras: isCheck ? ahora : null,
                            tiempoAbastecimientoHoras: leadTime,
                          );
                        });
                      },
                      title: Row(
                        children: [
                          if (item.codigo.isNotEmpty)
                            InkWell(
                              onTap: () => _copiarTexto(
                                item.codigo,
                                'Código ${item.codigo} copiado',
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE3F2FD),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      item.codigo,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Color(0xFF0D47A1),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.copy, size: 12, color: Color(0xFF0D47A1)),
                                  ],
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
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Text(
                              'Requerido: ${item.cantidadSolicitada} ${item.unidad}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              check
                                  ? '✓ Listo en Bodega'
                                  : '⏳ Pendiente de Llegada',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: check
                                    ? const Color(0xFF2E7D32)
                                    : Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],

              // Sección 2: Repuestos que ya contaban con stock suficiente (No requirieron compra)
              if (itemsConStock.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Repuestos con Stock Local en Bodega (${itemsConStock.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2E7D32)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...itemsConStock.map((item) {
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 6),
                    color: const Color(0xFFF1F8E9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.green.shade200),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.inventory, color: Color(0xFF2E7D32), size: 20),
                      title: Text(
                        '${item.codigo.isNotEmpty ? "${item.codigo} - " : ""}${item.descripcion}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                      subtitle: Text(
                        'Solicitado: ${item.cantidadSolicitada} ${item.unidad} • Stock: ${item.stockDisponibleAlEvaluar} ${item.unidad}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'En Stock',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),

        // Barra Inferior con Botones de Acción
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!todosSinStockValidados && validadosSinStock > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'ℹ️ Al guardar parcial, los repuestos marcados ya aparecerán en Despacho Bodega para que puedan ir despachándolos al taller.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blueGrey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Row(
                  children: [
                    // Guardar validación parcial
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _guardarValidacion(transferirABodega: false),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Guardar Parcial'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF005A9C),
                          side: const BorderSide(color: Color(0xFF005A9C)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Transferir a bodega (solo si 100% completo de los que requerían compra)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: todosSinStockValidados
                            ? () => _guardarValidacion(transferirABodega: true)
                            : null,
                        icon: const Icon(Icons.send),
                        label: const Text('Transferir a Bodega'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          disabledForegroundColor: Colors.grey.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatoRow(String etiqueta, String valor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            etiqueta,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
          ),
        ),
        Expanded(
          child: Text(
            valor,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
