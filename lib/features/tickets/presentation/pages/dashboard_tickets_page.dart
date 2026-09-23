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
import '../../domain/entities/ticket_entity.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';

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
  'Creado', 'En camino', 'Recepción física', 'Revisión garantía', 'Comercial',
  'Cotizado', 'Costos', 'Compras', 'Bodega', 'Proceso de trabajo',
  'Validación facturación', 'Entrega', 'Finalizado', 'Anulado',
];

Color _colorPorNombreEstado(String nombre) {
  if (nombre == 'Finalizado') return _good;
  if (nombre == 'Anulado') return _bad;
  if (nombre == 'Validación facturación') return _warn;
  return _slate;
}

// 🆕 Orden y color fijos para los segmentos operativos (tipo de equipo del
// ticket) — así el color de cada uno es siempre el mismo en todo el
// dashboard (gráfico agrupado + leyenda + desglose por departamento).
const List<String> _ordenSegmentosDash = ['CARACOL', 'COSECHADORA', 'CONTADOR', 'GENERAL'];
const Map<String, Color> _coloresPorSegmentoDash = {
  'CARACOL': _teal,
  'COSECHADORA': _aqua,
  'CONTADOR': _sand,
  'GENERAL': _slate,
};
Color _colorPorSegmentoDash(String segmento) => _coloresPorSegmentoDash[segmento] ?? _slate;

