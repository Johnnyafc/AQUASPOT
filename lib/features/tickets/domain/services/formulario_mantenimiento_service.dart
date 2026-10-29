// lib/features/tickets/domain/services/formulario_mantenimiento_service.dart
//
// 🛠️ Reglas del formulario de MANTENIMIENTO INTERNO (Crear Ticket →
// "Mantenimiento Interno"). Solo reglas puras, sin Flutter ni Firebase;
// probado en test/formulario_mantenimiento_test.dart.
//
// - Tipo de mantenimiento: cualquier usuario elige Correctivo o Preventivo.
// - Campos según el tipo de máquina:
//     Cosechadora: serie, horómetro + foto del horómetro (obligatorios)
//     Contador / Caracol: serie, fecha y hora (de la falla; en preventivo,
//       la programada)
//     Vehículo: placa, kilometraje + foto del kilometraje (obligatorios)
//     Aire acondicionado / Herramientas: fecha (solo fecha; de la falla o
//       la programada) y serie OPCIONAL escrita a mano (en MAYÚSCULAS)
//   Aire acondicionado / Herramientas además: marca y especificación del
//   equipo (obligatorias, en MAYÚSCULAS; en aire acondicionado la
//   especificación es la UBICACIÓN del equipo);
//   y en todos: detalle de la falla (o del trabajo, si es preventivo) y al
//   menos una evidencia, foto o video (máximo 3 videos de 60 s).
// - La serie y la placa salen del catálogo de Firestore
//   (catalogos/activos_mantenimiento, una lista por tipo); el tipo que no
//   esté allí usa catalogoPorDefecto (combinarCatalogo). Aire acondicionado
//   y Herramientas no tienen catálogo: la serie se escribe a mano y puede
//   quedar vacía.
// - El ticket se crea directo en Evaluación Técnica (recepcionFisica: la
//   máquina es nuestra, no hay recepción física), sin cliente ("AQUASPOT
//   (interno)") ni contacto, así no dispara correos a clientes.

import '../../../../core/enum/proceso_auditoria.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../entities/evento_auditoria_entity.dart';
import '../entities/mantenimiento_interno_entity.dart';
import '../entities/ticket_entity.dart';

/// Lo que el usuario llenó en el formulario.
class DatosMantenimientoInterno {
  final TipoMantenimiento tipoMantenimiento;
  final TipoActivoMantenimiento? tipoActivo;
  final String? serieOPlaca;
  final double? horometro;
  final double? kilometraje;
  final DateTime? fechaHora;
  final String marca;
  final String especificacion;
  final String detalle;
  final int cantidadFotos;
  final int cantidadVideos;
  final bool tieneFotoLectura; // foto del horómetro / kilometraje

  const DatosMantenimientoInterno({
    this.tipoMantenimiento = TipoMantenimiento.correctivo,
    this.tipoActivo,
    this.serieOPlaca,
    this.horometro,
    this.kilometraje,
    this.fechaHora,
    this.marca = '',
    this.especificacion = '',
    this.detalle = '',
    this.cantidadFotos = 0,
    this.cantidadVideos = 0,
    this.tieneFotoLectura = false,
  });

  DatosMantenimientoInterno copyWith({
    TipoMantenimiento? tipoMantenimiento,
    TipoActivoMantenimiento? tipoActivo,
    String? serieOPlaca,
    double? horometro,
    double? kilometraje,
    DateTime? fechaHora,
    String? marca,
    String? especificacion,
    String? detalle,
    int? cantidadFotos,
    int? cantidadVideos,
    bool? tieneFotoLectura,
    bool limpiarSerieOPlaca = false,
    bool limpiarHorometro = false,
    bool limpiarKilometraje = false,
    bool limpiarFechaHora = false,
  }) {
    return DatosMantenimientoInterno(
      tipoMantenimiento: tipoMantenimiento ?? this.tipoMantenimiento,
      tipoActivo: tipoActivo ?? this.tipoActivo,
      serieOPlaca: limpiarSerieOPlaca ? null : (serieOPlaca ?? this.serieOPlaca),
      horometro: limpiarHorometro ? null : (horometro ?? this.horometro),
      kilometraje: limpiarKilometraje ? null : (kilometraje ?? this.kilometraje),
      fechaHora: limpiarFechaHora ? null : (fechaHora ?? this.fechaHora),
      marca: marca ?? this.marca,
      especificacion: especificacion ?? this.especificacion,
      detalle: detalle ?? this.detalle,
      cantidadFotos: cantidadFotos ?? this.cantidadFotos,
      cantidadVideos: cantidadVideos ?? this.cantidadVideos,
      tieneFotoLectura: tieneFotoLectura ?? this.tieneFotoLectura,
    );
  }
}

