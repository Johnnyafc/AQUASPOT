import 'package:flutter_test/flutter_test.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/item_despacho_bodega_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/orden_recepcion_repuestos_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/registro_despacho_entity.dart';
import 'package:aquaspot_postventa/features/tickets/data/models/registro_despacho_model.dart';
import 'package:aquaspot_postventa/features/tickets/data/models/ticket_model.dart';
import 'package:aquaspot_postventa/features/tickets/data/models/orden_recepcion_repuestos_model.dart';
import 'package:aquaspot_postventa/features/tecnicos/data/models/tecnico_model.dart';
import 'package:aquaspot_postventa/features/tickets/data/models/token_recepcion_externa_model.dart';
import 'package:aquaspot_postventa/core/services/acceso_temporal_bodega_service.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/services/generador_excel_despacho_bodega.dart';

void main() {
  group('Circuito Logística Integral Bodega -> Técnico -> Supervisor -> Taller', () {
    test('1. ItemDespachoBodegaEntity: estaHabilitadoParaDespacho con stock local sin requerir compras', () {
      const itemConStock = ItemDespachoBodegaEntity(
        codigo: 'REP-001',
        descripcion: 'Filtro de Aceite',
        unidad: 'UND',
        cantidadSolicitada: 2,
        stockDisponibleAlEvaluar: 5,
        validadoPorCompras: false,
      );

      const itemSinStockNiCompras = ItemDespachoBodegaEntity(
        codigo: 'REP-002',
        descripcion: 'Válvula Especial',
        unidad: 'UND',
        cantidadSolicitada: 1,
        stockDisponibleAlEvaluar: 0,
        validadoPorCompras: false,
      );

      const itemSinStockPeroValidadoCompras = ItemDespachoBodegaEntity(
        codigo: 'REP-003',
        descripcion: 'Sensor de Presión',
        unidad: 'UND',
        cantidadSolicitada: 1,
        stockDisponibleAlEvaluar: 0,
        validadoPorCompras: true,
      );

      expect(itemConStock.tieneStockSuficiente, isTrue);
      expect(itemConStock.estaHabilitadoParaDespacho, isTrue);

      expect(itemSinStockNiCompras.tieneStockSuficiente, isFalse);
      expect(itemSinStockNiCompras.estaHabilitadoParaDespacho, isFalse);

      expect(itemSinStockPeroValidadoCompras.tieneStockSuficiente, isFalse);
      expect(itemSinStockPeroValidadoCompras.estaHabilitadoParaDespacho, isTrue);
    });

    test('2. Enclavamientos de Validación en Taller y Liberación', () {
      final ticketBase = TicketModel.fromJson({
        'id': 'TICK-TEST-1',
        'estadoActual': 'procesoTrabajo',
        'sede': 'DURAN',
        'clienteId': 'CLI-01',
        'campamento': 'Camp 1',
        'nombreContacto': 'Juan Perez',
        'emailContacto': 'juan@mail.com',
        'telefonoContacto': '0999999999',
        'equipo': 'Caracol',
        'fallaReportada': 'Ruido',
      }).copyWith(
        trabajoIniciado: false,
        materialesValidadosEnTaller: false,
        itemsDespachoBodega: const [
          ItemDespachoBodegaEntity(
            codigo: 'REP-A',
            descripcion: 'Empaque',
            unidad: 'UND',
            cantidadSolicitada: 2,
            stockDisponibleAlEvaluar: 2,
            cantidadDespachada: 2,
          ),
          ItemDespachoBodegaEntity(
            codigo: 'REP-B',
            descripcion: 'Rodamiento',
            unidad: 'UND',
            cantidadSolicitada: 1,
            stockDisponibleAlEvaluar: 1,
            cantidadDespachada: 1,
          ),
        ],
      );

      // A) No iniciado, sin recepciones -> No puede validar ni liberar
      expect(ticketBase.todosRepuestosRecibidosEnTaller, isFalse);
      expect(ticketBase.puedeSupervisorValidarMateriales, isFalse);
      expect(ticketBase.puedeLiberarEnTaller, isFalse);
      expect(ticketBase.itemsPendientesDeRecogerEnBodega.length, equals(2));
      expect(ticketBase.cantidadPendienteRecogerEnBodega('REP-A'), equals(2.0));

      // B) Técnico recoge REP-A parcialmente (1 de 2)
      final orden1 = OrdenRecepcionRepuestosEntity(
        id: 'REC-1',
        ticketId: 'TICK-TEST-1',
        tecnicoId: 'TEC-1',
        tecnicoNombre: 'Pedro Gomez',
        supervisorAsigna: 'Carlos Supervisor',
        fechaAsignacion: DateTime.now(),
        fechaRecepcion: DateTime.now(),
        estado: EstadoOrdenRecepcion.recibidoParcial,
        items: const [
          ItemRecepcionRepuestoEntity(
            codigo: 'REP-A',
            descripcion: 'Empaque',
            unidad: 'UND',
            cantidadDespachadaBodega: 2,
            cantidadRecibidaTecnico: 1,
            validado: true,
          ),
        ],
      );

      final ticketConOrden1 = ticketBase.copyWith(ordenesRecepcion: [orden1]);
      expect(ticketConOrden1.cantidadTotalRecibidaEnTaller('REP-A'), equals(1.0));
      expect(ticketConOrden1.cantidadPendienteRecogerEnBodega('REP-A'), equals(1.0));
      expect(ticketConOrden1.todosRepuestosRecibidosEnTaller, isFalse);
      expect(ticketConOrden1.puedeSupervisorValidarMateriales, isFalse);

      // C) Técnico recoge el saldo de REP-A (1 restante) y todo REP-B (1)
      final orden2 = OrdenRecepcionRepuestosEntity(
        id: 'REC-2',
        ticketId: 'TICK-TEST-1',
        tecnicoId: 'TEC-1',
        tecnicoNombre: 'Pedro Gomez',
        supervisorAsigna: 'Carlos Supervisor',
        fechaAsignacion: DateTime.now(),
        fechaRecepcion: DateTime.now(),
        estado: EstadoOrdenRecepcion.recibidoTotal,
        items: const [
          ItemRecepcionRepuestoEntity(
            codigo: 'REP-A',
            descripcion: 'Empaque',
            unidad: 'UND',
            cantidadDespachadaBodega: 1,
            cantidadRecibidaTecnico: 1,
            validado: true,
          ),
          ItemRecepcionRepuestoEntity(
            codigo: 'REP-B',
            descripcion: 'Rodamiento',
            unidad: 'UND',
            cantidadDespachadaBodega: 1,
            cantidadRecibidaTecnico: 1,
            validado: true,
          ),
        ],
      );

      final ticketConTodoRecibido = ticketBase.copyWith(
        ordenesRecepcion: [orden1, orden2],
      );

      expect(ticketConTodoRecibido.cantidadTotalRecibidaEnTaller('REP-A'), equals(2.0));
      expect(ticketConTodoRecibido.cantidadTotalRecibidaEnTaller('REP-B'), equals(1.0));
      expect(ticketConTodoRecibido.cantidadPendienteRecogerEnBodega('REP-A'), equals(0.0));
      expect(ticketConTodoRecibido.cantidadPendienteRecogerEnBodega('REP-B'), equals(0.0));
      expect(ticketConTodoRecibido.itemsPendientesDeRecogerEnBodega.isEmpty, isTrue);

      // Ahora el 100% está en taller: el supervisor PUEDE validar
      expect(ticketConTodoRecibido.todosRepuestosRecibidosEnTaller, isTrue);
      expect(ticketConTodoRecibido.puedeSupervisorValidarMateriales, isTrue);

      // Pero aún no puede liberar porque falta iniciar trabajo y la validación formal
      expect(ticketConTodoRecibido.puedeLiberarEnTaller, isFalse);

      // D) Inicia trabajo y Supervisor valida formalmente
      final ticketValidadoYIniciado = ticketConTodoRecibido.copyWith(
        trabajoIniciado: true,
        materialesValidadosEnTaller: true,
        supervisorValidoMateriales: 'Carlos Supervisor',
        fechaValidacionMaterialesTaller: DateTime.now(),
      );

      expect(ticketValidadoYIniciado.puedeLiberarEnTaller, isTrue);
    });

    test('3. Ticket sin compras ni repuestos: puedeLiberarEnTaller solo exige trabajoIniciado', () {
      final ticketSinRepuestos = TicketModel.fromJson({
        'id': 'TICK-TEST-2',
        'estadoActual': 'procesoTrabajo',
        'sede': 'DURAN',
        'clienteId': 'CLI-02',
        'campamento': 'Camp 2',
        'nombreContacto': 'Maria Lopez',
        'emailContacto': 'maria@mail.com',
        'telefonoContacto': '0999999998',
        'equipo': 'Caracol',
        'fallaReportada': 'Mantenimiento preventivo',
      }).copyWith(
        trabajoIniciado: false,
        noRequiereCompras: true,
      );

      expect(ticketSinRepuestos.puedeLiberarEnTaller, isFalse);

      final ticketIniciado = ticketSinRepuestos.copyWith(trabajoIniciado: true);
      expect(ticketIniciado.puedeLiberarEnTaller, isTrue);
    });

    test('3.b Retiro parcial sucesivo, saldo dinámico por asignar y certificación parcial de consumo', () {
      final ticketConPartes = TicketModel.fromJson({
        'id': 'TICK-TEST-PARTIAL',
        'estadoActual': 'compras',
        'codigoProyecto': 'PROJ-999',
        'sede': 'DURAN',
        'clienteId': 'CLI-03',
        'campamento': 'Camp 3',
        'nombreContacto': 'Carlos',
        'emailContacto': 'carlos@mail.com',
        'telefonoContacto': '0999999991',
        'equipo': 'Caracol',
        'fallaReportada': 'Cambio pernos',
      }).copyWith(
        trabajoIniciado: true,
        itemsDespachoBodega: const [
          ItemDespachoBodegaEntity(
            codigo: 'PERNO-01',
            descripcion: 'Pernos Grado 8',
            unidad: 'UND',
            cantidadSolicitada: 10,
            stockDisponibleAlEvaluar: 10,
            cantidadDespachada: 6,
          ),
          ItemDespachoBodegaEntity(
            codigo: 'EMPAQUE-02',
            descripcion: 'Empaque Especial',
            unidad: 'UND',
            cantidadSolicitada: 1,
            stockDisponibleAlEvaluar: 0,
            validadoPorCompras: false,
            cantidadDespachada: 0,
          ),
        ],
      );

      // Hay 6 pernos alistados en Bodega que aún no se han asignado a ningún técnico
      expect(ticketConPartes.cantidadDisponibleParaAsignarRetiro('PERNO-01'), equals(6.0));
      expect(ticketConPartes.hayMaterialesDespachadosPorAsignar, isTrue);

      // Se asigna orden para que Técnico 1 recoja los 6
      final ordenT1 = OrdenRecepcionRepuestosEntity(
        id: 'ORD-P1',
        ticketId: 'TICK-TEST-PARTIAL',
        tecnicoId: 'TEC-1',
        tecnicoNombre: 'Técnico 1',
        supervisorAsigna: 'Supervisor',
        fechaAsignacion: DateTime.now(),
        estado: EstadoOrdenRecepcion.pendienteRecoger,
        items: const [
          ItemRecepcionRepuestoEntity(
            codigo: 'PERNO-01',
            descripcion: 'Pernos Grado 8',
            unidad: 'UND',
            cantidadDespachadaBodega: 6,
            cantidadRecibidaTecnico: 0,
            validado: false,
          ),
        ],
      );

      final ticketConOrdenT1 = ticketConPartes.copyWith(ordenesRecepcion: [ordenT1]);
      // Mientras la orden esté en tránsito (pendiente), el saldo disponible para asignar es 0
      expect(ticketConOrdenT1.cantidadDisponibleParaAsignarRetiro('PERNO-01'), equals(0.0));
      expect(ticketConOrdenT1.hayMaterialesDespachadosPorAsignar, isFalse);

      // Técnico 1 realiza el conteo físico en Bodega y retira parcialmente 4 pernos (quedaron 2)
      final ordenT1CompletadaParcial = ordenT1.copyWith(
        estado: EstadoOrdenRecepcion.recibidoParcial,
        fechaRecepcion: DateTime.now(),
        items: const [
          ItemRecepcionRepuestoEntity(
            codigo: 'PERNO-01',
            descripcion: 'Pernos Grado 8',
            unidad: 'UND',
            cantidadDespachadaBodega: 6,
            cantidadRecibidaTecnico: 4,
            validado: false,
          ),
        ],
      );

      final ticketConEntregaT1 = ticketConPartes.copyWith(
        ordenesRecepcion: [ordenT1CompletadaParcial],
      );

      // Al completarse la orden por 4 unidades, el saldo restante (6 - 4 = 2) vuelve a estar disponible para asignar
      expect(ticketConEntregaT1.cantidadDisponibleParaAsignarRetiro('PERNO-01'), equals(2.0));
      expect(ticketConEntregaT1.hayMaterialesDespachadosPorAsignar, isTrue);

      // El lote de 4 pernos llegó al taller, pero el supervisor aún no ha certificado su consumo
      expect(ticketConEntregaT1.tieneAlMenosUnLoteRecibidoEnTaller, isTrue);
      expect(ticketConEntregaT1.tieneConsumoValidadoEnTaller, isFalse);
      expect(ticketConEntregaT1.puedeLiberarEnTaller, isFalse);

      // El supervisor presiona "Validar Consumo de este Lote" en la orden ORD-P1
      final ordenT1ValidadaSupervisor = ordenT1CompletadaParcial.copyWith(
        validadoSupervisor: true,
        fechaValidadoSupervisor: DateTime.now(),
        supervisorValida: 'Supervisor Principal',
      );

      final ticketLoteValidado = ticketConEntregaT1.copyWith(
        ordenesRecepcion: [ordenT1ValidadaSupervisor],
      );

      expect(ticketLoteValidado.tieneConsumoValidadoEnTaller, isTrue);
      // ¡No hay bloqueo circular! Como inició el trabajo y certificó el consumo del lote recibido, puede liberar
      expect(ticketLoteValidado.puedeLiberarEnTaller, isTrue);
      // Y aún sabe que Compras / Bodega general no han completado el 100% total
      expect(ticketLoteValidado.comprasYBodegaTotalmenteCompletados, isFalse);
    });

    test('4. Serialización y Deserialización en TicketModel (Retrocompatibilidad)', () {
      final jsonLegado = <String, dynamic>{
        'id': 'REQ-00046',
        'estadoActual': 'procesoTrabajo',
        'sede': 'DURAN',
        'clienteId': 'CLI-001',
        'campamento': 'Principal',
        'nombreContacto': 'Ing. Andrade',
        'emailContacto': 'andrade@empresa.com',
        'telefonoContacto': '0987654321',
        'equipo': 'Caracol',
        'fallaReportada': 'Fuga en sello',
      };

      final modelLegado = TicketModel.fromJson(jsonLegado);
      expect(modelLegado.ordenesRecepcion, isEmpty);
      expect(modelLegado.materialesValidadosEnTaller, isFalse);
      expect(modelLegado.supervisorValidoMateriales, isNull);

      // Agregar órdenes y validación
      final ordenModel = OrdenRecepcionRepuestosModel(
        id: 'REC-12345',
        ticketId: 'REQ-00046',
        tecnicoId: 'TEC-99',
        tecnicoNombre: 'Marcos Ruiz',
        supervisorAsigna: 'Supervisor Taller',
        fechaAsignacion: DateTime(2026, 9, 16, 8, 30),
        estado: EstadoOrdenRecepcion.recibidoTotal,
        items: const [
          ItemRecepcionRepuestoModel(
            codigo: 'SELLO-01',
            descripcion: 'Sello Mecánico 2 pulg',
            unidad: 'UND',
            cantidadDespachadaBodega: 1,
            cantidadRecibidaTecnico: 1,
            validado: true,
          ),
        ],
      );

      final modelNuevo = TicketModel.fromEntity(modelLegado.copyWith(
        ordenesRecepcion: [ordenModel],
        materialesValidadosEnTaller: true,
        supervisorValidoMateriales: 'Supervisor Taller',
        fechaValidacionMaterialesTaller: DateTime(2026, 9, 16, 9, 0),
      ));

      final jsonNuevo = modelNuevo.toJson();
      expect(jsonNuevo['materialesValidadosEnTaller'], isTrue);
      expect(jsonNuevo['supervisorValidoMateriales'], equals('Supervisor Taller'));
      expect(jsonNuevo['ordenesRecepcion'], isA<List>());
      expect((jsonNuevo['ordenesRecepcion'] as List).length, equals(1));

      // Deserializar el nuevo JSON
      final deserializado = TicketModel.fromJson(jsonNuevo);
      expect(deserializado.materialesValidadosEnTaller, isTrue);
      expect(deserializado.supervisorValidoMateriales, equals('Supervisor Taller'));
      expect(deserializado.ordenesRecepcion.length, equals(1));
      expect(deserializado.ordenesRecepcion.first.items.first.codigo, equals('SELLO-01'));
      expect(deserializado.ordenesRecepcion.first.items.first.cantidadRecibidaTecnico, equals(1.0));
    });
  });

  group('Técnicos Externos y Enlace de Acceso Temporal para Bodega', () {
    test('1. TecnicoModel soporta retrocompatibilidad y discriminación esExterno', () {
      // Modelo legado sin esExterno
      final jsonLegado = {
        'id': 'TEC-001',
        'nombre': 'Juan Perez',
        'telefono': '0999999999',
        'especialidad': 'Electromecánico',
        'activo': true,
      };
      final tecLegado = TecnicoModel.fromJson(jsonLegado, docId: 'TEC-001');
      expect(tecLegado.esExterno, isFalse);
      expect(tecLegado.usuarioUid, isNull);

      // Modelo explícito externo
      final jsonExterno = {
        'id': 'TEC-EXT-002',
        'nombre': 'Carlos Contratista',
        'telefono': '0988888888',
        'especialidad': 'Montajes Externos',
        'activo': true,
        'esExterno': true,
        'usuarioUid': null,
      };
      final tecExterno = TecnicoModel.fromJson(jsonExterno, docId: 'TEC-EXT-002');
      expect(tecExterno.esExterno, isTrue);
      expect(tecExterno.toJson()['esExterno'], isTrue);

      // Modelo interno enrolado con uid
      final jsonEnrolado = {
        'id': 'TEC-INT-003',
        'nombre': 'Luis Planta',
        'telefono': '0977777777',
        'especialidad': 'Mecánico de Planta',
        'activo': true,
        'esExterno': false,
        'usuarioUid': 'firebase_uid_123',
      };
      final tecEnrolado = TecnicoModel.fromJson(jsonEnrolado, docId: 'TEC-INT-003');
      expect(tecEnrolado.esExterno, isFalse);
      expect(tecEnrolado.usuarioUid, equals('firebase_uid_123'));
    });

    test('2. TokenRecepcionExternaModel: ciclo de vida, expiración y serialización', () {
      final ahora = DateTime.now();
      final expiracion = ahora.add(const Duration(hours: 12));

      final token = TokenRecepcionExternaModel(
        token: 'TOKEN-ABC-123',
        ticketId: 'REQ-00046',
        ordenId: 'REC-12345',
        tecnicoNombre: 'Carlos Contratista',
        tecnicoId: 'TEC-EXT-002',
        fechaCreacion: ahora,
        fechaExpiracion: expiracion,
        usado: false,
        creadoPor: 'Supervisor Taller',
      );

      expect(token.estaExpirado, isFalse);
      expect(token.usado, isFalse);

      final json = token.toJson();
      expect(json['token'], equals('TOKEN-ABC-123'));
      expect(json['ticketId'], equals('REQ-00046'));
      expect(json['ordenId'], equals('REC-12345'));
      expect(json['usado'], isFalse);

      final tokenExpirado = token.copyWith(
        fechaExpiracion: ahora.subtract(const Duration(minutes: 1)),
      );
      expect(tokenExpirado.estaExpirado, isTrue);

      final tokenUsado = token.copyWith(usado: true);
      expect(tokenUsado.usado, isTrue);
    });

    test('3. AccesoTemporalBodegaService: formato de URL de acceso directo', () {
      final url = AccesoTemporalBodegaService.construirUrlAcceso(
        'TEST-TOKEN-999',
        baseOrigin: 'https://postventa.aquaspot.com',
      );
      expect(url, equals('https://postventa.aquaspot.com/#/recepcion-externa?token=TEST-TOKEN-999'));
    });

    test('4. ItemRecepcionRepuestoEntity: validación de tope máximo alistado por bodega', () {
      // Caso 1: Conforme exacto (1 de 1)
      const itemConforme = ItemRecepcionRepuestoEntity(
        codigo: 'HID00161',
        descripcion: 'MOTOR HIDRAULICO CHARLYNN',
        unidad: 'UNIDAD',
        cantidadDespachadaBodega: 1,
        cantidadRecibidaTecnico: 1,
        validado: true,
      );
      expect(itemConforme.esConforme, isTrue);
      expect(itemConforme.excedeMaximo, isFalse);
      expect(itemConforme.esValida, isTrue);

      // Caso 2: Parcial / Discrepancia (0 de 1)
      const itemParcial = ItemRecepcionRepuestoEntity(
        codigo: 'HID00161',
        descripcion: 'MOTOR HIDRAULICO CHARLYNN',
        unidad: 'UNIDAD',
        cantidadDespachadaBodega: 1,
        cantidadRecibidaTecnico: 0,
        validado: false,
      );
      expect(itemParcial.esConforme, isFalse);
      expect(itemParcial.excedeMaximo, isFalse);
      expect(itemParcial.esValida, isTrue);

      // Caso 3: Excede tope máximo (12 de 1 - Caso reportado por usuario)
      const itemExcedido = ItemRecepcionRepuestoEntity(
        codigo: 'HID00161',
        descripcion: 'MOTOR HIDRAULICO CHARLYNN',
        unidad: 'UNIDAD',
        cantidadDespachadaBodega: 1,
        cantidadRecibidaTecnico: 12,
        validado: true,
      );
      expect(itemExcedido.esConforme, isFalse, reason: '12 no puede ser conforme si bodega solo alistó 1');
      expect(itemExcedido.excedeMaximo, isTrue);
      expect(itemExcedido.esValida, isFalse);

      // Caso 4: Negativo
      const itemNegativo = ItemRecepcionRepuestoEntity(
        codigo: 'HID00161',
        descripcion: 'MOTOR HIDRAULICO CHARLYNN',
        unidad: 'UNIDAD',
        cantidadDespachadaBodega: 1,
        cantidadRecibidaTecnico: -1,
        validado: false,
      );
      expect(itemNegativo.esValida, isFalse);
    });
  });

  group('Flujo de Despacho Bodega: Generación de Excels, Múltiples Evidencias y Bloqueo', () {
    test('1. RegistroDespachoModel y Entity: soporte de fotosEvidenciasUrls y retrocompatibilidad', () {
      // JSON legado sin fotos
      final jsonLegado = {
        'id': 'DESP-1001',
        'fecha': '2026-09-22T10:00:00.000',
        'usuarioNombre': 'Bodeguero Central',
        'usuarioId': 'USR-1',
        'items': [
          {
            'codigo': 'HID00355',
            'descripcion': 'Eje Cónico',
            'unidad': 'UNIDAD',
            'cantidad': 1.0,
          },
        ],
      };

      final modelLegado = RegistroDespachoModel.fromJson(jsonLegado);
      expect(modelLegado.fotosEvidenciasUrls, isEmpty);
      expect(modelLegado.tieneEvidencia, isFalse);

      // Despacho con múltiples fotos de soporte (repuestos + documento ERP)
      final despachoConFotos = modelLegado.copyWith(
        fotosEvidenciasUrls: [
          'https://storage.googleapis.com/evidencia_repuestos_1.jpg',
          'https://storage.googleapis.com/evidencia_documento_erp_2.jpg',
        ],
      );

      expect(despachoConFotos.fotosEvidenciasUrls.length, equals(2));
      expect(despachoConFotos.tieneEvidencia, isTrue);

      final modelConFotos = RegistroDespachoModel.fromEntity(despachoConFotos);
      final jsonNuevo = modelConFotos.toJson();
      expect(jsonNuevo['fotosEvidenciasUrls'], isA<List>());
      expect((jsonNuevo['fotosEvidenciasUrls'] as List).length, equals(2));

      final deserializado = RegistroDespachoModel.fromJson(jsonNuevo);
      expect(deserializado.fotosEvidenciasUrls.length, equals(2));
      expect(deserializado.tieneEvidencia, isTrue);
    });

    test('2. Enclavamiento de Seguridad: tieneDespachoPendienteDeEvidencia bloquea bodega', () {
      final ticketBase = TicketModel.fromJson({
        'id': 'REQ-00049',
        'estadoActual': 'compras',
        'sede': 'DURAN',
        'clienteId': 'CLI-AQ',
        'campamento': 'Camaronera Norte',
        'nombreContacto': 'Carlos Bodega',
        'emailContacto': 'carlos@aquaspot.com',
        'telefonoContacto': '0987654321',
        'equipo': 'Caracol',
        'fallaReportada': 'Cambio sellos',
      });

      // Ticket sin despachos aún: no tiene evidencia pendiente
      expect(ticketBase.tieneDespachoPendienteDeEvidencia, isFalse);
      expect(ticketBase.despachoPendienteDeEvidencia, isNull);

      // Se realiza un despacho sin fotos aún (pendiente de subir soporte)
      final despachoSinFotos = RegistroDespachoEntity(
        id: 'DESP-1002',
        fecha: DateTime.now(),
        usuarioNombre: 'Bodeguero Central',
        usuarioId: 'USR-BOD',
        items: const [
          DetalleItemDespachadoEntity(
            codigo: 'PRT00048',
            descripcion: 'Empaque O-Ring',
            unidad: 'UNIDAD',
            cantidad: 2,
          ),
        ],
        fotosEvidenciasUrls: const [],
      );

      final ticketBloqueado = ticketBase.copyWith(
        historialDespachos: [despachoSinFotos],
      );

      // Bloqueo activado: detecta despacho pendiente de evidencia
      expect(ticketBloqueado.tieneDespachoPendienteDeEvidencia, isTrue);
      expect(ticketBloqueado.despachoPendienteDeEvidencia?.id, equals('DESP-1002'));

      // Se regulariza el despacho subiendo las evidencias fotográficas
      final despachoRegularizado = despachoSinFotos.copyWith(
        fotosEvidenciasUrls: ['https://storage.googleapis.com/evidencia_despacho_1002.jpg'],
      );

      final ticketDesbloqueado = ticketBase.copyWith(
        historialDespachos: [despachoRegularizado],
      );

      // Bloqueo desactivado: ya cuenta con fotos de soporte
      expect(ticketDesbloqueado.tieneDespachoPendienteDeEvidencia, isFalse);
      expect(ticketDesbloqueado.despachoPendienteDeEvidencia, isNull);
    });

    test('3. GeneradorExcelDespachoBodega: generarExcelBajaERP genera archivo tabular válido', () {
      final ticket = TicketModel.fromJson({
        'id': 'REQ-00049',
        'estadoActual': 'compras',
        'sede': 'DURAN',
        'clienteId': 'CLI-AQ',
        'campamento': 'Camaronera Norte',
        'nombreContacto': 'Carlos Bodega',
        'emailContacto': 'carlos@aquaspot.com',
        'telefonoContacto': '0987654321',
        'equipo': 'Caracol',
        'fallaReportada': 'Mantenimiento',
      });

      final bytes = GeneradorExcelDespachoBodega.generarExcelBajaERP(
        ticket: ticket,
        itemsDespachados: const [
          DetalleItemDespachadoEntity(
            codigo: 'HID00355',
            descripcion: 'Eje Conico Charlynn',
            unidad: 'UNIDAD',
            cantidad: 2,
          ),
        ],
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));
    });

    test('4. GeneradorExcelDespachoBodega: generarExcelSolicitudMateriales genera formato formal con firmas', () {
      final ticket = TicketModel.fromJson({
        'id': 'REQ-00049',
        'estadoActual': 'compras',
        'codigoProyecto': 'PROJ-AQ-01',
        'numeroSerie': 'AQ-SN-999',
        'sede': 'DURAN',
        'clienteId': 'CLI-AQ',
        'campamento': 'Camaronera Norte',
        'nombreContacto': 'Carlos Bodega',
        'emailContacto': 'carlos@aquaspot.com',
        'telefonoContacto': '0987654321',
        'equipo': 'Caracol',
        'fallaReportada': 'Mantenimiento',
      });

      final bytes = GeneradorExcelDespachoBodega.generarExcelSolicitudMateriales(
        ticket: ticket,
        items: const [
          ItemDespachoBodegaEntity(
            codigo: 'HID00355',
            descripcion: 'Eje Conico Charlynn',
            unidad: 'UNIDAD',
            cantidadSolicitada: 3,
            cantidadDespachada: 0,
            stockDisponibleAlEvaluar: 3,
            validadoPorCompras: true,
          ),
          ItemDespachoBodegaEntity(
            codigo: 'INS000170',
            descripcion: 'Aceite Hidráulico AW68',
            unidad: 'CANECA',
            cantidadSolicitada: 2,
            cantidadDespachada: 0,
            stockDisponibleAlEvaluar: 0,
            validadoPorCompras: false,
          ),
        ],
        cantidadesDespachadasLote: {'HID00355': 2.0},
        nombreBodeguero: 'Juan Bodeguero',
        nombreTecnico: 'Pedro Mecánico',
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));
    });

    test('5. Código Consecutivo de Despacho por Ticket', () {
      final ticketBase = TicketModel.fromJson({
        'id': 'REQ-00051',
        'estadoActual': 'bodega',
        'sede': 'DURAN',
        'clienteId': 'CLI-01',
        'campamento': 'Lebama',
        'nombreContacto': 'Ing. Juan',
        'emailContacto': 'juan@empresa.com',
        'telefonoContacto': '0987654321',
        'equipo': 'Caracol',
        'fallaReportada': 'Revisión',
      });

      // Sin despachos previos -> correlativo 1
      final int correlativo1 = ticketBase.historialDespachos.length + 1;
      final codigo1 = '${ticketBase.id}-DESP-${correlativo1.toString().padLeft(2, '0')}';
      expect(codigo1, equals('REQ-00051-DESP-01'));

      // Con 1 despacho previo -> correlativo 2
      final ticketConUnDespacho = ticketBase.copyWith(
        historialDespachos: [
          RegistroDespachoEntity(
            id: codigo1,
            fecha: DateTime.now(),
            usuarioNombre: 'Bodega',
            usuarioId: 'USR-01',
            items: const [],
            fotosEvidenciasUrls: const ['https://storage.url/foto1.jpg'],
          ),
        ],
      );

      final int correlativo2 = ticketConUnDespacho.historialDespachos.length + 1;
      final codigo2 = '${ticketConUnDespacho.id}-DESP-${correlativo2.toString().padLeft(2, '0')}';
      expect(codigo2, equals('REQ-00051-DESP-02'));
    });

    test('6. Ítems con stock local en bodega se habilitan inmediatamente para despacho', () {
      // Repuesto que cuenta con stock en bodega
      const itemConStock = ItemDespachoBodegaEntity(
        codigo: 'HID00355',
        descripcion: 'EJE CONICO',
        unidad: 'UNIDAD',
        cantidadSolicitada: 1,
        stockDisponibleAlEvaluar: 2, // Stock: 2 en bodega
        validadoPorCompras: false,
      );

      // Repuesto sin stock en bodega
      const itemSinStock = ItemDespachoBodegaEntity(
        codigo: 'INS000019',
        descripcion: 'BROCHA 1"',
        unidad: 'UNIDAD',
        cantidadSolicitada: 1,
        stockDisponibleAlEvaluar: 0, // Falta: 1.0
        validadoPorCompras: false,
      );

      expect(itemConStock.estaHabilitadoParaDespacho, isTrue);
      expect(itemSinStock.estaHabilitadoParaDespacho, isFalse);

      // Si Compras valida la brocha que llegó físicamente:
      final itemBrochaValidada = itemSinStock.copyWith(validadoPorCompras: true);
      expect(itemBrochaValidada.estaHabilitadoParaDespacho, isTrue);
    });

    test('7. Enclavamiento de despacho completo sin evidencia: permanece en Bodega y bloqueado hasta regularizar', () {
      final ticketDespachadoTotalmente = TicketModel.fromJson({
        'id': 'REQ-00051',
        'estadoActual': 'bodega',
        'sede': 'DURAN',
        'clienteId': 'CLI-01',
        'campamento': 'Camp 1',
        'nombreContacto': 'Juan Perez',
        'emailContacto': 'juan@mail.com',
        'telefonoContacto': '0999999999',
        'equipo': 'Caracol',
        'fallaReportada': 'Ruido',
        'codigoProyecto': 'PRY-2026-001',
      }).copyWith(
        itemsDespachoBodega: const [
          ItemDespachoBodegaEntity(
            codigo: 'INS000019',
            descripcion: 'BROCHA 1"',
            unidad: 'UNIDAD',
            cantidadSolicitada: 1,
            stockDisponibleAlEvaluar: 1,
            cantidadDespachada: 1, // Despachado 1 de 1
            validadoPorCompras: true,
          ),
        ],
        historialDespachos: [
          RegistroDespachoEntity(
            id: 'REQ-00051-DESP-01',
            fecha: DateTime.now(),
            usuarioNombre: 'Bodega',
            usuarioId: 'USR-01',
            items: const [
              DetalleItemDespachadoEntity(
                codigo: 'INS000019',
                descripcion: 'BROCHA 1"',
                unidad: 'UNIDAD',
                cantidad: 1,
              ),
            ],
            fotosEvidenciasUrls: const [], // Sin fotos -> Requiere evidencia
          ),
        ],
      );

      expect(ticketDespachadoTotalmente.bodegaDespachoCompleto, isTrue);
      expect(ticketDespachadoTotalmente.tieneDespachoPendienteDeEvidencia, isTrue);

      // Simulación del filtro de Bandeja Despacho Bodega:
      final saleDeBodega = ticketDespachadoTotalmente.bodegaDespachoCompleto &&
          !ticketDespachadoTotalmente.tieneDespachoPendienteDeEvidencia;
      expect(saleDeBodega, isFalse, reason: 'No debe salir de Bodega si debe evidencias');

      // Regularización: se suben las fotos
      final ticketRegularizado = ticketDespachadoTotalmente.copyWith(
        historialDespachos: [
          ticketDespachadoTotalmente.historialDespachos.first.copyWith(
            fotosEvidenciasUrls: const ['https://firebasestorage.googleapis.com/.../foto.jpg'],
          ),
        ],
      );

      expect(ticketRegularizado.tieneDespachoPendienteDeEvidencia, isFalse);
      final saleDeBodegaRegularizado = ticketRegularizado.bodegaDespachoCompleto &&
          !ticketRegularizado.tieneDespachoPendienteDeEvidencia;
      expect(saleDeBodegaRegularizado, isTrue, reason: 'Al regularizar sale de Bodega hacia Taller');
    });
  });
}