String _dosDigitos(int n) => n.toString().padLeft(2, '0');
String _fmtFecha(DateTime? d) => d == null ? '' : '${d.year}-${_dosDigitos(d.month)}-${_dosDigitos(d.day)}';
String _fmtFechaHora(DateTime? d) => d == null ? '' : '${_fmtFecha(d)} ${_dosDigitos(d.hour)}:${_dosDigitos(d.minute)}';
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
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatefulWidget {
  const _DashboardView();

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  String? _marca;
  String? _equipo;
  String? _sede;
  String? _tipoGarantia;
  String? _estadoBucket;
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;

  String _sortKey = 'fecha_creacion';
  bool _sortAsc = false;

  void _limpiarFiltros() {
    setState(() {
      _marca = null;
      _equipo = null;
      _sede = null;
      _tipoGarantia = null;
      _estadoBucket = null;
      _fechaDesde = null;
      _fechaHasta = null;
    });
  }

  List<ResumenTicketDash> _filtrar(List<ResumenTicketDash> resumen) {
    return resumen.where((r) {
      if (_marca != null && r.marca != _marca) return false;
      if (_equipo != null && r.equipo != _equipo) return false;
      if (_sede != null && r.sede != _sede) return false;
      if (_tipoGarantia != null && (r.tipoGarantia ?? '') != _tipoGarantia) return false;
      if (_estadoBucket != null && r.estadoBucket != _estadoBucket) return false;
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
        _sede == null &&
        _tipoGarantia == null &&
        _estadoBucket == null &&
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
      case 'estado_bucket': va = a.estadoBucket; vb = b.estadoBucket; break;
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

  Widget _kpiCard(String valor, String etiqueta, Color color) {
    return Container(
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
          Text(valor, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 2),
          Text(etiqueta, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
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
          _dropdownFiltro('Sede', _sede, datos.sedes, (v) => setState(() => _sede = v)),
          _dropdownFiltro('Garantía', _tipoGarantia, datos.tiposGarantia, (v) => setState(() => _tipoGarantia = v)),
          _dropdownFiltro('Estado', _estadoBucket, datos.estadosBucket, (v) => setState(() => _estadoBucket = v)),
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
  }) {
    if (labels.isEmpty) {
      return SizedBox(height: height, child: Center(child: Text('Sin datos', style: TextStyle(color: Colors.grey.shade500))));
    }
    final maxValor = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    final maxY = maxValor <= 0 ? 1.0 : maxValor * 1.25;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 4 <= 0 ? 1 : maxY / 4),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                  final texto = labels[i].length > 10 ? '${labels[i].substring(0, 9)}…' : labels[i];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Transform.rotate(
                      angle: labels.length > 6 ? -0.7 : 0,
                      child: Text(texto, style: const TextStyle(fontSize: 10, color: Colors.black87)),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final String valorTexto = formateadorTooltip != null
                    ? formateadorTooltip(rod.toY)
                    : (mostrarDecimales ? rod.toY.toStringAsFixed(1) : rod.toY.toInt().toString());
                return BarTooltipItem(
                  '${labels[group.x]}\n$valorTexto',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                );
              },
            ),
          ),
          barGroups: List.generate(labels.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  color: color,
                  width: labels.length > 10 ? 10 : 22,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // --- Gráfico de barras AGRUPADAS: un grupo de barras por cada elemento
  // del eje X (ej. departamento), con una barra por cada serie (ej.
  // segmento operativo) dentro del grupo — para comparar sub-categorías
  // dentro de cada categoría principal. Incluye su propia leyenda de
  // colores por serie, igual que _pieChartFl. ---
  Widget _barChartAgrupadoFl({
    required List<String> gruposLabels,
    required List<String> seriesLabels,
    required List<Color> seriesColores,
    required List<List<double>> valores, // valores[grupo][serie]
    double height = 240,
    String Function(double)? formateadorTooltip,
  }) {
    if (gruposLabels.isEmpty || seriesLabels.isEmpty) {
      return SizedBox(height: height, child: Center(child: Text('Sin datos', style: TextStyle(color: Colors.grey.shade500))));
    }
    var maxValor = 0.0;
    for (final fila in valores) {
      for (final v in fila) {
        if (v > maxValor) maxValor = v;
      }
    }
    final maxY = maxValor <= 0 ? 1.0 : maxValor * 1.25;
    final anchoBarra = seriesLabels.length > 3 ? 7.0 : 10.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 4 <= 0 ? 1 : maxY / 4),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 46,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= gruposLabels.length) return const SizedBox.shrink();
                      final texto = gruposLabels[i].length > 10 ? '${gruposLabels[i].substring(0, 9)}…' : gruposLabels[i];
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Transform.rotate(
                          angle: gruposLabels.length > 6 ? -0.7 : 0,
                          child: Text(texto, style: const TextStyle(fontSize: 10, color: Colors.black87)),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final String valorTexto = formateadorTooltip != null
                        ? formateadorTooltip(rod.toY)
                        : rod.toY.toStringAsFixed(1);
                    final String serieNombre = rodIndex < seriesLabels.length ? seriesLabels[rodIndex] : '';
                    return BarTooltipItem(
                      '${gruposLabels[group.x]} · $serieNombre\n$valorTexto',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    );
                  },
                ),
              ),
              barGroups: List.generate(gruposLabels.length, (i) {
                return BarChartGroupData(
                  x: i,
                  barsSpace: 3,
                  barRods: List.generate(seriesLabels.length, (j) {
                    return BarChartRodData(
                      toY: valores[i][j],
                      color: seriesColores[j % seriesColores.length],
                      width: anchoBarra,
                      borderRadius: BorderRadius.circular(3),
                    );
                  }),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: List.generate(seriesLabels.length, (j) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: seriesColores[j % seriesColores.length], borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                Text(seriesLabels[j], style: const TextStyle(fontSize: 11.5, color: Colors.black87)),
              ],
            );
          }),
        ),
      ],
    );
  }

  // --- Gráfico circular (pie / donut) con leyenda propia ---
  // Si hay más de 8 categorías, agrupa el resto en "Otros" — evita pintar
  // decenas de porciones ilegibles y mantiene el widget liviano.
  Widget _pieChartFl({
    required Map<String, int> counts,
    List<Color>? colors,
    bool donut = false,
    double height = 200,
  }) {
    var entries = counts.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return SizedBox(height: height, child: Center(child: Text('Sin datos', style: TextStyle(color: Colors.grey.shade500))));
    }
    if (entries.length > 8) {
      final principales = entries.take(7).toList();
      final restoTotal = entries.skip(7).fold<int>(0, (s, e) => s + e.value);
      entries = [...principales, MapEntry('Otros', restoTotal)];
    }
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    final paleta = colors ?? _seriesColors;

    return Column(
      children: [
        SizedBox(
          height: height,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: donut ? height * 0.22 : 0,
              sections: List.generate(entries.length, (i) {
                final e = entries[i];
                final pct = total > 0 ? (e.value / total * 100) : 0.0;
                return PieChartSectionData(
                  value: e.value.toDouble(),
                  color: paleta[i % paleta.length],
                  title: '${pct.toStringAsFixed(0)}%',
                  radius: donut ? height * 0.20 : height * 0.42,
                  titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: List.generate(entries.length, (i) {
            final e = entries[i];
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: paleta[i % paleta.length], shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('${e.key} (${e.value})', style: const TextStyle(fontSize: 11.5, color: Colors.black87)),
              ],
            );
          }),
        ),
      ],
    );
  }

  // --- Ranking horizontal (barras de progreso) para conteos con etiquetas largas ---
  Widget _rankingBars({
    required Map<String, int> counts,
    Color color = _tealLight,
    Map<String, Color>? coloresPorEtiqueta,
    int? topN,
    double maxLabelWidth = 140,
    List<String>? ordenFijo,
  }) {
    List<MapEntry<String, int>> entries;
    if (ordenFijo != null) {
      entries = ordenFijo.where((k) => (counts[k] ?? 0) > 0).map((k) => MapEntry(k, counts[k]!)).toList();
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
      case 'Cerrado': bg = const Color(0xFFE2F3EA); fg = _good; break;
      case 'Anulado': bg = const Color(0xFFFBE6E2); fg = _bad; break;
      case 'Validación facturación': bg = const Color(0xFFFDF2DF); fg = _warn; break;
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
    var conGarantia = 0;
    var sumaDias = 0.0;
    for (final r in data) {
      if (r.estadoBucket == 'Cerrado') cerrados++;
      if (r.estadoBucket == 'Anulado') anulados++;
      final tg = r.tipoGarantia;
      if (tg != null && tg.isNotEmpty && tg != 'pendiente') conGarantia++;
      sumaDias += r.diasTotales;
    }
    final enProceso = total - cerrados - anulados;
    final avgDias = total > 0 ? sumaDias / total : 0.0;

    return [
      _kpiCard(total.toString(), 'Tickets (filtrados)', _tealLight),
      _kpiCard(cerrados.toString(), 'Cerrados', _good),
      _kpiCard(enProceso.toString(), 'En proceso', _warn),
      _kpiCard(anulados.toString(), 'Anulados', _bad),
      _kpiCard(conGarantia.toString(), 'Con garantía', _slate),
      _kpiCard(avgDias.toStringAsFixed(1), 'Días promedio (ciclo)', _sand),
    ];
  }

  // =========================================================================
  // 📈 SECCIONES
  // =========================================================================
  Widget _seccionTendencia(List<ResumenTicketDash> data) {
    final conteoFecha = <String, int>{};
    final conteoEstado = <String, int>{};
    for (final r in data) {
      final f = _fmtFecha(r.fechaCreacion);
      if (f.isNotEmpty) conteoFecha[f] = (conteoFecha[f] ?? 0) + 1;
      conteoEstado[r.estadoNombre] = (conteoEstado[r.estadoNombre] ?? 0) + 1;
    }
    final fechas = conteoFecha.keys.toList()..sort();
    final valoresFecha = fechas.map((f) => conteoFecha[f]!.toDouble()).toList();
    final coloresEstado = {for (final n in _ordenEstadosPipeline) n: _colorPorNombreEstado(n)};

    return _grid([
      _card(
        titulo: 'Tickets creados por fecha',
        nota: 'Fecha de creación del requerimiento (primer registro del ticket)',
        child: _barChartFl(labels: fechas, values: valoresFecha, color: _tealLight),
      ),
      _card(
        titulo: 'Estado actual de los tickets',
        nota: 'Etapa donde está cada ticket ahora mismo — en orden del flujo del proceso',
        child: _rankingBars(counts: conteoEstado, ordenFijo: _ordenEstadosPipeline, coloresPorEtiqueta: coloresEstado, maxLabelWidth: 150),
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
    final finalizados = data.where((r) => r.estadoBucket == 'Cerrado');
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
        nota: 'Caracol, cosechadora, contador',
        child: _barChartFl(labels: labelsEquipo, values: valoresEquipo, color: _aqua),
      ),
      _card(
        titulo: 'Tiempo de atención promedio por equipo',
        nota: 'Horas transcurridas desde creación hasta el último registro (promedio por ticket, solo tickets finalizados)',
        child: _barChartFl(labels: labelsEquipo, values: valoresHoras, color: _sand, mostrarDecimales: true),
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
    final sumaPorProceso = <String, double>{};
    final conteoPorProceso = <String, int>{};
    // 🆕 proceso -> usuario -> [suma horas, conteo] — permite desglosar el
    // tiempo de un proceso (ej. COMPRAS) por cada persona que lo atendió,
    // en vez de un solo promedio mezclado.
    final porProcesoYUsuario = <String, Map<String, List<double>>>{};

    for (final s in segmentos) {
      final proceso = _procesoDeAccion(s.accion);
      sumaPorProceso[proceso] = (sumaPorProceso[proceso] ?? 0) + s.horas;
      conteoPorProceso[proceso] = (conteoPorProceso[proceso] ?? 0) + 1;

      final usuario = s.usuarioNombre.trim().isEmpty ? 'Sin asignar' : s.usuarioNombre;
      final porUsuario = porProcesoYUsuario.putIfAbsent(proceso, () => {});
      final acumulado = porUsuario.putIfAbsent(usuario, () => [0, 0]);
      acumulado[0] += s.horas;
      acumulado[1] += 1;
    }

    final labels = sumaPorProceso.keys.toList()..sort();
    final valoresProceso = labels.map((d) => sumaPorProceso[d]! / conteoPorProceso[d]!).toList();

    // 📋 Leyenda siempre visible: proceso (promedio general, en
    // días/horas/minutos) ordenado de mayor a menor demora, con el
    // desglose por usuario debajo cuando el proceso tuvo más de una
    // persona atendiendo tickets.
    final ordenProcesos = [...labels]
      ..sort((a, b) => (sumaPorProceso[b]! / conteoPorProceso[b]!).compareTo(sumaPorProceso[a]! / conteoPorProceso[a]!));

    return _card(
      titulo: 'Tiempo promedio por proceso',
      nota: 'Tiempo promedio entre que un ticket llega a una etapa del flujo y esa etapa marca su paso como completado, desglosado por la persona que lo atendió (solo tickets finalizados)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _barChartFl(
            labels: labels,
            values: valoresProceso,
            color: _slate,
            mostrarDecimales: true,
            formateadorTooltip: _fmtDuracionHoras,
          ),
          if (ordenProcesos.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...ordenProcesos.map((proceso) {
              final promedioGeneral = sumaPorProceso[proceso]! / conteoPorProceso[proceso]!;
              final porUsuario = porProcesoYUsuario[proceso] ?? const {};
              final usuariosOrdenados = porUsuario.keys.toList()
                ..sort((a, b) => (porUsuario[b]![0] / porUsuario[b]![1]).compareTo(porUsuario[a]![0] / porUsuario[a]![1]));

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(proceso, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        Text(
                          _fmtDuracionHoras(promedioGeneral),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _slate),
                        ),
                      ],
                    ),
                    // 🆕 Solo se desglosa por usuario cuando el proceso
                    // tuvo más de una persona atendiendo — si solo hubo
                    // una, ya coincide con la fila de arriba.
                    if (usuariosOrdenados.length > 1)
                      ...usuariosOrdenados.map((usuario) {
                        final par = porUsuario[usuario]!;
                        final promedioUsuario = par[1] == 0 ? 0.0 : par[0] / par[1];
                        return Padding(
                          padding: const EdgeInsets.only(left: 14, top: 2),
                          child: Row(
                            children: [
                              Icon(Icons.person_outline, size: 12, color: Colors.grey.shade500),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(usuario, style: TextStyle(fontSize: 11, color: Colors.grey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              Text(_fmtDuracionHoras(promedioUsuario), style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
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

  // 🆕 Clasifica la acción de auditoría de un paso del historial (texto
  // libre, ej. "FASE COSTOS - Código Proyecto Asignado: X") en el proceso
  // del flujo al que pertenece. Es un clasificador por palabras clave,
  // igual al patrón que ya se usa en otras pantallas para detectar
  // "caracol" por texto — no depende de un campo nuevo en Firestore, así
  // que funciona también con el historial ya guardado.
  // ⚠️ El orden de los checks importa cuando una acción menciona más de
  // una palabra clave (ej. una acción de bodega que menciona "taller" se
  // clasifica como Bodega, no como Proceso de Trabajo).
  String _procesoDeAccion(String accion) {
    final a = accion.toUpperCase();
    if (a.contains('GARANT')) return 'Revisión Garantía';
    if (a.contains('RECEP')) return 'Recepción';
    if (a.contains('COMERCIAL') || a.contains('COTIZA')) return 'Comercial';
    if (a.contains('COSTO')) return 'Costos';
    if (a.contains('COMPRA')) return 'Compras';
    if (a.contains('BODEGA') || a.contains('DESPACHO')) return 'Bodega';
    if (a.contains('TALLER') || a.contains('TRABAJO')) return 'Proceso de Trabajo';
    if (a.contains('FACTUR')) return 'Facturación';
    if (a.contains('ENTREGA') || a.contains('GUÍA') || a.contains('GUIA')) return 'Entrega';
    return 'Otro';
  }

  Widget _seccionDimensiones(List<ResumenTicketDash> data) {
    final conteoMarca = <String, int>{};
    final conteoReq = <String, int>{};
    final conteoLugar = <String, int>{};
    for (final r in data) {
      conteoMarca[r.marca] = (conteoMarca[r.marca] ?? 0) + 1;
      conteoReq[r.tipoRequerimientoEtiqueta] = (conteoReq[r.tipoRequerimientoEtiqueta] ?? 0) + 1;
      conteoLugar[r.lugarAtencion] = (conteoLugar[r.lugarAtencion] ?? 0) + 1;
    }
    return _grid([
      _card(titulo: 'Tickets por marca', child: _pieChartFl(counts: conteoMarca)),
      _card(titulo: 'Garantía vs. reparación regular', nota: 'Según tipo de requerimiento', child: _pieChartFl(counts: conteoReq, donut: true)),
      _card(titulo: 'Lugar de atención', child: _pieChartFl(counts: conteoLugar, donut: true, colors: const [_teal, _coral, _slate, _sand])),
    ], columnasAncho: 3);
  }

  Widget _seccionClientesFallas(List<ResumenTicketDash> data) {
    final conteoCliente = <String, int>{};
    final conteoFalla = <String, int>{};
    for (final r in data) {
      conteoCliente[r.clienteId] = (conteoCliente[r.clienteId] ?? 0) + 1;
      conteoFalla[r.fallaReportada] = (conteoFalla[r.fallaReportada] ?? 0) + 1;
    }
    return _grid([
      _card(titulo: 'Top clientes por # de tickets', child: _rankingBars(counts: conteoCliente, color: _teal, topN: 10, maxLabelWidth: 150)),
      _card(
        titulo: 'Fallas reportadas más frecuentes',
        nota: 'Top 8 — descripciones agrupadas por texto exacto',
        child: _rankingBars(counts: conteoFalla, color: _coral, topN: 8, maxLabelWidth: 170),
      ),
    ]);
  }

  Widget _seccionGarantias(List<ResumenTicketDash> data) {
    final garantias = data.where((r) => r.esReclamoGarantia).toList(growable: false);
    var nota = '${garantias.length} de ${data.length} tickets (con los filtros actuales) son reclamos de garantía.';
    if (garantias.isNotEmpty && garantias.length < 5) {
      nota += ' Muestra pequeña — interpretar las proporciones con cautela.';
    }

    final conteoCliente = <String, int>{};
    final conteoEquipo = <String, int>{};
    final conteoFalla = <String, int>{};
    final conteoMarca = <String, int>{};
    for (final r in garantias) {
      conteoCliente[r.clienteId] = (conteoCliente[r.clienteId] ?? 0) + 1;
      conteoEquipo[r.equipo] = (conteoEquipo[r.equipo] ?? 0) + 1;
      conteoFalla[r.fallaReportada] = (conteoFalla[r.fallaReportada] ?? 0) + 1;
      conteoMarca[r.marca] = (conteoMarca[r.marca] ?? 0) + 1;
    }

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
          _card(titulo: 'Garantías por cliente', child: _rankingBars(counts: conteoCliente, color: _coral, topN: 10, maxLabelWidth: 150)),
          _card(titulo: 'Garantías por tipo de equipo', child: _pieChartFl(counts: conteoEquipo)),
        ]),
        const SizedBox(height: 16),
        _grid([
          _card(
            titulo: 'Garantías por falla reportada',
            nota: 'Qué está fallando en los equipos que entran por garantía',
            child: _rankingBars(counts: conteoFalla, color: _sand, topN: 10, maxLabelWidth: 170),
          ),
          _card(
            titulo: '¿En qué estamos fallando? — Garantías por marca',
            nota: 'Ayuda a identificar si las fallas de garantía se concentran en equipos propios o en marcas de terceros',
            child: _rankingBars(counts: conteoMarca, color: _slate, topN: 10, maxLabelWidth: 150),
          ),
        ]),
      ],
    );
  }


  // ⏱️ Métricas de Trabajo Neto vs Tiempo de Espera (Trazabilidad Concurrente Justa)
  Widget _seccionTiemposNetosVsEspera(List<ResumenTicketDash> filtrados) {
    final ticketsConNetos = filtrados.where((r) => r.horasNetasTaller != null || r.horasNetasBodega != null).toList();

    if (ticketsConNetos.isEmpty) {
      return _card(
        titulo: 'Tiempos de Ciclo Concurrentes (Neto vs. Espera)',
        nota: 'Se calcularán automáticamente con los tickets que utilicen la nueva trazabilidad concurrente.',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blueGrey.shade400, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Aún no hay tickets nuevos procesados con el cronómetro concurrente. Los tickets anteriores se visualizan en "Tiempo por departamento".',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    double sumaTallerNeto = 0.0;
    double sumaTallerEspera = 0.0;
    int countTaller = 0;

    double sumaBodegaNeto = 0.0;
    double sumaBodegaEspera = 0.0;
    int countBodega = 0;

    for (final t in ticketsConNetos) {
      if (t.horasNetasTaller != null) {
        sumaTallerNeto += t.horasNetasTaller!;
        sumaTallerEspera += (t.horasEsperaTaller ?? 0.0);
        countTaller++;
      }
      if (t.horasNetasBodega != null) {
        sumaBodegaNeto += t.horasNetasBodega!;
        sumaBodegaEspera += (t.horasEsperaBodega ?? 0.0);
        countBodega++;
      }
    }

    final promTallerNeto = countTaller > 0 ? (sumaTallerNeto / countTaller) : 0.0;
    final promTallerEspera = countTaller > 0 ? (sumaTallerEspera / countTaller) : 0.0;
    final promBodegaNeto = countBodega > 0 ? (sumaBodegaNeto / countBodega) : 0.0;
    final promBodegaEspera = countBodega > 0 ? (sumaBodegaEspera / countBodega) : 0.0;

    return _grid([
      _card(
        titulo: 'Taller: Mano de Obra Neta vs. Espera de Materiales',
        nota: 'Diferencia el tiempo real trabajado en el equipo del tiempo parado esperando repuestos',
        child: Column(
          children: [
            _kpiRow([
              _kpiCard(_fmtDuracionHoras(promTallerNeto), 'Trabajo Neto Real', _good),
              _kpiCard(_fmtDuracionHoras(promTallerEspera), 'Espera por Repuestos', _bad),
            ]),
          ],
        ),
      ),
      _card(
        titulo: 'Bodega: Reacción de Despacho vs. Espera de Compras',
        nota: 'Diferencia lo que tarda Bodega en entregar del tiempo que estuvo esperando que Compras autorice',
        child: Column(
          children: [
            _kpiRow([
              _kpiCard(_fmtDuracionHoras(promBodegaNeto), 'Despacho Neto Real', _good),
              _kpiCard(_fmtDuracionHoras(promBodegaEspera), 'Espera por Compras', _warn),
            ]),
          ],
        ),
      ),
    ]);
  }

  // 📦 Ranking de Repuestos y Evaluación de Abastecimiento (Proveedores)
  Widget _seccionRankingRepuestos(List<ResumenRepuestoDash> ranking) {
    if (ranking.isEmpty) {
      return _card(
        titulo: 'Lead Time por Repuesto (Evaluación de Proveedores)',
        nota: 'Registra el tiempo de abastecimiento individual de cada repuesto requerido en los tickets.',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'No hay repuestos registrados con seguimiento de compras aún.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ),
      );
    }

    return _card(
      titulo: 'Top Repuestos con Mayor Demora de Abastecimiento',
      nota: 'Permite identificar qué repuestos y proveedores están generando cuellos de botella y cuáles requieren stock mínimo en bodega',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
              dataRowMinHeight: 40,
              dataRowMaxHeight: 52,
              headingRowHeight: 40,
              columns: const [
                DataColumn(label: Text('Código SKU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Descripción', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Veces Solicitado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Demora Compras (Lead Time)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Reacción Bodega', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Diagnóstico Proveedor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: ranking.take(15).map((r) {
                final esCritico = r.esCritico;
                return DataRow(
                  cells: [
                    DataCell(Text(r.codigo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0D47A1)))),
                    DataCell(Text(r.descripcion, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                    DataCell(Text('${r.vecesSolicitado} veces (${r.cantidadTotalSolicitada.toStringAsFixed(0)} und)', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(
                      r.promedioHorasAbastecimiento > 0 ? _fmtDuracionHoras(r.promedioHorasAbastecimiento) : 'Sin datos',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: esCritico ? Colors.red.shade700 : (r.promedioHorasAbastecimiento > 24 ? Colors.orange.shade800 : Colors.green.shade800),
                      ),
                    )),
                    DataCell(Text(
                      r.promedioHorasDespachoBodega > 0 ? _fmtDuracionHoras(r.promedioHorasDespachoBodega) : '—',
                      style: const TextStyle(fontSize: 12),
                    )),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: esCritico ? Colors.red.shade50 : (r.promedioHorasAbastecimiento > 24 ? Colors.orange.shade50 : Colors.green.shade50),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: esCritico ? Colors.red.shade300 : (r.promedioHorasAbastecimiento > 24 ? Colors.orange.shade300 : Colors.green.shade300)),
                      ),
                      child: Text(
                        esCritico ? '🔴 Proveedor Crítico / Stock Urgente' : (r.promedioHorasAbastecimiento > 24 ? '🟡 Demora Media' : '🟢 Abastecimiento Ágil'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: esCritico ? Colors.red.shade900 : (r.promedioHorasAbastecimiento > 24 ? Colors.orange.shade900 : Colors.green.shade900),
                        ),
                      ),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
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
    _ColumnaTabla('Garantía', 110, 'tipoGarantia'),
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
    _ColumnaTabla('Evaluación', 105, 'doc_evaluacion', documentos: (r) => r.documentosEvaluacion),
    _ColumnaTabla('Proforma', 95, 'doc_proforma', documentos: (r) => r.documentosProforma),
    _ColumnaTabla('Compras', 90, 'doc_compras', documentos: (r) => r.documentosCompras),
    _ColumnaTabla('Evidencia trabajo', 135, 'doc_evidencia', documentos: (r) => r.documentosEvidenciaTrabajo),
    _ColumnaTabla('Entrega', 90, 'doc_entrega', documentos: (r) => r.documentosEntrega),
    _ColumnaTabla('Garantía', 90, 'doc_garantia', documentos: (r) => r.documentosGarantia),
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
          _celda(columnas[12].ancho, child: _pillEstado(r.estadoBucket)),
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
    return SingleChildScrollView(
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
    );
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
          final idsFinalizados = filtrados.where((r) => r.estadoBucket == 'Cerrado').map((r) => r.id).toSet();
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
                // 🆕 Secciones "Tiempos de Ciclo: Trabajo Neto vs. Espera" y
                // "Lead Time de Repuestos y Evaluación de Proveedores"
                // retiradas de la vista por pedido — el cálculo sigue
                // existiendo (_seccionTiemposNetosVsEspera /
                // _seccionRankingRepuestos, más abajo en este archivo), así
                // que es fácil reactivarlas más adelante si hacen falta.
                _seccionTitulo('Otras dimensiones'),
                _seccionDimensiones(filtrados),
                _seccionTitulo('Clientes y fallas'),
                _seccionClientesFallas(filtrados),
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
