// lib/features/tickets/presentation/widgets/trazabilidad_grafica_widget.dart
//
// Tarjeta gráfica de "cuánto se demoró cada acción", construida evento por
// evento sobre el mismo historial de auditoría que ya se muestra en la
// tarjeta "Trazabilidad y Auditoría" (esa tarjeta no se toca). Cada barra
// es una acción real, con su duración = esta acción menos la anterior, sin
// agrupar ni reclasificar nada. Toca una fila para ver el texto completo,
// el responsable y las fechas exactas.

import 'package:flutter/material.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/services/trazabilidad_grafica_service.dart';

class TrazabilidadGraficaWidget extends StatefulWidget {
  final TicketEntity ticket;

  const TrazabilidadGraficaWidget({super.key, required this.ticket});

  @override
  State<TrazabilidadGraficaWidget> createState() => _TrazabilidadGraficaWidgetState();
}

class _TrazabilidadGraficaWidgetState extends State<TrazabilidadGraficaWidget> {
  static const _colorAccento = Color(0xFF003366);
  static const _colorAccentoSuave = Color(0xFFDDE6F0);
  static const _colorDestacado = Color(0xFFB9792B);

  int? _filaExpandida;

  @override
  Widget build(BuildContext context) {
    final resultado = TrazabilidadCalculator.calcular(widget.ticket.historialEventos);

    if (resultado == null || resultado.eventos.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Todavía no hay suficientes eventos registrados para calcular la trazabilidad gráfica.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final cicloCerrado = widget.ticket.estadoActual == EstadoTicket.finalizado ||
        widget.ticket.estadoActual == EstadoTicket.anulado;

    // Si el ticket sigue vivo, agregamos una fila final "esperando" desde
    // el último evento real hasta ahora mismo -- así se ve de un vistazo
    // cuánto lleva detenido en el punto donde está ahora.
    final filas = List<EventoConDuracion>.from(resultado.eventos);
    Duration? esperaActual;
    if (!cicloCerrado) {
      esperaActual = DateTime.now().difference(resultado.ultimoEvento);
    }

    final todasLasDuraciones = [
      ...filas.map((f) => f.duracion),
      if (esperaActual != null) esperaActual,
    ];
    final maxDur = todasLasDuraciones.isEmpty
        ? const Duration(hours: 1)
        : todasLasDuraciones.reduce((a, b) => a > b ? a : b);

    EventoConDuracion? masLarga;
    for (final f in filas) {
      if (masLarga == null || f.duracion > masLarga.duracion) masLarga = f;
    }
    final esperaEsLaMasLarga = esperaActual != null && esperaActual > (masLarga?.duracion ?? Duration.zero);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResumen(resultado, cicloCerrado, esperaActual),
            const SizedBox(height: 18),
            const Text(
              'Duración por acción',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _colorAccento),
            ),
            const SizedBox(height: 4),
            const Text(
              'Cada barra es el tiempo entre una acción y la anterior. Toca una fila para ver el detalle.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            for (int i = 0; i < filas.length; i++)
              _buildFila(
                indice: i,
                label: filas[i].evento.accion,
                duracion: filas[i].duracion,
                maxDur: maxDur,
                destacada: !esperaEsLaMasLarga && identical(filas[i], masLarga),
                inicio: filas[i].inicio,
                fin: filas[i].fin,
                responsable: '${filas[i].evento.usuarioNombre} [${filas[i].evento.usuarioRol}]',
              ),
            if (esperaActual != null)
              _buildEsperaActual(esperaActual, maxDur, esperaEsLaMasLarga, resultado.ultimoEvento),
          ],
        ),
      ),
    );
  }

  Widget _buildResumen(ResultadoTrazabilidad r, bool cicloCerrado, Duration? esperaActual) {
    final fmt = (DateTime d) => d.toString().substring(0, 16);
    final tiempoTotal = cicloCerrado ? r.tiempoTotal : r.tiempoTotal + (esperaActual ?? Duration.zero);
    return Wrap(
      spacing: 24,
      runSpacing: 10,
      children: [
        _statTile('TIEMPO TOTAL', TrazabilidadCalculator.formatDuracion(tiempoTotal) + (cicloCerrado ? '' : ' (en curso)')),
        _statTile('CREADO', fmt(r.creacion)),
        _statTile(cicloCerrado ? 'ÚLTIMO EVENTO' : 'ÚLTIMA ACCIÓN', fmt(r.ultimoEvento)),
      ],
    );
  }

  Widget _statTile(String etiqueta, String valor) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: const TextStyle(fontSize: 10, letterSpacing: 0.4, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildFila({
    required int indice,
    required String label,
    required Duration duracion,
    required Duration maxDur,
    required bool destacada,
    required DateTime inicio,
    required DateTime fin,
    required String responsable,
  }) {
    final expandida = _filaExpandida == indice;
    final proporcion = maxDur.inSeconds == 0 ? 0.05 : (duracion.inSeconds / maxDur.inSeconds).clamp(0.04, 1.0);

    return InkWell(
      onTap: () => setState(() => _filaExpandida = expandida ? null : indice),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 128,
                  child: Row(
                    children: [
                      if (destacada) ...[
                        const Icon(Icons.circle, size: 7, color: _colorDestacado),
                        const SizedBox(width: 5),
                      ],
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 11.5),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: proporcion.toDouble(),
                      minHeight: 14,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(destacada ? _colorDestacado : _colorAccento),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 58,
                  child: Text(
                    TrazabilidadCalculator.formatDuracion(duracion),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (expandida)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _colorAccentoSuave,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${inicio.toString().substring(0, 16)}  →  ${fin.toString().substring(0, 16)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                    ),
                    const SizedBox(height: 4),
                    Text(responsable, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEsperaActual(Duration espera, Duration maxDur, bool esLaMasLarga, DateTime desde) {
    final proporcion = maxDur.inSeconds == 0 ? 0.05 : (espera.inSeconds / maxDur.inSeconds).clamp(0.04, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 128,
            child: Row(
              children: [
                Icon(Icons.hourglass_top, size: 13, color: esLaMasLarga ? _colorDestacado : _colorAccento),
                const SizedBox(width: 5),
                const Expanded(
                  child: Text(
                    'Esperando siguiente acción',
                    style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: proporcion.toDouble(),
                minHeight: 14,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(esLaMasLarga ? _colorDestacado : Colors.blueGrey.shade300),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 58,
            child: Text(
              '${TrazabilidadCalculator.formatDuracion(espera)} ⏱',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}
