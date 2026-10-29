// test/menu_principal_test.dart
//
// Menú principal: qué ve cada rol (los mismos permisos que tenía el menú,
// más "Plan Preventivo" para supervisor y admin), sin opciones repetidas,
// secciones y buscador (sin tildes, por palabras clave) con resaltado.

import 'package:aquaspot_postventa/core/enum/rol_usuario.dart';
import 'package:aquaspot_postventa/core/utils/constants.dart' show correoAdministradorMaestro;
import 'package:aquaspot_postventa/features/auth/domain/services/menu_principal_service.dart';
import 'package:flutter_test/flutter_test.dart';

typedef M = MenuPrincipalService;

Set<OpcionMenu> ve(RolUsuario rol, {String email = 'x@aquaspot.ec'}) => M.visibles(rol: rol, email: email).toSet();

void main() {
  group('Permisos por rol (iguales al menú anterior)', () {
    test('Técnico: solo Recepción Bodega', () {
      expect(ve(RolUsuario.tecnico), {OpcionMenu.recepcionBodega});
    });

    test('Requerimiento: Crear Ticket y Biblioteca', () {
      expect(ve(RolUsuario.requerimiento), {OpcionMenu.crearTicket, OpcionMenu.biblioteca});
    });

    test('Recepción: Tickets y Biblioteca', () {
      expect(ve(RolUsuario.recepcion), {OpcionMenu.tickets, OpcionMenu.biblioteca});
    });

    test('Supervisor: taller, catálogos y Plan Preventivo; nada comercial ni de compras', () {
      expect(ve(RolUsuario.supervisor), {
        OpcionMenu.biblioteca,
        OpcionMenu.crearTicket,
        OpcionMenu.tickets,
        OpcionMenu.recepcionGuabo,
        OpcionMenu.evaluaciones,
        OpcionMenu.evaluacionesOt,
        OpcionMenu.procesoTrabajo,
        OpcionMenu.procesoTrabajoOt,
        OpcionMenu.recepcionBodega,
        OpcionMenu.garantias,
        OpcionMenu.catalogoActividades,
        OpcionMenu.revisionCodigosPlanMaestro,
        OpcionMenu.planPreventivo,
        OpcionMenu.tecnicos,
        OpcionMenu.metricasFallas,
        OpcionMenu.fallasTicketsAntiguos,
      });
    });

    test('Comercial', () {
      expect(ve(RolUsuario.comercial), {
        OpcionMenu.biblioteca,
        OpcionMenu.crearTicket,
        OpcionMenu.clientes,
        OpcionMenu.crearProforma,
        OpcionMenu.proformasEnviadas,
        OpcionMenu.validacionEntregas,
        OpcionMenu.entregaFacturacion,
      });
    });

    test('Costos, Compras y Bodega', () {
      expect(ve(RolUsuario.costos), {OpcionMenu.biblioteca, OpcionMenu.crearProyecto, OpcionMenu.creacionCodigos});
      expect(ve(RolUsuario.compras),
          {OpcionMenu.biblioteca, OpcionMenu.compras, OpcionMenu.validacionBodegaCompras, OpcionMenu.inventario});
      expect(ve(RolUsuario.bodega), {OpcionMenu.biblioteca, OpcionMenu.despachoBodega, OpcionMenu.inventario});
    });

    test('Admin ve todo menos las opciones de la cuenta maestra, sin repetir Inventario', () {
      final admin = M.visibles(rol: RolUsuario.admin, email: 'otro@aquaspot.ec');
      expect(admin.length, admin.toSet().length);
      expect(admin.where((o) => o == OpcionMenu.inventario).length, 1);
      expect(admin.toSet(), OpcionMenu.values.toSet()..removeAll([OpcionMenu.modificarTicket, OpcionMenu.inconsistencias]));
    });

    test('Cuenta administradora maestra: Modificar Ticket e Inconsistencias', () {
      final maestra = ve(RolUsuario.admin, email: correoAdministradorMaestro);
      expect(maestra, containsAll([OpcionMenu.modificarTicket, OpcionMenu.inconsistencias]));
      expect(ve(RolUsuario.admin), isNot(contains(OpcionMenu.modificarTicket)));
    });

    test('Todas las opciones tienen datos', () {
      for (final o in OpcionMenu.values) {
        expect(M.datos[o], isNotNull, reason: o.name);
      }
    });
  });

  test('Agrupa por sección en orden, solo las que tienen opciones', () {
    final grupos = M.agrupar(M.visibles(rol: RolUsuario.compras, email: ''));
    expect(grupos.map((g) => g.$1), [SeccionMenu.tickets, SeccionMenu.costosCompras, SeccionMenu.bodega]);
    expect(grupos[1].$2, [OpcionMenu.compras, OpcionMenu.validacionBodegaCompras]);
  });

  group('Buscador', () {
    final todas = M.visibles(rol: RolUsuario.admin, email: '');

    test('Sin tildes ni mayúsculas', () {
      expect(M.buscar(todas, 'EVALUACION'), contains(OpcionMenu.evaluaciones));
      expect(M.buscar(todas, 'orden de trabajo'), containsAll([OpcionMenu.evaluacionesOt, OpcionMenu.procesoTrabajoOt]));
      expect(M.buscar(todas, 'garantía'), contains(OpcionMenu.garantias));
    });

    test('Por palabras clave y todas las palabras', () {
      expect(M.buscar(todas, 'stock'), [OpcionMenu.inventario]);
      expect(M.buscar(todas, 'preventivo'), [OpcionMenu.planPreventivo]);
      expect(M.buscar(todas, 'picking'), [OpcionMenu.despachoBodega]);
      expect(M.buscar(todas, 'plan maestro codigos'), [OpcionMenu.revisionCodigosPlanMaestro]);
    });

    test('Vacío devuelve todo; sin coincidencias, nada', () {
      expect(M.buscar(todas, '  '), todas);
      expect(M.buscar(todas, 'zzzz'), isEmpty);
    });

    test('Resalta lo buscado en el título (sin tildes, tramos unidos)', () {
      expect(M.resaltar('Evaluaciones Técnicas', 'tecni'), [(13, 18)]);
      expect(M.resaltar('Plan Preventivo', 'plan prev'), [(0, 4), (5, 9)]);
      expect(M.resaltar('Compras', 'comp ompr'), [(0, 5)]);
      expect(M.resaltar('Compras', ''), isEmpty);
    });
  });
}
