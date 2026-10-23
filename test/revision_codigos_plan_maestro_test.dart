// test/revision_codigos_plan_maestro_test.dart
//
// Revisión de Códigos del Plan Maestro: comparación plan vs inventario,
// exclusiones (servicios / mano de obra), sugerencias y reemplazo.

import 'package:aquaspot_postventa/features/catalogo/domain/entities/actividad_catalogo_entity.dart';
import 'package:aquaspot_postventa/features/catalogo/domain/entities/item_catalogo_entity.dart';
import 'package:aquaspot_postventa/features/catalogo/domain/services/revision_codigos_plan_maestro_service.dart';
import 'package:aquaspot_postventa/features/inventario/domain/entities/item_inventario_entity.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Svc = RevisionCodigosPlanMaestroService;

ItemInventarioEntity inv(String codigo, String descripcion, {double stock = 5, double reservado = 0}) =>
    ItemInventarioEntity(
      codigo: codigo,
      descripcion: descripcion,
      stockDisponible: stock,
      stockReservado: reservado,
      fechaActualizacion: DateTime(2026, 10, 8),
    );

ActividadCatalogoEntity act(
  String codigo, {
  List<ItemCatalogoEntity> internos = const [],
  List<ItemCatalogoEntity> comerciales = const [],
}) =>
    ActividadCatalogoEntity(
      id: 'caracol_${codigo.toLowerCase()}',
      codigo: codigo,
      nombre: 'Actividad $codigo',
      equipo: 'caracol',
      esVariable: false,
      itemsInternos: internos,
      itemsComerciales: comerciales,
    );

