// test/resumen_mantenimiento_test.dart
//
// Regla de mantenimiento interno: las pantallas muestran los datos con los
// que se creó el requerimiento (máquina, marca, especificación, serie /
// placa, lecturas, fecha, quién lo creó) y sus fotos; nunca cliente,
// contacto ni proyecto. También: nombre de la actividad editable.

import 'package:aquaspot_postventa/core/enum/rol_usuario.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/actividad_mantenimiento.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/mantenimiento_interno_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/evaluacion_mantenimiento_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/formulario_mantenimiento_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/resumen_mantenimiento_service.dart';
import 'package:flutter_test/flutter_test.dart';

typedef R = ResumenMantenimientoService;

final ahora = DateTime(2026, 10, 28, 15);

TicketEntity ticket(TipoActivoMantenimiento tipo) {
  final d = FormularioMantenimientoService.cambiarTipoActivo(
    const DatosMantenimientoInterno(
      marca: 'john deere',
      especificacion: 's700 2020',
      detalle: 'Ruido en el motor',
      cantidadFotos: 1,
      tieneFotoLectura: true,
    ),
    tipo,
  ).copyWith(horometro: 1520, kilometraje: 45200, fechaHora: ahora);
  final t = FormularioMantenimientoService.construirTicket(d, usuarioNombre: 'Ana', rol: RolUsuario.requerimiento, ahora: ahora);
  return t.copyWith(
    id: 'REQ-5',
    fotosUrls: ['https://f/1.jpg', 'https://f/2.jpg'],
    mantenimientoInterno: t.mantenimientoInterno!.copyWith(urlFotoLectura: 'https://f/horometro.jpg', videosUrls: ['https://v/1.mp4']),
  );
}

void main() {
  test('Filas con los datos de la creación (sin cliente, contacto ni proyecto)', () {
    final filas = {for (final (k, v) in R.filas(ticket(TipoActivoMantenimiento.cosechadora))) k: v};
    expect(filas['Tipo de mantenimiento'], 'Correctivo');
    expect(filas['Máquina'], 'Cosechadora');
    expect(filas.containsKey('Marca'), isFalse, reason: 'marca y especificación solo en aire y herramientas');
    expect(filas['Serie de máquina'], 'AQ2');
    expect(filas['Horómetro'], '1520 h');
    expect(filas['Creado por'], 'Ana');
    expect(filas.keys.any((k) => k.contains('Cliente') || k.contains('Contacto') || k.contains('Proyecto')), isFalse);
  });

  test('Vehículo: placa y kilometraje; aire acondicionado: solo fecha', () {
    final v = {for (final (k, x) in R.filas(ticket(TipoActivoMantenimiento.vehiculo))) k: x};
    expect(v['Placa'], 'GTA1234');
    expect(v['Kilometraje'], '45200 km');
    final a = {for (final (k, x) in R.filas(ticket(TipoActivoMantenimiento.aireAcondicionado))) k: x};
    expect(a['Fecha de la falla'], '28/10/2026');
    expect(a['Marca'], 'JOHN DEERE');
    expect(a['Especificación'], 'S700 2020');
    expect(a['Serie de máquina'], '—');
  });

  test('Tarjetas: todos los datos de la creación más el detalle, sin fotos', () {
    final filas = {for (final (k, v) in R.filasTarjeta(ticket(TipoActivoMantenimiento.cosechadora))) k: v};
    expect(filas['Máquina'], 'Cosechadora');
    expect(filas['Horómetro'], '1520 h');
    expect(filas['Creado por'], 'Ana');
    expect(filas['Detalles de la falla'], 'Ruido en el motor');
    expect(filas.values.any((v) => v.startsWith('https://')), isFalse);
  });

  test('Línea corta para las bandejas', () {
    expect(R.lineaCorta(ticket(TipoActivoMantenimiento.cosechadora)), 'MANTENIMIENTO CORRECTIVO · COSECHADORA · AQ2');
    expect(R.lineaCorta(ticket(TipoActivoMantenimiento.herramientas)), 'MANTENIMIENTO CORRECTIVO · HERRAMIENTAS · JOHN DEERE');
  });

  test('Fotos: primero la del horómetro / kilometraje, luego las evidencias; y los videos', () {
    final fotos = R.fotos(ticket(TipoActivoMantenimiento.cosechadora));
    expect(fotos.first, ('https://f/horometro.jpg', 'Foto del horómetro'));
    expect(fotos.map((f) => f.$2).skip(1), ['Evidencia 1', 'Evidencia 2']);
    expect(R.videos(ticket(TipoActivoMantenimiento.cosechadora)), ['https://v/1.mp4']);
  });

  test('Nombre de la actividad editable (no vacío); el código no cambia', () {
    const a = ActividadMantenimiento(codigo: 'MO010', nombre: 'Cambio', horasHombre: 1, observacion: 'ok');
    final editada = a.copyWith(nombre: 'Cambio de rodamientos del cabezal');
    expect(editada.codigo, 'MO010');
    expect(EvaluacionMantenimientoService.validar([editada]), isEmpty);
    expect(EvaluacionMantenimientoService.validar([a.copyWith(nombre: ' ')]).single, contains('MO010: escriba el nombre'));
  });
}
