// lib/features/tickets/domain/services/formulario_mantenimiento_service.dart
//
// 🛠️ Reglas del formulario de MANTENIMIENTO INTERNO (Crear Ticket →
// "Mantenimiento Interno"). Solo reglas puras, sin Flutter ni Firebase;
// probado en test/formulario_mantenimiento_test.dart.
//
// - Tipo de mantenimiento: supervisor y admin eligen Correctivo o
//   Preventivo; el resto de roles queda fijo en Correctivo (se valida
//   también al crear, no solo en la pantalla).
// - Campos según el tipo de máquina:
//     Cosechadora: serie, horómetro
//     Contador / Caracol: serie, fecha y hora (de la falla; en preventivo,
//       la programada)
//     Vehículo: placa, kilometraje
//   y en todos: detalle de la falla (o del trabajo, si es preventivo) y al
//   menos una foto.
// - La serie y la placa salen de un catálogo fijo (catalogo); para agregar
//   una máquina se agrega aquí.
// - El ticket se crea en estado "creado", sin cliente ("AQUASPOT
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
  final String detalle;
  final int cantidadFotos;

  const DatosMantenimientoInterno({
    this.tipoMantenimiento = TipoMantenimiento.correctivo,
    this.tipoActivo,
    this.serieOPlaca,
    this.horometro,
    this.kilometraje,
    this.fechaHora,
    this.detalle = '',
    this.cantidadFotos = 0,
  });

  DatosMantenimientoInterno copyWith({
    TipoMantenimiento? tipoMantenimiento,
    TipoActivoMantenimiento? tipoActivo,
    String? serieOPlaca,
    double? horometro,
    double? kilometraje,
    DateTime? fechaHora,
    String? detalle,
    int? cantidadFotos,
    bool limpiarSerieOPlaca = false,
    bool limpiarHorometro = false,
    bool limpiarKilometraje = false,
  }) {
    return DatosMantenimientoInterno(
      tipoMantenimiento: tipoMantenimiento ?? this.tipoMantenimiento,
      tipoActivo: tipoActivo ?? this.tipoActivo,
      serieOPlaca: limpiarSerieOPlaca ? null : (serieOPlaca ?? this.serieOPlaca),
      horometro: limpiarHorometro ? null : (horometro ?? this.horometro),
      kilometraje: limpiarKilometraje ? null : (kilometraje ?? this.kilometraje),
      fechaHora: fechaHora ?? this.fechaHora,
      detalle: detalle ?? this.detalle,
      cantidadFotos: cantidadFotos ?? this.cantidadFotos,
    );
  }
}

class FormularioMantenimientoService {
  static const String clienteInterno = 'AQUASPOT (interno)';
  static const int minimoCaracteresDetalle = 10;

  /// Series (máquinas) y placas (vehículos) disponibles por tipo.
  static const Map<TipoActivoMantenimiento, List<String>> catalogo = {
    TipoActivoMantenimiento.cosechadora: ['AQ2'],
    TipoActivoMantenimiento.contador: ['Contador AQUASPOT'],
    TipoActivoMantenimiento.caracol: ['AQ2'],
    TipoActivoMantenimiento.vehiculo: ['GTA1234'],
  };

  static List<String> opcionesDe(TipoActivoMantenimiento tipo) => catalogo[tipo] ?? const [];

  // ------------------------------------------------------------ Por rol
  static bool puedeElegirTipo(RolUsuario rol) => rol == RolUsuario.supervisor || rol == RolUsuario.admin;

  static List<TipoMantenimiento> tiposPermitidos(RolUsuario rol) =>
      puedeElegirTipo(rol) ? TipoMantenimiento.values : const [TipoMantenimiento.correctivo];

  // ------------------------------------------------------------ Campos
  static bool esVehiculo(TipoActivoMantenimiento? t) => t == TipoActivoMantenimiento.vehiculo;
  static bool pideHorometro(TipoActivoMantenimiento? t) => t == TipoActivoMantenimiento.cosechadora;
  static bool pideFechaHora(TipoActivoMantenimiento? t) =>
      t == TipoActivoMantenimiento.contador || t == TipoActivoMantenimiento.caracol;
  static bool pideKilometraje(TipoActivoMantenimiento? t) => esVehiculo(t);

  static String etiquetaSerieOPlaca(TipoActivoMantenimiento? t) => esVehiculo(t) ? 'Placa' : 'Serie de máquina';

