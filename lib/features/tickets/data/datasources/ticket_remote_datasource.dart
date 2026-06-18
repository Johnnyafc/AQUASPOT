// lib/features/tickets/data/datasources/ticket_remote_datasource.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cliente_model.dart';
import '../models/ticket_model.dart';
import '../../../../core/errors/exceptions.dart';

abstract class TicketRemoteDataSource {
  Future<List<ClienteModel>> obtenerClientes();
  Future<TicketModel> crearTicket(TicketModel ticket);
  Future<TicketModel> actualizarTicket(TicketModel ticket);
  
  // ✅ NUEVO: Sonda de extracción para el historial
  Future<List<TicketModel>> obtenerTickets(); 
}

class TicketRemoteDataSourceImpl implements TicketRemoteDataSource {
  final FirebaseFirestore firestore;

  TicketRemoteDataSourceImpl({required this.firestore});

  @override
  Future<List<ClienteModel>> obtenerClientes() async {
    try {
      final snapshot = await firestore.collection('clientes').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ClienteModel.fromJson(data);
      }).toList();
    } catch (e) {
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
  Future<List<TicketModel>> obtenerTickets() async {
    try {
      // Extraemos la colección completa. A nivel industrial luego puedes meter un .orderBy()
      final snapshot = await firestore.collection('tickets').get(); 
      
      return snapshot.docs.map((doc) {
        return TicketModel.fromJson(doc.data());
      }).toList();
    } catch (e) {
      print("🚨 ERROR CRUDO DE FIREBASE (LECTURA HISTORIAL): $e");
      throw ServerException(e.toString());
    }
  }
}