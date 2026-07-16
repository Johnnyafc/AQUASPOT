// lib/features/tickets/data/datasources/ticket_remote_datasource.dart

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../../../clientes/data/models/cliente_model.dart';
import '../models/ticket_model.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../../../../core/enum/segmento_operativo.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data'; // <-- Ruta de tu nuevo Enum       // <-- Ruta de tu Enum de máquinas
import '../datasources/ticket_remote_datasource.dart';

class TicketRemoteDataSourceImpl implements TicketRemoteDataSource {
  final FirebaseFirestore firestore;

  TicketRemoteDataSourceImpl({required this.firestore});


 Future<List<ClienteModel>> obtenerClientes() async {
    try {
      // ⚙️ VÁLVULA ABIERTA: Extrae toda la colección sin filtros
      final snapshot = await firestore.collection('clientes').get();

      return snapshot.docs.map((doc) {
        // ⚙️ INYECCIÓN LIMPIA: Pasamos la data pura y el ID como argumentos separados
        return ClienteModel.fromJson(doc.data(), doc.id);
      }).toList();
      
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Fallo de conexión con Firestore');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }


  @override
  Future<String> subirActaPdfStorage(String ticketId, Uint8List pdfBytes) async {
    try {
      // 1. Apuntamos al directorio de actas
      final storageRef = FirebaseStorage.instance.ref().child('actas_recepcion/acta_$ticketId.pdf');
      
      // 2. Metadatos vitales para que el navegador sepa que es un PDF
      final metadata = SettableMetadata(contentType: 'application/pdf');

      // 3. Bombeo de datos
      final uploadTask = await storageRef.putData(pdfBytes, metadata);

      // 4. Extracción de la telemetría (URL)
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print("🚨 ERROR CRUDO DE FIREBASE (STORAGE PDF): $e");
      throw ServerException(e.toString());
    }
  }


@override
  Future<String> subirArchivoDocumental(PlatformFile archivo, String ticketId, String subcarpeta) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final nombreUnico = '${timestamp}_${archivo.name}';
      final ref = FirebaseStorage.instance.ref().child('tickets/$ticketId/$subcarpeta/$nombreUnico');
      
      UploadTask uploadTask;

      // ⚙️ COMPUERTA LÓGICA DE ENTORNO
      if (kIsWeb) {
        // En WEB no hay rutas, inyectamos los bytes binarios directamente
        uploadTask = ref.putData(archivo.bytes!);
      } else {
        // En MOBILE leemos la ruta física del disco
        uploadTask = ref.putFile(File(archivo.path!));
      }
      
      return await (await uploadTask).ref.getDownloadURL();
    } catch (e) {
      throw ServerException('Error de telemetría: $e'); 
    }
  }





@override
  Future<TicketModel> crearTicket(TicketModel ticket) async {
    try {
      final counterRef = firestore.collection('metadata').doc('contadores');

      final ticketGenerado = await firestore.runTransaction<TicketModel>((transaction) async {
        
        final snapshot = await transaction.get(counterRef);
        int currentCount = 0;
        
        if (snapshot.exists && snapshot.data() != null && snapshot.data()!.containsKey('ticket_count')) {
          currentCount = snapshot.data()!['ticket_count'] as int;
        }

        final nextCount = currentCount + 1;

        // ⚙️ TROQUELADO LÓGICO
        final nuevoId = 'REQ-${nextCount.toString().padLeft(5, '0')}';
        
        // 🔌 LA LÍNEA CRÍTICA: Apuntamos al nuevo ID, NO a ticket.id
        final docRef = firestore.collection('tickets').doc(nuevoId); 

        // Inyección directa para esquivar el error de copyWith
        final Map<String, dynamic> ticketJson = ticket.toJson();
        ticketJson['id'] = nuevoId; 

        // Escritura síncrona
        transaction.set(counterRef, {'ticket_count': nextCount}, SetOptions(merge: true));
        transaction.set(docRef, ticketJson);

        return TicketModel.fromJson(ticketJson);
      });

      return ticketGenerado;
      
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<TicketModel> actualizarTicket(TicketModel ticket) async {
    try {
      await firestore.collection('tickets').doc(ticket.id).update(ticket.toJson());
      return ticket;
    } catch (e) {
      print("🚨 ERROR CRUDO DE FIREBASE (ACTUALIZACIÓN): $e");
      throw ServerException(e.toString());
    }
  }

  // ✅ NUEVO: Implementación de la lectura de historial
@override
  Future<String> subirDocumentoComercial(String ticketId, PlatformFile archivo, String tipoDocumento) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Añadimos el tipoDocumento (ej. proforma_pdf) como prefijo para identificar rápido la telemetría
      final nombreUnico = '${tipoDocumento}_${timestamp}_${archivo.name}';
      
      // 🔧 Ruteo estricto a la celda comercial
      final ref = FirebaseStorage.instance.ref().child('tickets/$ticketId/comercial/$nombreUnico');
      
      UploadTask uploadTask;

      // ⚙️ COMPUERTA LÓGICA DE ENTORNO (Matriz Estandarizada)
      if (kIsWeb) {
        // En WEB no hay rutas del sistema operativo, inyectamos los bytes crudos
        uploadTask = ref.putData(archivo.bytes!);
      } else {
        // En MOBILE leemos la ruta física del almacenamiento local
        uploadTask = ref.putFile(File(archivo.path!));
      }
      
      return await (await uploadTask).ref.getDownloadURL();
    } catch (e) {
      throw ServerException('Fallo en la válvula de inyección comercial: $e'); 
    }
  }




@override
  Future<List<TicketModel>> obtenerTickets(SegmentoOperativo segmentoUsuario) async {
    try {
      // 1. Instanciamos la tubería principal (Query base)
      Query query = firestore.collection('tickets');
      

      // 2. Aplicamos la válvula de segmentación (Filtro por Tenant)
      
      if (segmentoUsuario != null && segmentoUsuario != SegmentoOperativo.general && segmentoUsuario != SegmentoOperativo.ninguno ) {
        print('Entramos al if si tenemos algo en segmento');
        print(segmentoUsuario);
        List<String> maquinasPermitidas = [];

        switch (segmentoUsuario) {
          case SegmentoOperativo.caracol:
            maquinasPermitidas = [TipoEquipo.Caracol.name];
            break;
          case SegmentoOperativo.cosechadora:
            // Ruteo múltiple: El supervisor de cosechadoras ve toda la familia
            maquinasPermitidas = [
              TipoEquipo.Cosechadora.name,
            ];
            break;
          case SegmentoOperativo.contador:
            maquinasPermitidas = [TipoEquipo.Contador.name];
            break;
          default:
            maquinasPermitidas = [];
        }


        if (maquinasPermitidas.isNotEmpty) {
          query = query.where('equipo', whereIn: maquinasPermitidas);

        } else {
          // Bloqueo de seguridad: Si su segmento es inválido, retornamos lista vacía
          return []; 
        }
      }

// 3. Extracción ordenada
// 3. Extracción ordenada por ID de Requerimiento
// FieldPath.documentId es la clave interna que Firestore usa para identificar el documento
final snapshot = await query
    .orderBy(FieldPath.documentId, descending: true) 
    .get();

// --- [DEBUG] PUNTO DE INSPECCIÓN ---
print("🔍 [DEBUG] Consulta ejecutada. Total de documentos recibidos: ${snapshot.docs.length}");

// Si este número es 0, el problema es el filtro de la query (el .where)
if (snapshot.docs.isEmpty) {
  print("⚠️ [DEBUG] La consulta no trajo nada. Revisa tus filtros o el nombre de la colección.");
}
      // 4. Mapeo seguro
return snapshot.docs.map((doc) {
  final data = doc.data() as Map<String, dynamic>;
  data['id'] = doc.id; 

  // --- [DEBUG] INSPECCIÓN DE CONTRATO ---
  print("🔍 [SERIALIZACIÓN] Documento ID: ${doc.id}");
  print("📦 [DATA RAW]: $data");
  
  try {
    return TicketModel.fromJson(data);
  } catch (e, stackTrace) {
    // Si falla aquí, tu TicketModel no está preparado para los datos que vienen de la DB
    print("🚨 [ERROR CRÍTICO] Falla al convertir a TicketModel:");
    print("Datos que causaron el error: $data");
    print("Detalle: $e");
    print("Stacktrace: $stackTrace");
    rethrow; // Esto detiene la ejecución para que veas el error en la consola
  }
}).toList();
      
    } catch (e) {
      print("🚨 ERROR CRUDO DE FIREBASE (LECTURA HISTORIAL): $e");
      throw ServerException(e.toString());
    }
  }
}