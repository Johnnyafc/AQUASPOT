// lib/features/tickets/data/datasources/ticket_remote_datasource.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cliente_model.dart';
import '../models/ticket_model.dart';
import '../../../../core/errors/exceptions.dart';

abstract class TicketRemoteDataSource {
  Future<List<ClienteModel>> obtenerClientes();
  Future<TicketModel> crearTicket(TicketModel ticket);
  Future<TicketModel> actualizarTicket(TicketModel ticket);
}

class TicketRemoteDataSourceImpl implements TicketRemoteDataSource {
  final FirebaseFirestore firestore;

  TicketRemoteDataSourceImpl({required this.firestore});

  @override
  Future<List<ClienteModel>> obtenerClientes() async {
    try {
      final snapshot = await firestore.collection('clientes').get();
      return snapshot.docs.map((doc) {
        // Inyectamos el ID del documento dentro del JSON para mapearlo
        final data = doc.data();
        data['id'] = doc.id;
        return ClienteModel.fromJson(data);
      }).toList();
    } catch (e) {
      throw ServerException();
    }
  }

  @override
  Future<TicketModel> crearTicket(TicketModel ticket) async {
    try {
      final jsonTicket = ticket.toJson();

      // INYECCIÓN DE SEGURIDAD: Usar el reloj atómico de Google, no el del celular.
      final eventos = List<dynamic>.from(jsonTicket['historialEventos']);
      if (eventos.isNotEmpty) {
        eventos.last['timestamp'] = FieldValue.serverTimestamp();
        jsonTicket['historialEventos'] = eventos;
      }

      // Creamos el documento
      final docRef = await firestore.collection('tickets').add(jsonTicket);
      
      // Actualizamos el documento para que guarde su propio ID alfanumérico
      await docRef.update({'id': docRef.id});

      return ticket;
    } catch (e) {
      throw ServerException();
    }
  }

  @override
  Future<TicketModel> actualizarTicket(TicketModel ticket) async {
    try {
      final jsonTicket = ticket.toJson();

      // INYECCIÓN DE SEGURIDAD
      final eventos = List<dynamic>.from(jsonTicket['historialEventos']);
      if (eventos.isNotEmpty) {
        eventos.last['timestamp'] = FieldValue.serverTimestamp();
        jsonTicket['historialEventos'] = eventos;
      }

      // Actualizamos usando update() para no machacar campos enteros
      await firestore.collection('tickets').doc(ticket.id).update(jsonTicket);
      
      return ticket;
    } catch (e) {
      throw ServerException();
    }
  }
}