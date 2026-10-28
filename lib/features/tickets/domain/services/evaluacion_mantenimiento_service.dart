// lib/features/tickets/domain/services/evaluacion_mantenimiento_service.dart
//
// 🛠️ Reglas de la EVALUACIÓN TÉCNICA de un MANTENIMIENTO INTERNO. Solo
// reglas puras, sin Flutter ni Firebase; probado en
// test/evaluacion_mantenimiento_test.dart.
//
// - Las actividades se agregan del Plan Maestro del equipo (cosechadora,
//   contador, caracol; el vehículo aún no tiene plan) o son NUEVAS (código
//   NUEVA-01…, solo en este ticket); todas son modificables.
// - No hay propuesta comercial: cada actividad tiene UNA lista de repuestos
//   (al agregarla se juntan los internos y los comerciales del plan, sin
//   repetir). Se agregan del inventario registrado o, si no está, como
//   repuesto NO REGISTRADO (sin código: Compras sabe que hay que comprarlo).
// - Informe técnico y Solicitud de materiales: los datos y textos salen de
//   aquí (datosInforme, encabezadoSolicitud, firma); los generadores solo
//   les dan formato.
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
import '../../../plan_preventivo/domain/entities/actividad_preventiva_entity.dart';
import '../entities/actividad_mantenimiento.dart';
import '../entities/actividad_registrada_entity.dart';
import '../entities/evaluacion_tecnica_entity.dart';
import '../entities/evento_auditoria_entity.dart';
import '../entities/ficha_creacion_repuesto_entity.dart';
import '../entities/item_despacho_bodega_entity.dart';
import '../entities/mantenimiento_interno_entity.dart';
import '../entities/repuesto_registrado_entity.dart';
import '../entities/ticket_entity.dart';
import 'creacion_codigos_mantenimiento_service.dart';
import 'formulario_mantenimiento_service.dart';

class EvaluacionMantenimientoService {
  static const int limiteBusqueda = 30;
  static const String prefijoActividadNueva = 'NUEVA-';
  static const int minimoCaracteresNombre = 3;

  /// Unidades para un repuesto no registrado.
  static const List<String> unidades = ['UNIDAD', 'METRO', 'CENTÍMETRO', 'LITRO', 'GALÓN', 'KILOGRAMO', 'JUEGO'];

  /// Encabezado de la Solicitud de materiales de un mantenimiento interno.
  static const encabezadoSolicitud = (
    proyecto: 'AQUASPOT',
    centroCosto: 'MANTENIMIENTO INTERNO',
    cargo: 'CONSUMO MANTENIMIENTO INTERNO',
  );

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

  /// Actividad del Plan Preventivo lista para editar (mismo código PREV-…,
  /// sus horas y sus repuestos).
  static ActividadMantenimiento desdePreventivo(ActividadPreventivaEntity a) => ActividadMantenimiento(
        codigo: a.codigo,
        nombre: a.nombre,
        horasHombre: a.horasHombre,
        repuestos: [for (final r in a.repuestos) if (r.cantidad > 0) r],
      );

  /// Actividades preventivas activas que aún no se agregaron.
  static List<ActividadPreventivaEntity> preventivasDisponibles(
    List<ActividadPreventivaEntity> plan,
    List<ActividadMantenimiento> agregadas,
  ) {
    final ya = {for (final a in agregadas) a.codigo};
    return [for (final a in plan) if (a.activo && !ya.contains(a.codigo)) a]..sort((x, y) => x.codigo.compareTo(y.codigo));
  }

  /// Actividades del catálogo que aún no se agregaron.
  static List<ActividadCatalogoEntity> disponibles(
    List<ActividadCatalogoEntity> catalogo,
    List<ActividadMantenimiento> agregadas,
  ) {
    final ya = {for (final a in agregadas) a.codigo};
    return [for (final a in catalogo) if (!ya.contains(a.codigo)) a];
  }

  // ------------------------------------------------------------ Actividad nueva
  static bool esActividadNueva(ActividadMantenimiento a) => a.codigo.startsWith(prefijoActividadNueva);

  /// Siguiente código libre: NUEVA-01, NUEVA-02…
  static String codigoActividadNueva(List<ActividadMantenimiento> actividades) {
    final usados = {for (final a in actividades) a.codigo};
    var n = 1;
    while (usados.contains('$prefijoActividadNueva${n.toString().padLeft(2, '0')}')) {
      n++;
    }
    return '$prefijoActividadNueva${n.toString().padLeft(2, '0')}';
  }