/// Series / placas disponibles por tipo de máquina.
typedef CatalogoActivos = Map<TipoActivoMantenimiento, List<String>>;

class FormularioMantenimientoService {
  static const String clienteInterno = 'AQUASPOT (interno)';
  static const int minimoCaracteresDetalle = 10;
  static const int maximoVideos = 3;
  static const Duration duracionMaximaVideo = Duration(seconds: 60);

  /// Series (máquinas) y placas (vehículos) por tipo, si Firestore no
  /// tiene la lista de ese tipo.
  static const CatalogoActivos catalogoPorDefecto = {
    TipoActivoMantenimiento.cosechadora: ['AQ2'],
    TipoActivoMantenimiento.contador: ['Contador AQUASPOT'],
    TipoActivoMantenimiento.caracol: ['AQ2'],
    TipoActivoMantenimiento.vehiculo: ['GTA1234'],
  };

  /// Tipos con serie / placa de catálogo (el resto se escribe a mano).
  static List<TipoActivoMantenimiento> get tiposConCatalogo => catalogoPorDefecto.keys.toList();

  /// Catálogo leído de Firestore ([leido]: nombre del tipo → series /
  /// placas). Se quitan vacíos y repetidos; el tipo que no venga usa el
  /// catálogo por defecto (una lista vacía sí cuenta: sin opciones).
  static CatalogoActivos combinarCatalogo(Map<String, List<String>> leido) => {
        for (final t in tiposConCatalogo)
          t: leido.containsKey(t.name)
              ? [...{for (final v in leido[t.name]!) if (v.trim().isNotEmpty) v.trim()}]
              : catalogoPorDefecto[t]!,
      };

  static List<String> opcionesDe(TipoActivoMantenimiento tipo, [CatalogoActivos catalogo = catalogoPorDefecto]) =>
      catalogo[tipo] ?? const [];

  // ------------------------------------------------------------ Campos
  static bool esVehiculo(TipoActivoMantenimiento? t) => t == TipoActivoMantenimiento.vehiculo;
  static bool pideHorometro(TipoActivoMantenimiento? t) => t == TipoActivoMantenimiento.cosechadora;
  static bool pideFechaHora(TipoActivoMantenimiento? t) =>
      t == TipoActivoMantenimiento.contador || t == TipoActivoMantenimiento.caracol;
  static bool pideKilometraje(TipoActivoMantenimiento? t) => esVehiculo(t);

  /// Serie escrita a mano y opcional (sin catálogo).
  static bool serieManual(TipoActivoMantenimiento? t) =>
      t == TipoActivoMantenimiento.aireAcondicionado || t == TipoActivoMantenimiento.herramientas;

  /// Solo fecha, sin hora.
  static bool pideFecha(TipoActivoMantenimiento? t) => serieManual(t);

  /// Marca y especificación del equipo (obligatorias): solo aire
  /// acondicionado y herramientas.
  static bool pideMarcaYEspecificacion(TipoActivoMantenimiento? t) => serieManual(t);

  /// Foto obligatoria de la lectura: horómetro (cosechadora) o kilometraje
  /// (vehículo).
  static bool pideFotoLectura(TipoActivoMantenimiento? t) => pideHorometro(t) || pideKilometraje(t);
  static String etiquetaFotoLectura(TipoActivoMantenimiento? t) =>
      esVehiculo(t) ? 'Foto del kilometraje' : 'Foto del horómetro';

  /// En aire acondicionado la especificación es dónde está el equipo.
  static String etiquetaEspecificacion(TipoActivoMantenimiento? t) =>
      t == TipoActivoMantenimiento.aireAcondicionado ? 'Ubicación del equipo' : 'Especificación del equipo';

  static String etiquetaSerieOPlaca(TipoActivoMantenimiento? t) => esVehiculo(t) ? 'Placa' : 'Serie de máquina';

  static String etiquetaDetalle(TipoMantenimiento m) =>
      m == TipoMantenimiento.preventivo ? 'Detalle del trabajo a realizar' : 'Detalles de la falla';

  static String etiquetaFechaHora(TipoMantenimiento m) =>
      m == TipoMantenimiento.preventivo ? 'Fecha y hora programada' : 'Fecha y hora de la falla';

  static String etiquetaFecha(TipoMantenimiento m) =>
      m == TipoMantenimiento.preventivo ? 'Fecha programada' : 'Fecha de la falla';

