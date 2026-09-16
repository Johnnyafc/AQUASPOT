// lib/core/utils/duracion_utils.dart
//
// 🕒 Formato compartido para mostrar duraciones como "días horas minutos"
// (ej. "2d 3h 15m"). Lo usan las tarjetas de ticket (con el reloj en vivo,
// ver tiempo_en_curso_widget.dart) y el Dashboard, para que toda la app
// hable "el mismo idioma" al mostrar tiempos.

String formatearDuracion(Duration d) {
  final dias = d.inDays;
  final horas = d.inHours.remainder(24);
  final minutos = d.inMinutes.remainder(60);
  if (dias > 0) return '${dias}d ${horas}h ${minutos}m';
  if (horas > 0) return '${horas}h ${minutos}m';
  if (minutos > 0) return '${minutos}m';
  return '<1m';
}
