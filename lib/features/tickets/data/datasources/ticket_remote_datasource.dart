// lib/features/tickets/data/datasources/ticket_remote_datasource.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cliente_model.dart';
import '../models/ticket_model.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../features/tickets/domain/entities/ticket_enums.dart';
import '../../../../core/enum/segmento_operativo.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data'; // <-- Ruta de tu nuevo Enum       // <-- Ruta de tu Enum de máquinas

abstract class TicketRemoteDataSource {
  Future<List<ClienteModel>> obtenerClientes();
  Future<TicketModel> crearTicket(TicketModel ticket);
  Future<TicketModel> actualizarTicket(TicketModel ticket);
  Future<String> subirActaPdfStorage(String ticketId, Uint8List pdfBytes);
  
  // ✅ NUEVO: Sonda de extracción para el historial
  Future<List<TicketModel>> obtenerTickets({SegmentoOperativo? segmentoUsuario});
}

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
  Future<TicketModel> crearTicket(TicketModel ticket) async {
    try {
      final docRef = firestore.collection('tickets').doc(ticket.id);
      await docRef.set(ticket.toJson());
      return ticket;
    } catch (e) {
      print("🚨 ERROR CRUDO DE FIREBASE (ESCRITURA): $e");
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
  Future<List<TicketModel>> obtenerTickets({SegmentoOperativo? segmentoUsuario}) async {
    try {
      // 1. Instanciamos la tubería principal (Query base)
      Query query = firestore.collection('tickets');
      

      // 2. Aplicamos la válvula de segmentación (Filtro por Tenant)
      
      if (segmentoUsuario != null && segmentoUsuario != SegmentoOperativo.general) {
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
              TipoEquipo.Cosechadora_premium.name,
              TipoEquipo.Cosechadora_standart.name,
              TipoEquipo.Cosechadora_elevacion.name,
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