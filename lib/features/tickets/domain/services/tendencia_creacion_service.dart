// lib/features/tickets/domain/services/tendencia_creacion_service.dart
//
// 📅 Dashboard → "Tickets creados por mes": desglose al tocar una barra.
//   mes → semanas del mes → días de la semana.
// Solo cálculo, sin Flutter ni Firebase; probado en
// test/tendencia_creacion_test.dart.
//
// - Las semanas van de lunes a domingo y se recortan al mes (ej. si el 1
//   es jueves, la primera semana es del 1 al domingo siguiente).
// - Semanas y días incluyen los que tienen 0 tickets; los meses, solo los
//   que tienen tickets (igual que el gráfico por mes de siempre).

/// Una barra del gráfico: el periodo [inicio, fin] (días completos) y
/// cuántos tickets se crearon en él.
class BarraTendencia {
  final DateTime inicio;
  final DateTime fin;
  final int tickets;

  const BarraTendencia({required this.inicio, required this.fin, required this.tickets});
}

class TendenciaCreacionService {
  static DateTime dia(DateTime f) => DateTime(f.year, f.month, f.day);

  static DateTime ultimoDiaDelMes(DateTime mes) => DateTime(mes.year, mes.month + 1, 0);

  static int _contar(Iterable<DateTime> fechas, DateTime inicio, DateTime fin) =>
      fechas.map(dia).where((d) => !d.isBefore(inicio) && !d.isAfter(fin)).length;

  /// Meses con tickets, del más antiguo al más reciente.
  static List<BarraTendencia> porMes(Iterable<DateTime> fechas) {
    final conteo = <DateTime, int>{};
    for (final f in fechas) {
      final m = DateTime(f.year, f.month);
      conteo[m] = (conteo[m] ?? 0) + 1;
    }
    final meses = conteo.keys.toList()..sort();
    return [
      for (final m in meses) BarraTendencia(inicio: m, fin: ultimoDiaDelMes(m), tickets: conteo[m]!),
    ];
  }

  /// Semanas (lunes a domingo, recortadas al mes) del mes de [mes].
  static List<BarraTendencia> semanasDelMes(Iterable<DateTime> fechas, DateTime mes) {
    final ultimo = ultimoDiaDelMes(mes);
    final semanas = <BarraTendencia>[];
    var inicio = DateTime(mes.year, mes.month, 1);
    while (!inicio.isAfter(ultimo)) {
      final domingo = DateTime(inicio.year, inicio.month, inicio.day + (DateTime.sunday - inicio.weekday));
      final fin = domingo.isAfter(ultimo) ? ultimo : domingo;
      semanas.add(BarraTendencia(inicio: inicio, fin: fin, tickets: _contar(fechas, inicio, fin)));
      inicio = DateTime(fin.year, fin.month, fin.day + 1);
    }
    return semanas;
  }

  /// Días de [inicio] a [fin] (ambos incluidos), con sus tickets.
  static List<BarraTendencia> dias(Iterable<DateTime> fechas, DateTime inicio, DateTime fin) {
    final lista = <BarraTendencia>[];
    for (var d = dia(inicio); !d.isAfter(dia(fin)); d = DateTime(d.year, d.month, d.day + 1)) {
      lista.add(BarraTendencia(inicio: d, fin: d, tickets: _contar(fechas, d, d)));
    }
    return lista;
  }
}