  static String etiquetaDetalle(TipoMantenimiento m) =>
      m == TipoMantenimiento.preventivo ? 'Detalle del trabajo a realizar' : 'Detalles de la falla';

  static String etiquetaFechaHora(TipoMantenimiento m) =>
      m == TipoMantenimiento.preventivo ? 'Fecha y hora programada' : 'Fecha y hora de la falla';

  /// Equipo del ticket (filtros por equipo del Dashboard).
  static TipoEquipo equipoDe(TipoActivoMantenimiento t) => switch (t) {
        TipoActivoMantenimiento.cosechadora => TipoEquipo.Cosechadora,
        TipoActivoMantenimiento.contador => TipoEquipo.Contador,
        TipoActivoMantenimiento.caracol => TipoEquipo.Caracol,
        TipoActivoMantenimiento.vehiculo => TipoEquipo.Otros,
      };

  /// Al cambiar de tipo de máquina se borran los campos que ya no aplican
  /// (serie/placa, horómetro, kilometraje) para no guardar datos cruzados.
  static DatosMantenimientoInterno cambiarTipoActivo(DatosMantenimientoInterno d, TipoActivoMantenimiento nuevo) {
    if (d.tipoActivo == nuevo) return d;
    final opciones = opcionesDe(nuevo);
    return d.copyWith(
      tipoActivo: nuevo,
      serieOPlaca: opciones.length == 1 ? opciones.first : null,
      limpiarSerieOPlaca: opciones.length != 1,
      limpiarHorometro: !pideHorometro(nuevo),
      limpiarKilometraje: !pideKilometraje(nuevo),
    );
  }

  // ------------------------------------------------------------ Validación
  /// Errores del formulario (vacío = se puede crear).
  static List<String> validar(DatosMantenimientoInterno d, {required RolUsuario rol, required DateTime ahora}) {
    final errores = <String>[];
    if (!tiposPermitidos(rol).contains(d.tipoMantenimiento)) {
      errores.add('Solo un supervisor puede crear un mantenimiento ${d.tipoMantenimiento.etiqueta.toLowerCase()}.');
    }
    final tipo = d.tipoActivo;
    if (tipo == null) {
      errores.add('Seleccione el tipo de máquina.');
      return errores;
    }
    final valor = d.serieOPlaca?.trim() ?? '';
    if (valor.isEmpty) {
      errores.add('Seleccione la ${etiquetaSerieOPlaca(tipo).toLowerCase()}.');
    } else if (!opcionesDe(tipo).contains(valor)) {
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
    if (pideFechaHora(tipo)) {
      if (d.fechaHora == null) {
        errores.add('Seleccione la fecha y hora.');
      } else if (d.tipoMantenimiento == TipoMantenimiento.correctivo && d.fechaHora!.isAfter(ahora)) {
        errores.add('La fecha y hora de la falla no puede ser futura.');
      }
    }
    if (d.detalle.trim().length < minimoCaracteresDetalle) {
      errores.add('${etiquetaDetalle(d.tipoMantenimiento)}: escriba al menos $minimoCaracteresDetalle caracteres.');
    }
    if (d.cantidadFotos < 1) {
      errores.add('Agregue al menos una foto de evidencia.');
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
    final valor = d.serieOPlaca!.trim();
    return TicketEntity(
      id: 'TEMP',
      estadoActual: EstadoTicket.creado,
      sede: Sede.NINGUNO,
      clienteId: clienteInterno,
      campamento: '',
      nombreContacto: '',
      emailContacto: '',
      telefonoContacto: '',
      equipo: equipoDe(tipo),
      equipoDetalle: tipo.etiqueta,
      accesoriosRecibidos: null,
      fallaReportada: d.detalle.trim(),
      numeroSerie: esVehiculo(tipo) ? null : valor,
      horometro: pideHorometro(tipo) ? d.horometro : null,
      historialEventos: [
        EventoAuditoriaEntity(
          accion: 'CREACIÓN DE REQUERIMIENTO — MANTENIMIENTO INTERNO '
              '${d.tipoMantenimiento.etiqueta.toUpperCase()} (${tipo.etiqueta.toUpperCase()} $valor)',
          usuarioNombre: usuarioNombre,
          usuarioRol: rol.name.toUpperCase(),
          timestamp: ahora,
          proceso: ProcesoAuditoria.recepcion,
          hito: HitoProceso.fin,
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
        fechaHoraFalla: pideFechaHora(tipo) ? d.fechaHora : null,
      ),
    );
  }
}
