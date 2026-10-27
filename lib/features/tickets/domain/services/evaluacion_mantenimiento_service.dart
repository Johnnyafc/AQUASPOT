// lib/features/tickets/domain/services/evaluacion_mantenimiento_service.dart
//
// 🛠️ Reglas de la EVALUACIÓN TÉCNICA de un MANTENIMIENTO INTERNO. Solo
// reglas puras, sin Flutter ni Firebase; probado en
// test/evaluacion_mantenimiento_test.dart.
//
// - Las actividades se agregan del Plan Maestro del equipo (cosechadora,
//   contador, caracol; el vehículo aún no tiene plan) y son modificables.
// - No hay propuesta comercial: cada actividad tiene UNA lista de repuestos
//   (al agregarla se juntan los internos y los comerciales del plan, sin
//   repetir) y se agregan repuestos solo de lo registrado en el inventario.
// - TODOS los repuestos de todas las actividades van a bodega (solicitud de
//   materiales / picking), sumando los iguales.
// - Al guardar, el ticket pasa a Compras como en reparación, pero sin
//   Comercial ni Costos (Costos se da por completado). En Caracol se aparta
//   el stock, igual que en reparación, porque el picking lo libera.

import '../../../../core/enum/proceso_auditoria.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../../../catalogo/domain/entities/actividad_catalogo_entity.dart';
import '../../../inventario/domain/entities/item_inventario_entity.dart';
import '../entities/actividad_mantenimiento.dart';
import '../entities/actividad_registrada_entity.dart';
import '../entities/evaluacion_tecnica_entity.dart';
import '../entities/evento_auditoria_entity.dart';
import '../entities/item_despacho_bodega_entity.dart';
import '../entities/mantenimiento_interno_entity.dart';
import '../entities/repuesto_registrado_entity.dart';
import '../entities/ticket_entity.dart';

class EvaluacionMantenimientoService {
  static const int limiteBusqueda = 30;

  /// Equipo del Plan Maestro para este ticket (null = sin plan: vehículo).
  static String? equipoCatalogo(TicketEntity t) => switch (t.mantenimientoInterno?.tipoActivo) {
        TipoActivoMantenimiento.cosechadora => 'cosechadora',
        TipoActivoMantenimiento.contador => 'contador',
        TipoActivoMantenimiento.caracol => 'caracol',
        _ => null,
      };

  static String clave(String codigo, String descripcion) {
    final c = codigo.trim().toUpperCase();
    return c.isNotEmpty ? c : descripcion.trim().toUpperCase();
  }

  // ------------------------------------------------------------ Actividades
  /// Actividad del Plan Maestro lista para editar: horas del plan (0 si es
  /// variable) y sus repuestos internos + comerciales en una sola lista.
  static ActividadMantenimiento desdeCatalogo(ActividadCatalogoEntity a) {
    final repuestos = <String, RepuestoRegistradoEntity>{};
    for (final it in [...a.itemsInternos, ...a.itemsComerciales]) {
      if (it.cantidad <= 0) continue;
      repuestos.putIfAbsent(
        clave(it.codigo, it.descripcion),
        () => RepuestoRegistradoEntity(
          codigo: it.codigo,
          descripcion: it.descripcion,
          unidad: it.unidad,
          cantidad: it.cantidad,
        ),
      );
    }
    return ActividadMantenimiento(
      codigo: a.codigo,
      nombre: a.nombre,
      horasHombre: a.horasHombre ?? 0,
      repuestos: repuestos.values.toList(),
    );
  }

  /// Actividades del catálogo que aún no se agregaron.
  static List<ActividadCatalogoEntity> disponibles(
    List<ActividadCatalogoEntity> catalogo,
    List<ActividadMantenimiento> agregadas,
  ) {
    final ya = {for (final a in agregadas) a.codigo};
    return [for (final a in catalogo) if (!ya.contains(a.codigo)) a];
  }

