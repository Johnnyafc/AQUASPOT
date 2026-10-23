// lib/features/tickets/domain/services/trazabilidad_grafica_service.dart
//
// 🧭 LECTOR DE TRAZABILIDAD GRÁFICA
//
// No agrega ningún campo nuevo al ticket ni cambia cómo se generan los
// eventos de auditoría. Solo RE-LEE el mismo `historialEventos` que ya
// alimenta la tarjeta "Trazabilidad y Auditoría" y calcula, para CADA
// evento, cuánto tiempo pasó desde el evento inmediatamente anterior
// (final - inicial). No se agrupa, no se clasifica ni se reinterpreta
// nada por "a qué proceso pertenece" -- cada acción real queda con su
// propia duración, atribuida a quien la ejecutó. Por construcción, nunca
// se pierde ni se bloquea en ningún evento: todo lo que está en el
// historial aparece.

import '../entities/evento_auditoria_entity.dart';

/// Un evento real del historial, ya con el tiempo transcurrido desde el
/// evento inmediatamente anterior.
class EventoConDuracion {
  final EventoAuditoriaEntity evento;
  final DateTime inicio; // marca de tiempo del evento anterior (o la creación, si es el primero)

  const EventoConDuracion({required this.evento, required this.inicio});

  DateTime get fin => evento.timestamp;

  Duration get duracion => fin.difference(inicio);
}

class ResultadoTrazabilidad {
  final DateTime creacion;
  final DateTime ultimoEvento;
  final List<EventoConDuracion> eventos;

  const ResultadoTrazabilidad({
    required this.creacion,
    required this.ultimoEvento,
    required this.eventos,
  });

  Duration get tiempoTotal => ultimoEvento.difference(creacion);
}

class TrazabilidadCalculator {
  static ResultadoTrazabilidad? calcular(List<EventoAuditoriaEntity> historial) {
    if (historial.isEmpty) return null;

    final ordenados = List<EventoAuditoriaEntity>.from(historial)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final creacion = ordenados.first.timestamp;
    final eventos = <EventoConDuracion>[];

    DateTime anterior = creacion;
    for (int i = 1; i < ordenados.length; i++) {
      final e = ordenados[i];
      eventos.add(EventoConDuracion(evento: e, inicio: anterior));
      anterior = e.timestamp;
    }

    return ResultadoTrazabilidad(
      creacion: creacion,
      ultimoEvento: ordenados.last.timestamp,
      eventos: eventos,
    );
  }

  static String formatDuracion(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes}min';
    final dias = d.inHours ~/ 24;
    final horas = d.inHours % 24;
    if (dias > 0) return horas > 0 ? '${dias}d ${horas}h' : '${dias}d';
    return '${d.inHours}h';
  }
}