  /// Error al crear una actividad nueva (null = válida).
  static String? validarActividadNueva(String nombre) => nombre.trim().length < minimoCaracteresNombre
      ? 'Escriba el nombre de la actividad (mínimo $minimoCaracteresNombre caracteres).'
      : null;

  static ActividadMantenimiento actividadNueva(
    List<ActividadMantenimiento> actividades, {
    required String nombre,
    double? horasHombre,
  }) =>
      ActividadMantenimiento(
        codigo: codigoActividadNueva(actividades),
        nombre: nombre.trim(),
        horasHombre: horasHombre ?? 0,
      );

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

  /// Repuesto que no está en el inventario: sin código, descripción en
  /// MAYÚSCULAS; si ya está (misma descripción), suma la cantidad.
  static ActividadMantenimiento agregarRepuestoNoRegistrado(
    ActividadMantenimiento act, {
    required String descripcion,
    required String unidad,
    required double cantidad,
  }) {
    final desc = descripcion.trim().toUpperCase();
    final k = clave('', desc);
    final i = act.repuestos.indexWhere((r) => esSinCodigo(r) && clave('', r.descripcion) == k);
    final repuestos = [...act.repuestos];
    if (i >= 0) {
      repuestos[i] = repuestos[i].copyWith(cantidad: repuestos[i].cantidad + cantidad);
    } else {
      repuestos.add(RepuestoRegistradoEntity(codigo: '', descripcion: desc, unidad: unidad, cantidad: cantidad));
    }
    return act.copyWith(repuestos: repuestos);
  }

  /// Error al agregar un repuesto no registrado (null = válido).
  static String? validarRepuestoNoRegistrado(String descripcion, double? cantidad) {
    if (descripcion.trim().length < minimoCaracteresNombre) {
      return 'Escriba la descripción del repuesto (mínimo $minimoCaracteresNombre caracteres).';
    }
    if (cantidad == null || cantidad <= 0) return 'La cantidad debe ser mayor a 0.';
    return null;
  }

  /// Sin código = no registrado en el inventario: lleva ficha de creación
  /// de código y Costos lo crea antes de que pase a Compras.
  static bool esSinCodigo(RepuestoRegistradoEntity r) => r.codigo.trim().isEmpty;

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

  // ------------------------------------------------------------ Informe
  static const _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  static String fechaLarga(DateTime f) => '${f.day} de ${_meses[f.month - 1]} de ${f.year}';

