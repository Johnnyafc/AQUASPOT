// test/estado_despacho_test.dart
//
// Picking en Bodega: estado del despacho (estadoDespacho), reglas de
// Iniciar / Finalizar picking, bloqueo de "Finalizar trabajo" y evidencia
// del retiro en las órdenes de recepción.

import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/core/services/acceso_temporal_bodega_service.dart';
import 'package:aquaspot_postventa/features/tickets/data/models/orden_recepcion_repuestos_model.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/item_despacho_bodega_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/orden_recepcion_repuestos_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/registro_despacho_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/estado_despacho_service.dart';
import 'package:flutter_test/flutter_test.dart';

typedef E = EstadoDespachoService;

ItemDespachoBodegaEntity item(String codigo, double solicitado, double despachado) => ItemDespachoBodegaEntity(
      codigo: codigo,
      descripcion: 'Repuesto $codigo',
      unidad: 'UNIDAD',
      cantidadSolicitada: solicitado,
      stockDisponibleAlEvaluar: solicitado,
      cantidadDespachada: despachado,
    );

RegistroDespachoEntity despacho(String id, {bool conFotos = true}) => RegistroDespachoEntity(
      id: id,
      fecha: DateTime(2026, 10, 12),
      usuarioNombre: 'Bodeguero',
      usuarioId: 'u1',
      items: const [],
      fotosEvidenciasUrls: conFotos ? const ['https://foto'] : const [],
    );

TicketEntity ticket({
  List<ItemDespachoBodegaEntity> items = const [],
  List<RegistroDespachoEntity> despachos = const [],
  String? estadoDespacho,
  EstadoTicket estado = EstadoTicket.bodega,
}) =>
    TicketEntity(
      id: 'REQ-1',
      estadoActual: estado,
      sede: Sede.DURAN,
      clienteId: 'CLI',
      campamento: '',
      nombreContacto: '',
      emailContacto: '',
      telefonoContacto: '',
      equipoDetalle: null,
      accesoriosRecibidos: null,
      equipo: TipoEquipo.Caracol,
      fallaReportada: '',
      numeroSerie: null,
      historialEventos: const [],
      tipoRequerimiento: TipoRequerimiento.reparacion,
      lugarAtencion: LugarAtencion.taller,
      esRegistroCompleto: true,
      itemsDespachoBodega: items,
      historialDespachos: despachos,
      estadoDespacho: estadoDespacho,
    );