  /// Filtra actividades por código o nombre (todas las palabras).
  static List<ActividadCatalogoEntity> buscarActividades(List<ActividadCatalogoEntity> lista, String texto) {
    final palabras = texto.trim().toUpperCase().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (palabras.isEmpty) return lista;
    return [
      for (final a in lista)
        if (palabras.every('${a.codigo} ${a.nombre}'.toUpperCase().contains)) a,
    ];
  }

  // ------------------------------------------------------------ Repuestos
  /// Agrega un repuesto del inventario (cantidad 1); si ya está, suma 1.
  static ActividadMantenimiento agregarRepuesto(ActividadMantenimiento act, ItemInventarioEntity item) {
    final k = clave(item.codigo, item.descripcion);
    final i = act.repuestos.indexWhere((r) => clave(r.codigo, r.descripcion) == k);
    final repuestos = [...act.repuestos];
    if (i >= 0) {
      repuestos[i] = repuestos[i].copyWith(cantidad: repuestos[i].cantidad + 1);
    } else {
      repuestos.add(RepuestoRegistradoEntity(
        codigo: item.codigo,
        descripcion: item.descripcion,
        unidad: item.unidad,
        cantidad: 1,
      ));
    }
    return act.copyWith(repuestos: repuestos);
  }

  static ActividadMantenimiento cambiarCantidad(ActividadMantenimiento act, int indice, double cantidad) {
    final repuestos = [...act.repuestos];
    repuestos[indice] = repuestos[indice].copyWith(cantidad: cantidad);
    return act.copyWith(repuestos: repuestos);
  }

  static ActividadMantenimiento quitarRepuesto(ActividadMantenimiento act, int indice) =>
      act.copyWith(repuestos: [...act.repuestos]..removeAt(indice));

  /// Busca en el inventario registrado por código o descripción (todas las
  /// palabras, sin distinguir mayúsculas).
  static List<ItemInventarioEntity> buscarInventario(List<ItemInventarioEntity> inventario, String texto) {
    final palabras = texto.trim().toUpperCase().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (palabras.isEmpty) return const [];
    return inventario
        .where((it) {
          final hay = '${it.codigo} ${it.descripcion}'.toUpperCase();
          return palabras.every(hay.contains);
        })
        .take(limiteBusqueda)
        .toList();
  }

  /// Todos los repuestos de todas las actividades, sumando los iguales.
  static List<RepuestoRegistradoEntity> consolidar(List<ActividadMantenimiento> actividades) {
    final mapa = <String, RepuestoRegistradoEntity>{};
    for (final act in actividades) {
      for (final r in act.repuestos) {
        if (r.cantidad <= 0) continue;
        final k = clave(r.codigo, r.descripcion);
        final anterior = mapa[k];
        mapa[k] = anterior == null ? r : anterior.copyWith(cantidad: anterior.cantidad + r.cantidad);
      }
    }
    return mapa.values.toList();
  }

  /// "Incluye: 2 FILTRO DE ACEITE, 30 CM DE MANGUERA…" con todos los
  /// repuestos de la actividad (mismo formato que en reparación).
  static String textoIncluye(ActividadMantenimiento act) {
    final partes = [
      for (final r in act.repuestos)
        if (r.cantidad > 0) _parteIncluye(r),
    ];
    return partes.isEmpty ? '' : 'Incluye: ${partes.join(', ')}.';
  }

  static String _parteIncluye(RepuestoRegistradoEntity r) {
    final cant = r.cantidad % 1 == 0 ? r.cantidad.toInt().toString() : r.cantidad.toString();
    final desc = r.descripcion.trim();
    var unidad = r.unidad.trim().toUpperCase();
    if (const ['CENTIMETRO', 'CENTÍMETRO', 'CENTIMETROS', 'CENTÍMETROS'].contains(unidad)) {
      unidad = 'CM';
    } else if (unidad == 'METRO' || unidad == 'METROS') {
      unidad = 'M';
    }
    final sinUnidad = unidad.isEmpty || const ['UNIDAD', 'UND', 'UNIDADES'].contains(unidad);
    if (!sinUnidad && !desc.toUpperCase().contains(unidad)) return '$cant $unidad DE $desc';
    return '$cant $desc';
  }

