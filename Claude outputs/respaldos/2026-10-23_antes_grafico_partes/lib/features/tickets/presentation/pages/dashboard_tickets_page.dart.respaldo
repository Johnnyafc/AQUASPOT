// lib/features/tickets/presentation/pages/dashboard_tickets_page.dart
//
// 📊 DASHBOARD DE TICKETS
//
// ⚙️ ARQUITECTURA (separación con BLoC, para que la interfaz no se cargue):
// Esta página es "tonta" a propósito: NO conoce TicketEntity ni sabe cómo
// se calculan horas, buckets de estado o departamentos. Todo ese trabajo
// pesado vive en `DashboardBloc`, que lo ejecuta dentro de `compute()`
// (un isolate separado del hilo de la interfaz — ver dashboard_bloc.dart).
// Esta pantalla solo:
//   1) crea el Bloc y le pide procesar los tickets recibidos,
//   2) escucha su estado (cargando / listo / error) con BlocBuilder,
//   3) filtra y ordena en memoria los DTOs ya calculados (operación
//      barata, O(n) sobre datos ya planos — no vuelve a tocar
//      historialEventos ni TicketEntity).
//
// ⚙️ SOBRE EL COSTO EN FIRESTORE: no hay ninguna lectura nueva aquí. Los
// `tickets` recibidos son los que Historial ya descargó una sola vez.
//
// ⚙️ RENDIMIENTO DE LA TABLA DE DETALLE: en vez de `DataTable` (que
// construye TODAS las filas de una sola vez, sin importar cuántas haya),
// la tabla usa `ListView.builder` con `itemExtent` fijo — solo construye
// las filas visibles en pantalla, así que sigue siendo fluida aunque la
// colección de tickets crezca a miles de registros.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/services/indicadores_postventa_service.dart';
import '../services/generador_excel_indicadores_postventa.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../../domain/services/tiempos_por_proceso_service.dart';
import '../../../../core/utils/constants.dart' show razonesProblemaEstandar;
import '../../../../core/enum/rol_usuario.dart';
import '../../../../core/enum/segmento_operativo.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

// ---------------------------------------------------------------------------
// 🎨 PALETA
// ---------------------------------------------------------------------------
const Color _navy = Color(0xFF0D2438);
const Color _teal = Color(0xFF0F6E6B);
const Color _tealLight = Color(0xFF17968F);
const Color _aqua = Color(0xFF4FC3BF);
const Color _sand = Color(0xFFE8A94B);
const Color _coral = Color(0xFFD9634F);
const Color _good = Color(0xFF2F8F6B);
const Color _warn = Color(0xFFD9A441);
const Color _bad = Color(0xFFC85C46);
const Color _slate = Color(0xFF2B5B86);

const List<Color> _seriesColors = [
  _teal, _aqua, _sand, _coral, _slate,
  Color(0xFF8BD3A0), Color(0xFFA9789A), Color(0xFFC4A35A),
];

// Mismo orden que EstadoTicket.values / _estadoLabelsBloc en el Bloc — se
// usa solo para mostrar la pestaña "Estado actual" en orden de flujo, no
// por magnitud. Si el flujo de estados cambia en ticket_enums.dart, esta
// lista (y la del Bloc) hay que actualizarlas juntas.
const List<String> _ordenEstadosPipeline = [
  'Creado', 'En camino', 'Evaluación Técnica', 'Revisión Garantía', 'Cotizando repuesto',
  'En cotización', 'Proforma enviada', 'Costos', 'Compras', 'Bodega', 'Proceso de Trabajo',
  'Revisión de pagos', 'Entrega', 'Finalizado', 'Anulado',
];

// 🆕 Orden fijo (según el flujo real del proceso) para las categorías del
// gráfico "Tiempo promedio por proceso" (_procesoDeAccion). A diferencia
// de _ordenEstadosPipeline, aquí NO se fuerza a mostrar todas — solo se
// ordenan las que sí tienen datos (ver _seccionDepartamentos). 'Otro' va
// al final porque no es una etapa real del flujo, es el residual de lo
// que no matchea ninguna palabra clave.
const List<String> _ordenProcesosDash = [
  'Recepción', 'Evaluación Técnica', 'Revisión Garantía', 'En cotización',
  'Proforma enviada', 'Costos', 'Compras', 'Validación Bodega', 'Despacho',
  'Proceso de Trabajo', 'Revisión de pagos', 'Entrega', 'Otro', 'Sin clasificar',
];

Color _colorPorNombreEstado(String nombre) {
  if (nombre == 'Finalizado') return _good;
  if (nombre == 'Anulado') return _bad;
  if (nombre == 'Revisión de pagos') return _warn;
  return _slate;
}

String _dosDigitos(int n) => n.toString().padLeft(2, '0');
String _fmtFecha(DateTime? d) => d == null ? '' : '${d.year}-${_dosDigitos(d.month)}-${_dosDigitos(d.day)}';
String _fmtFechaHora(DateTime? d) => d == null ? '' : '${_fmtFecha(d)} ${_dosDigitos(d.hour)}:${_dosDigitos(d.minute)}';
// 🆕 Igual que _fmtFecha pero agrupado por mes (sin el día) — usado para
// que "Tickets creados por fecha" muestre volumen mensual en vez de un
// pico por cada día individual.
String _fmtMes(DateTime? d) => d == null ? '' : '${d.year}-${_dosDigitos(d.month)}';
// 🕒 Convierte horas decimales (ej. 51.3) a "días horas minutos" (ej.
// "2d 3h 18m"), igual al formato que ya usan las tarjetas de ticket en
// historial_tickets_page.dart, para que el dashboard hable "el mismo
// idioma" en toda la app.
String _fmtDuracionHoras(double horas) {
  final totalMinutos = (horas * 60).round();
  final dias = totalMinutos ~/ 1440;
  final horasResto = (totalMinutos % 1440) ~/ 60;
  final minutosResto = totalMinutos % 60;
  if (dias > 0) return '${dias}d ${horasResto}h ${minutosResto}m';
  if (horasResto > 0) return '${horasResto}h ${minutosResto}m';
  return '${minutosResto}m';
}

// ---------------------------------------------------------------------------
// 🖥️ PÁGINA (crea el Bloc, le pide procesar los tickets recibidos)
// ---------------------------------------------------------------------------
class DashboardTicketsPage extends StatelessWidget {
  final List<TicketEntity> tickets;

  const DashboardTicketsPage({super.key, required this.tickets});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DashboardBloc()..add(CargarDashboardEvent(tickets)),
      child: _DashboardView(tickets: tickets),
    );
  }
}

class _DashboardView extends StatefulWidget {
  // Tickets sin procesar: solo los usa el botón "Indicadores de Postventa".
  final List<TicketEntity> tickets;

  const _DashboardView({required this.tickets});

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  // 🆕 Controlador dedicado para el scroll horizontal de la tabla de
  // detalle (_tablaDetalle) — permite mostrarle al usuario una barra de
  // scroll visible y arrastrable con el mouse (antes solo se podía
  // desplazar con gestos táctiles/trackpad, sin ninguna señal visual de
  // que había más columnas a la derecha).
  final ScrollController _tablaScrollController = ScrollController();

  String? _marca;
  String? _equipo;
  // Filtro por tipo de requerimiento (ticket.tipoRequerimiento, etiqueta legible).
  String? _tipoRequerimiento;
  String? _sede;
  String? _tipoGarantia;
  // Filtro "Estado": uno de los estados del ticket (nombre legible).
  String? _estado;
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  // 🔍 Categoría de falla seleccionada con clic en "Fallas por categoría".
  String? _categoriaSel;
  // ⏱️ Procesos desplegados en "Tiempo promedio por proceso" (ver sus partes).
  final Set<String> _procesosExpandidos = {};


  String _sortKey = 'fecha_creacion';
  bool _sortAsc = false;

  @override
  void dispose() {
    _tablaScrollController.dispose();
    super.dispose();
  }

  void _limpiarFiltros() {
    setState(() {
      _marca = null;
      _equipo = null;
      _tipoRequerimiento = null;
      _sede = null;
      _tipoGarantia = null;
      _estado = null;
      _fechaDesde = null;
      _fechaHasta = null;
      _categoriaSel = null;
    });
  }

  List<ResumenTicketDash> _filtrar(List<ResumenTicketDash> resumen) {
    return resumen.where((r) {
      if (_marca != null && r.marca != _marca) return false;
      if (_equipo != null && r.equipo != _equipo) return false;
      if (_tipoRequerimiento != null && r.tipoRequerimientoEtiqueta != _tipoRequerimiento) return false;
      if (_sede != null && r.sede != _sede) return false;
      if (_tipoGarantia != null && (r.tipoGarantia ?? '') != _tipoGarantia) return false;
      if (_estado != null && r.estadoNombre != _estado) return false;
      if (_fechaDesde != null) {
        if (r.fechaCreacion == null) return false;
        final dia = DateTime(r.fechaCreacion!.year, r.fechaCreacion!.month, r.fechaCreacion!.day);
        if (dia.isBefore(_fechaDesde!)) return false;
      }
      if (_fechaHasta != null) {
        if (r.fechaCreacion == null) return false;
        final dia = DateTime(r.fechaCreacion!.year, r.fechaCreacion!.month, r.fechaCreacion!.day);
        if (dia.isAfter(_fechaHasta!)) return false;
      }
      return true;
    }).toList(growable: false);
  }

  List<SegmentoTiempoDash> _segmentosDe(List<ResumenTicketDash> filtrados, List<SegmentoTiempoDash> todos) {
    // 🚀 Si no hay ningún filtro activo, los segmentos de TODOS los
    // tickets ya son los que corresponden — evita construir un Set y
    // recorrer la lista completa de segmentos sin necesidad.
    final sinFiltros = _marca == null &&
        _equipo == null &&
        _tipoRequerimiento == null &&
        _sede == null &&
        _tipoGarantia == null &&
        _estado == null &&
        _fechaDesde == null &&
        _fechaHasta == null;
    if (sinFiltros) return todos;

    final ids = filtrados.map((r) => r.id).toSet();
    return todos.where((s) => ids.contains(s.ticketId)).toList(growable: false);
  }