void main() {
  group('Estado deducido (tickets anteriores sin el campo)', () {
    test('sin entregas → pendiente', () {
      expect(E.deducido(ticket(items: [item('A', 2, 0)])), E.pendiente);
    });
    test('con alguna entrega → despacho parcial', () {
      expect(E.deducido(ticket(items: [item('A', 2, 1)], despachos: [despacho('D1')])), E.despachoParcial);
    });
    test('todo despachado con evidencia → picking finalizado', () {
      expect(E.deducido(ticket(items: [item('A', 2, 2)], despachos: [despacho('D1')])), E.pickingFinalizado);
    });
    test('todo despachado pero sin evidencia → sigue en despacho parcial', () {
      expect(E.deducido(ticket(items: [item('A', 2, 2)], despachos: [despacho('D1', conFotos: false)])),
          E.despachoParcial);
    });
    test('el valor guardado en Firestore manda sobre el deducido', () {
      final t = ticket(items: [item('A', 2, 2)], despachos: [despacho('D1')], estadoDespacho: E.despachoParcial);
      expect(E.efectivo(t), E.despachoParcial);
    });
  });

  group('Botones de la tarjeta', () {
    test('Iniciar picking solo en pendiente; la ventana solo con picking iniciado', () {
      final pendiente = ticket(items: [item('A', 2, 0)], estadoDespacho: E.pendiente);
      expect(E.puedeIniciarPicking(pendiente), isTrue);
      expect(E.pickingIniciado(pendiente), isFalse);
      final enCurso = ticket(items: [item('A', 2, 0)], estadoDespacho: E.pickingEnCurso);
      expect(E.puedeIniciarPicking(enCurso), isFalse);
      expect(E.pickingIniciado(enCurso), isTrue);
    });

    test('Finalizar picking: todo con check (100 %) y todas las entregas con evidencia', () {
      final faltaDespachar = ticket(items: [item('A', 2, 1)], despachos: [despacho('D1')], estadoDespacho: E.despachoParcial);
      expect(E.puedeFinalizarPicking(faltaDespachar), isFalse);
      expect(E.motivoNoFinaliza(faltaDespachar), 'Faltan repuestos por despachar.');

      final sinEvidencia = ticket(
        items: [item('A', 2, 2)],
        despachos: [despacho('D1'), despacho('D2', conFotos: false)],
        estadoDespacho: E.despachoParcial,
      );
      expect(E.puedeFinalizarPicking(sinEvidencia), isFalse);
      expect(E.motivoNoFinaliza(sinEvidencia), 'Hay despachos sin evidencia.');

      final listo = ticket(items: [item('A', 2, 2)], despachos: [despacho('D1')], estadoDespacho: E.despachoParcial);
      expect(E.puedeFinalizarPicking(listo), isTrue);
      expect(E.motivoNoFinaliza(listo), isNull);

      final sinIniciar = ticket(items: [item('A', 2, 0)], estadoDespacho: E.pendiente);
      expect(E.motivoNoFinaliza(sinIniciar), 'Inicie el picking primero.');
    });

    test('porcentaje despachado por cantidades (sin pasar de lo solicitado)', () {
      final t = ticket(items: [item('A', 2, 1), item('B', 2, 3)]);
      expect(E.porcentajeDespachado(t), 75);
    });
  });

  group('Proceso de Trabajo', () {
    test('no se finaliza el trabajo con materiales sin despachar', () {
      expect(E.materialesDespachados(ticket()), isTrue); // sin materiales
      expect(
          E.materialesDespachados(ticket(items: [item('A', 2, 2)], despachos: [despacho('D1')], estadoDespacho: E.despachoParcial)),
          isFalse);
      expect(
          E.materialesDespachados(ticket(items: [item('A', 2, 2)], despachos: [despacho('D1')], estadoDespacho: E.pickingFinalizado)),
          isTrue);
    });
  });

  group('Validación simple', () {
    test('el caso "despacho cerrado sin traspaso" solo aplica a tickets sin estadoDespacho', () {
      final antiguo = ticket(items: [item('A', 2, 2)], despachos: [despacho('D1')]);
      expect(antiguo.requiereValidacionSimpleBodega, isTrue);
      final conPicking = ticket(items: [item('A', 2, 2)], despachos: [despacho('D1')], estadoDespacho: E.despachoParcial);
      expect(conPicking.requiereValidacionSimpleBodega, isFalse);
    });
  });

  group('Tipo de imagen de las fotos del enlace externo', () {
    test('si el navegador entrega el tipo vacío, se deduce por la extensión', () {
      expect(AccesoTemporalBodegaService.tipoImagen('', 'hoja.png'), 'image/png');
      expect(AccesoTemporalBodegaService.tipoImagen(null, 'foto.HEIC'), 'image/heic');
      expect(AccesoTemporalBodegaService.tipoImagen('application/octet-stream', 'x.jpg'), 'image/jpeg');
      expect(AccesoTemporalBodegaService.tipoImagen('image/webp', 'x.jpg'), 'image/webp');
      expect(AccesoTemporalBodegaService.tipoImagen('', 'sin_extension'), 'image/jpeg');
    });
  });

  group('Evidencia del retiro en la orden de recepción', () {
    test('se guarda y se lee con el modelo; sin fotos no hay evidencia', () {
      final orden = OrdenRecepcionRepuestosEntity(
        id: 'ORD-1',
        ticketId: 'REQ-1',
        tecnicoId: 't1',
        tecnicoNombre: 'Técnico',
        supervisorAsigna: 'Sup',
        fechaAsignacion: DateTime(2026, 10, 12),
        validadoSupervisor: true,
        supervisorValida: 'Sup',
        urlsHojaFirmada: const ['https://hoja'],
        urlsFotosMateriales: const ['https://mat1', 'https://mat2'],
      );
      final leida = OrdenRecepcionRepuestosModel.fromJson(OrdenRecepcionRepuestosModel.fromEntity(orden).toJson());
      expect(leida.urlsHojaFirmada, ['https://hoja']);
      expect(leida.urlsFotosMateriales, ['https://mat1', 'https://mat2']);
      expect(leida.tieneEvidenciaRetiro, isTrue);
      // La certificación del supervisor no se pierde al serializar.
      expect(leida.validadoSupervisor, isTrue);
      expect(orden.copyWith(urlsFotosMateriales: const []).tieneEvidenciaRetiro, isFalse);
    });
  });
}
