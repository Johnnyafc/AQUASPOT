import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../../../../core/enum/segmento_operativo.dart';
import '../../domain/entities/evaluacion_tecnica_entity.dart';
import '../widgets/copy_icon_button_widget.dart';
import '../widgets/tarjeta_no_requiere_compras_widget.dart';
import '../../domain/entities/repuesto_registrado_entity.dart';
import '../../domain/entities/cambio_material_entity.dart';
import '../../domain/entities/linea_repuesto_venta_entity.dart';
import '../../domain/services/edicion_venta_comercial_service.dart';
import '../../../inventario/domain/entities/item_inventario_entity.dart';
import '../../../inventario/presentation/bloc/inventario_bloc.dart';
import '../../../inventario/presentation/bloc/inventario_state.dart';
import '../widgets/cambios_materiales_widget.dart';
import '../../../catalogo/domain/entities/item_catalogo_entity.dart';
import '../../../catalogo/presentation/bloc/catalogo_bloc.dart';
import '../../../catalogo/presentation/bloc/catalogo_event.dart';
import '../../../catalogo/presentation/bloc/catalogo_state.dart';

class GenerarCotizacionPage extends StatefulWidget {
  final TicketEntity ticket;
  const GenerarCotizacionPage({super.key, required this.ticket});

  @override
  State<GenerarCotizacionPage> createState() => _GenerarCotizacionPageState();
}

class _GenerarCotizacionPageState extends State<GenerarCotizacionPage> {
  final TextEditingController _observacionController = TextEditingController();
  final List<fp.PlatformFile> _pdfsSeleccionados = [];
  final List<fp.PlatformFile> _excelsSeleccionados = [];

  // 💼 ESTADO DINÁMICO DE LA PROPUESTA COMERCIAL Y MATERIALES DE TALLER
  late List<RepuestoRegistradoEntity> _repuestosComerciales;
  late List<RepuestoRegistradoEntity> _repuestosTaller;
  // 🧾 Copias de las dos listas en el último guardado: de ahí salen los
  // "Cambios de materiales" (registro aparte de la auditoría).
  late List<RepuestoRegistradoEntity> _repuestosTallerOriginal;
  late List<RepuestoRegistradoEntity> _repuestosComercialesOriginal;
  // Copias al abrir la pantalla: total de cambios para el único evento de
  // auditoría cuando el ticket regresó a Comercial.
  late final List<RepuestoRegistradoEntity> _tallerAlAbrir;
  late final List<RepuestoRegistradoEntity> _comercialAlAbrir;
  double? _totalHorasHombre;
  bool _propuestaModificada = false;

  // 🛒 Venta de Repuesto: lista editable por Comercial (agregar, quitar,
  // cambiar cantidad). Se guarda con "Guardar cambios" antes de finalizar.
  late List<LineaRepuestoVentaEntity> _lineasVenta;
  bool _ventaModificada = false;
  bool _guardandoVenta = false;

  bool get _esCaracol => widget.ticket.equipo == TipoEquipo.Caracol;

  /// 💲 Tarifa por hora hombre para el costo de mano de obra (USD).
  static const int _tarifaHoraHombre = 25;

  // Candado de etapa: SOLO aplica a Caracol. Cualquier otro equipo se
  // comporta exactamente igual que antes (siempre editable en esta pantalla).
  bool get _puedeEditarRequerimiento =>
      !_esCaracol ||
      widget.ticket.estadoActual == EstadoTicket.comercial ||
      widget.ticket.estadoActual == EstadoTicket.cotizado;

  @override
  void initState() {
    super.initState();
    final evaluacion = widget.ticket.evaluacionTecnica;
    _repuestosComerciales = evaluacion != null
        ? List<RepuestoRegistradoEntity>.from(evaluacion.repuestosComercial)
        : [];
    _repuestosTaller = evaluacion != null
        ? List<RepuestoRegistradoEntity>.from(evaluacion.repuestosTaller)
        : [];
    _repuestosTallerOriginal = List<RepuestoRegistradoEntity>.from(_repuestosTaller);
    _repuestosComercialesOriginal = List<RepuestoRegistradoEntity>.from(_repuestosComerciales);
    _tallerAlAbrir = List<RepuestoRegistradoEntity>.unmodifiable(_repuestosTaller);
    _comercialAlAbrir = List<RepuestoRegistradoEntity>.unmodifiable(_repuestosComerciales);
    _totalHorasHombre = evaluacion?.totalHorasHombre ??
        evaluacion?.actividades.fold<double>(0.0, (acc, a) => acc + a.horasHombre);
    _lineasVenta = List<LineaRepuestoVentaEntity>.from(widget.ticket.lineasRepuestoVenta);

    // Precargar catálogo del equipo correspondiente para autocompletado rápido
    final equipoStr = widget.ticket.equipo.name.toLowerCase();
    context.read<CatalogoBloc>().add(CargarCatalogoPorEquipoEvent(equipoStr));
  }

  // ⚙️ SUBRUTINA: Extracción de la justificación de auditoría
  String _obtenerMotivoModificacion() {
    try {
      final eventoReversion = widget.ticket.historialEventos.lastWhere(
        (e) => e.accion.startsWith('SOLICITUD DE MODIFICACIÓN:'),
      );
      return eventoReversion.accion.replaceAll('SOLICITUD DE MODIFICACIÓN:', '').trim();
    } catch (e) {
      return 'Motivo no registrado en la traza de auditoría.';
    }
  }

  // ⚙️ SUBRUTINA DE APERTURA DE ARCHIVOS TÉCNICOS
  Future<void> _abrirEnlaceTecnico(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Circuito bloqueado por el SO.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al abrir el documento técnico.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _seleccionarPDFs() async {
    final result = await fp.FilePicker.pickFiles(
      allowMultiple: true, 
      type: fp.FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true, 
    );
    if (result != null) {
      setState(() {
        _pdfsSeleccionados.addAll(result.files);
      });
    }
  }

  Future<void> _seleccionarExcels() async {
    final result = await fp.FilePicker.pickFiles(
      allowMultiple: true, 
      type: fp.FileType.custom,
      allowedExtensions: ['xls', 'xlsx'],
      withData: true,
    );
    if (result != null) {
      setState(() {
        _excelsSeleccionados.addAll(result.files);
      });
    }
  }

  void _eliminarArchivo(List<fp.PlatformFile> lista, fp.PlatformFile archivo) {
    setState(() {
      lista.remove(archivo);
    });
  }

  // 🏭 SUBRUTINAS DE GESTIÓN DE MATERIALES DE TALLER / BODEGA
  void _incrementarCantidadTaller(int index) {
    if (!_puedeEditarRequerimiento) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este requerimiento ya no se puede editar: el ticket avanzó más allá de comercial.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() {
      final rep = _repuestosTaller[index];
      _repuestosTaller[index] = rep.copyWith(cantidad: rep.cantidad + 1);
      _propuestaModificada = true;
    });
  }