  static String _numero(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

  /// Filas de datos del encabezado del informe técnico.
  static List<(String, String)> datosInforme(TicketEntity t, {required DateTime fecha}) {
    final m = t.mantenimientoInterno;
    final tipo = m?.tipoActivo;
    final esVehiculo = tipo == TipoActivoMantenimiento.vehiculo;
    final f = m?.fechaHoraFalla;
    return [
      ('FECHA:', fechaLarga(fecha)),
      ('INGRESO:', t.id),
      ('ACTIVIDAD:', 'MANTENIMIENTO INTERNO ${m?.tipoMantenimiento.etiqueta.toUpperCase() ?? ''}'.trim()),
      ('MÁQUINA:', tipo?.etiqueta.toUpperCase() ?? t.equipo.name.toUpperCase()),
      (esVehiculo ? 'PLACA:' : 'N° SERIE:', (esVehiculo ? m?.placa : t.numeroSerie) ?? 'S/N'),
      if (t.horometro != null) ('HORÓMETRO:', '${_numero(t.horometro!)} h'),
      if (m?.kilometraje != null) ('KILOMETRAJE:', '${_numero(m!.kilometraje!)} km'),
      if (f != null)
        (m!.tipoMantenimiento == TipoMantenimiento.preventivo ? 'PROGRAMADO:' : 'FECHA FALLA:',
            FormularioMantenimientoService.textoFecha(tipo, f)),
      if (t.historialEventos.isNotEmpty) ('SOLICITADO POR:', t.historialEventos.first.usuarioNombre),
    ];
  }

  /// Texto del hallazgo de una actividad: su observación (o su nombre).
  static String hallazgo(ActividadMantenimiento a) => a.observacion.trim().isNotEmpty ? a.observacion.trim() : a.nombre;

  /// "Ing. Nombre" sin duplicar el prefijo si ya viene.
  static String firma(String nombre) {
    final n = nombre.trim().replaceFirst(RegExp(r'^ing(\.\s*|\s+)', caseSensitive: false), '');
    return 'Ing. ${n.isEmpty ? 'Técnico de Servicio' : n}';
  }

  static double totalHoras(List<ActividadMantenimiento> actividades) =>
      actividades.fold<double>(0, (s, a) => s + a.horasHombre);

  // ------------------------------------------------------------ Validación
  /// Errores de la evaluación (vacío = se puede guardar). Cada repuesto sin
  /// código necesita su ficha completa en [fichas] (clave:
  /// CreacionCodigosMantenimientoService.claveFicha).
  static List<String> validar(
    List<ActividadMantenimiento> actividades, {
    Map<String, FichaCreacionRepuestoEntity> fichas = const {},
  }) {
    if (actividades.isEmpty) return const ['Agregue al menos una actividad.'];
    final errores = <String>[];
    for (final a in actividades) {
      if (a.horasHombre <= 0) errores.add('${a.nombre}: ingrese las horas hombre.');
      if (a.observacion.trim().isEmpty) errores.add('${a.nombre}: escriba la observación.');
      if (a.repuestos.any((r) => r.cantidad <= 0)) {
        errores.add('${a.nombre}: las cantidades de repuestos deben ser mayores a 0.');
      }
    }
    errores.addAll(CreacionCodigosMantenimientoService.validarFichas(actividades, fichas));
    return errores;
  }

  // ------------------------------------------------------------ Guardado
  /// En Caracol se aparta el stock al evaluar (el picking lo libera).
  static bool reservaStock(TicketEntity t) => t.equipo == TipoEquipo.Caracol;

  /// Ticket evaluado: actividades (con sus fotos ya subidas), los repuestos
  /// CON código para bodega y paso a Compras sin Comercial ni Costos. Los
  /// SIN código (con su ficha) esperan en Costos; si todos son sin código,
  /// el ticket queda en Costos hasta que se creen.
  static TicketEntity construirTicketEvaluado(
    TicketEntity ticket,
    List<ActividadMantenimiento> actividades, {
    Map<String, FichaCreacionRepuestoEntity> fichas = const {},
    required bool necesitaCompras,
    String? motivoNoCompras,
    required String usuarioNombre,
    required RolUsuario rol,
    required DateTime ahora,
    String? urlInformePdf,
    String? urlSolicitudExcel,
  }) {
    final repuestos = consolidar(actividades);
    final conCodigo = repuestos.where((r) => !esSinCodigo(r)).toList();
    final porCodificar = CreacionCodigosMantenimientoService.porCodificar(actividades, fichas);
    final soloSinCodigo = porCodificar.isNotEmpty && conCodigo.isEmpty;
    final motivo = motivoNoCompras?.trim() ?? '';
    final accion = StringBuffer('EVALUACIÓN TÉCNICA DE MANTENIMIENTO INTERNO REGISTRADA');
    if (!necesitaCompras) {
      accion.write(' — DECLARADO: NO REQUIERE COMPRAS');
      if (motivo.isNotEmpty) accion.write(' ($motivo)');
    }
    if (porCodificar.isNotEmpty) {
      accion.write(' — ${porCodificar.length} REPUESTO(S) SIN CÓDIGO A COSTOS PARA CREAR SU CÓDIGO');
    }
    final m = ticket.mantenimientoInterno;
    return ticket.copyWith(
      evaluacionTecnica: EvaluacionTecnicaEntity(
        urlProformaExcel: urlSolicitudExcel,
        urlsAdjuntosPdf: [?urlInformePdf],
        observacion: 'Evaluación técnica de mantenimiento interno: informe y solicitud de materiales generados en la app.',
        totalHorasHombre: totalHoras(actividades),
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
      mantenimientoInterno: m?.copyWith(repuestosPorCodificar: porCodificar),
      itemsDespachoBodega: [
        for (final r in conCodigo)
          ItemDespachoBodegaEntity(
            codigo: r.codigo,
            descripcion: r.descripcion,
            unidad: r.unidad,
            cantidadSolicitada: r.cantidad,
            stockDisponibleAlEvaluar: 0,
          ),
      ],
      estadoActual: soloSinCodigo ? EstadoTicket.costos : EstadoTicket.compras,
      isCostosCompletado: true, // sin proyecto de Costos: Compras pasa directo a Bodega
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
          habilita: [
            if (!soloSinCodigo) ProcesoAuditoria.compras,
            if (porCodificar.isNotEmpty) ProcesoAuditoria.costos,
          ],
        ),
      ],
    );
  }
}
