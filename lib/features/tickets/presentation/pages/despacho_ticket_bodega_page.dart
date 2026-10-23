import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/entities/item_despacho_bodega_entity.dart';
import '../../domain/entities/registro_despacho_entity.dart';
import '../../domain/services/flujo_venta_repuesto_service.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../services/generador_excel_despacho_bodega.dart';
import '../../../inventario/presentation/bloc/inventario_bloc.dart';
import '../../../inventario/presentation/bloc/inventario_state.dart';
import '../../../inventario/domain/entities/item_inventario_entity.dart';

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

  // Estado para subida de evidencias en modo regularización
  final List<XFile> _fotosRegularizacion = [];
  final ImagePicker _picker = ImagePicker();
  bool _estaSubiendoEvidencias = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _sincronizarItemsConTicket(widget.ticket);
  }

  /// 🛒 Textos de Venta de Repuesto (preparar pedido / guía firmada);
  /// reparación queda igual que antes.
  String _t(TicketEntity t, String reparacion, String venta) =>
      FlujoVentaRepuestoService.esVenta(t) ? venta : reparacion;

  void _sincronizarItemsConTicket(TicketEntity ticket) {
    // 🔍 Sincronización en vivo con el catálogo de inventario en bodega
    final invState = context.read<InventarioBloc>().state;
    final Map<String, ItemInventarioEntity> mapaStock =
        invState is InventarioLoaded ? invState.mapaPorCodigo : {};

    final baseItems = ticket.itemsDespachoBodega.isNotEmpty
        ? ticket.itemsDespachoBodega
        : (ticket.evaluacionTecnica?.repuestosTaller ?? []).map((r) => ItemDespachoBodegaEntity(
            codigo: r.codigo,
            descripcion: r.descripcion,
            unidad: r.unidad,
            cantidadSolicitada: r.cantidad,
            stockDisponibleAlEvaluar: 0.0,
            validadoPorCompras: false,
          )).toList();

    _items = baseItems.map((i) {
      final codKey = i.codigo.trim().toUpperCase();
      final stockItem = mapaStock[codKey];
      final double stockReal = stockItem?.stockDisponible ?? i.stockDisponibleAlEvaluar;
      final bool tieneStock = stockReal > 0;
      return i.copyWith(
        stockDisponibleAlEvaluar:
            stockReal > i.stockDisponibleAlEvaluar ? stockReal : i.stockDisponibleAlEvaluar,
        validadoPorCompras:
            i.validadoPorCompras || tieneStock || ticket.noRequiereCompras,
      );
    }).toList();

    _cantidadesADespachar.clear();
    _itemsSeleccionados.clear();

    // 🛑 ENCLAVAMIENTO: Solo preseleccionar ítems HABILITADOS para despacho
    for (final item in _items) {
      if (item.estaHabilitadoParaDespacho && item.cantidadFaltante > 0) {
        final double maxDespachable = item.validadoPorCompras
            ? item.cantidadFaltante
            : (item.stockDisponibleAlEvaluar - item.cantidadDespachada)
                .clamp(0.0, item.cantidadFaltante);
        if (maxDespachable > 0) {
          _cantidadesADespachar[item.codigo] = maxDespachable;
          _itemsSeleccionados.add(item.codigo);
        }
      }
    }

    // 💾 SINCRONIZACION AUTOMATICA CON INVENTARIO REAL:
    // El bloque de arriba ya recalculo el stock en vivo contra InventarioBloc,
    // pero ese resultado solo vivia en esta pantalla (variable local _items) y
    // se perdia al cerrarla. Si detectamos que el cruce contra inventario real
    // cambio algo respecto a lo que hay guardado en el ticket, lo persistimos
    // en segundo plano para que la lista de Bodega y el resto de pantallas
    // dejen de mostrar estos repuestos como pendientes.
    if (_huboCambiosDeStockReal(ticket.itemsDespachoBodega, _items)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<TicketBloc>().add(
          SincronizarStockDespachoBodegaEvent(
            ticket: ticket,
            itemsActualizados: _items,
          ),
        );
      });
    }
  }

  // Compara los items tal como estan guardados en el ticket contra el
  // recalculo en vivo hecho arriba, para saber si vale la pena escribir
  // en Firestore (evita sincronizaciones innecesarias en cada apertura).
  bool _huboCambiosDeStockReal(
    List<ItemDespachoBodegaEntity> originales,
    List<ItemDespachoBodegaEntity> recalculados,
  ) {
    // 🆕 Primera vez que el ticket llega a Bodega (todavia sin pasar
    // por Compras): no hay nada guardado en el ticket, pero si hay ítems
    // recalculados con stock real que vale la pena persistir -- si no lo
    // hacemos aqui, Despacho depende de que alguien abra el ticket en
    // Compras primero para que itemsDespachoBodega deje de estar vacio.
    if (originales.isEmpty) {
      return recalculados.isNotEmpty;
    }
    final mapaOriginal = {for (final i in originales) i.codigo: i};
    for (final item in recalculados) {
      final original = mapaOriginal[item.codigo];
      if (original == null) continue;
      if (original.stockDisponibleAlEvaluar != item.stockDisponibleAlEvaluar ||
          original.validadoPorCompras != item.validadoPorCompras) {
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<ItemDespachoBodegaEntity> get _itemsHabilitados =>
      _items.where((i) => i.estaHabilitadoParaDespacho).toList();

  List<ItemDespachoBodegaEntity> get _itemsPendientesCompras =>
      _items.where((i) => !i.estaHabilitadoParaDespacho).toList();

  // ===========================================================================
  // 1. DIÁLOGO REUTILIZABLE: "¿ESTÁ SEGURO DE...?"
  // ===========================================================================
  Future<bool?> _mostrarDialogoConfirmacion({
    required BuildContext context,
    required String titulo,
    required String mensaje,
    required String textoConfirmar,
    Color colorConfirmar = const Color(0xFF005A9C),
    IconData icono = Icons.help_outline_rounded,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icono, color: colorConfirmar, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          mensaje,
          style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorConfirmar,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(textoConfirmar, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. EXPORTAR EXCEL: MENÚ DE 2 FORMATOS OFICIALES
  // ===========================================================================
  void _mostrarDialogoExportarExcel(TicketEntity ticket) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
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
                    const SizedBox(width: 10),
                    const Text(
                      'Formatos Oficiales de Bodega',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Seleccione el documento oficial que desea generar en formato Excel:',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 16),

                // Formato 1: Baja ERP
                Material(
                  color: const Color(0xFFF3F7FA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.blue.shade100),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF005A9C),
                      child: Icon(Icons.table_view_outlined, color: Colors.white, size: 20),
                    ),
                    title: const Text(
                      '1. Excel para baja ERP',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Formato tabular para dar de baja en el sistema (CODIGO, DESCRIPCION, CANTIDAD, COSTO U, UNIDAD DE MEDIDA). Contiene solo ítems del lote.',
                      style: TextStyle(fontSize: 12),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final seguro = await _mostrarDialogoConfirmacion(
                        context: context,
                        titulo: '¿Está seguro de descargar el Excel para baja ERP?',
                        mensaje: 'Se generará el archivo con los repuestos seleccionados para descontar del sistema.',
                        textoConfirmar: 'Sí, Descargar Excel',
                        icono: Icons.file_download,
                      );
                      if (seguro == true) {
                        _descargarExcelBajaERP(ticket);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Formato 2: Solicitud de Materiales
                Material(
                  color: const Color(0xFFF1F8F4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.green.shade100),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF2E7D32),
                      child: Icon(Icons.assignment_outlined, color: Colors.white, size: 20),
                    ),
                    title: const Text(
                      '2. Solicitud de materiales',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Formato formal completo con cabecera oficial, centro de costos, serie, proyecto, diferenciador entre requeridos y faltantes, y firmas.',
                      style: TextStyle(fontSize: 12),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final seguro = await _mostrarDialogoConfirmacion(
                        context: context,
                        titulo: '¿Está seguro de descargar la Solicitud de Materiales?',
                        mensaje: 'Se generará el formato formal con todos los repuestos y líneas de firma.',
                        textoConfirmar: 'Sí, Descargar Solicitud',
                        colorConfirmar: const Color(0xFF2E7D32),
                        icono: Icons.assignment,
                      );
                      if (seguro == true) {
                        _descargarExcelSolicitudMateriales(ticket);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Formato 3: Solicitud de materiales COMPLETA (todo el ticket)
                Material(
                  color: const Color(0xFFFFF3E0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.orange.shade100),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE65100),
                      child: Icon(Icons.list_alt, color: Colors.white, size: 20),
                    ),
                    title: const Text(
                      '3. Solicitud de materiales (completo)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Incluye TODOS los repuestos del ticket: los ya entregados en cualquier despacho y los que aun faltan por completo.',
                      style: TextStyle(fontSize: 12),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final seguro = await _mostrarDialogoConfirmacion(
                        context: context,
                        titulo: '¿Esta seguro de descargar la Solicitud de Materiales completa?',
                        mensaje: 'Se generara el listado completo del ticket, con todos los repuestos entregados y pendientes hasta la fecha.',
                        textoConfirmar: 'Si, Descargar Completo',
                        colorConfirmar: const Color(0xFFE65100),
                        icono: Icons.list_alt,
                      );
                      if (seguro == true) {
                        final fuenteItems = ticket.itemsDespachoBodega.isNotEmpty ? ticket.itemsDespachoBodega : _items;
                        final mapAcumulado = {for (final it in fuenteItems) it.codigo: it.cantidadDespachada};
                        _descargarExcelSolicitudMateriales(
                          ticket,
                          items: fuenteItems,
                          cantidadesDespachadasLote: mapAcumulado,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 3. DESCARGA DIRECTA DE AMBOS ARCHIVOS
  // ===========================================================================
  Future<void> _descargarExcelBajaERP(
    TicketEntity ticket, {
    List<DetalleItemDespachadoEntity>? itemsDespachados,
    Map<String, double>? cantidades,
    String? codigoDespacho,
  }) async {
    final bytes = GeneradorExcelDespachoBodega.generarExcelBajaERP(
      ticket: ticket,
      itemsDespachados: itemsDespachados,
      items: _items,
      cantidadesSeleccionadas: cantidades ?? _cantidadesADespachar,
    );

    final sufijo = codigoDespacho ?? 'DESP-${(ticket.historialDespachos.length + 1).toString().padLeft(2, '0')}';
    final fileName = 'baja_erp_${ticket.id}_$sufijo.xlsx';
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  Future<void> _descargarExcelSolicitudMateriales(
    TicketEntity ticket, {
    List<ItemDespachoBodegaEntity>? items,
    Map<String, double>? cantidadesDespachadasLote,
    String? codigoDespacho,
  }) async {
    final authState = context.read<AuthBloc>().state;
    String nombre = 'BODEGA CENTRAL';
    if (authState is Authenticated) {
      nombre = authState.usuario.nombre;
    }

    // 🎯 Por defecto (sin 'items' explicito) la hoja solo incluye lo
    // que esta seleccionado para despachar en este momento -- no todo el
    // ticket ni lo ya entregado en lotes anteriores. Quien llama puede
    // pasar su propio 'items' para otro alcance (reimpresion de un lote
    // pasado, o la descarga completa del ticket).
    final itemsParaHoja = items ??
        _items.where((i) => _itemsSeleccionados.contains(i.codigo)).toList();

    final bytes = GeneradorExcelDespachoBodega.generarExcelSolicitudMateriales(
      ticket: ticket,
      items: itemsParaHoja,
      cantidadesDespachadasLote: cantidadesDespachadasLote ?? _cantidadesADespachar,
      nombreBodeguero: nombre,
    );

    final sufijo = codigoDespacho ?? 'DESP-${(ticket.historialDespachos.length + 1).toString().padLeft(2, '0')}';
    final fileName = 'solicitud_materiales_${ticket.id}_$sufijo.xlsx';
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  // ===========================================================================
  // 4. CONFIRMAR DESPACHO CON GENERACIÓN INMEDIATA Y VENTANA DE FOTOS
  // ===========================================================================
  Future<void> _confirmarDespacho(TicketEntity ticket) async {
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
      if (!item.estaHabilitadoParaDespacho) {
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
        SnackBar(
          content: Text(_t(ticket, 'Seleccione al menos un repuesto con cantidad mayor a 0 para el picking',
              'Seleccione al menos un repuesto con cantidad mayor a 0 para preparar el pedido')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 🔢 CÓDIGO CONSECUTIVO DEL PICKING (los anteriores conservan "DESP").
    final int correlativo = ticket.historialDespachos.length + 1;
    final codigoDespacho = '${ticket.id}-PICK-${correlativo.toString().padLeft(2, '0')}';

    // 🛑 DIÁLOGO DE SEGURIDAD CRÍTICO: "¿Está seguro de...?"
    final confirmado = await _mostrarDialogoConfirmacion(
      context: context,
      titulo: _t(ticket, '¿Confirmar picking listo para retiro?', '¿Confirmar preparación del pedido?'),
      mensaje: FlujoVentaRepuestoService.esVenta(ticket)
          ? 'Se confirmará que ${detalles.length} repuesto(s) están preparados para el cliente.\n\n'
              '1. Se registrará la preparación ($codigoDespacho).\n'
              '2. Se descargarán inmediatamente los dos Excels (Baja ERP y Solicitud de Materiales).\n'
              '3. Cuando todo esté preparado, pulse "Pasar a entrega" en la bandeja.\n'
              '4. La guía firmada se sube al final, ya en Entrega.'
          : 'Se confirmará que ${detalles.length} repuesto(s) están recolectados y listos para retiro.\n\n'
              '1. Se registrará el picking parcial ($codigoDespacho).\n'
              '2. Se descargarán inmediatamente los dos Excels (Baja ERP y Solicitud de Materiales).\n'
              '3. Deberá subir obligatoriamente las fotos de evidencia (repuestos y documento de baja del ERP).\n'
              '4. Se notificará a Proceso de Trabajo que puede enviar a retirar los repuestos.',
      textoConfirmar: _t(ticket, 'Sí, confirmar picking y descargar', 'Sí, confirmar preparación y descargar'),
      colorConfirmar: const Color(0xFF2E7D32),
      icono: Icons.check_circle_outline,
    );

    if (confirmado != true) return;

    final nuevoRegistro = RegistroDespachoEntity(
      id: codigoDespacho,
      fecha: DateTime.now(),
      usuarioNombre: nombre,
      usuarioId: uid,
      items: detalles,
      fotosEvidenciasUrls: const [], // Inicialmente vacío -> requerirá fotos
    );

    // 1. GENERACIÓN INMEDIATA Y DESCARGA DE AMBOS ARCHIVOS EXCEL
    try {
      await _descargarExcelBajaERP(ticket, itemsDespachados: detalles, codigoDespacho: codigoDespacho);
      await _descargarExcelSolicitudMateriales(
        ticket,
        items: _items.where((i) => _itemsSeleccionados.contains(i.codigo)).toList(),
        cantidadesDespachadasLote: _cantidadesADespachar,
        codigoDespacho: codigoDespacho,
      );
    } catch (e) {
      debugPrint('Advertencia al descargar Excels: $e');
    }

    // 2. REGISTRO EN BASE DE DATOS
    if (!mounted) return;
    context.read<TicketBloc>().add(
          RegistrarDespachoBodegaEvent(
            ticket: ticket,
            itemsActualizados: itemsActualizados,
            nuevoRegistro: nuevoRegistro,
            nombreUsuario: nombre,
            rolUsuario: rol,
          ),
        );

    // 3. APERTURA AUTOMÁTICA DEL MODAL PARA SUBIR MÚLTIPLES EVIDENCIAS
    // 🛒 Venta: la evidencia (guía firmada) se sube al final, ya en Entrega.
    // Se cierra la ventana (como en reparación tras las fotos) para que la
    // lista de repuestos no quede desactualizada y no se repita la preparación.
    if (!FlujoVentaRepuestoService.esVenta(ticket)) {
      _mostrarModalSubirEvidencias(ticket, nuevoRegistro, itemsActualizados);
    } else if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Preparación registrada. Cuando todo esté preparado, pulse "Pasar a entrega".'),
          backgroundColor: Color(0xFF2E7D32),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // ===========================================================================
  // 5. VENTANA EMERGENTE PARA MÚLTIPLES EVIDENCIAS DE DESPACHO
  // ===========================================================================
  void _mostrarModalSubirEvidencias(
    TicketEntity ticket,
    RegistroDespachoEntity despacho,
    List<ItemDespachoBodegaEntity> itemsActualizados,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ModalCargaEvidencias(
        ticket: ticket,
        despacho: despacho,
        itemsActualizados: itemsActualizados,
        onConfirmarCierreSinFotos: () {
          Navigator.pop(ctx);
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '⚠️ Picking registrado. Quedó BLOQUEADO hasta adjuntar las fotos de evidencia.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
        },
        onCompletado: () {
          Navigator.pop(ctx);
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Picking listo para retiro. Se notificó a Proceso de Trabajo.'),
                backgroundColor: Color(0xFF2E7D32),
                duration: Duration(seconds: 3),
              ),
            );
          }
        },
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
          // Si el ticket ya no tiene repuestos pendientes y no tiene evidencia pendiente, salir
          if (state.currentTicket != null &&
              state.currentTicket!.bodegaDespachoCompleto &&
              !state.currentTicket!.tieneDespachoPendienteDeEvidencia) {
            Navigator.pop(context);
          }
        } else if (state.status == TicketStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${state.message}'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
      builder: (context, state) {
        // Obtenemos el ticket más reciente del estado o el provisto por widget
        final currentTicket = state.currentTicket?.id == widget.ticket.id
            ? state.currentTicket!
            : (state.historial.where((t) => t.id == widget.ticket.id).firstOrNull ??
                widget.ticket);

        // 🛑 ENCLAVAMIENTO BLOQUEANTE:
        // Si hay algún despacho pendiente de regularizar fotos de evidencia,
        // la pantalla se bloquea exclusivamente en el Modo Regularización.
        if (currentTicket.tieneDespachoPendienteDeEvidencia &&
            (!FlujoVentaRepuestoService.esVenta(currentTicket) ||
                currentTicket.estadoActual == EstadoTicket.entrega)) {
          return _buildPantallaRegularizacionEvidencias(
            currentTicket,
            currentTicket.despachoPendienteDeEvidencia!,
          );
        }

        // Pantalla normal de Despacho
        final habilitados = _itemsHabilitados;
        final pendientes = _itemsPendientesCompras;
        final historial = currentTicket.historialDespachos;

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6F9),
          appBar: AppBar(
            title: Text(
              '${_t(currentTicket, 'Picking', 'Preparación de pedido')}: ${currentTicket.id}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            backgroundColor: const Color(0xFF005A9C),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.file_download_outlined),
                tooltip: 'Exportar Formatos de Despacho',
                onPressed: () => _mostrarDialogoExportarExcel(currentTicket),
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
                  text: 'Pendientes (${pendientes.length})',
                ),
                Tab(
                  icon: const Icon(Icons.history, size: 18),
                  text: '${_t(currentTicket, 'Pickings realizados', 'Preparaciones realizadas')} (${historial.length})',
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              // Cabecera Resumen
              Container(
                padding: const EdgeInsets.all(14),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Equipo: ${currentTicket.equipo.name.toUpperCase()} • ${currentTicket.marca.toUpperCase()} (Serie: ${currentTicket.numeroSerie ?? "S/N"})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Proyecto: ${currentTicket.codigoProyecto ?? (currentTicket.campamento.isNotEmpty ? currentTicket.campamento : "SIN PROYECTO")}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Excels', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF005A9C),
                        side: const BorderSide(color: Color(0xFF005A9C)),
                      ),
                      onPressed: () => _mostrarDialogoExportarExcel(currentTicket),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // TabBarView: Habilitados, Pendientes Compras, Historial
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildVistaHabilitados(habilitados, currentTicket),
                    _buildVistaPendientesCompras(pendientes),
                    _buildVistaHistorialDespachos(currentTicket),
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
                        onPressed: _itemsSeleccionados.isNotEmpty
                            ? () => _confirmarDespacho(currentTicket)
                            : null,
                        icon: const Icon(Icons.check_circle),
                        label: Text(
                          '${_t(currentTicket, 'Confirmar picking listo', 'Confirmar preparación')} (${_itemsSeleccionados.length} repuestos)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
        );
      },
    );
  }

  // ===========================================================================
  // 6. VISTA BLOQUEANTE: REGULARIZACIÓN OBLIGATORIA DE EVIDENCIA PENDIENTE
  // ===========================================================================
  Widget _buildPantallaRegularizacionEvidencias(
    TicketEntity ticket,
    RegistroDespachoEntity despacho,
  ) {
    final fechaStr =
        '${despacho.fecha.day.toString().padLeft(2, '0')}/${despacho.fecha.month.toString().padLeft(2, '0')}/${despacho.fecha.year} ${despacho.fecha.hour.toString().padLeft(2, '0')}:${despacho.fecha.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFFFBF6EE),
      appBar: AppBar(
        title: Text(
          '${_t(ticket, '⚠️ Evidencia Pendiente', '📝 Guía firmada pendiente')}: ${ticket.id}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Alerta Informativa
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade300, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade900, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _t(ticket, 'PICKING CON EVIDENCIA PENDIENTE', 'SUBA LA GUÍA FIRMADA PARA FINALIZAR'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t(
                      ticket,
                      'El picking ${despacho.id} realizado el $fechaStr por ${despacho.usuarioNombre} no tiene fotos de evidencia.\n\n'
                          'Para registrar otro picking, primero adjunte las fotos (repuestos alistados y documento físico generado por el ERP).',
                      'Los repuestos de ${despacho.id} (preparados el $fechaStr por ${despacho.usuarioNombre}) ya se entregaron.\n\n'
                          'Adjunte la guía de remisión FIRMADA por el cliente. Es el último paso: con la guía y la factura '
                          'registradas en Entregas, el requerimiento pasa a Finalizado.',
                    ),
                    style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Resumen de repuestos del despacho pendiente
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Repuestos del picking (${despacho.items.length}):',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        // Botones para re-descargar los Excels si necesita imprimir
                        Row(
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.download, size: 14),
                              label: const Text('Baja ERP', style: TextStyle(fontSize: 11)),
                              onPressed: () => _descargarExcelBajaERP(ticket, itemsDespachados: despacho.items),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.assignment, size: 14),
                              label: const Text('Solicitud', style: TextStyle(fontSize: 11)),
                              onPressed: () {
                                final fuenteItems = ticket.itemsDespachoBodega.isNotEmpty ? ticket.itemsDespachoBodega : _items;
                                final codigosLote = despacho.items.map((it) => it.codigo).toSet();
                                final itemsLote = fuenteItems.where((i) => codigosLote.contains(i.codigo)).toList();
                                final mapCant = {for (final it in despacho.items) it.codigo: it.cantidad};
                                _descargarExcelSolicitudMateriales(
                                  ticket,
                                  items: itemsLote,
                                  cantidadesDespachadasLote: mapCant,
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 10),
                    ...despacho.items.map((it) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE3F2FD),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  it.codigo,
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
                                  it.descripcion,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Text(
                                '${it.cantidad} ${it.unidad}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Selector de Múltiples Fotos de Evidencia
            const Text(
              'Adjuntar Fotos de Soporte (Múltiple):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'Tome o seleccione varias fotos: una de los repuestos alistados en mesón y otra del vale o documento impreso del ERP.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Tomar Foto'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF005A9C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      final foto = await _picker.pickImage(
                        source: ImageSource.camera,
                        imageQuality: 80,
                      );
                      if (foto != null) {
                        setState(() {
                          _fotosRegularizacion.add(foto);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galería / Archivos'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF005A9C),
                      side: const BorderSide(color: Color(0xFF005A9C)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      final fotos = await _picker.pickMultiImage(imageQuality: 80);
                      if (fotos.isNotEmpty) {
                        setState(() {
                          _fotosRegularizacion.addAll(fotos);
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Mosaico de Miniaturas de Fotos Seleccionadas
            if (_fotosRegularizacion.isNotEmpty) ...[
              Text(
                'Fotos seleccionadas (${_fotosRegularizacion.length}):',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _fotosRegularizacion.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final file = entry.value;
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 90,
                          height: 90,
                          color: Colors.grey.shade200,
                          child: kIsWeb
                              ? Image.network(file.path, fit: BoxFit.cover)
                              : Image.file(File(file.path), fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () async {
                            final seguro = await _mostrarDialogoConfirmacion(
                              context: context,
                              titulo: '¿Eliminar foto?',
                              mensaje: '¿Está seguro de remover esta imagen seleccionada?',
                              textoConfirmar: 'Sí, Eliminar',
                              colorConfirmar: Colors.red,
                              icono: Icons.delete_outline,
                            );
                            if (seguro == true) {
                              setState(() {
                                _fotosRegularizacion.removeAt(idx);
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Botón de Envío y Regularización
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_fotosRegularizacion.isNotEmpty && !_estaSubiendoEvidencias)
                    ? () async {
                        final authState = context.read<AuthBloc>().state;
                        final ticketBloc = context.read<TicketBloc>();
                        final seguro = await _mostrarDialogoConfirmacion(
                          context: context,
                          titulo: _t(ticket, '¿Está seguro de guardar las evidencias?', '¿Guardar la guía firmada?'),
                          mensaje: _t(
                            ticket,
                            'Se vincularán ${_fotosRegularizacion.length} foto(s) al picking ${despacho.id}; quedará listo para retiro y podrá registrar otro picking.',
                            'Se vincularán ${_fotosRegularizacion.length} archivo(s) de la guía firmada a ${despacho.id}.',
                          ),
                          textoConfirmar: _t(ticket, 'Sí, Guardar Evidencias', 'Sí, guardar guía firmada'),
                          colorConfirmar: const Color(0xFF2E7D32),
                          icono: Icons.cloud_upload_outlined,
                        );
                        if (seguro == true) {
                          if (!mounted) return;
                          setState(() => _estaSubiendoEvidencias = true);
                          String nombre = 'BODEGA';
                          String rol = 'BODEGA';
                          if (authState is Authenticated) {
                            nombre = authState.usuario.nombre;
                            rol = authState.usuario.rol.name.toUpperCase();
                          }

                          ticketBloc.add(
                            ActualizarEvidenciasDespachoEvent(
                              ticket: ticket,
                              despachoId: despacho.id,
                              fotosEvidencias: List.from(_fotosRegularizacion),
                              nombreUsuario: nombre,
                              rolUsuario: rol,
                            ),
                          );
                          _fotosRegularizacion.clear();
                          setState(() => _estaSubiendoEvidencias = false);
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_t(ticket, '✅ Evidencia guardada. Picking listo para retiro.',
                                    '✅ Guía firmada guardada.')),
                                backgroundColor: const Color(0xFF2E7D32),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        }
                      }
                    : null,
                icon: _estaSubiendoEvidencias
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _estaSubiendoEvidencias
                      ? 'Subiendo fotos a almacenamiento seguro...'
                      : _t(ticket, 'Guardar evidencia del picking (${_fotosRegularizacion.length} fotos)',
                          'Guardar guía firmada (${_fotosRegularizacion.length})'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 7. VISTA TAB 1: ÍTEMS HABILITADOS
  // ===========================================================================
  Widget _buildVistaHabilitados(
    List<ItemDespachoBodegaEntity> habilitados,
    TicketEntity ticket,
  ) {
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
                'No hay repuestos disponibles para picking todavía.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                'Los repuestos aparecen aquí cuando cuentan con stock suficiente en bodega o han sido validados por Compras.',
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

                // Control dinámico de cantidades para el lote
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
                          'Recolectar en este picking:',
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
                          onPressed: (isSelected &&
                                  aDespachar <
                                      (item.validadoPorCompras
                                          ? item.cantidadFaltante
                                          : (item.stockDisponibleAlEvaluar - item.cantidadDespachada)
                                              .clamp(0.0, item.cantidadFaltante)))
                              ? () {
                                  final double maxDesp = item.validadoPorCompras
                                      ? item.cantidadFaltante
                                      : (item.stockDisponibleAlEvaluar - item.cantidadDespachada)
                                          .clamp(0.0, item.cantidadFaltante);
                                  setState(() {
                                    final nv = (aDespachar + 1).clamp(0.0, maxDesp);
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

  // ===========================================================================
  // 8. VISTA TAB 2: PENDIENTES DE VALIDACIÓN EN COMPRAS
  // ===========================================================================
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
                    'Pendiente Compras',
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

  // ===========================================================================
  // 9. VISTA TAB 3: HISTORIAL DE DESPACHOS CON MINIATURAS Y RE-DESCARGA
  // ===========================================================================
  Widget _buildVistaHistorialDespachos(TicketEntity ticket) {
    final historial = ticket.historialDespachos.reversed.toList();

    if (historial.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'Aún no hay pickings registrados para este requerimiento.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                'Cada picking confirmado queda aquí con sus Excels y fotos.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: historial.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final reg = historial[index];
        final fechaStr =
            '${reg.fecha.day.toString().padLeft(2, '0')}/${reg.fecha.month.toString().padLeft(2, '0')}/${reg.fecha.year} ${reg.fecha.hour.toString().padLeft(2, '0')}:${reg.fecha.minute.toString().padLeft(2, '0')}';

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      reg.id,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: reg.tieneEvidencia ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        reg.tieneEvidencia
                            ? _t(ticket, '✅ Con Evidencias (${reg.fotosEvidenciasUrls.length})',
                                '✅ Guía firmada (${reg.fotosEvidenciasUrls.length})')
                            : _t(ticket, '⚠️ Evidencia Pendiente', '⏳ Guía firmada pendiente'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: reg.tieneEvidencia ? const Color(0xFF2E7D32) : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Fecha: $fechaStr • Bodeguero: ${reg.usuarioNombre}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Divider(height: 14),

                // Lista de ítems del despacho
                ...reg.items.map((it) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text('• ${it.codigo}: ',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Expanded(
                              child: Text(it.descripcion,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis)),
                          Text('${it.cantidad} ${it.unidad}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ),
                    )),

                // Galería de Miniaturas de Evidencias Subidas
                if (reg.fotosEvidenciasUrls.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Fotos de Respaldo:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: reg.fotosEvidenciasUrls.map((url) {
                      return GestureDetector(
                        onTap: () => _mostrarFotoAmpliada(context, url),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.shade200,
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 24),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 12),

                // Botones para re-descargar ambos archivos Excel de ese despacho
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.table_view_outlined, size: 14),
                      label: const Text('Baja ERP', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF005A9C),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: () => _descargarExcelBajaERP(ticket, itemsDespachados: reg.items),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.assignment_outlined, size: 14),
                      label: const Text('Solicitud', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: () {
                        final fuenteItems = ticket.itemsDespachoBodega.isNotEmpty ? ticket.itemsDespachoBodega : _items;
                        final codigosLote = reg.items.map((it) => it.codigo).toSet();
                        final itemsLote = fuenteItems.where((i) => codigosLote.contains(i.codigo)).toList();
                        final mapCant = {for (var it in reg.items) it.codigo: it.cantidad};
                        _descargarExcelSolicitudMateriales(
                          ticket,
                          items: itemsLote,
                          cantidadesDespachadasLote: mapCant,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _mostrarFotoAmpliada(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// MODAL BOTTOM SHEET: SUBIDA DE MÚLTIPLES EVIDENCIAS INMEDIATA TRAS DESPACHO
// ===========================================================================
class _ModalCargaEvidencias extends StatefulWidget {
  final TicketEntity ticket;
  final RegistroDespachoEntity despacho;
  final List<ItemDespachoBodegaEntity> itemsActualizados;
  final VoidCallback onConfirmarCierreSinFotos;
  final VoidCallback onCompletado;

  const _ModalCargaEvidencias({
    required this.ticket,
    required this.despacho,
    required this.itemsActualizados,
    required this.onConfirmarCierreSinFotos,
    required this.onCompletado,
  });

  @override
  State<_ModalCargaEvidencias> createState() => _ModalCargaEvidenciasState();
}

class _ModalCargaEvidenciasState extends State<_ModalCargaEvidencias> {
  final List<XFile> _fotos = [];
  final ImagePicker _picker = ImagePicker();
  bool _subiendo = false;

  Future<void> _cerrarConAdvertencia() async {
    final seguro = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '¿Posponer subida de evidencias?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          '⚠️ El picking quedará registrado pero BLOQUEADO.\n\n'
          'No podrá registrar otro picking de este ticket hasta adjuntar las fotos de evidencia.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuar Subiendo Fotos'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, Posponer Bloqueando Ticket'),
          ),
        ],
      ),
    );

    if (seguro == true) {
      widget.onConfirmarCierreSinFotos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _cerrarConAdvertencia();
        }
      },
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.camera_alt_outlined, color: Color(0xFF005A9C), size: 26),
                        SizedBox(width: 8),
                        Text(
                          'Fotos de Evidencia Requeridas',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _cerrarConAdvertencia,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'El picking fue registrado y los Excels generados. Adjunte las fotos: repuestos alistados en mesón y documento/vale emitido por el ERP.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 16),

                // Botones para agregar fotos
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Tomar Foto'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF005A9C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final foto = await _picker.pickImage(
                            source: ImageSource.camera,
                            imageQuality: 80,
                          );
                          if (foto != null) {
                            setState(() => _fotos.add(foto));
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Galería'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF005A9C),
                          side: const BorderSide(color: Color(0xFF005A9C)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final fotos = await _picker.pickMultiImage(imageQuality: 80);
                          if (fotos.isNotEmpty) {
                            setState(() => _fotos.addAll(fotos));
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Lista de fotos seleccionadas
                if (_fotos.isNotEmpty) ...[
                  Text(
                    'Fotos agregadas (${_fotos.length}):',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _fotos.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final file = entry.value;
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey.shade200,
                              child: kIsWeb
                                  ? Image.network(file.path, fit: BoxFit.cover)
                                  : Image.file(File(file.path), fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _fotos.removeAt(idx));
                              },
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Botón Guardar Evidencias
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_fotos.isNotEmpty && !_subiendo)
                        ? () async {
                            final authState = context.read<AuthBloc>().state;
                            final ticketBloc = context.read<TicketBloc>();
                            final seguro = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: const Text('¿Guardar Evidencias?',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                content: Text(
                                  'Se subirán ${_fotos.length} foto(s) de evidencia para el picking ${widget.despacho.id}.',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2E7D32),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Sí, Guardar'),
                                  ),
                                ],
                              ),
                            );

                            if (seguro == true) {
                              if (!mounted) return;
                              setState(() => _subiendo = true);
                              String nombre = 'BODEGA';
                              String rol = 'BODEGA';
                              if (authState is Authenticated) {
                                nombre = authState.usuario.nombre;
                                rol = authState.usuario.rol.name.toUpperCase();
                              }

                              final ticketConDespacho = widget.ticket.copyWith(
                                itemsDespachoBodega: widget.itemsActualizados,
                                historialDespachos: [
                                  ...widget.ticket.historialDespachos
                                      .where((d) => d.id != widget.despacho.id),
                                  widget.despacho,
                                ],
                              );

                              ticketBloc.add(
                                ActualizarEvidenciasDespachoEvent(
                                  ticket: ticketConDespacho,
                                  despachoId: widget.despacho.id,
                                  fotosEvidencias: List.from(_fotos),
                                  nombreUsuario: nombre,
                                  rolUsuario: rol,
                                ),
                              );

                              widget.onCompletado();
                            }
                          }
                        : null,
                    icon: _subiendo
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _subiendo
                          ? 'Subiendo fotos...'
                          : 'Guardar evidencia del picking (${_fotos.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

