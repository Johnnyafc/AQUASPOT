// lib/features/tickets/domain/entities/cambio_material_entity.dart
//
// 🧾 "Cambios de materiales": registro APARTE de la auditoría
// (ticket.historialCambiosMateriales) con lo que Comercial agrega, quita o
// cambia de cantidad en los materiales de taller y en los repuestos
// comerciales. Solo se agrega con arrayUnion, nunca se reescribe. La
// auditoría real (historialEventos) no se ensucia con estos cambios.

import 'package:equatable/equatable.dart';
import 'repuesto_registrado_entity.dart';

class CambioMaterialEntity extends Equatable {
  static const String agrego = 'agrego';
  static const String quito = 'quito';
  static const String cambioCantidad = 'cambioCantidad';

  static const String listaTaller = 'taller';
  static const String listaComercial = 'comercial';
  static const String listaVenta = 'venta'; // repuestos de una Venta de Repuesto

  static const String primeraCotizacion = 'primeraCotizacion';
  static const String regresoComercial = 'regresoComercial';

  final DateTime fecha;
  final String usuarioNombre;
  final String usuarioRol;
  final String accion; // agrego | quito | cambioCantidad
  final String codigo;
  final String descripcion;
  final String unidad;
  final double? cantidadAntes; // null si se agregó
  final double? cantidadDespues; // null si se quitó
  final String lista; // taller | comercial | venta
  final String momento; // primeraCotizacion | regresoComercial

  const CambioMaterialEntity({
    required this.fecha,
    required this.usuarioNombre,
    required this.usuarioRol,
    required this.accion,
    required this.codigo,
    required this.descripcion,
    required this.unidad,
    this.cantidadAntes,
    this.cantidadDespues,
    required this.lista,
    required this.momento,
  });

  String get accionTexto => switch (accion) {
        agrego => 'Agregó',
        quito => 'Quitó',
        _ => 'Cambió cantidad',
      };

  String get listaTexto => switch (lista) {
        listaTaller => 'Materiales de taller',
        listaVenta => 'Repuestos de la venta',
        _ => 'Repuestos comerciales',
      };

  String get momentoTexto => momento == regresoComercial ? 'Regreso a Comercial' : 'Primera cotización';

  Map<String, dynamic> toJson() => {
        'fecha': fecha.toIso8601String(),
        'usuarioNombre': usuarioNombre,
        'usuarioRol': usuarioRol,
        'accion': accion,
        'codigo': codigo,
        'descripcion': descripcion,
        'unidad': unidad,
        'cantidadAntes': cantidadAntes,
        'cantidadDespues': cantidadDespues,
        'lista': lista,
        'momento': momento,
      };

  static CambioMaterialEntity? fromJson(dynamic json) {
    if (json is! Map) return null;
    final m = Map<String, dynamic>.from(json);
    final fechaRaw = m['fecha'];
    DateTime? fecha;
    if (fechaRaw is String) fecha = DateTime.tryParse(fechaRaw);
    // Timestamp de Firestore sin importar el paquete: tiene toDate().
    if (fecha == null && fechaRaw != null) {
      try {
        fecha = (fechaRaw as dynamic).toDate() as DateTime;
      } catch (_) {}
    }
    return CambioMaterialEntity(
      fecha: fecha ?? DateTime.fromMillisecondsSinceEpoch(0),
      usuarioNombre: m['usuarioNombre'] as String? ?? '',
      usuarioRol: m['usuarioRol'] as String? ?? '',
      accion: m['accion'] as String? ?? cambioCantidad,
      codigo: m['codigo'] as String? ?? '',
      descripcion: m['descripcion'] as String? ?? '',
      unidad: m['unidad'] as String? ?? '',
      cantidadAntes: (m['cantidadAntes'] as num?)?.toDouble(),
      cantidadDespues: (m['cantidadDespues'] as num?)?.toDouble(),
      lista: m['lista'] as String? ?? listaTaller,
      momento: m['momento'] as String? ?? primeraCotizacion,
    );
  }

  /// Diferencias entre dos versiones de una lista de materiales (clave:
  /// código; si no tiene, la descripción).
  static List<CambioMaterialEntity> diferencias({
    required List<RepuestoRegistradoEntity> antes,
    required List<RepuestoRegistradoEntity> despues,
    required String lista,
    required String momento,
    required String usuarioNombre,
    required String usuarioRol,
    required DateTime fecha,
  }) {
    String clave(RepuestoRegistradoEntity r) =>
        r.codigo.trim().isNotEmpty ? r.codigo.trim().toUpperCase() : r.descripcion.trim().toUpperCase();

    // Si un mismo material aparece dos veces, se suman sus cantidades.
    Map<String, ({RepuestoRegistradoEntity r, double cantidad})> agrupar(List<RepuestoRegistradoEntity> l) {
      final mapa = <String, ({RepuestoRegistradoEntity r, double cantidad})>{};
      for (final r in l) {
        final k = clave(r);
        final previo = mapa[k];
        mapa[k] = (r: previo?.r ?? r, cantidad: (previo?.cantidad ?? 0) + r.cantidad);
      }
      return mapa;
    }

    final a = agrupar(antes);
    final d = agrupar(despues);
    CambioMaterialEntity crear(RepuestoRegistradoEntity r, String accion, double? cantAntes, double? cantDespues) =>
        CambioMaterialEntity(
          fecha: fecha,
          usuarioNombre: usuarioNombre,
          usuarioRol: usuarioRol,
          accion: accion,
          codigo: r.codigo,
          descripcion: r.descripcion,
          unidad: r.unidad,
          cantidadAntes: cantAntes,
          cantidadDespues: cantDespues,
          lista: lista,
          momento: momento,
        );

    final cambios = <CambioMaterialEntity>[];
    a.forEach((k, v) {
      if (!d.containsKey(k)) cambios.add(crear(v.r, quito, v.cantidad, null));
    });
    d.forEach((k, v) {
      final previo = a[k];
      if (previo == null) {
        cambios.add(crear(v.r, agrego, null, v.cantidad));
      } else if (previo.cantidad != v.cantidad) {
        cambios.add(crear(v.r, cambioCantidad, previo.cantidad, v.cantidad));
      }
    });
    return cambios;
  }

  @override
  List<Object?> get props => [
        fecha,
        usuarioNombre,
        usuarioRol,
        accion,
        codigo,
        descripcion,
        unidad,
        cantidadAntes,
        cantidadDespues,
        lista,
        momento,
      ];
}