  int _comparar(ResumenTicketDash a, ResumenTicketDash b, String key) {
    dynamic va;
    dynamic vb;
    switch (key) {
      case 'id': va = a.id; vb = b.id; break;
      case 'clienteId': va = a.clienteId; vb = b.clienteId; break;
      case 'equipo': va = a.equipo; vb = b.equipo; break;
      case 'marca': va = a.marca; vb = b.marca; break;
      case 'fallaReportada': va = a.fallaReportada; vb = b.fallaReportada; break;
      case 'lugarAtencion': va = a.lugarAtencion; vb = b.lugarAtencion; break;
      case 'sede': va = a.sede; vb = b.sede; break;
      case 'tipoGarantia': va = a.tipoGarantia ?? ''; vb = b.tipoGarantia ?? ''; break;
      case 'fecha_creacion': va = a.fechaCreacion; vb = b.fechaCreacion; break;
      case 'fecha_actualizacion': va = a.fechaActualizacion; vb = b.fechaActualizacion; break;
      case 'dias_totales': va = a.diasTotales; vb = b.diasTotales; break;
      case 'num_pasos': va = a.numPasos; vb = b.numPasos; break;
      case 'estado_bucket': va = a.estadoNombre; vb = b.estadoNombre; break;
      default: va = ''; vb = '';
    }
    if (va == null && vb == null) return 0;
    if (va == null) return -1;
    if (vb == null) return 1;
    if (va is String) return va.toLowerCase().compareTo((vb as String).toLowerCase());
    if (va is DateTime) return va.compareTo(vb as DateTime);
    if (va is num) return va.compareTo(vb as num);
    return 0;
  }

  List<ResumenTicketDash> _ordenar(List<ResumenTicketDash> data) {
    final copia = [...data];
    copia.sort((a, b) => _comparar(a, b, _sortKey) * (_sortAsc ? 1 : -1));
    return copia;
  }

  // =========================================================================
  // 🧱 PIEZAS DE UI REUTILIZABLES
  // =========================================================================