void main() {
  final inventario = [
    inv('HID000239', 'KIT DE MANTENIMIENTO PARA MOTOR CHARLYNN SERIE 2000'),
    inv('PER000119', "TUERCA CASTILLA NEGRA 1'' - 20 HILOS"),
    inv('MEC000003', 'ABRAZADERA DE SERPENTÍN 3D', stock: 10, reservado: 4),
    inv('INS000065', 'LIJA DE AGUA 120'),
    inv('ELC000001', 'ALTERNADOR JOHN DEERE'),
  ];

  group('Exclusiones (servicios y mano de obra)', () {
    test('SER y MO se excluyen; MOT no', () {
      expect(Svc.esExcluido(const ItemCatalogoEntity(codigo: 'SER00052', descripcion: 'SANDBLASTING')), isTrue);
      expect(Svc.esExcluido(const ItemCatalogoEntity(codigo: 'MO001', descripcion: 'DESARMADO')), isTrue);
      expect(Svc.esExcluido(const ItemCatalogoEntity(codigo: 'MOT000010', descripcion: 'MOTOR')), isFalse);
      expect(Svc.esExcluido(const ItemCatalogoEntity(codigo: 'INS000065', descripcion: 'DISCO DE CORTE')), isFalse);
    });

    test('por descripción: SERVICIO / MANO DE OBRA (con o sin tildes)', () {
      expect(Svc.esExcluido(const ItemCatalogoEntity(codigo: 'XYZ001', descripcion: 'Servicio de torno')), isTrue);
      expect(Svc.esExcluido(const ItemCatalogoEntity(codigo: '', descripcion: 'Mano de obra soldadura')), isTrue);
    });
  });

  group('revisar', () {
    final actividades = [
      act('MO001', internos: const [
        ItemCatalogoEntity(codigo: 'HID00239', descripcion: 'KIT DE MANTENIMIENTO PARA MOTOR CHARLYNN SERIE 2000'),
        ItemCatalogoEntity(codigo: 'MEC000003', descripcion: 'ABRAZADERA DE SERPENTIN 3D', cantidad: 2),
        ItemCatalogoEntity(codigo: 'SER00052', descripcion: 'SERVICIO DE SANDBLASTING'),
      ], comerciales: const [
        ItemCatalogoEntity(codigo: 'INS000065', descripcion: "DISCO DE CORTE DE 4.5'' X 1MM"),
      ]),
      act('MO002', internos: const [
        ItemCatalogoEntity(codigo: 'mec000003 ', descripcion: 'ABRAZADERA SERPENTIN 3D'),
        ItemCatalogoEntity(codigo: '', descripcion: 'PERNO SIN CODIGO'),
        ItemCatalogoEntity(codigo: 'HID00239', descripcion: 'KIT MANTENIMIENTO CHARLYNN'),
      ]),
    ];
    final r = Svc.revisar(actividades: actividades, inventario: inventario);
    RevisionCodigoPlan fila(String codigo) =>
        r.filas.firstWhere((f) => Svc.normalizarCodigo(f.codigo) == codigo);

    test('agrupa por código (sin importar mayúsculas/espacios) y excluye servicios', () {
      expect(r.excluidos.map((u) => u.item.codigo), ['SER00052']);
      expect(fila('MEC000003').numActividades, 2);
      expect(r.filas.length, 4); // HID00239, MEC000003, INS000065, sin código
    });

    test('estados', () {
      expect(fila('HID00239').estado, EstadoCodigoPlan.noExiste);
      expect(fila('MEC000003').estado, EstadoCodigoPlan.coincide); // tildes y "DE" no cuentan
      expect(fila('INS000065').estado, EstadoCodigoPlan.descripcionDistinta);
      expect(r.filas.firstWhere((f) => f.codigo.isEmpty).estado, EstadoCodigoPlan.sinCodigo);
    });

    test('aviso de descripciones distintas dentro del equipo', () {
      expect(fila('HID00239').descripcionesInconsistentes, isTrue);
      expect(fila('INS000065').descripcionesInconsistentes, isFalse);
    });

    test('orden: no existe → descripción distinta → sin código → coincide', () {
      expect(r.filas.map((f) => f.estado).toList(), [
        EstadoCodigoPlan.noExiste,
        EstadoCodigoPlan.descripcionDistinta,
        EstadoCodigoPlan.sinCodigo,
        EstadoCodigoPlan.coincide,
      ]);
      expect(r.contar(EstadoCodigoPlan.noExiste), 1);
    });

    test('stock neto del inventario disponible en la fila', () {
      expect(fila('MEC000003').inventario!.stockNetoDisponible, 6);
    });
  });

  group('sugerencias', () {
    test('código con un cero de menos: la primera sugerencia es el código correcto', () {
      final s = Svc.sugerir(
        codigoPlan: 'HID00239',
        descripcionPlan: 'KIT DE MANTENIMIENTO PARA MOTOR CHARLYNN SERIE 2000',
        inventario: inventario,
      );
      expect(s.first.item.codigo, 'HID000239');
      expect(s.first.puntaje, greaterThan(0.9));
    });

    test('por descripción cuando el código no se parece', () {
      final s = Svc.sugerir(codigoPlan: 'XX1', descripcionPlan: 'ALTERNADOR JOHN DEERE 12V', inventario: inventario);
      expect(s.first.item.codigo, 'ELC000001');
    });

    test('nunca sugiere el mismo código y devuelve como máximo 5', () {
      final s = Svc.sugerir(codigoPlan: 'INS000065', descripcionPlan: 'LIJA', inventario: inventario);
      expect(s.any((x) => x.item.codigo == 'INS000065'), isFalse);
      expect(s.length, lessThanOrEqualTo(5));
    });

    test('similitud de código: guiones y ceros', () {
      expect(Svc.similitudCodigo('HID-000239', 'HID000239'), 0.97);
      expect(Svc.similitudCodigo('HID00239', 'HID000239'), 0.95);
      expect(Svc.similitudCodigo('PER000119', 'PER000119'), 1);
    });
  });

  group('reemplazarEnLista', () {
    final items = [
      {'codigo': 'HID00239', 'descripcion': 'KIT', 'unidad': 'UNIDAD', 'cantidad': 2.0},
      {'codigo': 'PER000119', 'descripcion': 'TUERCA', 'unidad': 'UNIDAD', 'cantidad': 4.0},
      {'codigo': '', 'descripcion': 'Perno sin código', 'unidad': 'UNIDAD', 'cantidad': 1.0},
    ];

    test('cambia código, descripción y unidad y conserva la cantidad', () {
      final r = Svc.reemplazarEnLista(
        items: items,
        codigoAnterior: 'hid00239',
        descripcionAnterior: 'KIT',
        codigoNuevo: 'HID000239',
        descripcionNueva: 'KIT DE MANTENIMIENTO',
        unidadNueva: 'JGO',
      )!;
      expect(r[0], {'codigo': 'HID000239', 'descripcion': 'KIT DE MANTENIMIENTO', 'unidad': 'JGO', 'cantidad': 2.0});
      expect(r[1], items[1]);
      expect(items[0]['codigo'], 'HID00239'); // no modifica la lista original
    });

    test('sin descripción/unidad nuevas, cada ítem conserva las suyas', () {
      final r = Svc.reemplazarEnLista(
        items: items,
        codigoAnterior: 'PER000119',
        descripcionAnterior: 'TUERCA',
        codigoNuevo: 'PER000120',
      )!;
      expect(r[1]['descripcion'], 'TUERCA');
      expect(r[1]['codigo'], 'PER000120');
    });

    test('ítem sin código: se identifica por descripción', () {
      final r = Svc.reemplazarEnLista(
        items: items,
        codigoAnterior: '',
        descripcionAnterior: 'PERNO SIN CODIGO',
        codigoNuevo: 'PER000200',
      )!;
      expect(r[2]['codigo'], 'PER000200');
    });

    test('null si no hay nada que cambiar', () {
      expect(
        Svc.reemplazarEnLista(items: items, codigoAnterior: 'NOEXISTE', descripcionAnterior: '', codigoNuevo: 'X'),
        isNull,
      );
    });

    test('huella ignora el orden de las claves', () {
      expect(
        Svc.huellaItems([{'codigo': 'A', 'descripcion': 'B', 'unidad': 'U', 'cantidad': 1.0}]),
        Svc.huellaItems([{'cantidad': 1.0, 'unidad': 'U', 'descripcion': 'B', 'codigo': 'A'}]),
      );
    });
  });
}
