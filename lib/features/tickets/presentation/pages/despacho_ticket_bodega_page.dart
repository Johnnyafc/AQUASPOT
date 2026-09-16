import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/entities/item_despacho_bodega_entity.dart';
import '../../domain/entities/registro_despacho_entity.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../services/generador_excel_despacho_bodega.dart';

class DespachoTicketBodegaPage extends StatefulWidget {
  final TicketEntity ticket;

  const DespachoTicketBodegaPage({super.key, required this.ticket});

  @override
  State<DespachoTicketBodegaPage> createState() =>
      _DespachoTicketBodegaPageState();
}

class _DespachoTicketBodegaPageState extends State<DespachoTicketBodegaPage>
    with SingleTickerProviderStateMixin {
  late List<ItemDespachoBodegaEntity> _items;
  final Map<String, double> _cantidadesADespachar = {};
  final Set<String> _itemsSeleccionados = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _items = widget.ticket.itemsDespachoBodega.map((i) => i.copyWith()).toList();

    // 🛑 ENCLAVAMIENTO ESTRICTO: Solo inicializar y preseleccionar ítems VALIDADOS por Compras
    for (final item in _items) {
      if (item.validadoPorCompras && item.cantidadFaltante > 0) {
        _cantidadesADespachar[item.codigo] = item.cantidadFaltante;
        _itemsSeleccionados.add(item.codigo);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<ItemDespachoBodegaEntity> get _itemsHabilitados =>
      _items.where((i) => i.validadoPorCompras).toList();

  List<ItemDespachoBodegaEntity> get _itemsPendientesCompras =>
      _items.where((i) => !i.validadoPorCompras).toList();

  void _mostrarDialogoExportarExcel() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.file_download_outlined,
                        color: Color(0xFF005A9C), size: 28),
                    const SizedBox(width: 8),
                    const Text(
                      'Descargar Excel de Despacho',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Seleccione la modalidad de reporte para descargar del ERP o consultar faltantes:',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 20),

                // Opción 1: Lote Actual Seleccionado (Solo habilitados y marcados)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE3F2FD),
                    child: Icon(Icons.checklist, color: Color(0xFF0D47A1)),
                  ),
                  title: const Text('1. Repuestos Habilitados y Seleccionados',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text(
                      'Genera el vale con las cantidades validadas por compras para descontar ahora del ERP.',
                      style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context);
                    _descargarExcel(ModoExcelDespacho.seleccionActual);
                  },
                ),
                const Divider(),

                // Opción 2: Solo Faltantes
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF3E0),
                    child: Icon(Icons.pending_actions, color: Colors.orange),
                  ),
                  title: const Text('2. Solo Repuestos Faltantes',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text(
                      'Genera el reporte con lo que aún falta despachar o recibir en compras.',
                      style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context);
                    _descargarExcel(ModoExcelDespacho.faltantes);
                  },
                ),
                const Divider(),

                // Opción 3: Consolidado Completo
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(Icons.table_chart_outlined, color: Color(0xFF2E7D32)),
                  ),
                  title: const Text('3. Consolidado General (Todos los Repuestos)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text(
                      'Reporte completo con estado de validación en compras, despachados y saldos.',
                      style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context);
                    _descargarExcel(ModoExcelDespacho.consolidadoTodos);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _descargarExcel(ModoExcelDespacho modo) async {
    final authState = context.read<AuthBloc>().state;
    String nombre = 'BODEGA';
    if (authState is Authenticated) {
      nombre = authState.usuario.nombre;
    }

    final bytes = GeneradorExcelDespachoBodega.generarExcel(
      ticket: widget.ticket,
      modo: modo,
      items: _items,
      cantidadesSeleccionadas: _cantidadesADespachar,
      operadorBodega: nombre,
    );

    String sufijo = 'seleccion';
    if (modo == ModoExcelDespacho.faltantes) sufijo = 'faltantes';
    if (modo == ModoExcelDespacho.consolidadoTodos) sufijo = 'consolidado';

    final fileName = 'despacho_${widget.ticket.id}_$sufijo.xlsx';
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  void _confirmarDespacho() {
    final authState = context.read<AuthBloc>().state;
    String nombre = 'BODEGA';
    String rol = 'BODEGA';
    String uid = 'SISTEMA';
    if (authState is Authenticated) {
      nombre = authState.usuario.nombre;
      rol = authState.usuario.rol.name.toUpperCase();
      uid = authState.usuario.uid;
    }

    final detalles = <DetalleItemDespachadoEntity>[];
    final itemsActualizados = <ItemDespachoBodegaEntity>[];

    for (final item in _items) {
      // 🛑 ENCLAVAMIENTO CRÍTICO:
      // Jamás se despacha un ítem que no haya sido validado previamente por Compras
      if (!item.validadoPorCompras) {
        itemsActualizados.add(item);
        continue;
      }

      if (_itemsSeleccionados.contains(item.codigo)) {
        final cantADespachar = _cantidadesADespachar[item.codigo] ?? 0.0;
        if (cantADespachar > 0) {
          detalles.add(DetalleItemDespachadoEntity(
            codigo: item.codigo,
            descripcion: item.descripcion,
            unidad: item.unidad,
            cantidad: cantADespachar,
          ));

          final nuevaCantTotalDespachada = item.cantidadDespachada + cantADespachar;
          itemsActualizados.add(item.copyWith(
            cantidadDespachada: nuevaCantTotalDespachada,
            fechaUltimoDespacho: DateTime.now(),
            despachadoPor: nombre,
          ));
          continue;
        }
      }
      itemsActualizados.add(item);
    }

    if (detalles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione al menos un repuesto habilitado con cantidad mayor a 0 para despachar'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final nuevoRegistro = RegistroDespachoEntity(
      id: 'DESP-${DateTime.now().millisecondsSinceEpoch}',
      fecha: DateTime.now(),
      usuarioNombre: nombre,
      usuarioId: uid,
      items: detalles,
    );

    context.read<TicketBloc>().add(
          RegistrarDespachoBodegaEvent(
            ticket: widget.ticket,
            itemsActualizados: itemsActualizados,
            nuevoRegistro: nuevoRegistro,
            nombreUsuario: nombre,
            rolUsuario: rol,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final habilitados = _itemsHabilitados;
    final pendientes = _itemsPendientesCompras;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text(
          'Despachar: ${widget.ticket.id}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF005A9C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Exportar Excel de Despacho',
            onPressed: _mostrarDialogoExportarExcel,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              icon: const Icon(Icons.check_circle_outline, size: 18),
              text: 'Disponibles (${habilitados.length})',
            ),
            Tab(
              icon: const Icon(Icons.lock_clock_outlined, size: 18),
              text: 'Pendientes Compras (${pendientes.length})',
            ),
          ],
        ),
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
        child: Column(
          children: [
            // Cabecera Resumen
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Equipo: ${widget.ticket.equipo.name.toUpperCase()} • Marca: ${widget.ticket.marca.toUpperCase()} (Serie: ${widget.ticket.numeroSerie ?? "S/N"})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Campamento: ${widget.ticket.campamento}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text('Excel ERP'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF005A9C),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _mostrarDialogoExportarExcel,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // TabBarView: Tab 1 (Habilitados) vs Tab 2 (Pendientes en Compras)
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // TAB 1: ÍTEMS HABILITADOS PARA DESPACHO
                  _buildVistaHabilitados(habilitados),

                  // TAB 2: ÍTEMS PENDIENTES DE VALIDACIÓN EN COMPRAS (BLOQUEADOS)
                  _buildVistaPendientesCompras(pendientes),
                ],
              ),
            ),

            // Barra de Confirmación Inferior
            if (habilitados.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _itemsSeleccionados.isNotEmpty ? _confirmarDespacho : null,
                      icon: const Icon(Icons.check_circle),
                      label: Text(
                        'Confirmar Despacho en Bodega (${_itemsSeleccionados.length} seleccionados)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
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
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVistaHabilitados(List<ItemDespachoBodegaEntity> habilitados) {
    if (habilitados.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_clock_outlined, size: 72, color: Colors.orange.shade300),
              const SizedBox(height: 16),
              const Text(
                'No hay repuestos disponibles para despacho todavía.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                'Para que un repuesto aparezca aquí, Compras debe marcarlo con check en "Validación Bodega" indicando que ya llegó o fue autorizado.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: habilitados.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = habilitados[index];
        final isCompleto = item.despachadoCompletamente;
        final isSelected = _itemsSeleccionados.contains(item.codigo);
        final double aDespachar = _cantidadesADespachar[item.codigo] ?? 0.0;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isCompleto
                  ? Colors.green.shade300
                  : (isSelected ? const Color(0xFF005A9C) : Colors.grey.shade300),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: isSelected,
                      activeColor: const Color(0xFF005A9C),
                      onChanged: isCompleto
                          ? null
                          : (val) {
                              setState(() {
                                if (val == true) {
                                  _itemsSeleccionados.add(item.codigo);
                                } else {
                                  _itemsSeleccionados.remove(item.codigo);
                                }
                              });
                            },
                    ),
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
                          fontSize: 12,
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isCompleto
                            ? const Color(0xFFE8F5E9)
                            : (item.tieneDespachoParcial
                                ? const Color(0xFFFFF3E0)
                                : const Color(0xFFE8F5E9)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isCompleto
                            ? 'COMPLETO'
                            : (item.tieneDespachoParcial ? 'PARCIAL' : 'DISPONIBLE'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isCompleto
                              ? const Color(0xFF2E7D32)
                              : (item.tieneDespachoParcial
                                  ? Colors.orange.shade900
                                  : const Color(0xFF2E7D32)),
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
                      'Solicitado: ${item.cantidadSolicitada} ${item.unidad}',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    Text(
                      'Despachado: ${item.cantidadDespachada} ${item.unidad}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: item.tieneDespachoParcial
                            ? const Color(0xFF2E7D32)
                            : Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      'Faltante: ${item.cantidadFaltante} ${item.unidad}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: item.cantidadFaltante > 0
                            ? Colors.red.shade700
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),

                // Control para seleccionar cantidad a despachar ahora
                if (!isCompleto) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4F8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Despachar en este lote:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF005A9C),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          color: Colors.blueGrey,
                          onPressed: isSelected && aDespachar > 0
                              ? () {
                                  setState(() {
                                    final nv = (aDespachar - 1).clamp(0.0, item.cantidadFaltante);
                                    _cantidadesADespachar[item.codigo] = nv;
                                  });
                                }
                              : null,
                        ),
                        Text(
                          '$aDespachar ${item.unidad}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          color: const Color(0xFF005A9C),
                          onPressed: isSelected && aDespachar < item.cantidadFaltante
                              ? () {
                                  setState(() {
                                    final nv = (aDespachar + 1).clamp(0.0, item.cantidadFaltante);
                                    _cantidadesADespachar[item.codigo] = nv;
                                  });
                                }
                              : null,
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
    );
  }

  Widget _buildVistaPendientesCompras(List<ItemDespachoBodegaEntity> pendientes) {
    if (pendientes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_outlined, size: 64, color: Color(0xFF2E7D32)),
              const SizedBox(height: 16),
              const Text(
                '¡Todos los repuestos han sido validados por Compras!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No hay ítems retenidos ni pendientes de autorización.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: pendientes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = pendientes[index];

        return Card(
          elevation: 0,
          color: const Color(0xFFFAFAFA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.orange.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.codigo,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.descripcion,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Requerido: ${item.cantidadSolicitada} ${item.unidad}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Text(
                    'No Habilitado',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