  void _decrementarCantidadTaller(int index) {
    if (!_puedeEditarRequerimiento) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este requerimiento ya no se puede editar: el ticket avanzó más allá de comercial.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final rep = _repuestosTaller[index];
    if (rep.cantidad > 1) {
      setState(() {
        _repuestosTaller[index] = rep.copyWith(cantidad: rep.cantidad - 1);
        _propuestaModificada = true;
      });
    } else {
      _confirmarEliminarRepuestoTaller(index);
    }
  }

  void _confirmarEliminarRepuestoTaller(int index) {
    if (!_puedeEditarRequerimiento) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este requerimiento ya no se puede editar: el ticket avanzó más allá de comercial.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final item = _repuestosTaller[index];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar material de taller?'),
        content: Text('¿Desea retirar "${item.descripcion}" de los materiales internos de taller/bodega?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _repuestosTaller.removeAt(index);
                _propuestaModificada = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Eliminado de taller: ${item.descripcion}'),
                  action: SnackBarAction(
                    label: 'Deshacer',
                    onPressed: () {
                      setState(() {
                        _repuestosTaller.insert(index, item);
                      });
                    },
                  ),
                ),
              );
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoEditarCantidadTaller(int index) {
    if (!_puedeEditarRequerimiento) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este requerimiento ya no se puede editar: el ticket avanzó más allá de comercial.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final rep = _repuestosTaller[index];
    final cantActual = (rep.cantidad % 1 == 0) ? rep.cantidad.toInt().toString() : rep.cantidad.toString();
    final controller = TextEditingController(text: cantActual);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar Cantidad (Taller): ${rep.descripcion}', style: const TextStyle(fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Código: ${rep.codigo.isNotEmpty ? rep.codigo : "S/C"} | Unidad: ${rep.unidad}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Cantidad requerida para taller',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.warehouse_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
            onPressed: () {
              final val = double.tryParse(controller.text.trim().replaceAll(',', '.'));
              if (val == null || val <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingrese una cantidad válida mayor a 0.'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(ctx);
              setState(() {
                _repuestosTaller[index] = rep.copyWith(cantidad: val);
                _propuestaModificada = true;
              });
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoAgregarRepuestoTaller() {
    if (!_puedeEditarRequerimiento) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este requerimiento ya no se puede editar: el ticket avanzó más allá de comercial.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final itemsCatalogo = _obtenerItemsCatalogo();
    showDialog(
      context: context,
      builder: (ctx) => _DialogoAgregarRepuesto(
        titulo: 'Añadir Material de Taller / Bodega',
        icono: Icons.warehouse_outlined,
        colorPrimario: Colors.blueGrey.shade800,
        catalogoItems: itemsCatalogo,
        onAgregar: (nuevoRepuesto) {
          setState(() {
            _repuestosTaller.add(nuevoRepuesto);
            _propuestaModificada = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Material de taller agregado: ${nuevoRepuesto.descripcion}'),
              backgroundColor: Colors.blueGrey,
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  // 💼 SUBRUTINAS DE GESTIÓN COMERCIAL (Añadir, modificar, eliminar)
  void _incrementarCantidad(int index) {
    setState(() {
      final rep = _repuestosComerciales[index];
      _repuestosComerciales[index] = rep.copyWith(cantidad: rep.cantidad + 1);
      _propuestaModificada = true;
    });
  }

  void _decrementarCantidad(int index) {
    final rep = _repuestosComerciales[index];
    if (rep.cantidad > 1) {
      setState(() {
        _repuestosComerciales[index] = rep.copyWith(cantidad: rep.cantidad - 1);
        _propuestaModificada = true;
      });
    } else {
      _confirmarEliminarRepuesto(index);
    }
  }

  void _confirmarEliminarRepuesto(int index) {
    final item = _repuestosComerciales[index];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar repuesto?'),
        content: Text('¿Desea retirar "${item.descripcion}" de la cotización comercial?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _repuestosComerciales.removeAt(index);
                _propuestaModificada = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Eliminado: ${item.descripcion}'),
                  action: SnackBarAction(
                    label: 'Deshacer',
                    onPressed: () {
                      setState(() {
                        _repuestosComerciales.insert(index, item);
                      });
                    },
                  ),
                ),
              );
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoEditarCantidad(int index) {
    final rep = _repuestosComerciales[index];
    final cantActual = (rep.cantidad % 1 == 0) ? rep.cantidad.toInt().toString() : rep.cantidad.toString();
    final controller = TextEditingController(text: cantActual);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar Cantidad: ${rep.descripcion}', style: const TextStyle(fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Código: ${rep.codigo.isNotEmpty ? rep.codigo : "S/C"} | Unidad: ${rep.unidad}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Cantidad requerida',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.pin),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              final val = double.tryParse(controller.text.trim().replaceAll(',', '.'));
              if (val == null || val <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingrese una cantidad válida mayor a 0.'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(ctx);
              setState(() {
                _repuestosComerciales[index] = rep.copyWith(cantidad: val);
                _propuestaModificada = true;
              });
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoEditarHorasHombre() {
    final double actual = _totalHorasHombre ?? 0.0;
    final controller = TextEditingController(text: actual > 0 ? actual.toStringAsFixed(1) : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modificar Horas Hombre (HH)', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ajuste el total de Horas Hombre cotizadas para este servicio:',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Total Horas Hombre (HH)',
                border: OutlineInputBorder(),
                suffixText: 'HH',
                prefixIcon: Icon(Icons.timer_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              final val = double.tryParse(controller.text.trim().replaceAll(',', '.'));
              if (val == null || val < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingrese un valor válido de Horas Hombre.'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(ctx);
              setState(() {
                _totalHorasHombre = val;
                _propuestaModificada = true;
              });
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  List<ItemCatalogoEntity> _obtenerItemsCatalogo() {
    final catalogoState = context.read<CatalogoBloc>().state;
    final Map<String, ItemCatalogoEntity> mapa = {};
    if (catalogoState is CatalogoLoaded) {
      for (final act in catalogoState.actividades) {
        for (final item in [...act.itemsComerciales, ...act.itemsInternos]) {
          final key = item.codigo.trim().isNotEmpty
              ? item.codigo.trim().toUpperCase()
              : item.descripcion.trim().toUpperCase();
          if (!mapa.containsKey(key)) {
            mapa[key] = item;
          }
        }
      }
    }
    return mapa.values.toList();
  }

  void _mostrarDialogoAgregarRepuesto() {
    final itemsCatalogo = _obtenerItemsCatalogo();
    showDialog(
      context: context,
      builder: (ctx) => _DialogoAgregarRepuesto(
        catalogoItems: itemsCatalogo,
        onAgregar: (nuevoRepuesto) {
          setState(() {
            _repuestosComerciales.add(nuevoRepuesto);
            _propuestaModificada = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Repuesto agregado: ${nuevoRepuesto.descripcion}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  /// El ticket ya fue cotizado antes y regresó a Comercial.
  bool get _esRegresoAComercial => widget.ticket.proforma != null;

  /// 🛒 Venta de Repuesto: sin apartado Excel; muestra los repuestos a
  /// cotizar y las cotizaciones que subió Compras.
  bool get _esVentaRepuesto => widget.ticket.tipoRequerimiento == TipoRequerimiento.ventaRepuesto;

  ({String nombre, String rol}) _usuarioActual() {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      return (nombre: authState.usuario.nombre, rol: authState.usuario.rol.name.toUpperCase());
    }
    return (nombre: 'DESCONOCIDO', rol: 'SIN_ROL');
  }

  /// 🧾 Cambios de materiales (taller y comerciales) respecto de las bases dadas.
  List<CambioMaterialEntity> _cambiosDesde(
    List<RepuestoRegistradoEntity> tallerBase,
    List<RepuestoRegistradoEntity> comercialBase,
  ) {
    final u = _usuarioActual();
    final ahora = DateTime.now();
    final momento =
        _esRegresoAComercial ? CambioMaterialEntity.regresoComercial : CambioMaterialEntity.primeraCotizacion;
    return [
      ...CambioMaterialEntity.diferencias(
        antes: tallerBase,
        despues: _repuestosTaller,
        lista: CambioMaterialEntity.listaTaller,
        momento: momento,
        usuarioNombre: u.nombre,
        usuarioRol: u.rol,
        fecha: ahora,
      ),
      ...CambioMaterialEntity.diferencias(
        antes: comercialBase,
        despues: _repuestosComerciales,
        lista: CambioMaterialEntity.listaComercial,
        momento: momento,
        usuarioNombre: u.nombre,
        usuarioRol: u.rol,
        fecha: ahora,
      ),
    ];
  }

  void _reiniciarBasesDeComparacion() {
    _repuestosTallerOriginal = List<RepuestoRegistradoEntity>.from(_repuestosTaller);
    _repuestosComercialesOriginal = List<RepuestoRegistradoEntity>.from(_repuestosComerciales);
  }

  void _guardarCambiosPropuesta() {
    final evaluacionBase = widget.ticket.evaluacionTecnica ??
        const EvaluacionTecnicaEntity(
          urlsAdjuntosPdf: [],
          observacion: '',
        );

    // 🧾 Los cambios de materiales van a su registro aparte; la auditoría
    // real no se toca al guardar.
    final cambios = _cambiosDesde(_repuestosTallerOriginal, _repuestosComercialesOriginal);

    final ticketActualizado = widget.ticket.copyWith(
      evaluacionTecnica: evaluacionBase.copyWith(
        repuestosComercial: _repuestosComerciales,
        repuestosTaller: _repuestosTaller,
        totalHorasHombre: _totalHorasHombre,
      ),
    );

    context.read<TicketBloc>().add(
      ActualizarEvaluacionEvent(ticket: ticketActualizado, cambiosMateriales: cambios),
    );

    // Reiniciamos la base de comparacion para el proximo guardado.
    _reiniciarBasesDeComparacion();

    setState(() {
      _propuestaModificada = false;
    });
  }

  void _finalizarCotizacion() {
    if (_pdfsSeleccionados.isEmpty && _excelsSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El campo documental está vacío. Adjunte al menos un archivo.'), 
          backgroundColor: Colors.red
        ),
      );
      return;
    }

    final authState = context.read<AuthBloc>().state;
    String operador = 'DESCONOCIDO';
    String rol = 'SIN_ROL';

    if (authState is Authenticated) {
      operador = authState.usuario.nombre;
      rol = authState.usuario.rol.name.toUpperCase();
    }

    final evaluacionBase = widget.ticket.evaluacionTecnica ??
        const EvaluacionTecnicaEntity(
          urlsAdjuntosPdf: [],
          observacion: '',
        );

    final ticketParaEnviar = widget.ticket.copyWith(
      evaluacionTecnica: evaluacionBase.copyWith(
        repuestosComercial: _repuestosComerciales,
        repuestosTaller: _repuestosTaller,
        totalHorasHombre: _totalHorasHombre,
      ),
      // 🛒 Venta: la lista ya guardada por Comercial, no la que se abrió.
      lineasRepuestoVenta: _esVentaRepuesto ? _lineasVenta : null,
    );

    // 🧾 Cambios aún no guardados + total desde que se abrió (solo si el
    // ticket regresó a Comercial: único evento de auditoría).
    final cambiosPendientes = _cambiosDesde(_repuestosTallerOriginal, _repuestosComercialesOriginal);
    final cambiosTrasRegreso =
        _esRegresoAComercial ? _cambiosDesde(_tallerAlAbrir, _comercialAlAbrir).length : null;
    _reiniciarBasesDeComparacion();

    context.read<TicketBloc>().add(
      ProcesarCotizacionEvent(
        ticket: ticketParaEnviar,
        archivosPdf: _pdfsSeleccionados, 
        archivosExcel: _excelsSeleccionados, 
        observacion: _observacionController.text.trim(),
        nombreUsuario: operador,
        rolUsuario: rol,
        cambiosMateriales: cambiosPendientes,
        cambiosTrasRegreso: cambiosTrasRegreso,
      ),
    );
  }

  // ⚙️ MÓDULO NUEVO: Panel de Telemetría Base (Datos de Salida)
  Widget _buildPanelTelemetriaBase(BuildContext context) {
    final t = widget.ticket;
    // Extracción segura para evitar Nulos en la pantalla
    final numSerie = (t.numeroSerie != null && t.numeroSerie!.trim().isNotEmpty) ? t.numeroSerie! : 'S/N';
    final marca = t.marca.trim().isNotEmpty ? t.marca : 'No registrada';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50, // Gris industrial claro
        border: Border.all(color: Colors.blueGrey.shade200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Datos de Salida', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
              if (_esVentaRepuesto) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade600),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_cart, size: 14, color: Colors.teal.shade800),
                      const SizedBox(width: 4),
                      Text('VENTA DE REPUESTO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal.shade900)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const Divider(height: 24, thickness: 1),
          
          _construirFilaDato(context, 'Ticket:', t.id),
          // 🛒 Venta de Repuesto: sin serie/marca; "Repuesto de" + datos de contacto.
          if (_esVentaRepuesto) ...[
            _construirFilaDato(context, 'Repuesto de:', t.equipo.name.toUpperCase()),
            _construirFilaDato(context, 'Cliente:', t.clienteId.toUpperCase()),
            _construirFilaDato(context, 'Contacto:', t.nombreContacto),
            _construirFilaDato(context, 'Teléfono:', t.telefonoContacto),
            _construirFilaDato(context, 'Correo:', t.emailContacto),
            if (t.medioContacto != null)
              _construirFilaDato(context, 'Medio de contacto:', t.medioContacto!.name.toUpperCase()),
          ] else ...[
            _construirFilaDato(context, 'Numero de serie:', numSerie),
            _construirFilaDato(context, 'Marca:', marca),
            _construirFilaDato(context, 'Equipo:', t.equipo.name.toUpperCase()),
            _construirFilaDato(context, 'Cliente:', t.clienteId.toUpperCase()),
          ],
          _construirFilaDato(context, 'Camaronera:', t.campamento.toLowerCase()),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    children: [
                      const TextSpan(text: 'Estación Actual: '),
                      TextSpan(
                        // Forzamos la lectura dinámica del estado actual del PLC
                        text: t.estadoActual.name.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              CopyIconButtonWidget(etiqueta: 'Estación Actual', valor: t.estadoActual.name.toUpperCase()),
            ],
          ),
        ],
      ),
    );
  }

  // Subrutina auxiliar para mantener el código limpio y simétrico
  Widget _construirFilaDato(BuildContext context, String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Text('$etiqueta $valor', style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ),
          CopyIconButtonWidget(etiqueta: etiqueta, valor: valor),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🧠 Sensor lógico: ¿Es un reclamo de garantía?
    final bool esGarantia = widget.ticket.tipoRequerimiento == TipoRequerimiento.reclamoGarantia;

    return Scaffold(
      appBar: AppBar(title: Text('Cotización: ${widget.ticket.id}'), backgroundColor: Colors.green),
      // 🔧 CIRCUITO LIMPIO: Un solo sensor conectado directamente al flujo principal
      body: BlocListener<TicketBloc, TicketState>(
        listener: (context, state) {
          if (state.status == TicketStatus.operationSuccess) { 
            final msg = state.message.isNotEmpty 
                ? state.message 
                : 'Operación completada exitosamente.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg), 
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              )
            );
            
            context.read<TicketBloc>().add(
              const ObtenerHistorialTicketsEvent(
                segmento: SegmentoOperativo.ninguno, 
              ),
            );
            
            if (msg.contains('Cotización') || msg.contains('SCADA') || msg.contains('Documentos en Storage')) {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            }
          } else if (state.status == TicketStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red)
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              // ==========================================
              // 🚨 ALERTA: ESTE TICKET NO NECESITA COMPRAS
              // ==========================================
              TarjetaNoRequiereComprasWidget(ticket: widget.ticket),

              // ==========================================
              // 🚨 BALIZA DE ADVERTENCIA: TICKET MODIFICADO
              // ==========================================
              if (widget.ticket.fueModificado)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade800, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.red.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4)),
                    ]
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.report_problem, color: Colors.red.shade900, size: 36),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TICKET REVERSADO PARA CORRECCIÓN', 
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900, fontSize: 16)
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Instrucción de Operaciones:',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
                                  ),
                                ),
                                CopyIconButtonWidget(etiqueta: 'Instrucción de Operaciones', valor: _obtenerMotivoModificacion()),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.red.shade200)
                              ),
                              child: Text(
                                _obtenerMotivoModificacion(),
                                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.red.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // ==========================================
              // 📊 PANEL DE TELEMETRÍA (NUEVO REQUERIMIENTO)
              // ==========================================
              _buildPanelTelemetriaBase(context),

              // 🛒 VENTA DE REPUESTO: repuestos a cotizar + cotizaciones de Compras
              if (_esVentaRepuesto) ...[
                _buildPanelRepuestosVenta(),
                _buildPanelCotizacionesCompras(),
              ],

              // ==========================================
              // 🔍 PANEL DE DIAGNÓSTICO TÉCNICO (Solo Lectura)
              // ==========================================
              if (widget.ticket.evaluacionTecnica != null) ...[
                _buildPanelPropuestaComercial(context, widget.ticket.evaluacionTecnica!),
                Card(
                  elevation: 2,
                  color: Colors.blueGrey.shade50,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.blueGrey.shade200, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.engineering, color: Colors.blueGrey),
                            SizedBox(width: 8),
                            Text('Diagnóstico de Servicio Técnico', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
                          ],
                        ),
                        const Divider(),
                        
                        Row(
                          children: [
                            const Expanded(
                              child: Text('Observaciones del Taller:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            ),
                            CopyIconButtonWidget(
                              etiqueta: 'Observaciones del Taller',
                              valor: widget.ticket.evaluacionTecnica!.observacion.isNotEmpty
                                  ? widget.ticket.evaluacionTecnica!.observacion
                                  : 'Sin observaciones reportadas.',
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            widget.ticket.evaluacionTecnica!.observacion.isNotEmpty
                                ? widget.ticket.evaluacionTecnica!.observacion
                                : 'Sin observaciones reportadas.',
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ==========================================
                        // 🔍 LECTURA DE EVIDENCIA
                        // ==========================================
                        const Text('Archivos Adjuntos de Evaluación:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        
                        Builder(
                          builder: (context) {
                            final evaluacion = widget.ticket.evaluacionTecnica!;
                            final bool tieneExcel = evaluacion.urlProformaExcel != null && evaluacion.urlProformaExcel!.isNotEmpty;
                            final bool tienePdfs = evaluacion.urlsAdjuntosPdf.isNotEmpty;

                            if (!tieneExcel && !tienePdfs) {
                              return const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Text('El técnico no subió documentos estructurales.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                              );
                            }

                            return Column(
                              children: [
                                if (tieneExcel)
                                  ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.table_view, color: Colors.green),
                                    title: const Text('Descargar Proforma Técnica Base', style: TextStyle(decoration: TextDecoration.underline, color: Colors.blue, fontWeight: FontWeight.bold)),
                                    trailing: const Icon(Icons.download, size: 20),
                                    onTap: () => _abrirEnlaceTecnico(evaluacion.urlProformaExcel!),
                                  ),

                                if (tienePdfs)
                                  ...evaluacion.urlsAdjuntosPdf.map((url) {
                                    return ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                                      title: const Text('Ver Evidencia Documental (PDF)', style: TextStyle(decoration: TextDecoration.underline, color: Colors.blue)),
                                      trailing: const Icon(Icons.open_in_new, size: 20),
                                      onTap: () => _abrirEnlaceTecnico(url),
                                    );
                                  }),
                              ],
                            );
                          }
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // ==========================================
              // 🚨 BALIZA DE ADVERTENCIA: FACTURACIÓN DE GARANTÍA
              // ==========================================
              if (esGarantia)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade800, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.orange.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4)),
                    ]
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade900, size: 36),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ATENCIÓN: TICKET DE GARANTÍA', 
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontSize: 16)
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(color: Colors.black87, fontSize: 14),
                                children: [
                                  const TextSpan(text: 'La facturación de esta orden debe emitirse a: '),
                                  TextSpan(
                                    text: widget.ticket.responsableFacturacionLegible,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // ==========================================
              // PANEL DE DOCUMENTOS MULTIPLES (Comercial)
              // ==========================================
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Carga Documental Comercial', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const Divider(),
                      
                      // 📁 SECCIÓN PDF
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Archivos PDF', style: TextStyle(fontWeight: FontWeight.w600)),
                          ElevatedButton.icon(
                            onPressed: _seleccionarPDFs, 
                            icon: const Icon(Icons.add), 
                            label: const Text('Añadir PDF')
                          ),
                        ],
                      ),
                      if (_pdfsSeleccionados.isEmpty)
                        const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('Sin PDFs cargados.', style: TextStyle(color: Colors.grey))),
                      ..._pdfsSeleccionados.map((file) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                        title: Text(file.name, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _eliminarArchivo(_pdfsSeleccionados, file),
                        ),
                      )),

                      // 📊 SECCIÓN EXCEL (no aplica a Venta de Repuesto)
                      if (!_esVentaRepuesto) ...[
                      const SizedBox(height: 16), 
                      const Divider(), 
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Archivos Excel', style: TextStyle(fontWeight: FontWeight.w600)),
                          ElevatedButton.icon(
                            onPressed: _seleccionarExcels,
                            icon: const Icon(Icons.add), 
                            label: const Text('Añadir Excel')
                          ),
                        ],
                      ),
                      if (_excelsSeleccionados.isEmpty)
                        const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('Sin Excels cargados.', style: TextStyle(color: Colors.grey))),
                      ..._excelsSeleccionados.map((file) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.table_chart, color: Colors.green), 
                        title: Text(file.name, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _eliminarArchivo(_excelsSeleccionados, file),
                        ),
                      )),
                      ],
                      
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // PANEL DE OBSERVACIONES
              TextField(
                controller: _observacionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Observaciones Comerciales',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.comment),
                ),
              ),
              const SizedBox(height: 16),

