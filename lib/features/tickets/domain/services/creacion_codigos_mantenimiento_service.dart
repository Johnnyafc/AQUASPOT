// lib/features/tickets/domain/services/creacion_codigos_mantenimiento_service.dart
//
// 🧾 MANTENIMIENTO INTERNO con repuestos SIN CÓDIGO (no están en el
// inventario). El técnico llena la ficha de creación de código de cada uno
// en la evaluación y:
//
//   - los repuestos CON código pasan a Compras como siempre;
//   - los SIN código esperan en Costos (en paralelo). Si todos son sin
//     código, el ticket queda en Costos y nada llega a Compras;
//   - cuando Costos registra el código oficial, esos repuestos entran a la
//     lista de despacho de Bodega (Compras los valida), al inventario con
//     stock 0 (en Caracol además se aparta su stock, como al evaluar), y si
//     el ticket esperaba en Costos pasa a Compras;
//   - mientras haya repuestos esperando código, Bodega no puede finalizar el
//     picking (EstadoDespachoService), y Costos ya no los registra si el
//     ticket pasó a Proceso de Trabajo o más allá.
//
// Solo reglas puras (sin Flutter ni Firebase); probado en
// test/creacion_codigos_mantenimiento_test.dart.

import '../../../../core/enum/proceso_auditoria.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../entities/actividad_mantenimiento.dart';
import '../entities/cambio_mantenimiento_interno.dart';
import '../entities/cambio_venta_repuesto.dart' show RepuestoInventarioNuevo;
import '../entities/evento_auditoria_entity.dart';
import '../entities/ficha_creacion_repuesto_entity.dart';
import '../entities/item_despacho_bodega_entity.dart';
import '../entities/repuesto_por_codificar_entity.dart';
import '../entities/repuesto_registrado_entity.dart';
import '../entities/ticket_entity.dart';
import 'evaluacion_mantenimiento_service.dart';

typedef _E = EvaluacionMantenimientoService;

/// Código que registró Costos para el repuesto [indice] de
/// mantenimientoInterno.repuestosPorCodificar.
class CodigoCreadoMantenimiento {
  final int indice;
  final String codigo;
  final String descripcion;

  const CodigoCreadoMantenimiento({required this.indice, required this.codigo, required this.descripcion});
}

class CreacionCodigosMantenimientoService {
  /// Clave de la ficha de un repuesto sin código (por su descripción).
  static String claveFicha(String descripcion) => _E.clave('', descripcion);

  /// Ficha nueva con lo que ya se sabe del repuesto.
  static FichaCreacionRepuestoEntity fichaInicial(RepuestoRegistradoEntity r) =>
      FichaCreacionRepuestoEntity(nombre: r.descripcion.trim().toUpperCase(), udm: r.unidad);

  // ------------------------------------------------------------ Evaluación
  /// Repuestos sin código de la evaluación (sumados entre actividades).
  static List<RepuestoRegistradoEntity> sinCodigo(List<ActividadMantenimiento> actividades) =>
      _E.consolidar(actividades).where(_E.esSinCodigo).toList();

  /// Errores de fichas: cada repuesto sin código necesita su ficha completa.
  static List<String> validarFichas(
    List<ActividadMantenimiento> actividades,
    Map<String, FichaCreacionRepuestoEntity> fichas,
  ) {
    return [
      for (final r in sinCodigo(actividades))
        if (fichas[claveFicha(r.descripcion)] == null)
          '${r.descripcion}: llene la ficha de creación de código (repuesto sin código).'
        else if (!fichas[claveFicha(r.descripcion)]!.completa)
          '${r.descripcion}: en la ficha falta ${fichas[claveFicha(r.descripcion)]!.faltantes.join(', ')}.',
    ];
  }

  /// Lo que se guarda para Costos.
  static List<RepuestoPorCodificarEntity> porCodificar(
    List<ActividadMantenimiento> actividades,
    Map<String, FichaCreacionRepuestoEntity> fichas,
  ) {
    return [
      for (final r in sinCodigo(actividades))
        RepuestoPorCodificarEntity(
          descripcion: r.descripcion,
          unidad: r.unidad,
          cantidad: r.cantidad,
          ficha: fichas[claveFicha(r.descripcion)] ?? fichaInicial(r),
        ),
    ];
  }

  // ------------------------------------------------------------ Bandejas
  static bool esMantenimiento(TicketEntity t) => t.tipoRequerimiento == TipoRequerimiento.mantenimientoInterno;

  /// Índices de los repuestos a los que Costos aún no les creó código.
  static List<int> indicesPendientes(TicketEntity t) {
    final lista = t.mantenimientoInterno?.repuestosPorCodificar ?? const <RepuestoPorCodificarEntity>[];
    return [
      for (var i = 0; i < lista.length; i++)
        if (lista[i].pendiente) i,
    ];
  }

  /// Mantenimiento con repuestos esperando código (aparece en Costos aunque
  /// esté en Compras o Bodega).
  static bool requiereCreacionCodigos(TicketEntity t) =>
      esMantenimiento(t) && t.estadoActual != EstadoTicket.anulado && indicesPendientes(t).isNotEmpty;

