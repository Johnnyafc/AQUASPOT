import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/core/services/borrador_storage_service.dart';
import 'package:aquaspot_postventa/features/tecnicos/data/models/tecnico_model.dart';
import 'package:aquaspot_postventa/features/fallas/data/models/metrica_falla_model.dart';
import 'package:aquaspot_postventa/features/fallas/data/datasources/metrica_falla_remote_datasource.dart';
import 'package:aquaspot_postventa/features/tickets/data/models/ticket_model.dart';

void main() {
  group('Pruebas Unitarias: Módulos de Técnicos y Métricas de Fallas', () {
    test('1. TecnicoModel serializa y deserializa correctamente', () {
      final json = {
        'id': 'tec-01',
        'nombre': 'Carlos Mendoza',
        'rol': 'Técnico Electrónico',
        'activo': true,
        'fechaRegistro': '2026-09-14T10:00:00.000Z',
      };

      final model = TecnicoModel.fromJson(json);
      expect(model.id, 'tec-01');
      expect(model.nombre, 'Carlos Mendoza');
      expect(model.rol, 'Técnico Electrónico');
      expect(model.activo, true);

      final map = model.toJson();
      expect(map['nombre'], 'Carlos Mendoza');
      expect(map['rol'], 'Técnico Electrónico');
    });

    test('2. MatrizFallasEquipoModel contiene las razones del Contador solicitadas', () {
      final matrizContador = MetricaFallaRemoteDataSource.obtenerMatrizPorDefecto('Contador');
      expect(matrizContador.tipoEquipo, 'Contador');
      expect(matrizContador.categorias.length, 3);

      final mecanico = matrizContador.categorias.firstWhere((c) => c.nombre == 'Mecánico');
      expect(mecanico.razones, contains('Defectos de soldadura'));
      expect(mecanico.razones, contains('Defectos de ensamblaje'));

      final electronico = matrizContador.categorias.firstWhere((c) => c.nombre == 'Electrónico');
      expect(electronico.razones, contains('Desgaste de puerto de los cables'));
      expect(electronico.razones, contains('Mala manipulación de los cables'));
      expect(electronico.razones, contains('Daños en la placa electrónica de la pantalla y sus componentes'));
      expect(electronico.razones, contains('Rotura de la soldadura'));
      expect(electronico.razones, contains('Daño en la placa del cabezal'));

      final software = matrizContador.categorias.firstWhere((c) => c.nombre == 'Software');
      expect(software.razones, contains('Mala calibración de la curva de la cámara'));
      expect(software.razones, contains('Error de licencia'));
      expect(software.razones, contains('Falta de iluminación en sistema'));
      expect(software.razones, contains('Cámara desalineada'));

      final model = MatrizFallasEquipoModel(
        tipoEquipo: matrizContador.tipoEquipo,
        categorias: matrizContador.categorias,
      );
      final json = model.toJson();
      final reconst = MatrizFallasEquipoModel.fromJson(json);
      expect(reconst.categorias.length, 3);

      final matrizCaracol = MetricaFallaRemoteDataSource.obtenerMatrizPorDefecto('Caracol');
      expect(matrizCaracol.categorias, isEmpty);

      final matrizCosechadora = MetricaFallaRemoteDataSource.obtenerMatrizPorDefecto('Cosechadora');
      expect(matrizCosechadora.categorias, isEmpty);
    });

    test('3. TicketModel deserializa tecnicosAsignados, diagnosticoFallas e informeTecnico con retrocompatibilidad', () {
      // 1. Ticket legado sin los nuevos campos (no debe fallar, debe dar listas vacías / null)
      final jsonLegado = <String, dynamic>{
        'id': 'TCK-LEGADO-002',
        'estadoActual': 'procesoTrabajo',
        'sede': 'GUABO',
        'clienteId': 'CLI-TEST',
        'campamento': 'CAMP-01',
        'nombreContacto': 'Maria',
        'telefonoContacto': '0987654321',
        'emailContacto': 'maria@test.com',
        'equipo': 'Contador',
        'fallaReportada': 'No enciende',
        'historialEventos': [],
        'tipoRequerimiento': 'reparacion',
        'lugarAtencion': 'taller',
      };

      final ticketLegado = TicketModel.fromJson(jsonLegado);
      expect(ticketLegado.tecnicosAsignados, isEmpty);
      expect(ticketLegado.diagnosticoFallas, isEmpty);
      expect(ticketLegado.urlInformeTecnico, isNull);

      // 2. Ticket moderno con los campos completos
      final jsonModerno = <String, dynamic>{
        ...jsonLegado,
        'id': 'TCK-MODERNO-003',
        'tecnicosAsignados': ['Juan Perez', 'Carlos Mendoza'],
        'diagnosticoFallas': [
          {
            'categoria': 'Electrónico',
            'razon': 'Rotura de la soldadura',
            'observacion': 'Re-soldado con estaño 60/40',
          },
          {
            'categoria': 'Software',
            'razon': 'Error de licencia',
            'observacion': 'Activada licencia anual',
          },
        ],
        'urlInformeTecnico': 'https://firebasestorage.googleapis.com/informe.pdf',
      };

      final ticketModerno = TicketModel.fromJson(jsonModerno);
      expect(ticketModerno.tecnicosAsignados.length, 2);
      expect(ticketModerno.tecnicosAsignados, contains('Juan Perez'));
      expect(ticketModerno.diagnosticoFallas.length, 2);
      expect(ticketModerno.diagnosticoFallas.first.categoria, 'Electrónico');
      expect(ticketModerno.diagnosticoFallas.first.razon, 'Rotura de la soldadura');
      expect(ticketModerno.urlInformeTecnico, 'https://firebasestorage.googleapis.com/informe.pdf');

      final serialized = ticketModerno.toJson();
      expect(serialized['tecnicosAsignados'], contains('Juan Perez'));
      expect(serialized['urlInformeTecnico'], 'https://firebasestorage.googleapis.com/informe.pdf');
    });

    test('4. Jerarquía de 3 Niveles: SubcategoriaFallaModel, CategoriaFallaModel y DiagnosticoFallaModel', () {
      // 1. Creación y serialización de 3 niveles
      const subcategoriaComap = SubcategoriaFallaModel(
        nombre: 'Comap',
        fallas: [
          'Falla en tarjeta electrónica',
          'Fallo en borneras',
        ],
      );
      const subcategoriaRele = SubcategoriaFallaModel(
        nombre: 'Relé',
        fallas: [
          'Relé pegado',
          'Bobina quemada',
        ],
      );

      final categoriaElectrico = CategoriaFallaModel(
        nombre: 'Eléctrico',
        subcategorias: [subcategoriaComap, subcategoriaRele],
      );

      final jsonCat = categoriaElectrico.toJson();
      expect(jsonCat['nombre'], 'Eléctrico');
      expect((jsonCat['subcategorias'] as List).length, 2);

      final catReconst = CategoriaFallaModel.fromJson(jsonCat);
      expect(catReconst.subcategorias.length, 2);
      expect(catReconst.subcategorias[0].nombre, 'Comap');
      expect(catReconst.subcategorias[0].fallas, contains('Falla en tarjeta electrónica'));
      expect(catReconst.subcategorias[0].fallas, contains('Fallo en borneras'));
      expect(catReconst.subcategorias[1].nombre, 'Relé');
      expect(catReconst.subcategorias[1].fallas, contains('Bobina quemada'));
      expect(catReconst.razones.length, 4);

      // 2. Diagnóstico de Falla con 3 niveles
      const diag = DiagnosticoFallaModel(
        categoria: 'Eléctrico',
        subcategoria: 'Comap',
        falla: 'Falla en tarjeta electrónica',
      );
      expect(diag.categoria, 'Eléctrico');
      expect(diag.subcategoria, 'Comap');
      expect(diag.falla, 'Falla en tarjeta electrónica');
      expect(diag.razon, 'Falla en tarjeta electrónica'); // Retrocompatibilidad

      final diagJson = diag.toJson();
      expect(diagJson['subcategoria'], 'Comap');
      expect(diagJson['falla'], 'Falla en tarjeta electrónica');

      // 3. Retrocompatibilidad: documento antiguo con formato plano 'razones'
      final jsonCatAntiguo = <String, dynamic>{
        'nombre': 'Hidráulico',
        'razones': ['Fuga de aceite', 'Manguera rota'],
      };
      final catMigrada = CategoriaFallaModel.fromJson(jsonCatAntiguo);
      expect(catMigrada.subcategorias.length, 1);
      expect(catMigrada.subcategorias.first.nombre, 'General');
      expect(catMigrada.subcategorias.first.fallas, contains('Fuga de aceite'));

      // 4. Retrocompatibilidad: diagnóstico antiguo con solo 'categoria' y 'razon'
      final jsonDiagAntiguo = <String, dynamic>{
        'categoria': 'Mecánico',
        'razon': 'Fisura en soporte',
      };
      final diagMigrado = DiagnosticoFallaModel.fromJson(jsonDiagAntiguo);
      expect(diagMigrado.categoria, 'Mecánico');
      expect(diagMigrado.subcategoria, '');
      expect(diagMigrado.falla, 'Fisura en soporte');
      expect(diagMigrado.razon, 'Fisura en soporte');
    });

    test('5. BorradorStorageService serializa y restaura PlatformFile con Base64', () {
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final fileOriginal = PlatformFile(
        name: 'evidencia_prueba.jpg',
        size: dummyBytes.length,
        bytes: dummyBytes,
      );

      final json = BorradorStorageService.platformFileToJson(fileOriginal);
      expect(json['name'], 'evidencia_prueba.jpg');
      expect(json['base64'], isNotNull);

      final fileRestaurado = BorradorStorageService.jsonToPlatformFile(json);
      expect(fileRestaurado, isNotNull);
      expect(fileRestaurado!.name, 'evidencia_prueba.jpg');
      expect(fileRestaurado.bytes, isNotNull);
      expect(fileRestaurado.bytes!.toList(), [1, 2, 3, 4, 5, 6, 7, 8]);
    });

    test('6. BorradorStorageService guarda y recupera borrador de proceso de trabajo', () async {
      SharedPreferences.setMockInitialValues({});
      final dummyBytes = Uint8List.fromList([10, 20, 30, 40]);
      final foto = PlatformFile(name: 'foto1.png', size: 4, bytes: dummyBytes);

      const ticketId = 'TCK-TEST-PERSIST-001';
      final clave = BorradorStorageService.claveDraftTrabajo(ticketId);

      final exito = await BorradorStorageService.guardarBorrador(
        clave: clave,
        datos: {
          'nombreTecnico': 'Pedro Picapiedra',
          'notasTecnicas': 'Se revisó y ajustó el cableado eléctrico.',
          'fotos': BorradorStorageService.platformFilesToJson([foto]),
          'tecnicosAsignados': ['Pedro Picapiedra'],
          'diagnosticoFallas': [
            {'categoria': 'Eléctrico', 'subcategoria': 'COMAP', 'falla': 'Fallo en borneras'}
          ],
        },
      );
      expect(exito, isTrue);

      final recuperado = await BorradorStorageService.obtenerBorrador(clave);
      expect(recuperado, isNotNull);
      expect(recuperado!['nombreTecnico'], 'Pedro Picapiedra');
      expect(recuperado['notasTecnicas'], 'Se revisó y ajustó el cableado eléctrico.');

      final fotosRestauradas = BorradorStorageService.jsonToPlatformFiles(recuperado['fotos'] as List);
      expect(fotosRestauradas.length, 1);
      expect(fotosRestauradas.first.name, 'foto1.png');
      expect(fotosRestauradas.first.bytes, isNotNull);
      expect(fotosRestauradas.first.bytes!.toList(), [10, 20, 30, 40]);

      // Eliminación al finalizar
      final eliminado = await BorradorStorageService.eliminarBorrador(clave);
      expect(eliminado, isTrue);
      final luegoDeBorrar = await BorradorStorageService.obtenerBorrador(clave);
      expect(luegoDeBorrar, isNull);
    });
  });
}