              // 🧾 CAMBIOS DE MATERIALES (registro aparte de la auditoría)
              BlocBuilder<TicketBloc, TicketState>(
                builder: (context, state) {
                  final vivo = state.historial.where((t) => t.id == widget.ticket.id).firstOrNull ??
                      (state.currentTicket?.id == widget.ticket.id ? state.currentTicket : null) ??
                      widget.ticket;
                  return CambiosMaterialesWidget(cambios: vivo.historialCambiosMateriales);
                },
              ),
              const SizedBox(height: 30),
              
              // BOTÓN ACTUADOR
              BlocBuilder<TicketBloc, TicketState>(
                builder: (context, state) {
                  if (state.status == TicketStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ElevatedButton.icon(
                    // 🛒 Venta: bloqueado hasta guardar los repuestos editados.
                    onPressed: _esVentaRepuesto && _ventaModificada ? null : _finalizarCotizacion,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('FINALIZAR Y ENVIAR COTIZACIÓN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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

  // ==========================================
  // 🛒 VENTA DE REPUESTO: REPUESTOS A COTIZAR
  // ==========================================
  String _fmtCantidad(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  Widget _buildPanelRepuestosVenta() {
    final lineas = _lineasVenta;
    final sinStock = lineas.where((l) => !l.tieneStockSuficiente).length;

    return BlocListener<TicketBloc, TicketState>(
      listener: (context, state) {
        if (!_guardandoVenta) return;
        if (state.status == TicketStatus.operationSuccess) {
          setState(() {
            _guardandoVenta = false;
            _ventaModificada = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.green));
        } else if (state.status == TicketStatus.error) {
          setState(() => _guardandoVenta = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
        }
      },
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 20),
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.green.shade600, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.inventory_2, color: Colors.green.shade800, size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Repuestos a cotizar',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade900),
                    ),
                  ),
                  if (lineas.isNotEmpty)
                    TextButton.icon(
                      icon: const Icon(Icons.copy, size: 15),
                      label: const Text('Copiar todos los códigos', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: lineas.map((l) => l.codigo).join('\n')));
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Códigos copiados al portapapeles.'), duration: Duration(seconds: 2)),
                        );
                      },
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Agregar repuesto', style: TextStyle(fontSize: 12)),
                    onPressed: _guardandoVenta ? null : _agregarRepuestoVenta,
                  ),
                ],
              ),
              if (sinStock > 0)
                Text(
                  '$sinStock repuesto(s) sin stock suficiente (en rojo).',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                ),
              if (_ventaModificada) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Modificaste repuestos. Guarda los cambios antes de enviar la cotización.',
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        icon: _guardandoVenta
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save, size: 14),
                        label: const Text('Guardar cambios'),
                        onPressed: _guardandoVenta ? null : _guardarRepuestosVenta,
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(height: 20),
              if (lineas.isEmpty)
                const Text('Sin repuestos registrados.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              for (int i = 0; i < lineas.length; i++) _filaRepuestoVenta(i, lineas[i]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filaRepuestoVenta(int index, LineaRepuestoVentaEntity l) {
    final falta = !l.tieneStockSuficiente;
    final color = falta ? Colors.red.shade700 : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(falta ? Icons.error_outline : Icons.check_circle_outline,
              color: falta ? Colors.red.shade700 : Colors.green.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: SelectableText(
                        l.codigo,
                        style: TextStyle(fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                    CopyIconButtonWidget(etiqueta: 'Código', valor: l.codigo),
                  ],
                ),
                Text(l.descripcionVisible, style: TextStyle(color: color)),
                Text(
                  'Cantidad: ${_fmtCantidad(l.cantidad)} ${l.unidad} • Stock: ${_fmtCantidad(l.stockDisponibleAlEvaluar ?? 0)}'
                  '${falta ? ' • Faltan: ${_fmtCantidad(l.cantidadFaltante)}' : ''}',
                  style: TextStyle(fontSize: 12, color: falta ? Colors.red.shade700 : Colors.grey.shade700),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cambiar cantidad',
            icon: const Icon(Icons.edit, size: 18),
            color: Colors.blueGrey,
            onPressed: _guardandoVenta ? null : () => _cambiarCantidadVenta(index),
          ),
          IconButton(
            tooltip: 'Quitar repuesto',
            icon: const Icon(Icons.delete_outline, size: 18),
            color: Colors.redAccent,
            onPressed: _guardandoVenta ? null : () => _quitarRepuestoVenta(index),
          ),
        ],
      ),
    );
  }

  double? _leerCantidad(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));

  Future<void> _cambiarCantidadVenta(int index) async {
    final l = _lineasVenta[index];
    final controller = TextEditingController(text: _fmtCantidad(l.cantidad));
    final nueva = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar cantidad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l.codigo} — ${l.descripcionVisible}', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Cantidad (${l.unidad})', border: const OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final c = _leerCantidad(controller.text);
              if (c == null || c <= 0) return;
              Navigator.pop(ctx, c);
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (nueva == null || nueva == l.cantidad) return;
    setState(() {
      _lineasVenta[index] = l.copyWith(cantidad: nueva);
      _ventaModificada = true;
    });
  }

  Future<void> _quitarRepuestoVenta(int index) async {
    final l = _lineasVenta[index];
    if (_lineasVenta.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Debe quedar al menos un repuesto en la venta.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Quitar repuesto?'),
        content: Text('${l.codigo} — ${l.descripcionVisible} × ${_fmtCantidad(l.cantidad)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quitar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _lineasVenta.removeAt(index);
      _ventaModificada = true;
    });
  }

  Future<void> _agregarRepuestoVenta() async {
    final cantidadController = TextEditingController(text: '1');
    ItemInventarioEntity? seleccionado;
    final nueva = await showDialog<LineaRepuestoVentaEntity>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Agregar repuesto'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BlocBuilder<InventarioBloc, InventarioState>(
                  builder: (context, state) {
                    final items = state is InventarioLoaded ? state.items : const <ItemInventarioEntity>[];
                    return Autocomplete<ItemInventarioEntity>(
                      displayStringForOption: (i) => '${i.codigo} - ${i.descripcion}',
                      optionsBuilder: (value) {
                        if (value.text.isEmpty) return const Iterable<ItemInventarioEntity>.empty();
                        final q = value.text.toLowerCase();
                        return items
                            .where((i) => i.codigo.toLowerCase().contains(q) || i.descripcion.toLowerCase().contains(q))
                            .take(20);
                      },
                      onSelected: (item) => setLocal(() => seleccionado = item),
                      fieldViewBuilder: (context, controller, focusNode, _) => TextField(
                        controller: controller,
                        focusNode: focusNode,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: state is InventarioLoading ? 'Cargando inventario...' : 'Buscar en el sistema por código o nombre',
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          if (seleccionado != null) setLocal(() => seleccionado = null);
                        },
                      ),
                    );
                  },
                ),
                if (seleccionado != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Stock neto: ${_fmtCantidad(seleccionado!.stockNetoDisponible)} ${seleccionado!.unidad}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: seleccionado!.stockNetoDisponible > 0 ? Colors.green.shade800 : Colors.red.shade700,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: cantidadController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Cantidad', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: seleccionado == null
                  ? null
                  : () {
                      final c = _leerCantidad(cantidadController.text);
                      if (c == null || c <= 0) return;
                      final item = seleccionado!;
                      Navigator.pop(
                        ctx,
                        EdicionVentaComercialService.nuevaLineaDesdeInventario(
                          codigo: item.codigo,
                          descripcion: item.descripcion,
                          unidad: item.unidad,
                          cantidad: c,
                          stockNeto: item.stockNetoDisponible,
                        ),
                      );
                    },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
    cantidadController.dispose();
    if (nueva == null || !mounted) return;
    final yaEsta = _lineasVenta.any((l) => l.codigo.trim().toUpperCase() == nueva.codigo.trim().toUpperCase());
    if (yaEsta) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ese repuesto ya está en la lista: cambie su cantidad con ✏️.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    setState(() {
      _lineasVenta.add(nueva);
      _ventaModificada = true;
    });
  }

  void _guardarRepuestosVenta() {
    final u = _usuarioActual();
    setState(() => _guardandoVenta = true);
    context.read<TicketBloc>().add(GuardarRepuestosVentaComercialEvent(
          ticketId: widget.ticket.id,
          lineas: List<LineaRepuestoVentaEntity>.from(_lineasVenta),
          nombreUsuario: u.nombre,
          rolUsuario: u.rol,
        ));
  }

  // ==========================================
  // 🛒 VENTA DE REPUESTO: COTIZACIONES (Compras + proveedor por repuesto)
  // ==========================================
  Widget _buildPanelCotizacionesCompras() {
    final urls = widget.ticket.urlsCotizacionCompras;
    final conProveedor =
        widget.ticket.lineasRepuestoVenta.where((l) => l.urlsCotizacionProveedor.isNotEmpty).toList();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: Colors.blueGrey.shade50,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.blueGrey.shade200, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.description, color: Colors.blueGrey),
                SizedBox(width: 8),
                Text('Cotizaciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
              ],
            ),
            const Divider(),
            const Text('De Compras', style: TextStyle(fontWeight: FontWeight.w600)),
            if (urls.isEmpty)
              const Text(
                'Compras no adjuntó cotizaciones (todos los repuestos tenían stock).',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ...urls.asMap().entries.map((e) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.attach_file, color: Colors.blueGrey),
                title: Text(
                  'Ver cotización de Compras ${e.key + 1}',
                  style: const TextStyle(decoration: TextDecoration.underline, color: Colors.blue),
                ),
                trailing: const Icon(Icons.open_in_new, size: 20),
                onTap: () => _abrirEnlaceTecnico(e.value),
              );
            }),
            if (conProveedor.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Del proveedor (Evaluación técnica)', style: TextStyle(fontWeight: FontWeight.w600)),
              for (final l in conProveedor)
                ...l.urlsCotizacionProveedor.asMap().entries.map((e) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.storefront, color: Colors.blueGrey),
                      title: Text(
                        'Cotización ${e.key + 1} — ${l.codigo.isNotEmpty ? '${l.codigo} · ' : ''}${l.descripcionVisible}',
                        style: const TextStyle(decoration: TextDecoration.underline, color: Colors.blue),
                      ),
                      trailing: const Icon(Icons.open_in_new, size: 20),
                      onTap: () => _abrirEnlaceTecnico(e.value),
                    )),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 💼 PANEL DE PROPUESTA COMERCIAL SOLICITADA (Editable por Comercial)
  // ==========================================
  Widget _buildPanelPropuestaComercial(BuildContext context, EvaluacionTecnicaEntity evaluacion) {
    if (evaluacion.actividades.isEmpty && _repuestosComerciales.isEmpty && _repuestosTaller.isEmpty) {
      return const SizedBox.shrink();
    }

    final double totalHH = _totalHorasHombre ??
        (evaluacion.totalHorasHombre ??
            evaluacion.actividades.fold<double>(0.0, (acc, a) => acc + a.horasHombre));

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.green.shade600, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // CABECERA DEL PANEL COMERCIAL
            // ==========================================
            Row(
              children: [
                Icon(Icons.request_quote, color: Colors.green.shade800, size: 26),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Propuesta Comercial Requerida',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade900),
                  ),
                ),
                Tooltip(
                  message: 'Tocar para modificar Total Horas Hombre',
                  child: InkWell(
                    onTap: _mostrarDialogoEditarHorasHombre,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade600),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Total: ${totalHH.toStringAsFixed(1)} HH',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900, fontSize: 13),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.edit, size: 13, color: Colors.green.shade800),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 💲 Costo de mano de obra = Total HH × $25 por hora (se
                // recalcula al editar las horas).
                Tooltip(
                  message: 'Costo de mano de obra: ${totalHH.toStringAsFixed(1)} HH × \$$_tarifaHoraHombre',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade600),
                    ),
                    child: Text(
                      'Costo M.O.: \$${(totalHH * _tarifaHoraHombre).toStringAsFixed(2)}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // ==========================================
            // BALIZA DE MODIFICACIÓN PENDIENTE DE GUARDAR
            // ==========================================
            if (_propuestaModificada) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Modificaste ítems o cantidades. Puedes guardar cambios ahora o al enviar la cotización.',
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      icon: const Icon(Icons.save, size: 14),
                      label: const Text('Guardar'),
                      onPressed: _guardarCambiosPropuesta,
                    ),
                  ],
                ),
              ),
            ],

            // ==========================================
            // 1. ACTIVIDADES A REALIZAR
            // ==========================================
            if (evaluacion.actividades.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Actividades y Alcance de Trabajo:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.copy, size: 15),
                    label: const Text('Copiar Actividades', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      final buffer = StringBuffer();
                      for (final act in evaluacion.actividades) {
                        buffer.writeln('${act.codigo} - ${act.nombre} (${act.horasHombre} HH)');
                        if (act.incluye != null && act.incluye!.isNotEmpty) {
                          buffer.writeln('  ${act.incluye}');
                        }
                      }
                      Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Actividades copiadas al portapapeles.'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...evaluacion.actividades.asMap().entries.map((entry) {
                final idx = entry.key;
                final act = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blueGrey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: const Color(0xFF005A9C),
                            child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Tooltip(
                              message: 'Tocar para copiar nombre de actividad',
                              child: InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: act.nombre));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Copiado: ${act.nombre}'),
                                      duration: const Duration(milliseconds: 1200),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                child: Text(
                                  '${act.codigo} - ${act.nombre}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                          CopyIconButtonWidget(etiqueta: 'Actividad', valor: act.nombre),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blue.shade300),
                            ),
                            child: Text('${act.horasHombre} HH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                          ),
                        ],
                      ),
                      if (act.incluye != null && act.incluye!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 32),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  act.incluye!,
                                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blueGrey.shade800),
                                ),
                              ),
                              CopyIconButtonWidget(etiqueta: 'Detalle Incluye', valor: act.incluye!),
                            ],
                          ),
                        ),
                      ],
                      if (act.observacion.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 32),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  'Hallazgo: ${act.observacion}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                                ),
                              ),
                              CopyIconButtonWidget(etiqueta: 'Hallazgo', valor: act.observacion),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
            ],

            // ==========================================
            // 2. TABLA DE REPUESTOS COMERCIALES (EDITABLE)
            // ==========================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Repuestos e Insumos Comerciales (${_repuestosComerciales.length} ítems):',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                  ),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_circle, size: 16),
                      label: const Text('Añadir Repuesto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: _mostrarDialogoAgregarRepuesto,
                    ),
                    if (_repuestosComerciales.isNotEmpty) ...[
                      TextButton.icon(
                        icon: const Icon(Icons.copy_all, size: 15),
                        label: const Text('Copiar Nombres', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          final buffer = StringBuffer();
                          for (final r in _repuestosComerciales) {
                            buffer.writeln(r.descripcion);
                          }
                          Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nombres de repuestos copiados al portapapeles.'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.table_chart_outlined, size: 15),
                        label: const Text('Copiar Tabla', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          final buffer = StringBuffer();
                          buffer.writeln('CÓDIGO\tDESCRIPCIÓN\tCANTIDAD\tUNIDAD');
                          for (final r in _repuestosComerciales) {
                            buffer.writeln('${r.codigo}\t${r.descripcion}\t${r.cantidad}\t${r.unidad}');
                          }
                          Clipboard.setData(ClipboardData(text: buffer.toString()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tabla de repuestos comerciales copiada al portapapeles.'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_repuestosComerciales.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 32, color: Colors.grey.shade500),
                    const SizedBox(height: 6),
                    const Text(
                      'No hay repuestos en la propuesta comercial.',
                      style: TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Presione "Añadir Repuesto" para agregar partes o suministros necesarios.',
                      style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2.2), // Código
                    1: FlexColumnWidth(4.5), // Descripción
                    2: FlexColumnWidth(3.0), // Cantidad con [-] [cant] [+]
                    3: FlexColumnWidth(1.5), // Unidad
                    4: FlexColumnWidth(1.0), // Eliminar
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade200),
                      children: const [
                        Padding(padding: EdgeInsets.all(8), child: Text('Código', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: EdgeInsets.all(8), child: Text('Descripción / Nombre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: EdgeInsets.all(8), child: Text('Cant.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                        Padding(padding: EdgeInsets.all(8), child: Text('Unidad', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                        Padding(padding: EdgeInsets.all(8), child: Text('', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      ],
                    ),
                    ..._repuestosComerciales.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final rep = entry.value;
                      final cantStr = (rep.cantidad % 1 == 0) ? rep.cantidad.toInt().toString() : rep.cantidad.toString();

                      return TableRow(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                        ),
                        children: [
                          // CÓDIGO
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    rep.codigo.isNotEmpty ? rep.codigo : 'S/C',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: rep.codigo.isNotEmpty ? Colors.black87 : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                                if (rep.codigo.isNotEmpty)
                                  CopyIconButtonWidget(etiqueta: 'Código', valor: rep.codigo),
                              ],
                            ),
                          ),
                          // DESCRIPCIÓN
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Tooltip(
                                    message: 'Tocar para copiar nombre',
                                    child: InkWell(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: rep.descripcion));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Copiado: ${rep.descripcion}'),
                                            duration: const Duration(milliseconds: 1200),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                      child: Text(rep.descripcion, style: const TextStyle(fontSize: 11)),
                                    ),
                                  ),
                                ),
                                CopyIconButtonWidget(etiqueta: 'Nombre de repuesto', valor: rep.descripcion),
                              ],
                            ),
                          ),
                          // CANTIDAD INTERACTIVA
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => _decrementarCantidad(idx),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(Icons.remove, size: 14, color: Colors.black87),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: 'Tocar para ingresar cantidad exacta',
                                  child: InkWell(
                                    onTap: () => _mostrarDialogoEditarCantidad(idx),
                                    child: Container(
                                      constraints: const BoxConstraints(minWidth: 32),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.blue.shade300),
                                      ),
                                      child: Text(
                                        cantStr,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF005A9C)),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => _incrementarCantidad(idx),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(Icons.add, size: 14, color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // UNIDAD
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                            child: Text(rep.unidad, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
                          ),
                          // ELIMINAR
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              tooltip: 'Eliminar ítem',
                              onPressed: () => _confirmarEliminarRepuesto(idx),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ],

            // ==========================================
            // 3. MATERIALES DE TALLER / BODEGA (MODIFICABLE)
            // ==========================================
            ExpansionTile(
              initiallyExpanded: true,
              tilePadding: EdgeInsets.zero,
              title: Row(
                children: [
                  const Icon(Icons.warehouse_outlined, size: 20, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Materiales Internos de Taller / Bodega (${_repuestosTaller.length} ítems)',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                  ),
                ],
              ),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_circle, size: 15),
                      label: const Text('Añadir Material', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: _mostrarDialogoAgregarRepuestoTaller,
                    ),
                    if (_repuestosTaller.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.copy_all, size: 14),
                            label: const Text('Copiar Nombres Taller', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              final buffer = StringBuffer();
                              for (final r in _repuestosTaller) {
                                buffer.writeln(r.descripcion);
                              }
                              Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Nombres de materiales de taller copiados.'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.table_chart_outlined, size: 14),
                            label: const Text('Copiar Tabla Taller', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              final buffer = StringBuffer();
                              buffer.writeln('CÓDIGO\tDESCRIPCIÓN\tCANTIDAD\tUNIDAD');
                              for (final r in _repuestosTaller) {
                                buffer.writeln('${r.codigo}\t${r.descripcion}\t${r.cantidad}\t${r.unidad}');
                              }
                              Clipboard.setData(ClipboardData(text: buffer.toString()));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Tabla de taller copiada al portapapeles.'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                if (_repuestosTaller.isEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blueGrey.shade200),
                    ),
                    child: const Center(
                      child: Text(
                        'Sin materiales internos de taller registrados. Use "Añadir Material" si requiere agregar ítems.',
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blueGrey.shade200),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2.2),
                        1: FlexColumnWidth(4.5),
                        2: FlexColumnWidth(3.0),
                        3: FlexColumnWidth(1.5),
                        4: FlexColumnWidth(1.0),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.blueGrey.shade100),
                          children: const [
                            Padding(padding: EdgeInsets.all(8), child: Text('Código', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: EdgeInsets.all(8), child: Text('Descripción / Nombre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: EdgeInsets.all(8), child: Text('Cant.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(8), child: Text('Unidad', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(8), child: Text('', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          ],
                        ),
                        ..._repuestosTaller.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final rep = entry.value;
                          final cantStr = (rep.cantidad % 1 == 0) ? rep.cantidad.toInt().toString() : rep.cantidad.toString();

                          return TableRow(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                            ),
                            children: [
                              // Código
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        rep.codigo.isNotEmpty ? rep.codigo : 'S/C',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: rep.codigo.isNotEmpty ? Colors.black87 : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                    if (rep.codigo.isNotEmpty)
                                      CopyIconButtonWidget(etiqueta: 'Código', valor: rep.codigo),
                                  ],
                                ),
                              ),
                              // Descripción
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Tooltip(
                                        message: 'Tocar para copiar nombre',
                                        child: InkWell(
                                          onTap: () {
                                            Clipboard.setData(ClipboardData(text: rep.descripcion));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Copiado: ${rep.descripcion}'),
                                                duration: const Duration(milliseconds: 1200),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          },
                                          child: Text(rep.descripcion, style: const TextStyle(fontSize: 11)),
                                        ),
                                      ),
                                    ),
                                    CopyIconButtonWidget(etiqueta: 'Nombre de material', valor: rep.descripcion),
                                  ],
                                ),
                              ),
                              // Cantidad interactiva con [-] [cant] [+]
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () => _decrementarCantidadTaller(idx),
                                      borderRadius: BorderRadius.circular(4),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Icon(Icons.remove, size: 14, color: Colors.black87),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Tooltip(
                                      message: 'Tocar para ingresar cantidad exacta',
                                      child: InkWell(
                                        onTap: () => _mostrarDialogoEditarCantidadTaller(idx),
                                        child: Container(
                                          constraints: const BoxConstraints(minWidth: 32),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.blueGrey.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.blueGrey.shade300),
                                          ),
                                          child: Text(
                                            cantStr,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => _incrementarCantidadTaller(idx),
                                      borderRadius: BorderRadius.circular(4),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Icon(Icons.add, size: 14, color: Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Unidad
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                                child: Text(rep.unidad, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
                              ),
                              // Eliminar
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                  tooltip: 'Eliminar material de taller',
                                  onPressed: () => _confirmarEliminarRepuestoTaller(idx),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 🛒 DIÁLOGO PARA AÑADIR REPUESTO / INSUMO / MATERIAL
// ==========================================
class _DialogoAgregarRepuesto extends StatefulWidget {
  final String titulo;
  final IconData icono;
  final Color colorPrimario;
  final List<ItemCatalogoEntity> catalogoItems;
  final Function(RepuestoRegistradoEntity) onAgregar;

  const _DialogoAgregarRepuesto({
    this.titulo = 'Añadir Repuesto o Insumo',
    this.icono = Icons.add_shopping_cart,
    this.colorPrimario = Colors.green,
    required this.catalogoItems,
    required this.onAgregar,
  });

  @override
  State<_DialogoAgregarRepuesto> createState() => _DialogoAgregarRepuestoState();
}

class _DialogoAgregarRepuestoState extends State<_DialogoAgregarRepuesto> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _codigoController = TextEditingController();
  final _cantidadController = TextEditingController(text: '1');
  final _unidadController = TextEditingController(text: 'UND');

  @override
  void dispose() {
    _descController.dispose();
    _codigoController.dispose();
    _cantidadController.dispose();
    _unidadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(widget.icono, color: widget.colorPrimario),
          const SizedBox(width: 8),
          Expanded(
            child: Text(widget.titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Busque en el catálogo o escriba la descripción personalizada:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                
                // Buscador / Autocomplete de catálogo
                Autocomplete<ItemCatalogoEntity>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.trim().isEmpty) {
                      return const Iterable<ItemCatalogoEntity>.empty();
                    }
                    final query = textEditingValue.text.toLowerCase();
                    return widget.catalogoItems.where((item) =>
                        item.descripcion.toLowerCase().contains(query) ||
                        item.codigo.toLowerCase().contains(query));
                  },
                  displayStringForOption: (ItemCatalogoEntity option) =>
                      '${option.codigo.isNotEmpty ? "[${option.codigo}] " : ""}${option.descripcion}',
                  onSelected: (ItemCatalogoEntity selection) {
                    _descController.text = selection.descripcion;
                    _codigoController.text = selection.codigo;
                    if (selection.unidad.trim().isNotEmpty) {
                      _unidadController.text = selection.unidad.trim().toUpperCase();
                    }
                  },
                  fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                    textEditingController.addListener(() {
                      _descController.text = textEditingController.text;
                    });
                    return TextFormField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Descripción / Repuesto *',
                        hintText: 'Ej: Rodamiento 6204, Aceite 15W40...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Ingrese la descripción del repuesto';
                        }
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Código
                TextFormField(
                  controller: _codigoController,
                  decoration: const InputDecoration(
                    labelText: 'Código de Parte (Opcional)',
                    hintText: 'Ej: ROD-001, O-RING-22...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tag),
                  ),
                ),
                const SizedBox(height: 12),

                // Cantidad y Unidad
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _cantidadController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Cantidad *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.pin),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Requerido';
                          final numVal = double.tryParse(val.replaceAll(',', '.'));
                          if (numVal == null || numVal <= 0) return '> 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _unidadController,
                        decoration: const InputDecoration(
                          labelText: 'Unidad *',
                          hintText: 'UND, JGO, MTR...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.colorPrimario,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.check),
          label: const Text('Agregar a Lista'),
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              final cant = double.tryParse(_cantidadController.text.replaceAll(',', '.')) ?? 1.0;
              final nuevo = RepuestoRegistradoEntity(
                codigo: _codigoController.text.trim().toUpperCase(),
                descripcion: _descController.text.trim(),
                cantidad: cant,
                unidad: _unidadController.text.trim().toUpperCase(),
              );
              widget.onAgregar(nuevo);
              Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }
}