  // ------------------------------------------------------------ Validación
  /// Errores de la evaluación (vacío = se puede guardar).
  static List<String> validar(List<ActividadMantenimiento> actividades) {
    if (actividades.isEmpty) return const ['Agregue al menos una actividad.'];
    final errores = <String>[];
    for (final a in actividades) {
      if (a.horasHombre <= 0) errores.add('${a.nombre}: ingrese las horas hombre.');
      if (a.observacion.trim().isEmpty) errores.add('${a.nombre}: escriba la observación.');
      if (a.repuestos.any((r) => r.cantidad <= 0)) {
        errores.add('${a.nombre}: las cantidades de repuestos deben ser mayores a 0.');
      }
    }
    return errores;
  }

  // ------------------------------------------------------------ Guardado
  /// En Caracol se aparta el stock al evaluar (el picking lo libera).
  static bool reservaStock(TicketEntity t) => t.equipo == TipoEquipo.Caracol;

  /// Ticket evaluado: actividades (con sus fotos ya subidas), todos los
  /// repuestos para bodega y paso a Compras sin Comercial ni Costos.
  static TicketEntity construirTicketEvaluado(
    TicketEntity ticket,
    List<ActividadMantenimiento> actividades, {
    required bool necesitaCompras,
    String? motivoNoCompras,
    required String usuarioNombre,
    required RolUsuario rol,
    required DateTime ahora,
  }) {
    final repuestos = consolidar(actividades);
    final motivo = motivoNoCompras?.trim() ?? '';
    final accion = StringBuffer('EVALUACIÓN TÉCNICA DE MANTENIMIENTO INTERNO REGISTRADA');
    if (!necesitaCompras) {
      accion.write(' — DECLARADO: NO REQUIERE COMPRAS');
      if (motivo.isNotEmpty) accion.write(' ($motivo)');
    }
    return ticket.copyWith(
      evaluacionTecnica: EvaluacionTecnicaEntity(
        urlsAdjuntosPdf: const [],
        totalHorasHombre: actividades.fold<double>(0, (s, a) => s + a.horasHombre),
        actividades: [
          for (final a in actividades)
            ActividadRegistradaEntity(
              codigo: a.codigo,
              nombre: a.nombre,
              horasHombre: a.horasHombre,
              observacion: a.observacion.trim(),
              fotosUrls: a.fotosUrls,
              incluye: textoIncluye(a),
            ),
        ],
        repuestosTaller: repuestos,
      ),
      itemsDespachoBodega: [
        for (final r in repuestos)
          ItemDespachoBodegaEntity(
            codigo: r.codigo,
            descripcion: r.descripcion,
            unidad: r.unidad,
            cantidadSolicitada: r.cantidad,
            stockDisponibleAlEvaluar: 0,
          ),
      ],
      estadoActual: EstadoTicket.compras,
      isCostosCompletado: true, // sin Costos: Compras pasa directo a Bodega
      noRequiereCompras: !necesitaCompras,
      motivoNoRequiereCompras: !necesitaCompras && motivo.isNotEmpty ? motivo : null,
      supervisorNoRequiereCompras: !necesitaCompras ? usuarioNombre : null,
      fechaNoRequiereCompras: !necesitaCompras ? ahora : null,
      historialEventos: [
        ...ticket.historialEventos,
        EventoAuditoriaEntity(
          accion: accion.toString(),
          usuarioNombre: usuarioNombre,
          usuarioRol: rol.name.toUpperCase(),
          timestamp: ahora,
          proceso: ProcesoAuditoria.evaluacion,
          hito: HitoProceso.fin,
          habilita: const [ProcesoAuditoria.compras],
        ),
      ],
    );
  }
}