  Widget _seccionTitulo(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 22),
      child: Row(
        children: [
          Container(width: 5, height: 16, decoration: BoxDecoration(color: _sand, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(texto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
        ],
      ),
    );
  }

  Widget _card({String? titulo, String? nota, required Widget child}) {
    // 🚀 RepaintBoundary: aísla el repintado de cada tarjeta (gráfico o
    // tabla) para que un cambio en una no obligue a repintar sus vecinas.
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (titulo != null && titulo.isNotEmpty)
              Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _navy)),
            if (nota != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 10),
                child: Text(nota, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
              )
            else if (titulo != null && titulo.isNotEmpty)
              const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _grid(List<Widget> tarjetas, {int columnasAncho = 2}) {
    return LayoutBuilder(builder: (context, constraints) {
      final ancho = constraints.maxWidth;
      final columnas = ancho < 700 ? 1 : columnasAncho;
      if (columnas <= 1) {
        return Column(
          children: [for (final t in tarjetas) Padding(padding: const EdgeInsets.only(bottom: 16), child: t)],
        );
      }
      final espacio = 16.0 * (columnas - 1);
      final anchoTarjeta = (ancho - espacio) / columnas;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: tarjetas.map((t) => SizedBox(width: anchoTarjeta, child: t)).toList(),
      );
    });
  }

  // `icono` y `descripcion` son opcionales: la descripción aparece al pasar
  // el mouse sobre la tarjeta (explica qué cuenta el indicador).
  Widget _kpiCard(String valor, String etiqueta, Color color, {IconData? icono, String? descripcion}) {
    final tarjeta = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(top: BorderSide(color: color, width: 3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(valor, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _navy)),
              if (icono != null) ...[
                const Spacer(),
                Icon(icono, size: 20, color: color),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Flexible(child: Text(etiqueta, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
              if (descripcion != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.info_outline, size: 13, color: Colors.grey.shade500),
              ],
            ],
          ),
        ],
      ),
    );
    if (descripcion == null) return tarjeta;
    return Tooltip(
      message: descripcion,
      waitDuration: const Duration(milliseconds: 250),
      preferBelow: true,
      child: tarjeta,
    );
  }

  Widget _kpiRow(List<Widget> kpis) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: kpis.map((k) => SizedBox(width: 160, child: k)).toList(),
    );
  }

  Widget _dropdownFiltro(String etiqueta, String? valor, List<String> opciones, ValueChanged<String?> onChanged) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String?>(
            value: valor,
            isExpanded: true,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
              ...opciones.map((o) => DropdownMenuItem<String?>(value: o, child: Text(o, overflow: TextOverflow.ellipsis))),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _campoFecha(String etiqueta, DateTime? valor, ValueChanged<DateTime?> onChanged) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final ahora = DateTime.now();
              final seleccion = await showDatePicker(
                context: context,
                initialDate: valor ?? ahora,
                firstDate: DateTime(2020),
                lastDate: DateTime(ahora.year + 1),
              );
              if (seleccion != null) {
                onChanged(DateTime(seleccion.year, seleccion.month, seleccion.day));
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(valor == null ? '—' : _fmtFecha(valor), style: const TextStyle(fontSize: 13)),
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros(DashboardDatos datos, int totalFiltrado) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          _dropdownFiltro('Marca', _marca, datos.marcas, (v) => setState(() => _marca = v)),
          _dropdownFiltro('Equipo', _equipo, datos.equipos, (v) => setState(() => _equipo = v)),
          _dropdownFiltro(
            'Requerimiento',
            _tipoRequerimiento,
            (datos.resumen.map((r) => r.tipoRequerimientoEtiqueta).toSet().toList()..sort()),
            (v) => setState(() => _tipoRequerimiento = v),
          ),
          _dropdownFiltro('Sede', _sede, datos.sedes, (v) => setState(() => _sede = v)),
          _dropdownFiltro('Garantía', _tipoGarantia, datos.tiposGarantia, (v) => setState(() => _tipoGarantia = v)),
          _dropdownFiltro('Estado', _estado, datos.estados, (v) => setState(() => _estado = v)),
          _campoFecha('Fecha desde', _fechaDesde, (d) => setState(() => _fechaDesde = d)),
          _campoFecha('Fecha hasta', _fechaHasta, (d) => setState(() => _fechaHasta = d)),
          ElevatedButton(
            onPressed: _limpiarFiltros,
            style: ElevatedButton.styleFrom(backgroundColor: _teal, foregroundColor: Colors.white),
            child: const Text('Limpiar filtros'),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('$totalFiltrado de ${datos.resumen.length} tickets', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
            ),
          ),
        ],
      ),
    );
  }

  // --- Gráfico de barras verticales (fl_chart) ---
  Widget _barChartFl({
    required List<String> labels,
    required List<double> values,
    required Color color,
    double height = 220,
    bool mostrarDecimales = false,
    // Si se pasa, formatea el valor del tooltip con esta función (ej. para
    // mostrar "2d 3h 15m" en vez de "51.3"). Si no se pasa, usa el formato
    // decimal/entero de siempre.
    String Function(double)? formateadorTooltip,
    // 🆕 Etiquetas del eje X sin truncar, en hasta 2 líneas y sin rotación
    // — para catálogos de nombres más largos (ej. "Evaluación Técnica")
    // donde cortar a 9 caracteres los vuelve ilegibles.
    bool etiquetasDosLineas = false,
    // 🆕 Muestra el valor de cada barra siempre visible arriba de ella (no
    // solo al tocar/pasar el mouse) — útil cuando hay mucha diferencia de
    // tamaño entre barras y el detalle exacto de las chicas es difícil de
    // leer solo con la altura.
    bool mostrarValoresEnBarras = false,
    // 🆕 Muestra solo 1 de cada N etiquetas del eje X (ej. tickets por día
    // en un rango largo) para que no se encimen. 1 = todas.
    int pasoEtiquetas = 1,
    // 🆕 Color de cada barra (misma posición que `labels`); si no se pasa,
    // todas usan `color`.
    List<Color>? colores,
    // 🆕 Clic en una barra (índice de la barra).
    ValueChanged<int>? onTapBarra,
  }) {
    if (labels.isEmpty) {
      return SizedBox(height: height, child: Center(child: Text('Sin datos', style: TextStyle(color: Colors.grey.shade500))));
    }
    final maxValor = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    final maxY = maxValor <= 0 ? 1.0 : maxValor * 1.25;
    // 🔧 Mismo paso para la grilla de fondo y las etiquetas del eje
    // izquierdo — antes cada uno calculaba su propio intervalo por
    // separado, y fl_chart generaba una marca automática extra cerca del
    // máximo que se encimaba con la última etiqueta manual (ej. "126"
    // superpuesto con "100").
    final intervaloEje = maxY / 4 <= 0 ? 1.0 : maxY / 4;

    return LayoutBuilder(builder: (context, constraints) {
    // Ancho disponible por barra: las etiquetas y los valores se ajustan a
    // él para no encimarse con las barras vecinas.
    final anchoBarra = labels.isEmpty ? 100.0 : (constraints.maxWidth - 32) / labels.length;
    final compacto = anchoBarra < 95;
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: intervaloEje),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: intervaloEje,
                getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: etiquetasDosLineas ? 54 : 46,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                  if (pasoEtiquetas > 1 && i % pasoEtiquetas != 0) return const SizedBox.shrink();
                  if (etiquetasDosLineas) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: SizedBox(
                        width: anchoBarra - 4 < 36 ? 36 : anchoBarra - 4,
                        child: Text(
                          labels[i],
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: compacto ? 9 : 10, color: Colors.black87, height: 1.15),
                        ),
                      ),
                    );
                  }
                  final texto = labels[i].length > 10 ? '${labels[i].substring(0, 9)}…' : labels[i];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Transform.rotate(
                      angle: (labels.length / pasoEtiquetas) > 6 ? -0.7 : 0,
                      child: Text(texto, style: const TextStyle(fontSize: 10, color: Colors.black87)),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchCallback: onTapBarra == null
                ? null
                : (event, respuesta) {
                    final spot = respuesta?.spot;
                    if (event is FlTapUpEvent && spot != null) onTapBarra(spot.touchedBarGroupIndex);
                  },
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                String valorTexto = formateadorTooltip != null
                    ? formateadorTooltip(rod.toY)
                    : (mostrarDecimales ? rod.toY.toStringAsFixed(1) : rod.toY.toInt().toString());
                // Barras angostas: el valor visible se parte en dos líneas
                // (ej. "1d 21h" + salto + "23m") para no taparse con el vecino.
                if (compacto && mostrarValoresEnBarras && valorTexto.contains(' ')) {
                  final corte = valorTexto.lastIndexOf(' ');
                  valorTexto = '${valorTexto.substring(0, corte)}\n${valorTexto.substring(corte + 1)}';
                }
                return BarTooltipItem(
                  mostrarValoresEnBarras ? valorTexto : '${labels[group.x]}\n$valorTexto',
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: compacto ? 9.5 : 11),
                );
              },
            ),
          ),
          barGroups: List.generate(labels.length, (i) {
            return BarChartGroupData(
              x: i,
              showingTooltipIndicators: mostrarValoresEnBarras ? [0] : [],
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  color: (colores != null && i < colores.length) ? colores[i] : color,
                  width: labels.length > 40 ? 5 : (labels.length > 10 ? 10 : 22),
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }),
        ),
      ),
    );
    });
  }

  // --- Ranking horizontal (barras de progreso) para conteos con etiquetas largas ---
  Widget _rankingBars({
    required Map<String, int> counts,
    Color color = _tealLight,
    Map<String, Color>? coloresPorEtiqueta,
    int? topN,
    double maxLabelWidth = 140,
    List<String>? ordenFijo,
    // 🆕 Cuando se usa `ordenFijo` (catálogo fijo de etapas), por defecto
    // se ocultan las etapas en 0 (comportamiento de siempre). Pasar
    // `false` mantiene TODAS las etapas del catálogo visibles aunque no
    // tengan tickets ahora mismo — útil para "Estado actual de los
    // tickets", donde se quiere ver el pipeline completo.
    bool ocultarCeros = true,
  }) {
    List<MapEntry<String, int>> entries;
    if (ordenFijo != null) {
      entries = ordenFijo
          .where((k) => ocultarCeros ? (counts[k] ?? 0) > 0 : true)
          .map((k) => MapEntry(k, counts[k] ?? 0))
          .toList();
    } else {
      entries = counts.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
      // 🚀 Tope de seguridad: aunque no se pida topN explícito, nunca se
      // pintan más de 20 filas (evita listas gigantes si crecen mucho los
      // datos, ej. cientos de clientes o fallas distintas).
      entries = entries.take(topN ?? 20).toList();
    }

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('Sin datos', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      );
    }

    final maxVal = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Column(
      children: entries.map((e) {
        final frac = maxVal > 0 ? e.value / maxVal : 0.0;
        final colorFila = coloresPorEtiqueta?[e.key] ?? color;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: maxLabelWidth,
                child: Text(e.key, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  return Stack(
                    children: [
                      Container(
                        height: 14,
                        decoration: BoxDecoration(color: colorFila.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                      ),
                      Container(
                        height: 14,
                        width: constraints.maxWidth * frac,
                        decoration: BoxDecoration(color: colorFila, borderRadius: BorderRadius.circular(6)),
                      ),
                    ],
                  );
                }),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 34,
                child: Text('${e.value}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _pillEstado(String estado) {
    Color bg;
    Color fg;
    switch (estado) {
      case 'Finalizado': bg = const Color(0xFFE2F3EA); fg = _good; break;
      case 'Anulado': bg = const Color(0xFFFBE6E2); fg = _bad; break;
      case 'Revisión de pagos': bg = const Color(0xFFFDF2DF); fg = _warn; break;
      default: bg = const Color(0xFFE5EEF7); fg = _slate;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(estado, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  // =========================================================================
  // 📊 KPIs
  // =========================================================================
  List<Widget> _construirKpis(List<ResumenTicketDash> data) {
    final total = data.length;
    var cerrados = 0;
    var anulados = 0;
    var reclamosGarantia = 0;
    var garantiasAprobadas = 0;
    var sumaDias = 0.0;
    for (final r in data) {
      if (r.estadoBucket == 'Finalizado') cerrados++;
      if (r.estadoBucket == 'Anulado') anulados++;
      if (r.esReclamoGarantia) reclamosGarantia++;
      if (r.garantiaAprobada) garantiasAprobadas++;
      if (r.estadoBucket == 'Finalizado') sumaDias += r.diasTotales;
    }
    final enProceso = total - cerrados - anulados;
    final avgDias = cerrados > 0 ? sumaDias / cerrados : 0.0;

    return [
      _kpiCard(total.toString(), 'Tickets (filtrados)', _tealLight),
      _kpiCard(cerrados.toString(), 'Finalizados', _good),
      _kpiCard(enProceso.toString(), 'En proceso', _warn),
      _kpiCard(anulados.toString(), 'Anulados', _bad),
      _kpiCard(reclamosGarantia.toString(), 'Reclamos de garantía', const Color(0xFFE07A2E),
          icono: Icons.assignment_late_outlined,
          descripcion: 'Tickets que ingresaron como RECLAMO DE GARANTÍA (tipo de requerimiento), sin importar si la garantía después se aprobó o se rechazó.'),
      _kpiCard(garantiasAprobadas.toString(), 'Garantías aprobadas', const Color(0xFFB23A48),
          icono: Icons.verified_outlined,
          descripcion: 'Reclamos cuya garantía fue APROBADA por ingeniería en la revisión de garantía. No incluye los rechazados (pasan a facturación al cliente) ni los que aún no tienen dictamen.'),
      _kpiCard(avgDias.toStringAsFixed(1), 'Días promedio (ciclo)', _sand,
          descripcion: 'Promedio de días desde la creación hasta la finalización. Solo tickets finalizados.'),
    ];
  }

  // =========================================================================
  // 📈 SECCIONES
  // =========================================================================
  Widget _seccionTendencia(List<ResumenTicketDash> data) {
    final conteoMes = <String, int>{};
    final conteoEstado = <String, int>{};
    for (final r in data) {
      final m = _fmtMes(r.fechaCreacion);
      if (m.isNotEmpty) conteoMes[m] = (conteoMes[m] ?? 0) + 1;
      conteoEstado[r.estadoNombre] = (conteoEstado[r.estadoNombre] ?? 0) + 1;
    }
    final meses = conteoMes.keys.toList()..sort();
    final valoresMes = meses.map((m) => conteoMes[m]!.toDouble()).toList();
    final coloresEstado = {for (final n in _ordenEstadosPipeline) n: _colorPorNombreEstado(n)};

    // 📅 Con filtro de fechas: tickets por DÍA dentro del rango (incluye los
    // días sin tickets). Si falta un extremo, se toma del primer/último
    // ticket. Rangos de más de 92 días siguen mostrándose por mes.
    Widget graficoCreados;
    String tituloCreados = 'Tickets creados por mes';
    String notaCreados = 'Mes de creación del requerimiento (primer registro del ticket)';
    final fechas = data.where((r) => r.fechaCreacion != null).map((r) {
      final f = r.fechaCreacion!;
      return DateTime(f.year, f.month, f.day);
    }).toList()
      ..sort();
    final hayFiltroFechas = _fechaDesde != null || _fechaHasta != null;
    final desde = _fechaDesde ?? (fechas.isEmpty ? null : fechas.first);
    final hasta = _fechaHasta ?? (fechas.isEmpty ? null : fechas.last);
    final dias = (desde != null && hasta != null) ? hasta.difference(desde).inDays + 1 : 0;

    String dosDigitos(int v) => v.toString().padLeft(2, '0');
    String fmtDia(DateTime d) => '${dosDigitos(d.day)}/${dosDigitos(d.month)}';
    String fmtFecha(DateTime d) => '${dosDigitos(d.day)}/${dosDigitos(d.month)}/${d.year}';

    if (hayFiltroFechas && dias > 0 && dias <= 92) {
      final conteoDia = <DateTime, int>{};
      for (final f in fechas) {
        conteoDia[f] = (conteoDia[f] ?? 0) + 1;
      }
      final listaDias = [for (var i = 0; i < dias; i++) DateTime(desde!.year, desde.month, desde.day + i)];
      tituloCreados = 'Tickets creados por día';
      notaCreados = 'Del ${fmtFecha(desde!)} al ${fmtFecha(hasta!)} (según el filtro de fechas) · ${fechas.length} ticket(s)';
      graficoCreados = _barChartFl(
        labels: listaDias.map(fmtDia).toList(),
        values: listaDias.map((d) => (conteoDia[d] ?? 0).toDouble()).toList(),
        color: _tealLight,
        pasoEtiquetas: dias <= 14 ? 1 : (dias / 12).ceil(),
      );
    } else {
      if (hayFiltroFechas && dias > 92) {
        notaCreados = 'Rango mayor a 3 meses: se agrupa por mes de creación';
      }
      graficoCreados = _barChartFl(labels: meses, values: valoresMes, color: _tealLight);
    }

    return _grid([
      _card(
        titulo: tituloCreados,
        nota: '$notaCreados · Incluye anulados',
        child: graficoCreados,
      ),
      _card(
        titulo: 'Estado actual de los tickets',
        nota: 'Etapa donde está cada ticket ahora mismo — en orden del flujo del proceso',
        child: _rankingBars(counts: conteoEstado, ordenFijo: _ordenEstadosPipeline, coloresPorEtiqueta: coloresEstado, maxLabelWidth: 150, ocultarCeros: false),
      ),
    ]);
  }

  Widget _seccionEquipo(List<ResumenTicketDash> data) {
    // 🔒 El conteo "# de tickets por equipo" sí cuenta todos los tickets
    // (en curso, finalizados, anulados) — es un volumen, no un tiempo.
    final conteoEquipo = <String, int>{};
    for (final r in data) {
      conteoEquipo[r.equipo] = (conteoEquipo[r.equipo] ?? 0) + 1;
    }
    final labelsEquipo = conteoEquipo.keys.toList()..sort();
    final valoresEquipo = labelsEquipo.map((l) => conteoEquipo[l]!.toDouble()).toList();

    // ⏱️ El promedio de horas, en cambio, solo debe salir de tickets
    // FINALIZADOS: uno en curso todavía no tiene su tiempo total real (el
    // reloj sigue corriendo), y uno anulado se cortó a mitad de camino y
    // no representa cómo se comporta el proceso normalmente. Mezclarlos
    // distorsiona el promedio.
    final finalizados = data.where((r) => r.estadoBucket == 'Finalizado');
    final sumaHoras = <String, double>{};
    final conteoHorasEquipo = <String, int>{};
    for (final r in finalizados) {
      sumaHoras[r.equipo] = (sumaHoras[r.equipo] ?? 0) + r.horasTotales;
      conteoHorasEquipo[r.equipo] = (conteoHorasEquipo[r.equipo] ?? 0) + 1;
    }
    final valoresHoras = labelsEquipo.map((l) {
      final conteo = conteoHorasEquipo[l];
      if (conteo == null || conteo == 0) return 0.0;
      return sumaHoras[l]! / conteo;
    }).toList();

    return _grid([
      _card(
        titulo: '# de tickets por equipo',
        nota: 'Caracol, cosechadora, contador · Incluye anulados',
        child: _barChartFl(labels: labelsEquipo, values: valoresEquipo, color: _aqua),
      ),
      _card(
        titulo: 'Tiempo de atención promedio por equipo',
        nota: 'Tiempo transcurrido desde creación hasta el último registro, en días:horas:minutos (promedio por ticket, solo tickets finalizados)',
        child: _barChartFl(labels: labelsEquipo, values: valoresHoras, color: _sand, formateadorTooltip: _fmtDuracionHoras),
      ),
    ]);
  }

  // 🆕 Tiempo que se demoró cada PROCESO (etapa del flujo: Comercial,
  // Costos, Compras, Bodega, Proceso de Trabajo, etc.) en completar su
  // parte: el segmento entre dos pasos consecutivos del historial se
  // clasifica según a qué proceso pertenece la acción del paso de
  // llegada (ver _procesoDeAccion). Antes se agrupaba por el ROL de quien
  // hizo el paso (usuarioRol) — eso mezclaba, por ejemplo, todo lo que
  // hacía un SUPERVISOR sin importar en qué etapa del flujo estaba
  // actuando. Agrupar por proceso responde la pregunta de negocio real:
  // "¿en qué etapa del flujo se estanca más un ticket?".
  // 🔒 Solo se consideran segmentos de tickets FINALIZADOS (ver filtro en
  // el llamador): un ticket en curso todavía no tiene un tiempo cerrado
  // para ese paso, y uno anulado no representa el comportamiento normal
  // del proceso.
  // 🔧 Desglose por USUARIO dentro de cada proceso, para ver qué persona
  // está tomando más tiempo en promedio dentro de esa etapa.
  Widget _seccionDepartamentos(List<SegmentoTiempoDash> segmentos) {
    // Cada segmento es el total de un (ticket, proceso, parte, persona): los
    // promedios se dividen entre TICKETS distintos del proceso.
    final sumaPorProceso = <String, double>{};
    final ticketsPorProceso = <String, Set<String>>{};
    // proceso -> parte -> suma de horas / tickets que tuvieron esa parte
    final sumaPorParte = <String, Map<String, double>>{};
    final ticketsPorParte = <String, Map<String, Set<String>>>{};
    // proceso -> usuario -> [suma de horas] y tickets distintos atendidos
    final horasPorUsuario = <String, Map<String, double>>{};
    final ticketsPorUsuario = <String, Map<String, Set<String>>>{};

    for (final s in segmentos) {
      final proceso = s.proceso;
      sumaPorProceso[proceso] = (sumaPorProceso[proceso] ?? 0) + s.horas;
      ticketsPorProceso.putIfAbsent(proceso, () => <String>{}).add(s.ticketId);

      final parte = s.subproceso;
      if (parte != null) {
        final p = sumaPorParte.putIfAbsent(proceso, () => {});
        p[parte] = (p[parte] ?? 0) + s.horas;
        ticketsPorParte.putIfAbsent(proceso, () => {}).putIfAbsent(parte, () => <String>{}).add(s.ticketId);
      }

      final usuario = s.usuarioNombre.trim().isEmpty ? 'Sin asignar' : s.usuarioNombre;
      final hu = horasPorUsuario.putIfAbsent(proceso, () => {});
      hu[usuario] = (hu[usuario] ?? 0) + s.horas;
      ticketsPorUsuario.putIfAbsent(proceso, () => {}).putIfAbsent(usuario, () => <String>{}).add(s.ticketId);
    }

    int tickets(String proceso) => ticketsPorProceso[proceso]!.length;
    double promedio(String proceso) => sumaPorProceso[proceso]! / tickets(proceso);
    bool desplegable(String proceso) => (sumaPorParte[proceso]?.isNotEmpty ?? false);
    // Partes en el orden definido por el servicio; las que no tuvieron
    // tiempo no se muestran.
    List<String> partes(String proceso) => (TiemposPorProcesoService.subprocesos[proceso] ?? const <String>[])
        .where((p) => (sumaPorParte[proceso]?[p] ?? 0) > 0)
        .toList();

    // Orden por flujo (no alfabético), según _ordenProcesosDash.
    final procesos = sumaPorProceso.keys.toList()
      ..sort((a, b) {
        final ia = _ordenProcesosDash.indexOf(a);
        final ib = _ordenProcesosDash.indexOf(b);
        final ra = ia == -1 ? _ordenProcesosDash.length : ia;
        final rb = ib == -1 ? _ordenProcesosDash.length : ib;
        return ra.compareTo(rb);
      });

    // Barras: los procesos desplegados muestran sus partes justo a la
    // derecha, en un tono más claro. Cada parte muestra su tiempo REAL:
    // promedio solo entre los tickets que pasaron por ella (por eso las
    // partes no tienen por qué sumar el total del proceso).
    final etiquetas = <String>[];
    final valores = <double>[];
    final colores = <Color>[];
    final procesoDeBarra = <String?>[]; // proceso a desplegar al hacer clic (null en las partes)
    for (final proceso in procesos) {
      final abierto = _procesosExpandidos.contains(proceso);
      etiquetas.add(desplegable(proceso) ? '$proceso ${abierto ? '▾' : '▸'}' : proceso);
      valores.add(promedio(proceso));
      colores.add(_slate);
      procesoDeBarra.add(desplegable(proceso) ? proceso : null);
      if (abierto) {
        for (final parte in partes(proceso)) {
          final conParte = ticketsPorParte[proceso]![parte]!.length;
          etiquetas.add('↳ $parte\n$conParte ${conParte == 1 ? 'ticket' : 'tickets'}');
          valores.add(sumaPorParte[proceso]![parte]! / conParte);
          colores.add(_slate.withValues(alpha: 0.45));
          procesoDeBarra.add(proceso);
        }
      }
    }

    void alternar(String proceso) => setState(() {
          if (!_procesosExpandidos.remove(proceso)) _procesosExpandidos.add(proceso);
        });

    final ordenProcesos = [...procesos]..sort((a, b) => promedio(b).compareTo(promedio(a)));

    return _card(
      titulo: 'Tiempo promedio por proceso',
      nota: 'Tiempo promedio por ticket que cada etapa del flujo dedicó desde que recibió el trabajo hasta completarlo (las etapas en paralelo se miden por separado), desglosado por la persona que lo atendió (solo tickets finalizados). Clic en las barras con ▸ para ver sus partes: cada parte muestra su tiempo promedio entre los tickets que pasaron por ella.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _barChartFl(
            labels: etiquetas,
            values: valores,
            color: _slate,
            colores: colores,
            height: 260,
            mostrarDecimales: true,
            formateadorTooltip: _fmtDuracionHoras,
            etiquetasDosLineas: true,
            mostrarValoresEnBarras: true,
            onTapBarra: (i) {
              final proceso = procesoDeBarra[i];
              if (proceso != null) alternar(proceso);
            },
          ),
          if (ordenProcesos.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...ordenProcesos.map((proceso) {
              final hu = horasPorUsuario[proceso] ?? const <String, double>{};
              final tu = ticketsPorUsuario[proceso] ?? const <String, Set<String>>{};
              double promedioUsuario(String u) => (tu[u]?.isEmpty ?? true) ? 0 : hu[u]! / tu[u]!.length;
              final usuariosOrdenados = hu.keys.toList()..sort((a, b) => promedioUsuario(b).compareTo(promedioUsuario(a)));
              final abierto = _procesosExpandidos.contains(proceso);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: desplegable(proceso) ? () => alternar(proceso) : null,
                      child: Row(
                        children: [
                          if (desplegable(proceso))
                            Icon(abierto ? Icons.expand_more : Icons.chevron_right, size: 16, color: _slate),
                          Expanded(
                            child: Text(
                              '$proceso (${tickets(proceso)} ${tickets(proceso) == 1 ? 'ticket' : 'tickets'})',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _fmtDuracionHoras(promedio(proceso)),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _slate),
                          ),
                        ],
                      ),
                    ),
                    // Partes del proceso (solo si está desplegado): tiempo
                    // promedio entre los tickets que pasaron por esa parte.
                    if (abierto)
                      ...partes(proceso).map((parte) {
                        final suma = sumaPorParte[proceso]![parte]!;
                        final conParte = ticketsPorParte[proceso]![parte]!.length;
                        return Padding(
                          padding: const EdgeInsets.only(left: 18, top: 3),
                          child: Row(
                            children: [
                              Text('↳ ', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                              Expanded(
                                child: Text(
                                  '$parte ($conParte ${conParte == 1 ? 'ticket' : 'tickets'})',
                                  style: const TextStyle(fontSize: 11.5, color: _navy),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(_fmtDuracionHoras(suma / conParte),
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _slate)),
                            ],
                          ),
                        );
                      }),
                    // Desglose por persona (siempre visible).
                    ...usuariosOrdenados.map((usuario) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 14, top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.person_outline, size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(usuario, style: TextStyle(fontSize: 11, color: Colors.grey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            Text(_fmtDuracionHoras(promedioUsuario(usuario)), style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // (La clasificación de cada acción por proceso vive ahora en
  // TiemposPorProcesoService, que también mide el paralelismo.)

  // 🍩 Dona interactiva de TICKETS agrupados por un campo (marca, tipo de
  // requerimiento, lugar de atención, equipo...). Al pasar el mouse muestra:
  // cantidad y %, estado de esos tickets, desglose por equipo (si el filtro
  // Equipo está en "Todos" y no se agrupa por equipo) y clientes principales.
  // Más de 8 grupos: el resto se junta en "Otros".
  Widget _donaTickets(
    List<ResumenTicketDash> data,
    String Function(ResumenTicketDash r) agrupar, {
    List<Color>? colores,
    Map<String, Color>? colorPorGrupo,
    bool agrupaPorEquipo = false,
  }) {
    final grupos = <String, List<ResumenTicketDash>>{};
    for (final r in data) {
      final k = agrupar(r).trim().isEmpty ? 'Sin especificar' : agrupar(r).trim();
      grupos.putIfAbsent(k, () => []).add(r);
    }
    var claves = grupos.keys.toList()..sort((a, b) => grupos[b]!.length.compareTo(grupos[a]!.length));
    if (claves.length > 8) {
      final resto = claves.skip(7).expand((k) => grupos[k]!).toList();
      claves = [...claves.take(7), 'Otros'];
      grupos['Otros'] = resto;
    }
    final total = data.length;
    final paleta = colores ?? _seriesColors;
    String pct(int v) => total == 0 ? '0' : (v / total * 100).toStringAsFixed(0);
    String top(Map<String, int> m, int n) =>
        (m.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(n).map((e) => '${e.key} ${e.value}').join(' · ');

    return _DonaInteractiva(
      textoTotal: 'tickets',
      porciones: [
        for (var i = 0; i < claves.length; i++)
          (() {
            final lista = grupos[claves[i]]!;
            final estados = <String, int>{};
            final equipos = <String, int>{};
            final clientes = <String, int>{};
            for (final r in lista) {
              final estado = r.estadoBucket == 'Finalizado' ? 'Finalizados' : (r.estadoBucket == 'Anulado' ? 'Anulados' : 'En curso');
              estados[estado] = (estados[estado] ?? 0) + 1;
              equipos[r.equipo] = (equipos[r.equipo] ?? 0) + 1;
              if (r.clienteId.trim().isNotEmpty) clientes[r.clienteId.trim()] = (clientes[r.clienteId.trim()] ?? 0) + 1;
            }
            return _PorcionDona(
              clave: claves[i],
              etiqueta: claves[i],
              valor: lista.length,
              color: colorPorGrupo?[claves[i]] ?? paleta[i % paleta.length],
              detalle: [
                '${lista.length} ticket(s) · ${pct(lista.length)}% del total',
                'Estado: ${top(estados, 3)}',
                if (_equipo == null && !agrupaPorEquipo) 'Por equipo: ${top(equipos, 4)}',
                if (clientes.isNotEmpty) 'Clientes principales: ${top(clientes, 3)}',
              ],
            );
          })(),
      ],
    );
  }

  Widget _seccionDimensiones(List<ResumenTicketDash> data) {
    return _grid([
      _card(titulo: 'Tickets por marca', nota: 'Incluye anulados', child: _donaTickets(data, (r) => r.marca)),
      _card(
        titulo: 'Garantía vs. reparación regular',
        nota: 'Solo reclamos de garantía y reparaciones · Incluye anulados',
        child: _donaTickets(
          data.where((r) => r.esReclamoGarantia || r.tipoRequerimientoEtiqueta == 'Reparación regular').toList(),
          (r) => r.tipoRequerimientoEtiqueta,
        ),
      ),
      _card(
        titulo: 'Lugar de atención',
        nota: 'Incluye anulados',
        child: _donaTickets(data, (r) => r.lugarAtencion, colores: const [_teal, _coral, _slate, _sand]),
      ),
    ], columnasAncho: 3);
  }

  Widget _seccionClientesFallas(List<ResumenTicketDash> data) {
    final conteoCliente = <String, int>{};
    for (final r in data) {
      conteoCliente[r.clienteId] = (conteoCliente[r.clienteId] ?? 0) + 1;
    }
    // (Se quitó "Fallas reportadas más frecuentes": era texto libre del
    // cliente; el diagnóstico técnico está en "Diagnóstico de fallas".)
    return _grid([
      _card(titulo: 'Top clientes por # de tickets', nota: 'Incluye anulados', child: _rankingBars(counts: conteoCliente, color: _teal, topN: 10, maxLabelWidth: 150)),
    ]);
  }

  // 🔍 Diagnóstico técnico registrado en Proceso de Trabajo
  // (categoría → subcategoría → falla → razones). Se vincula con los filtros
  // globales (Equipo, fechas, etc.). Clic en una categoría la selecciona y
  // limita "Razones" y "Fallas más frecuentes" a esa categoría. Cuenta FALLAS
  // diagnosticadas (no tickets) y cada razón marcada suma 1. Sin anulados.
  Widget _seccionDiagnosticoFallas(List<ResumenTicketDash> data) {
    String clave(String t) => t.trim().toLowerCase();
    String pct(num parte, num total) => total == 0 ? '0' : (parte / total * 100).toStringAsFixed(0);

    final validos = data.where((r) => r.estadoBucket != 'Anulado').toList();
    final conDiagnostico = validos.where((r) => r.diagnosticos.isNotEmpty).toList();
    final pares = [
      for (final r in conDiagnostico)
        for (final d in r.diagnosticos) (ticket: r, d: d),
    ];

    // ---------------------------------------------------------------- Categorías
    final etiquetaCat = <String, String>{};
    final conteoCat = <String, int>{};
    final ticketsCat = <String, Set<String>>{};
    final ticketsCatEquipo = <String, Map<String, Set<String>>>{};
    final fallasCat = <String, Map<String, int>>{};
    for (final x in pares) {
      final k = clave(x.d.categoria);
      if (k.isEmpty) continue;
      etiquetaCat.putIfAbsent(k, () => x.d.categoria.trim());
      conteoCat[k] = (conteoCat[k] ?? 0) + 1;
      ticketsCat.putIfAbsent(k, () => <String>{}).add(x.ticket.id);
      ticketsCatEquipo.putIfAbsent(k, () => {}).putIfAbsent(x.ticket.equipo, () => <String>{}).add(x.ticket.id);
      final f = fallasCat.putIfAbsent(k, () => <String, int>{});
      f[x.d.falla.trim()] = (f[x.d.falla.trim()] ?? 0) + 1;
    }
    final clavesCat = conteoCat.keys.toList()..sort((a, b) => conteoCat[b]!.compareTo(conteoCat[a]!));
    final colorCat = {for (var i = 0; i < clavesCat.length; i++) clavesCat[i]: _seriesColors[i % _seriesColors.length]};
    final totalFallas = conteoCat.values.fold<int>(0, (s, v) => s + v);

    // La categoría elegida se ignora si ya no existe con los filtros actuales.
    final catSel = (_categoriaSel != null && conteoCat.containsKey(_categoriaSel)) ? _categoriaSel : null;

    // En vista general (filtro Equipo en "Todos") el detalle desglosa los
    // tickets afectados por equipo, ej. "5 (Cosechadora 3 · Caracol 2)".
    String ticketsPorEquipo(Map<String, Set<String>> porEquipo) {
      final total = porEquipo.values.expand((s) => s).toSet().length;
      if (_equipo != null) return '$total';
      final partes = porEquipo.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
      return '$total (${partes.map((e) => '${e.key} ${e.value.length}').join(' · ')})';
    }
    final paresCat = catSel == null ? pares : pares.where((x) => clave(x.d.categoria) == catSel).toList();

    final porcionesCat = [
      for (final k in clavesCat)
        _PorcionDona(
          clave: k,
          etiqueta: etiquetaCat[k]!,
          valor: conteoCat[k]!,
          color: colorCat[k]!,
          detalle: [
            '${conteoCat[k]} falla(s) · ${pct(conteoCat[k]!, totalFallas)}% del total',
            'Tickets afectados: ${ticketsPorEquipo(ticketsCatEquipo[k]!)}',
            'Más comunes: ${(fallasCat[k]!.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(3).map((e) => '${e.key} (${e.value})').join(', ')}',
          ],
        ),
    ];

    // ---------------------------------------------------------------- Razones
    final estandar = {for (final r in razonesProblemaEstandar) clave(r): r};
    const otras = 'Otras (texto libre)';
    final marcas = <String, int>{};
    final fallasConRazon = <String, int>{};
    final ticketsConRazon = <String, Set<String>>{};
    final ticketsConRazonEquipo = <String, Map<String, Set<String>>>{};
    final catsConRazon = <String, Map<String, int>>{};
    for (final x in paresCat) {
      final vistas = <String>{};
      for (final razon in x.d.razones) {
        if (razon.trim().isEmpty) continue;
        final et = estandar[clave(razon)] ?? otras;
        marcas[et] = (marcas[et] ?? 0) + 1;
        if (vistas.add(et)) {
          fallasConRazon[et] = (fallasConRazon[et] ?? 0) + 1;
          ticketsConRazon.putIfAbsent(et, () => <String>{}).add(x.ticket.id);
          ticketsConRazonEquipo.putIfAbsent(et, () => {}).putIfAbsent(x.ticket.equipo, () => <String>{}).add(x.ticket.id);
          final c = catsConRazon.putIfAbsent(et, () => <String, int>{});
          final cat = x.d.categoria.trim();
          c[cat] = (c[cat] ?? 0) + 1;
        }
      }
    }
    final totalMarcas = marcas.values.fold<int>(0, (s, v) => s + v);
    final totalFallasAlcance = paresCat.length;
    // Color fijo por razón (mismo orden del catálogo) para que no cambie al filtrar.
    Color colorRazon(String et) {
      final i = razonesProblemaEstandar.indexOf(et);
      return i < 0 ? Colors.blueGrey.shade300 : _seriesColors[i % _seriesColors.length];
    }
    final clavesRazon = marcas.keys.toList()..sort((a, b) => marcas[b]!.compareTo(marcas[a]!));
    final porcionesRazon = [
      for (final et in clavesRazon)
        _PorcionDona(
          clave: et,
          etiqueta: et,
          valor: marcas[et]!,
          color: colorRazon(et),
          detalle: [
            '${marcas[et]} marca(s) · ${pct(marcas[et]!, totalMarcas)}% de las marcas',
            'Presente en ${fallasConRazon[et]} de $totalFallasAlcance falla(s) (${pct(fallasConRazon[et]!, totalFallasAlcance)}%)',
            'Tickets afectados: ${ticketsPorEquipo(ticketsConRazonEquipo[et]!)}',
            if (catSel == null)
              'Predomina en: ${(catsConRazon[et]!.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(3).map((e) => '${e.key} (${e.value})').join(', ')}',
          ],
        ),
    ];

    // ---------------------------------------------------------------- Fallas por equipo
    final porEquipo = <String, Map<String, ({String categoria, String texto, int n})>>{};
    for (final x in paresCat) {
      final sub = x.d.subcategoria.trim();
      final falla = x.d.falla.trim();
      final k = '${clave(x.d.categoria)}|${clave(sub)}|${clave(falla)}';
      final mapa = porEquipo.putIfAbsent(x.ticket.equipo, () => {});
      final previo = mapa[k];
      mapa[k] = (
        categoria: previo?.categoria ?? x.d.categoria.trim(),
        texto: previo?.texto ?? (sub.isEmpty ? falla : '$sub · $falla'),
        n: (previo?.n ?? 0) + 1,
      );
    }
    int totalDe(String e) => porEquipo[e]!.values.fold<int>(0, (s, v) => s + v.n);
    final equipos = porEquipo.keys.toList()..sort((a, b) => totalDe(b).compareTo(totalDe(a)));
    final unSoloEquipo = _equipo != null;

    final Widget listaFallas = equipos.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Sin datos', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          )
        : LayoutBuilder(builder: (context, c) {
            // Un panel por equipo, lado a lado (hasta 3 por fila).
            final porFila = c.maxWidth >= 1000 ? 3 : (c.maxWidth >= 640 ? 2 : 1);
            final columnas = equipos.length < porFila ? equipos.length : porFila;
            final ancho = (c.maxWidth - 16.0 * (columnas - 1)) / columnas;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final equipo in equipos)
                  SizedBox(
                    width: ancho,
                    child: _panelFallasEquipo(
                      equipo: equipo,
                      total: totalDe(equipo),
                      filas: (porEquipo[equipo]!.values.toList()..sort((a, b) => b.n.compareTo(a.n)))
                          .take(unSoloEquipo ? 10 : 5)
                          .toList(),
                      colorCategoria: (cat) => colorCat[clave(cat)] ?? _slate,
                    ),
                  ),
              ],
            );
          });

    final notaCategorias =
        '$totalFallas falla(s) en ${conDiagnostico.length} ticket(s) — ${conDiagnostico.length} de ${validos.length} tickets tienen diagnóstico. No incluye anulados (no llegan a Proceso de Trabajo). Clic en una categoría para filtrar.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (catSel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InputChip(
              avatar: CircleAvatar(backgroundColor: colorCat[catSel], radius: 6),
              label: Text('Categoría: ${etiquetaCat[catSel]}', style: const TextStyle(fontWeight: FontWeight.w600)),
              onDeleted: () => setState(() => _categoriaSel = null),
              onPressed: () => setState(() => _categoriaSel = null),
            ),
          ),
        _grid([
          _card(
            titulo: 'Fallas por categoría',
            nota: notaCategorias,
            child: _DonaInteractiva(
              porciones: porcionesCat,
              textoTotal: 'fallas',
              seleccionada: catSel,
              onSeleccionar: (k) => setState(() => _categoriaSel = _categoriaSel == k ? null : k),
            ),
          ),
          _card(
            titulo: catSel == null ? 'Razones de falla (causa raíz)' : 'Razones de falla — ${etiquetaCat[catSel]}',
            nota: 'Porcentaje de veces que se marcó cada causa raíz (una falla puede tener varias)',
            child: _DonaInteractiva(
              porciones: porcionesRazon,
              textoTotal: 'marcas',
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _card(
          titulo: catSel == null ? 'Fallas más frecuentes' : 'Fallas más frecuentes — ${etiquetaCat[catSel]}',
          nota: unSoloEquipo
              ? 'Top 10 del equipo seleccionado · % sobre las fallas del equipo'
              : 'Top 5 por equipo (elija un equipo en el filtro para ver el top 10) · % sobre las fallas del equipo',
          child: listaFallas,
        ),
      ],
    );
  }

  // Panel de "Fallas más frecuentes" de UN equipo: ranking numerado, cada
  // falla con su barra justo debajo (fácil de leer de un vistazo) y su
  // categoría como punto de color (mismo color que en el gráfico).
  Widget _panelFallasEquipo({
    required String equipo,
    required int total,
    required List<({String categoria, String texto, int n})> filas,
    required Color Function(String categoria) colorCategoria,
  }) {
    final maxN = filas.isEmpty ? 0 : filas.first.n;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(equipo.toUpperCase(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _navy, letterSpacing: 0.4)),
              ),
              Text('$total falla(s)', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
            ],
          ),
          const Divider(height: 16),
          for (var i = 0; i < filas.length; i++)
            _filaFalla(
              posicion: i + 1,
              categoria: filas[i].categoria,
              color: colorCategoria(filas[i].categoria),
              texto: filas[i].texto,
              n: filas[i].n,
              totalEquipo: total,
              maxN: maxN,
              equipo: equipo,
            ),
        ],
      ),
    );
  }

  Widget _filaFalla({
    required int posicion,
    required String categoria,
    required Color color,
    required String texto,
    required int n,
    required int totalEquipo,
    required int maxN,
    required String equipo,
  }) {
    final porcentaje = totalEquipo == 0 ? 0 : n / totalEquipo * 100;
    // "Subcategoría · Falla": la falla en negrita, la subcategoría debajo.
    final partes = texto.split(' · ');
    final falla = partes.length > 1 ? partes.sublist(1).join(' · ') : texto;
    final subcategoria = partes.length > 1 ? partes.first : '';
    return Tooltip(
      message: '$categoria › $texto\n$n falla(s) · ${porcentaje.toStringAsFixed(0)}% de las fallas de ${equipo.toUpperCase()}',
      waitDuration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              child: Text('$posicion', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(falla,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black87)),
                      ),
                      const SizedBox(width: 8),
                      Text('$n', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _navy)),
                      SizedBox(
                        width: 40,
                        child: Text('${porcentaje.toStringAsFixed(0)}%',
                            textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          subcategoria.isEmpty ? categoria : '$categoria · $subcategoria',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxN == 0 ? 0 : n / maxN,
                      minHeight: 6,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionGarantias(List<ResumenTicketDash> data) {
    final garantias = data.where((r) => r.esReclamoGarantia).toList(growable: false);
    var nota = '${garantias.length} de ${data.length} tickets (con los filtros actuales) son reclamos de garantía.';
    if (garantias.isNotEmpty && garantias.length < 5) {
      nota += ' Muestra pequeña — interpretar las proporciones con cautela.';
    }

    nota += ' Incluye anulados. Para ver clientes, equipos o marcas de las garantías, use el filtro Requerimiento = Reclamo de garantía.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Text(nota, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
        ),
        _grid([
          _card(
            titulo: 'Dictamen de garantía',
            nota: 'Reclamos de garantía: «Aprobada» = garantía aprobada por ingeniería · «Rechazada» = auditoría «GARANTÍA RECHAZADA - PASA A FACTURACIÓN CLIENTE» · «Sin dictamen» = aún en revisión.',
            child: _donaTickets(
              garantias,
              (r) => r.dictamenGarantia ?? 'Sin dictamen',
              colorPorGrupo: const {'Aprobada': _good, 'Rechazada': _bad, 'Sin dictamen': Color(0xFF9AA5B1)},
            ),
          ),
        ]),
      ],
    );
  }


  // =========================================================================
  // 📋 TABLA DE DETALLE — virtualizada con ListView.builder (no DataTable),
  // para que siga siendo fluida aunque haya miles de tickets: solo se
  // construyen las filas visibles en pantalla, no todas de una vez.
  // =========================================================================
  static const List<_ColumnaTabla> _columnasBase = [
    _ColumnaTabla('Ticket', 110, 'id'),
    _ColumnaTabla('Cliente', 130, 'clienteId'),
    _ColumnaTabla('Equipo', 100, 'equipo'),
    _ColumnaTabla('Marca', 100, 'marca'),
    _ColumnaTabla('Falla reportada', 220, 'fallaReportada'),
    _ColumnaTabla('Lugar', 90, 'lugarAtencion'),
    _ColumnaTabla('Sede', 90, 'sede'),
    _ColumnaTabla('Tipo de garantía', 130, 'tipoGarantia'),
    _ColumnaTabla('Creación', 130, 'fecha_creacion'),
    _ColumnaTabla('Últ. actualización', 150, 'fecha_actualizacion'),
    _ColumnaTabla('Días', 70, 'dias_totales'),
    _ColumnaTabla('Pasos', 70, 'num_pasos'),
    _ColumnaTabla('Estado', 150, 'estado_bucket'),
  ];

  // 🆕 Columnas de documentos, agrupadas por trámite lógico (no por variable
  // cruda de Firestore). Cada una define cómo sacar la lista de URLs de una
  // fila (`documentos`) — la propia definición de la columna no dice nada
  // sobre si hay datos o no, eso se decide en `_columnasPara` según el
  // conjunto de tickets filtrado actualmente en pantalla.
  static final List<_ColumnaTabla> _columnasDocDefinidas = [
    _ColumnaTabla('Acta', 90, 'doc_acta', documentos: (r) => r.documentosActa),
    _ColumnaTabla('Evidencia recepción', 140, 'doc_evidencia_recepcion', documentos: (r) => r.documentosEvidenciaRecepcion),
    _ColumnaTabla('Evaluación', 105, 'doc_evaluacion', documentos: (r) => r.documentosEvaluacion),
    _ColumnaTabla('Proforma', 95, 'doc_proforma', documentos: (r) => r.documentosProforma),
    _ColumnaTabla('Compras', 90, 'doc_compras', documentos: (r) => r.documentosCompras),
    _ColumnaTabla('Evidencia trabajo', 135, 'doc_evidencia', documentos: (r) => r.documentosEvidenciaTrabajo),
    _ColumnaTabla('Entrega', 90, 'doc_entrega', documentos: (r) => r.documentosEntrega),
    _ColumnaTabla('Foto horómetro', 120, 'doc_garantia', documentos: (r) => r.documentosGarantia),
  ];

  // ⚙️ "No pongas columnas por gusto, solo si tienen lo pones sino no": una
  // columna de documentos solo aparece si AL MENOS un ticket, dentro del
  // conjunto ya filtrado que se está mostrando, tiene algo ahí.
  List<_ColumnaTabla> _columnasPara(List<ResumenTicketDash> data) {
    final columnasDoc = _columnasDocDefinidas.where(
      (col) => data.any((r) => col.documentos!(r).isNotEmpty),
    );
    return [..._columnasBase, ...columnasDoc];
  }

  double _anchoTotal(List<_ColumnaTabla> columnas) => columnas.fold(0.0, (s, c) => s + c.ancho);

  Widget _headerCelda(_ColumnaTabla col) {
    final activo = _sortKey == col.clave;
    // 🆕 Las columnas de documentos no son ordenables (no tiene sentido
    // ordenar por lista de links), así que no reaccionan al tap.
    final ordenable = col.documentos == null;
    return InkWell(
      onTap: !ordenable
          ? null
          : () => setState(() {
                if (_sortKey == col.clave) {
                  _sortAsc = !_sortAsc;
                } else {
                  _sortKey = col.clave;
                  _sortAsc = true;
                }
              }),
      child: Container(
        width: col.ancho,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                col.etiqueta,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (activo) Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward, size: 13, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _celda(double ancho, {String texto = '', Widget? child}) {
    return SizedBox(
      width: ancho,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: child ?? Text(texto, style: const TextStyle(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  // 🆕 Abre un link de documento. Si hay más de uno en el grupo, primero
  // deja elegir cuál (hoja inferior con nombres condensados); si hay uno
  // solo, lo abre directo con el navegador/app del sistema.
  Future<void> _abrirDocumento(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final abierto = await canLaunchUrl(uri) ? await launchUrl(uri, mode: LaunchMode.externalApplication) : false;
    if (!abierto && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el documento.'), backgroundColor: _bad),
      );
    }
  }

  void _elegirYAbrirDocumento(BuildContext context, String ticketId, List<String> urls) {
    if (urls.length == 1) {
      _abrirDocumento(context, urls.first);
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (contextHoja) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Documentos — $ticketId', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (var i = 0; i < urls.length; i++)
              ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined, color: _teal),
                title: Text('Documento ${i + 1}', style: const TextStyle(fontSize: 13.5)),
                onTap: () {
                  Navigator.pop(contextHoja);
                  _abrirDocumento(context, urls[i]);
                },
              ),
          ],
        ),
      ),
    );
  }

  // 🆕 Celda-link condensada: "Ver (n)" cuando hay n documentos, o vacío si
  // no hay ninguno (la columna entera solo existe si algún ticket sí tiene
  // datos, pero fila por fila puede variar).
  Widget _celdaDocumentos(double ancho, String ticketId, List<String> urls) {
    if (urls.isEmpty) return _celda(ancho);
    final etiqueta = urls.length == 1 ? 'Ver' : 'Ver (${urls.length})';
    return _celda(
      ancho,
      child: InkWell(
        onTap: () => _elegirYAbrirDocumento(context, ticketId, urls),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link, size: 13, color: _teal),
            const SizedBox(width: 3),
            Text(etiqueta, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _teal, decoration: TextDecoration.underline)),
          ],
        ),
      ),
    );
  }

  Widget _filaTabla(List<_ColumnaTabla> columnas, ResumenTicketDash r, int index) {
    // 🔧 key estable: así Flutter reconoce esta fila como "la misma" entre
    // reconstrucciones (nuevo snapshot de Firestore, cambio de filtros)
    // en vez de destruirla y recrearla — reduce el riesgo del crash de
    // selección de texto (ver nota en _tablaDetalle).
    return Container(
      key: ValueKey(r.id),
      color: index.isEven ? Colors.white : const Color(0xFFF7FAFA),
      child: Row(
        children: [
          _celda(columnas[0].ancho, child: Text(r.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5), overflow: TextOverflow.ellipsis)),
          _celda(columnas[1].ancho, texto: r.clienteId),
          _celda(columnas[2].ancho, texto: r.equipo),
          _celda(columnas[3].ancho, texto: r.marca),
          _celda(columnas[4].ancho, texto: r.fallaReportada),
          _celda(columnas[5].ancho, texto: r.lugarAtencion),
          _celda(columnas[6].ancho, texto: r.sede),
          _celda(columnas[7].ancho, texto: r.tipoGarantia ?? ''),
          _celda(columnas[8].ancho, texto: _fmtFechaHora(r.fechaCreacion)),
          _celda(columnas[9].ancho, texto: _fmtFechaHora(r.fechaActualizacion)),
          _celda(columnas[10].ancho, texto: r.diasTotales.toString()),
          _celda(columnas[11].ancho, texto: r.numPasos.toString()),
          _celda(columnas[12].ancho, child: _pillEstado(r.estadoNombre)),
          // 🆕 Columnas de documentos (solo las que se agregaron para este
          // conjunto de datos — ver _columnasPara).
          for (final col in columnas.skip(_columnasBase.length))
            _celdaDocumentos(col.ancho, r.id, col.documentos!(r)),
        ],
      ),
    );
  }

  Widget _tablaDetalle(List<ResumenTicketDash> data) {
    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No hay tickets que coincidan con los filtros.', style: TextStyle(color: Colors.grey.shade500))),
      );
    }

    // 🆕 Columnas de documentos calculadas para ESTE conjunto de datos (con
    // los filtros actuales aplicados) — así una columna solo aparece si
    // hay algo que mostrar en ella.
    final columnas = _columnasPara(data);

    // 🔧 Selección de texto habilitada también aquí: cada fila lleva su
    // propia `key: ValueKey(r.id)` (ver _filaTabla) para que Flutter la
    // reutilice entre reconstrucciones (snapshot nuevo de Firestore,
    // cambio de filtros) en vez de destruirla y recrearla — eso reduce
    // mucho el riesgo del crash "RenderBox was not laid out" que puede
    // disparar el SelectionArea global (main.dart) cuando esta tabla, la
    // más pesada de la app, se reconstruye entera de golpe. No es una
    // garantía al 100% (es un bug del motor de Flutter Web), pero ataca
    // la causa real: widgets destruidos a mitad del escaneo de selección.
    // 🆕 Scrollbar SIEMPRE visible y arrastrable con el mouse (no solo con
    // gestos táctiles/trackpad): sin esto no había ninguna señal de que la
    // tabla tenía más columnas hacia la derecha en un escritorio normal.
    return Scrollbar(
      controller: _tablaScrollController,
      thumbVisibility: true,
      trackVisibility: true,
      child: SingleChildScrollView(
        controller: _tablaScrollController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _anchoTotal(columnas),
          child: Column(
            children: [
              Container(
                color: _navy,
                child: Row(children: columnas.map(_headerCelda).toList()),
              ),
              SizedBox(
                height: 480,
                // 🚀 itemExtent fijo: Flutter no necesita medir cada fila para
                // saber su tamaño/posición, lo que hace el scroll de listas
                // grandes notablemente más liviano.
                child: ListView.builder(
                  itemCount: data.length,
                  itemExtent: 46,
                  itemBuilder: (context, index) => _filaTabla(columnas, data[index], index),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 📊 INDICADORES DE POSTVENTA (Excel, un reporte por equipo). No usa los
  // filtros del dashboard: calcula sobre todos los tickets cargados, en el
  // rango de días elegido. Admin y supervisor General / sin equipo ven los 3
  // botones; el supervisor de un equipo, solo el suyo; otros roles, ninguno.
  // =========================================================================
  static const List<String> _equiposIndicadores = ['Caracol', 'Contador', 'Cosechadora'];

  List<String> _equiposIndicadoresPermitidos() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! Authenticated) return const [];
    final u = auth.usuario;
    if (u.rol == RolUsuario.admin) return _equiposIndicadores;
    if (u.rol != RolUsuario.supervisor) return const [];
    final propio = switch (u.segmento) {
      SegmentoOperativo.caracol => 'Caracol',
      SegmentoOperativo.contador => 'Contador',
      SegmentoOperativo.cosechadora => 'Cosechadora',
      _ => null,
    };
    return propio == null ? _equiposIndicadores : [propio];
  }

  Future<void> _generarIndicadores(String equipo) async {
    String dia(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    String clave(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final fechas = widget.tickets.map((t) => t.fechaCreacionTicket).whereType<DateTime>();
    final primeraFecha = fechas.isEmpty ? DateTime(ahora.year) : fechas.reduce((a, b) => a.isBefore(b) ? a : b);
    final minimo = DateTime(primeraFecha.year, primeraFecha.month, primeraFecha.day);
    var desde = DateTime(ahora.year, 1, 1);
    if (desde.isBefore(minimo)) desde = minimo;
    var hasta = hoy;

    final rango = await showDialog<(DateTime, DateTime)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          final valido = !desde.isAfter(hasta);
          Widget selector(String etiqueta, DateTime valor, ValueChanged<DateTime> alCambiar) => Row(
                children: [
                  SizedBox(width: 60, child: Text(etiqueta)),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(dia(valor)),
                    onPressed: () async {
                      final elegido = await showDatePicker(
                        context: ctx,
                        initialDate: valor,
                        firstDate: minimo.isBefore(DateTime(2020)) ? minimo : DateTime(2020),
                        lastDate: hoy,
                      );
                      if (elegido != null) setDialog(() => alCambiar(elegido));
                    },
                  ),
                ],
              );
          return AlertDialog(
            title: Text('Indicadores de Postventa — $equipo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Elija el rango de fechas (ambos días incluidos). Se genera un Excel con los 3 indicadores, '
                    'el desglose de fallas en pasteles y el detalle de tickets.'),
                const SizedBox(height: 16),
                selector('Desde:', desde, (v) => desde = v),
                const SizedBox(height: 8),
                selector('Hasta:', hasta, (v) => hasta = v),
                if (!valido)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('"Desde" no puede ser posterior a "Hasta".', style: TextStyle(color: _bad, fontSize: 12)),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Generar Excel'),
                onPressed: valido ? () => Navigator.pop(ctx, (desde, hasta)) : null,
              ),
            ],
          );
        },
      ),
    );
    if (rango == null || !mounted) return;

    try {
      final datos = IndicadoresPostventaService.calcular(
        tickets: widget.tickets,
        desde: rango.$1,
        hasta: rango.$2,
        equipo: equipo,
      );
      final bytes = GeneradorExcelIndicadoresPostventa.generar(datos);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Indicadores_${equipo}_${clave(rango.$1)}_a_${clave(rango.$2)}.xlsx',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar el Excel de indicadores: $e'), backgroundColor: _bad),
      );
    }
  }

  // =========================================================================
  // 🚀 BUILD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F6),
      appBar: AppBar(
        title: const Text('Dashboard de Tickets', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          for (final equipo in _equiposIndicadoresPermitidos())
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.assessment_outlined),
                label: Text('Indicadores $equipo'),
                onPressed: () => _generarIndicadores(equipo),
              ),
            ),
        ],
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state.status == DashboardStatus.error) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 48, color: _bad),
                    const SizedBox(height: 12),
                    Text(state.mensaje, textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          final datos = state.datos;
          if (state.status != DashboardStatus.listo || datos == null) {
            return const Center(child: CircularProgressIndicator(color: _navy));
          }

          final filtrados = _filtrar(datos.resumen);
          final ordenados = _ordenar(filtrados);
          final segmentosFiltrados = _segmentosDe(filtrados, datos.segmentos);

          // 🔒 "Tiempo promedio por proceso" solo debe salir de tickets
          // FINALIZADOS (ver nota en _seccionEquipo): un ticket en curso
          // no tiene un tiempo cerrado todavía, y uno anulado no
          // representa el comportamiento normal del proceso.
          final idsFinalizados = filtrados.where((r) => r.estadoBucket == 'Finalizado').map((r) => r.id).toSet();
          final segmentosFinalizados = segmentosFiltrados.where((s) => idsFinalizados.contains(s.ticketId)).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kpiRow(_construirKpis(filtrados)),
                _buildFiltros(datos, filtrados.length),
                _seccionTitulo('Volumen y tendencia'),
                _seccionTendencia(filtrados),
                _seccionTitulo('Por equipo'),
                _seccionEquipo(filtrados),
                _seccionTitulo('Tiempo por proceso'),
                _seccionDepartamentos(segmentosFinalizados),
                _seccionTitulo('Otras dimensiones'),
                _seccionDimensiones(filtrados),
                _seccionTitulo('Clientes'),
                _seccionClientesFallas(filtrados),
                _seccionTitulo('Diagnóstico de fallas'),
                _seccionDiagnosticoFallas(filtrados),
                _seccionTitulo('Análisis de garantías (reclamo de garantía)'),
                _seccionGarantias(filtrados),
                _seccionTitulo('Detalle de tickets'),
                _card(
                  nota: 'Toca un encabezado para ordenar. Los filtros de arriba también aplican a esta tabla.',
                  child: _tablaDetalle(ordenados),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    "Panel generado con los datos ya cargados de la colección 'tickets' · ${datos.resumen.length} tickets",
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ColumnaTabla {
  final String etiqueta;
  final double ancho;
  final String clave;
  // 🆕 Si no es null, esta es una columna de "documentos": en vez de leer
  // un campo plano, extrae la lista de URLs de la fila con este getter y
  // la tabla la pinta como link condensado en lugar de texto.
  final List<String> Function(ResumenTicketDash r)? documentos;
  const _ColumnaTabla(this.etiqueta, this.ancho, this.clave, {this.documentos});
}

// 🍩 Porción de un gráfico de dona interactivo: etiqueta, valor, color y
// las líneas de detalle que se muestran al pasar el mouse.
class _PorcionDona {
  final String clave;
  final String etiqueta;
  final int valor;
  final Color color;
  final List<String> detalle;
  const _PorcionDona({
    required this.clave,
    required this.etiqueta,
    required this.valor,
    required this.color,
    required this.detalle,
  });
}

// 🍩 Dona con leyenda en lista: al pasar el mouse (por la dona o la leyenda)
// la porción se resalta y se muestra su detalle; si hay `onSeleccionar`,
// el clic selecciona la porción. El estado del mouse vive aquí (no en la
// página) para no recalcular todo el dashboard en cada movimiento.
class _DonaInteractiva extends StatefulWidget {
  final List<_PorcionDona> porciones;
  final String textoTotal;
  final String? seleccionada;
  final ValueChanged<String>? onSeleccionar;

  const _DonaInteractiva({
    required this.porciones,
    required this.textoTotal,
    this.seleccionada,
    this.onSeleccionar,
  });

  @override
  State<_DonaInteractiva> createState() => _DonaInteractivaState();
}

class _DonaInteractivaState extends State<_DonaInteractiva> {
  int? _hover;

  void _setHover(int? i) {
    if (_hover != i) setState(() => _hover = i);
  }

  @override
  Widget build(BuildContext context) {
    final ps = widget.porciones;
    if (ps.isEmpty) {
      return SizedBox(height: 160, child: Center(child: Text('Sin datos', style: TextStyle(color: Colors.grey.shade500))));
    }
    final total = ps.fold<int>(0, (s, p) => s + p.valor);
    final maxValor = ps.map((p) => p.valor).reduce((a, b) => a > b ? a : b);
    final selIdx = widget.seleccionada == null ? -1 : ps.indexWhere((p) => p.clave == widget.seleccionada);
    final hover = (_hover != null && _hover! < ps.length) ? _hover : null;
    final foco = hover ?? (selIdx >= 0 ? selIdx : null);
    String pct(int v) => total == 0 ? '0' : (v / total * 100).toStringAsFixed(0);

    final dona = SizedBox(
      width: 210,
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 58,
              pieTouchData: PieTouchData(
                touchCallback: (event, respuesta) {
                  final idx = respuesta?.touchedSection?.touchedSectionIndex;
                  final valido = idx != null && idx >= 0 && idx < ps.length;
                  if (event is FlTapUpEvent && valido && widget.onSeleccionar != null) {
                    widget.onSeleccionar!(ps[idx].clave);
                  }
                  if (!event.isInterestedForInteractions || !valido) {
                    _setHover(null);
                    return;
                  }
                  _setHover(idx);
                },
              ),
              sections: [
                for (var i = 0; i < ps.length; i++)
                  PieChartSectionData(
                    value: ps[i].valor.toDouble(),
                    color: (selIdx >= 0 && selIdx != i) ? ps[i].color.withValues(alpha: 0.30) : ps[i].color,
                    radius: i == foco ? 44 : 36,
                    title: total > 0 && ps[i].valor / total >= 0.07 ? '${pct(ps[i].valor)}%' : '',
                    titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
              ],
            ),
          ),
          IgnorePointer(
            child: SizedBox(
              width: 104,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: foco == null
                    ? [
                        Text('$total', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _navy)),
                        Text(widget.textoTotal, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      ]
                    : [
                        Text('${pct(ps[foco].valor)}%',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ps[foco].color)),
                        Text(ps[foco].etiqueta,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _navy)),
                        Text('${ps[foco].valor} ${widget.textoTotal}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                      ],
              ),
            ),
          ),
        ],
      ),
    );

    final leyenda = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < ps.length; i++)
          MouseRegion(
            onEnter: (_) => _setHover(i),
            onExit: (_) => _setHover(null),
            cursor: widget.onSeleccionar != null ? SystemMouseCursors.click : MouseCursor.defer,
            child: GestureDetector(
              onTap: widget.onSeleccionar == null ? null : () => widget.onSeleccionar!(ps[i].clave),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: i == foco ? ps[i].color.withValues(alpha: 0.10) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: selIdx == i ? ps[i].color : Colors.transparent),
                ),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: ps[i].color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ps[i].etiqueta,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                          const SizedBox(height: 3),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: maxValor == 0 ? 0 : ps[i].valor / maxValor,
                              minHeight: 5,
                              color: ps[i].color,
                              backgroundColor: ps[i].color.withValues(alpha: 0.12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${ps[i].valor}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _navy)),
                    SizedBox(
                      width: 40,
                      child: Text('${pct(ps[i].valor)}%',
                          textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    final panelDetalle = Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: foco == null ? Colors.grey.shade50 : ps[foco].color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: foco == null ? Colors.grey.shade200 : ps[foco].color.withValues(alpha: 0.35)),
      ),
      child: foco == null
          ? Text(
              widget.onSeleccionar != null
                  ? 'Pase el mouse por el gráfico o la lista para ver el detalle. Clic para filtrar por esa categoría.'
                  : 'Pase el mouse por el gráfico o la lista para ver el detalle.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ps[foco].etiqueta, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ps[foco].color)),
                const SizedBox(height: 4),
                for (final linea in ps[foco].detalle)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(linea, style: const TextStyle(fontSize: 11.5, color: Colors.black87)),
                  ),
              ],
            ),
    );

    return LayoutBuilder(builder: (context, c) {
      final derecha = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [leyenda, panelDetalle]);
      if (c.maxWidth >= 600) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [dona, const SizedBox(width: 16), Expanded(child: derecha)],
        );
      }
      return Column(children: [Center(child: dona), const SizedBox(height: 12), derecha]);
    });
  }
}
