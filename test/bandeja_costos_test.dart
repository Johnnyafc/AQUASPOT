// test/bandeja_costos_test.dart
import 'package:aquaspot_postventa/core/enum/rol_usuario.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/actividad_mantenimiento.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ficha_creacion_repuesto_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/linea_repuesto_venta_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/mantenimiento_interno_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/repuesto_registrado_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/bandeja_costos_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/creacion_codigos_mantenimiento_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/evaluacion_mantenimiento_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/formulario_mantenimiento_service.dart';
import 'package:flutter_test/flutter_test.dart';

typedef B = BandejaCostosService;

final ahora = DateTime(2026, 10, 29);

/// Mantenimiento evaluado con un repuesto sin código (y otro con código).
TicketEntity mantenimientoConSinCodigo() {
  final t = FormularioMantenimientoService.construirTicket(
    const DatosMantenimientoInterno(
        tipoActivo: TipoActivoMantenimiento.cosechadora, serieOPlaca: 'AQ2', horometro: 10, detalle: 'Ruido en el motor',
        cantidadFotos: 1, tieneFotoLectura: true),
    usuarioNombre: 'Ana',
    rol: RolUsuario.requerimiento,
    ahora: ahora,
  ).copyWith(id: 'OT-00001');
  const actividad = ActividadMantenimiento(codigo: 'NUEVA-01', nombre: 'Cambio', horasHombre: 1, observacion: 'o', repuestos: [
    RepuestoRegistradoEntity(codigo: '', descripcion: 'SELLO 40MM', unidad: 'UNIDAD', cantidad: 2),
    RepuestoRegistradoEntity(codigo: 'F-1', descripcion: 'FILTRO', unidad: 'UNIDAD', cantidad: 1),
  ]);
  return EvaluacionMantenimientoService.construirTicketEvaluado(t, [actividad],
      fichas: {
        CreacionCodigosMantenimientoService.claveFicha('SELLO 40MM'):
            const FichaCreacionRepuestoEntity(nombre: 'SELLO 40MM', familiaPieza: 'F', tipo: 'T', categoria: 'C'),
      },
      necesitaCompras: true,
      usuarioNombre: 'Ana',
      rol: RolUsuario.supervisor,
      ahora: ahora);
}

TicketEntity reparacionEnCostos() => mantenimientoConSinCodigo().copyWith(
    id: 'REQ-00083',
    tipoRequerimiento: TipoRequerimiento.reparacion,
    mantenimientoInterno: null,
    estadoActual: EstadoTicket.costos);

TicketEntity ventaEnCostos({required bool conFicha}) => reparacionEnCostos().copyWith(
      id: 'REQ-00090',
      tipoRequerimiento: TipoRequerimiento.ventaRepuesto,
      lineasRepuestoVenta: [
        LineaRepuestoVentaEntity(
          codigo: '',
          descripcion: 'BOMBA',
          unidad: 'UND',
          cantidad: 1,
          stockDisponibleAlEvaluar: 0,
          fichaCreacion: conFicha ? const FichaCreacionRepuestoEntity(nombre: 'BOMBA') : null,
        ),
      ],
    );

void main() {
  test('Reparación en Costos: va a Creación de proyectos', () {
    final t = reparacionEnCostos();
    expect(B.corresponde(TarjetaCostos.creacionProyectos, t), isTrue);
    expect(B.corresponde(TarjetaCostos.creacionCodigos, t), isFalse);
  });

  test('Mantenimiento con repuestos sin código: va a Creación de códigos aunque ya esté en Compras', () {
    final t = mantenimientoConSinCodigo();
    expect(t.estadoActual, EstadoTicket.compras);
    expect(B.corresponde(TarjetaCostos.creacionCodigos, t), isTrue);
    expect(B.corresponde(TarjetaCostos.creacionProyectos, t), isFalse);
  });

  test('Mantenimiento solo con repuestos sin código (estado Costos): Creación de códigos, nunca proyectos', () {
    final t = mantenimientoConSinCodigo().copyWith(estadoActual: EstadoTicket.costos);
    expect(B.corresponde(TarjetaCostos.creacionCodigos, t), isTrue);
    expect(B.corresponde(TarjetaCostos.creacionProyectos, t), isFalse);
  });

  test('Venta en Costos: con fichas pendientes, Creación de códigos; sin ellas, proyectos', () {
    expect(B.corresponde(TarjetaCostos.creacionCodigos, ventaEnCostos(conFicha: true)), isTrue);
    expect(B.corresponde(TarjetaCostos.creacionProyectos, ventaEnCostos(conFicha: true)), isFalse);
    expect(B.corresponde(TarjetaCostos.creacionProyectos, ventaEnCostos(conFicha: false)), isTrue);
  });

  test('Fuera de Costos y sin códigos pendientes: en ninguna', () {
    final t = reparacionEnCostos().copyWith(estadoActual: EstadoTicket.compras);
    for (final tarjeta in TarjetaCostos.values) {
      expect(B.corresponde(tarjeta, t), isFalse, reason: tarjeta.name);
    }
  });
}