  /// Etiqueta de la fecha guardada según la máquina (con o sin hora).
  static String etiquetaFechaDe(TipoActivoMantenimiento? t, TipoMantenimiento m) =>
      pideFecha(t) ? etiquetaFecha(m) : etiquetaFechaHora(m);

  /// dd/mm/aaaa (y hh:mm si la máquina pide la hora).
  static String textoFecha(TipoActivoMantenimiento? t, DateTime f) {
    String dos(int v) => v.toString().padLeft(2, '0');
    final fecha = '${dos(f.day)}/${dos(f.month)}/${f.year}';
    return pideFecha(t) ? fecha : '$fecha ${dos(f.hour)}:${dos(f.minute)}';
  }

  /// Equipo del ticket (filtros por equipo del Dashboard).
  static TipoEquipo equipoDe(TipoActivoMantenimiento t) => switch (t) {
        TipoActivoMantenimiento.cosechadora => TipoEquipo.Cosechadora,
        TipoActivoMantenimiento.contador => TipoEquipo.Contador,
        TipoActivoMantenimiento.caracol => TipoEquipo.Caracol,
        TipoActivoMantenimiento.vehiculo => TipoEquipo.Otros,
        TipoActivoMantenimiento.aireAcondicionado => TipoEquipo.Otros,
        TipoActivoMantenimiento.herramientas => TipoEquipo.Otros,
      };

  /// Al cambiar de tipo de máquina se borran los campos que ya no aplican
  /// (serie/placa, horómetro, kilometraje y su foto; la fecha si cambia
  /// entre "fecha y hora" y "solo fecha") para no guardar datos cruzados.
  static DatosMantenimientoInterno cambiarTipoActivo(
    DatosMantenimientoInterno d,
    TipoActivoMantenimiento nuevo, {
    CatalogoActivos catalogo = catalogoPorDefecto,
  }) {
    if (d.tipoActivo == nuevo) return d;
    final opciones = opcionesDe(nuevo, catalogo);
    return d.copyWith(
      tipoActivo: nuevo,
      serieOPlaca: opciones.length == 1 ? opciones.first : null,
      limpiarSerieOPlaca: opciones.length != 1,
      limpiarHorometro: !pideHorometro(nuevo),
      limpiarKilometraje: !pideKilometraje(nuevo),
      limpiarFechaHora: pideFecha(nuevo) != pideFecha(d.tipoActivo),
      // Si la nueva máquina no las pide, los campos se ocultan: se vacían
      // para no guardar una marca que ya no se ve.
      marca: pideMarcaYEspecificacion(nuevo) ? null : '',
      // Entre aire (ubicación) y herramientas (especificación) el campo
      // significa otra cosa: se vacía.
      especificacion: !pideMarcaYEspecificacion(nuevo) ||
              (d.tipoActivo != null && etiquetaEspecificacion(nuevo) != etiquetaEspecificacion(d.tipoActivo))
          ? ''
          : null,
      tieneFotoLectura: false,
    );
  }