  /// Estados en los que ya no se pueden agregar repuestos al despacho.
  static const estadosCerrados = {
    EstadoTicket.procesoTrabajo,
    EstadoTicket.validacionFacturacion,
    EstadoTicket.entrega,
    EstadoTicket.finalizado,
    EstadoTicket.anulado,
  };

  /// Solo espera códigos: todos sus repuestos son sin código y aún no hay
  /// nada para Compras.
  static bool esperaSoloCodigos(TicketEntity t) =>
      requiereCreacionCodigos(t) && t.estadoActual == EstadoTicket.costos;

  // ------------------------------------------------------------ Costos
  /// Aplica los códigos que registró Costos sobre el ticket ACTUAL.
  /// Lanza CambioMantenimientoRechazado si ya no aplica.
  static CambioMantenimientoInterno aplicarCodigos(
    TicketEntity actual,
    List<CodigoCreadoMantenimiento> codigos, {
    required String usuarioNombre,
    required String usuarioRol,
    required DateTime ahora,
  }) {
    final m = actual.mantenimientoInterno;
    if (!requiereCreacionCodigos(actual) || m == null) {
      throw const CambioMantenimientoRechazado('El requerimiento ya no tiene repuestos pendientes de código.');
    }
    if (estadosCerrados.contains(actual.estadoActual)) {
      throw CambioMantenimientoRechazado(
          'El requerimiento ya está en ${actual.estadoActual.nombreLegible}: no se pueden agregar repuestos al despacho.');
    }
    final pendientes = indicesPendientes(actual).toSet();
    final recibidos = codigos.map((c) => c.indice).toSet();
    if (!recibidos.containsAll(pendientes) || !pendientes.containsAll(recibidos)) {
      throw const CambioMantenimientoRechazado('Los repuestos pendientes de código cambiaron. Vuelva a abrir la pantalla.');
    }

    final lista = [...m.repuestosPorCodificar];
    final cambios = <String, RepuestoPorCodificarEntity>{}; // clave sin código → con código
    for (final c in codigos) {
      final antes = lista[c.indice];
      lista[c.indice] = antes.conCodigo(
        codigo: c.codigo,
        descripcion: c.descripcion,
        creadoPor: usuarioNombre,
        creadoEn: ahora,
      );
      cambios[claveFicha(antes.descripcion)] = lista[c.indice];
    }
    final creados = [for (final c in codigos) lista[c.indice]];

    // Los repuestos de la evaluación ahora llevan su código oficial.
    final eval = actual.evaluacionTecnica;
    final repuestosTaller = eval == null
        ? null
        : [
            for (final r in eval.repuestosTaller)
              if (_E.esSinCodigo(r) && cambios.containsKey(claveFicha(r.descripcion)))
                r.copyWith(
                  codigo: cambios[claveFicha(r.descripcion)]!.codigoCreado,
                  descripcion: cambios[claveFicha(r.descripcion)]!.descripcionCreada,
                )
              else
                r,
          ];

    final pasaACompras = actual.estadoActual == EstadoTicket.costos;
    final ticket = actual.copyWith(
      mantenimientoInterno: m.copyWith(repuestosPorCodificar: lista),
      itemsDespachoBodega: [
        ...actual.itemsDespachoBodega,
        for (final r in creados)
          ItemDespachoBodegaEntity(
            codigo: r.codigoCreado,
            descripcion: r.descripcionCreada,
            unidad: r.unidad,
            cantidadSolicitada: r.cantidad,
            stockDisponibleAlEvaluar: 0,
            fechaSolicitud: ahora,
          ),
      ],
      evaluacionTecnica: repuestosTaller == null ? null : eval!.copyWith(repuestosTaller: repuestosTaller),
      estadoActual: pasaACompras ? EstadoTicket.compras : null,
    );

    return CambioMantenimientoInterno(
      ticket: ticket,
      reservas: !_E.reservaStock(actual)
          ? const {}
          : {
              for (final r in creados) r.codigoCreado: r.cantidad,
            },
      inventarioNuevos: [
        for (final r in creados)
          RepuestoInventarioNuevo(codigo: r.codigoCreado, descripcion: r.descripcionCreada, unidad: r.unidad),
      ],
      evento: EventoAuditoriaEntity(
        accion: 'COSTOS: ${creados.length} CÓDIGO(S) DE REPUESTO CREADO(S) (MANTENIMIENTO INTERNO) — '
            '${pasaACompras ? 'PASA A COMPRAS' : 'SE AGREGAN A LOS REPUESTOS DE COMPRAS / BODEGA'}',
        usuarioNombre: usuarioNombre,
        usuarioRol: usuarioRol,
        timestamp: ahora,
        proceso: ProcesoAuditoria.costos,
        hito: HitoProceso.fin,
        habilita: const [ProcesoAuditoria.compras],
      ),
    );
  }
}
