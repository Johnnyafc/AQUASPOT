// lib/features/tickets/domain/services/resumen_mantenimiento_service.dart
//
// 🛠️ REGLA (CLAUDE.md): en MANTENIMIENTO INTERNO toda pantalla muestra los
// datos con los que se creó el requerimiento — nunca datos de cliente,
// contacto ni proyecto. Aquí se arman esos datos (filas, línea corta para
// las tarjetas de las bandejas y fotos / videos de evidencia). Solo reglas
// puras; probado en test/resumen_mantenimiento_test.dart.

import '../entities/mantenimiento_interno_entity.dart';
import '../entities/ticket_entity.dart';
import 'formulario_mantenimiento_service.dart';

class ResumenMantenimientoService {
  static String _numero(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

  static String _texto(String? v) {
    final t = v?.trim() ?? '';
    return t.isEmpty || t == 'NO ESPECIFICADA' ? '—' : t;
  }

  /// Filas etiqueta → valor, en el orden del formulario de creación.
  static List<(String, String)> filas(TicketEntity t) {
    final m = t.mantenimientoInterno;
    final tipo = m?.tipoActivo;
    return [
      if (m != null) ('Tipo de mantenimiento', m.tipoMantenimiento.etiqueta),
      ('Máquina', tipo?.etiqueta ?? t.equipo.name),
      if (FormularioMantenimientoService.pideMarcaYEspecificacion(tipo)) ...[
        ('Marca', _texto(t.marca)),
        ('Especificación', _texto(m?.especificacion)),
      ],
      (FormularioMantenimientoService.etiquetaSerieOPlaca(tipo), _texto(m?.placa ?? t.numeroSerie)),
      if (t.horometro != null) ('Horómetro', '${_numero(t.horometro!)} h'),
      if (m?.kilometraje != null) ('Kilometraje', '${_numero(m!.kilometraje!)} km'),
      if (m?.fechaHoraFalla != null)
        (
          FormularioMantenimientoService.etiquetaFechaDe(tipo, m!.tipoMantenimiento),
          FormularioMantenimientoService.textoFecha(tipo, m.fechaHoraFalla!),
        ),
      if (t.historialEventos.isNotEmpty) ('Creado por', t.historialEventos.first.usuarioNombre),
    ];
  }

  /// Para las TARJETAS de las bandejas: todos los datos de la creación
  /// (filas + detalle), sin fotos ni videos.
  static List<(String, String)> filasTarjeta(TicketEntity t) => [
        ...filas(t),
        if (t.fallaReportada.trim().isNotEmpty)
          (
            t.mantenimientoInterno == null
                ? 'Detalle'
                : FormularioMantenimientoService.etiquetaDetalle(t.mantenimientoInterno!.tipoMantenimiento),
            t.fallaReportada.trim(),
          ),
      ];

  /// Para las tarjetas de las bandejas: "MANTENIMIENTO CORRECTIVO · COSECHADORA
  /// · JOHN DEERE · AQ2".
  static String lineaCorta(TicketEntity t) {
    final m = t.mantenimientoInterno;
    final serie = _texto(m?.placa ?? t.numeroSerie);
    return [
      'MANTENIMIENTO ${m?.tipoMantenimiento.etiqueta.toUpperCase() ?? 'INTERNO'}',
      (m?.tipoActivo.etiqueta ?? t.equipo.name).toUpperCase(),
      if (_texto(t.marca) != '—') _texto(t.marca),
      if (serie != '—') serie,
    ].join(' · ');
  }

  /// Fotos a mostrar en miniatura: la del horómetro / kilometraje primero y
  /// luego las de evidencia. (url, etiqueta)
  static List<(String, String)> fotos(TicketEntity t) {
    final m = t.mantenimientoInterno;
    return [
      if (m?.urlFotoLectura != null && m!.urlFotoLectura!.isNotEmpty)
        (m.urlFotoLectura!, FormularioMantenimientoService.etiquetaFotoLectura(m.tipoActivo)),
      for (var i = 0; i < t.fotosUrls.length; i++) (t.fotosUrls[i], 'Evidencia ${i + 1}'),
    ];
  }

  static List<String> videos(TicketEntity t) => t.mantenimientoInterno?.videosUrls ?? const [];
}
