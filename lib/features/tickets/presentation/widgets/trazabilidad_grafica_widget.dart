// lib/features/tickets/presentation/widgets/trazabilidad_grafica_widget.dart
//
// Tarjeta gráfica de "cuánto se demoró en cada proceso", construida sobre
// el mismo historial de auditoría que ya se muestra en la tarjeta
// "Trazabilidad y Auditoría" (esa tarjeta no se toca). Toca una fila para
// ver el evento real, el responsable y las fechas exactas.

import 'package:flutter/material.dart';
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

    if (resultado == null || resultado.etapas.isEmpty) {
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

    final etapasConBarra = resultado.etapasConDuracion.where((e) => e.fin != null).toList();
    final etapaEnCurso = resultado.etapas.where((e) => e.enCurso && e.nombre != 'Anulado').toList();
    final etapaAnulada = resultado.etapas.where((e) => e.nombre == 'Anulado').toList();

    final maxDur = etapasConBarra.isEmpty
        ? const Duration(hours: 1)
        : etapasConBarra.map((e) => e.duracion).reduce((a, b) => a > b ? a : b);

    EtapaTrazabilidad? masLarga;
    for (final e in etapasConBarra) {
      if (masLarga == null || e.duracion > masLarga.duracion) masLarga = e;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResumen(resultado),
            const SizedBox(height: 18),
            const Text(
              'Duración por proceso',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _colorAccento),
            ),
            const SizedBox(height: 4),
            const Text(
              'Toca una fila para ver el evento, el responsable y las fechas exactas.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            ..._buildFilas(etapasConBarra, maxDur, masLarga),
            if (etapaEnCurso.isNotEmpty) ...[
              const SizedBox(height: 4),
              ...etapaEnCurso.map((e) => _buildEnCurso(e)),
            ],
            if (etapaAnulada.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildAnulado(etapaAnulada.first),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResumen(ResultadoTrazabilidad r) {
    final fmt = (DateTime d) => d.toString().substring(0, 16);
    return Wrap(
      spacing: 24,
      runSpacing: 10,
      children: [
        _statTile('TIEMPO TOTAL', r.anulado ? _formatDuracion(r.tiempoTotal) : _formatDuracion(r.tiempoTotal) + (r.cierre == null ? ' (en curso)' : '')),
        _statTile('CREADO', fmt(r.creacion)),
        if (r.cierre != null) _statTile(r.anulado ? 'ANULADO' : 'FINALIZADO', fmt(r.cierre!)),
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

  List<Widget> _buildFilas(List<EtapaTrazabilidad> etapas, Duration maxDur, EtapaTrazabilidad? masLarga) {
    final filas = <Widget>[];
    bool dentroDeParalelo = false;

    for (int i = 0; i < etapas.length; i++) {
      final e = etapas[i];

      if (e.paralelo && !dentroDeParalelo) {
        dentroDeParalelo = true;
        filas.add(const Padding(
          padding: EdgeInsets.only(top: 8, bottom: 2),
          child: Text(
            'COSTOS + COMPRAS — EN PARALELO, CON COMPUERTA',
            style: TextStyle(fontSize: 10, letterSpacing: 0.4, color: Colors.grey, fontWeight: FontWeight.w600),
          ),
        ));
      } else if (!e.paralelo) {
        dentroDeParalelo = false;
      }

      final expandida = _filaExpandida == i;
      final esMasLarga = masLarga != null && identical(e, masLarga);
      final proporcion = maxDur.inSeconds == 0 ? 0.05 : (e.duracion.inSeconds / maxDur.inSeconds).clamp(0.04, 1.0);

      filas.add(InkWell(
        onTap: () => setState(() => _filaExpandida = expandida ? null : i),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 128,
                    child: Row(
                      children: [
                        if (esMasLarga) ...[
                          const Icon(Icons.circle, size: 7, color: _colorDestacado),
                          const SizedBox(width: 5),
                        ],
                        Expanded(
                          child: Text(
                            e.nombre,
                            style: const TextStyle(fontSize: 12.5),
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
                        valueColor: AlwaysStoppedAnimation<Color>(esMasLarga ? _colorDestacado : _colorAccento),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 58,
                    child: Text(
                      _formatDuracion(e.duracion),
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
                        '${e.inicio.toString().substring(0, 16)}  →  ${e.fin!.toString().substring(0, 16)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                      ),
                      if (e.eventoCierre != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${e.eventoCierre!.usuarioNombre} [${e.eventoCierre!.usuarioRol}]',
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.eventoCierre!.accion,
                          style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace'),
                        ),
                      ],
                      if (e.hitoIntermedio != null) ...[
                        const SizedBox(height: 4),
                        Text(e.hitoIntermedio!, style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
                      ],
                      if (e.nota != null) ...[
                        const SizedBox(height: 4),
                        Text(e.nota!, style: const TextStyle(fontSize: 11.5, color: _colorDestacado, fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ));
    }
    return filas;
  }

  Widget _buildEnCurso(EtapaTrazabilidad e) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top, size: 14, color: _colorAccento),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${e.nombre} — en curso, ${_formatDuracion(e.duracion)} y contando',
              style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: _colorAccento),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnulado(EtapaTrazabilidad e) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.block, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ticket anulado a los ${_formatDuracion(e.duracion)} de su último proceso abierto'
              '${e.eventoCierre != null ? ' (${e.eventoCierre!.usuarioNombre})' : ''}.',
              style: const TextStyle(fontSize: 12.5, color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuracion(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes}min';
    final dias = d.inHours ~/ 24;
    final horas = d.inHours % 24;
    if (dias > 0) return horas > 0 ? '${dias}d ${horas}h' : '${dias}d';
    return '${d.inHours}h';
  }
}