  // ------------------------------------------------------------ Validación
  /// Errores del formulario (vacío = se puede crear).
  static List<String> validar(
    DatosMantenimientoInterno d, {
    required DateTime ahora,
    CatalogoActivos catalogo = catalogoPorDefecto,
  }) {
    final errores = <String>[];
    final tipo = d.tipoActivo;
    if (tipo == null) {
      errores.add('Seleccione el tipo de máquina.');
      return errores;
    }
    final valor = d.serieOPlaca?.trim() ?? '';
    if (serieManual(tipo)) {
      // Opcional y sin catálogo.
    } else if (valor.isEmpty) {
      errores.add('Seleccione la ${etiquetaSerieOPlaca(tipo).toLowerCase()}.');
    } else if (!opcionesDe(tipo, catalogo).contains(valor)) {
      errores.add('La ${etiquetaSerieOPlaca(tipo).toLowerCase()} "$valor" no está en el catálogo de ${tipo.etiqueta}.');
    }
    if (pideHorometro(tipo)) {
      if (d.horometro == null) {
        errores.add('Ingrese el horómetro.');
      } else if (d.horometro! < 0) {
        errores.add('El horómetro no puede ser negativo.');
      }
    }
    if (pideKilometraje(tipo)) {
      if (d.kilometraje == null) {
        errores.add('Ingrese el kilometraje.');
      } else if (d.kilometraje! < 0) {
        errores.add('El kilometraje no puede ser negativo.');
      }
    }
    if (pideFotoLectura(tipo) && !d.tieneFotoLectura) {
      errores.add('Agregue la ${etiquetaFotoLectura(tipo).toLowerCase()}.');
    }
    if (pideFechaHora(tipo)) {
      if (d.fechaHora == null) {
        errores.add('Seleccione la fecha y hora.');
      } else if (d.tipoMantenimiento == TipoMantenimiento.correctivo && d.fechaHora!.isAfter(ahora)) {
        errores.add('La fecha y hora de la falla no puede ser futura.');
      }
    }
    if (pideFecha(tipo)) {
      final f = d.fechaHora;
      if (f == null) {
        errores.add('Seleccione la fecha.');
      } else if (d.tipoMantenimiento == TipoMantenimiento.correctivo &&
          DateTime(f.year, f.month, f.day).isAfter(DateTime(ahora.year, ahora.month, ahora.day))) {
        errores.add('La fecha de la falla no puede ser futura.');
      }
    }
    if (pideMarcaYEspecificacion(tipo)) {
      if (d.marca.trim().isEmpty) errores.add('Ingrese la marca.');
      if (d.especificacion.trim().isEmpty) errores.add('Ingrese la ${etiquetaEspecificacion(tipo).toLowerCase()}.');
    }
    if (d.detalle.trim().length < minimoCaracteresDetalle) {
      errores.add('${etiquetaDetalle(d.tipoMantenimiento)}: escriba al menos $minimoCaracteresDetalle caracteres.');
    }
    if (d.cantidadFotos + d.cantidadVideos < 1) {
      errores.add('Agregue al menos una evidencia (foto o video).');
    }
    if (d.cantidadVideos > maximoVideos) {
      errores.add('Máximo $maximoVideos videos de evidencia.');
    }
    return errores;
  }

  // ------------------------------------------------------------ Ticket
  /// Ticket a crear (id provisional: lo asigna la base de datos). Supone
  /// datos ya validados.
  static TicketEntity construirTicket(
    DatosMantenimientoInterno d, {
    required String usuarioNombre,
    required RolUsuario rol,
    required DateTime ahora,
  }) {
    final tipo = d.tipoActivo!;
    final escrito = (d.serieOPlaca ?? '').trim();
    final valor = serieManual(tipo) ? escrito.toUpperCase() : escrito;
    final f = d.fechaHora;
    return TicketEntity(
      id: 'TEMP',
      estadoActual: EstadoTicket.recepcionFisica,
      sede: Sede.NINGUNO,
      clienteId: clienteInterno,
      campamento: '',
      nombreContacto: '',
      emailContacto: '',
      telefonoContacto: '',
      equipo: equipoDe(tipo),
      equipoDetalle: tipo.etiqueta,
      marca: pideMarcaYEspecificacion(tipo) ? d.marca.trim().toUpperCase() : 'NO ESPECIFICADA',
      accesoriosRecibidos: null,
      fallaReportada: d.detalle.trim(),
      numeroSerie: esVehiculo(tipo) || valor.isEmpty ? null : valor,
      horometro: pideHorometro(tipo) ? d.horometro : null,
      historialEventos: [
        EventoAuditoriaEntity(
          accion: 'CREACIÓN DE REQUERIMIENTO — MANTENIMIENTO INTERNO '
              '${d.tipoMantenimiento.etiqueta.toUpperCase()} (${tipo.etiqueta.toUpperCase()} ${valor.isEmpty ? 'S/N' : valor})',
          usuarioNombre: usuarioNombre,
          usuarioRol: rol.name.toUpperCase(),
          timestamp: ahora,
          proceso: ProcesoAuditoria.recepcion,
          hito: HitoProceso.fin,
          habilita: const [ProcesoAuditoria.evaluacion],
        ),
      ],
      tipoRequerimiento: TipoRequerimiento.mantenimientoInterno,
      lugarAtencion: LugarAtencion.noAplica,
      esRegistroCompleto: true,
      mantenimientoInterno: MantenimientoInternoEntity(
        tipoMantenimiento: d.tipoMantenimiento,
        tipoActivo: tipo,
        placa: esVehiculo(tipo) ? valor : null,
        kilometraje: pideKilometraje(tipo) ? d.kilometraje : null,
        especificacion: pideMarcaYEspecificacion(tipo) ? d.especificacion.trim().toUpperCase() : '',
        fechaHoraFalla: pideFechaHora(tipo)
            ? f
            : (pideFecha(tipo) && f != null ? DateTime(f.year, f.month, f.day) : null),
      ),
    );
  }
}
