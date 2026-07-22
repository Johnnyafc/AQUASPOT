import 'dart:io';

import 'package:aquaspot_postventa/core/errors/failures.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../../clientes/data/models/cliente_model.dart';
import '../models/ticket_model.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../../../../core/enum/segmento_operativo.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data'; 

abstract class TicketRemoteDataSource {
  Future<List<ClienteModel>> obtenerClientes();
  Future<TicketModel> crearTicket(TicketModel ticket);
  Future<TicketModel> actualizarTicket(TicketModel ticket);
  Future<String> subirActaPdfStorage(String ticketId, Uint8List pdfBytes);
  
  // ✅ NUEVO: Sonda de extracción para el historial
  Future<List<TicketModel>> obtenerTickets(SegmentoOperativo segmento);
  Future<String> subirArchivoDocumental(PlatformFile archivo, String ticketId, String subcarpeta);
  Future<String> subirDocumentoComercial(String ticketId, PlatformFile archivo, String tipoDocumento);
  Future<String> subirOrdenVenta(XFile file, String ticketId);
Future<String> subirOrdenCompra(XFile file, String ticketId);
Future<void> anularTicket(String ticketId, Map<String, dynamic> data);
Stream<String?> escucharEstadoExcel(String ticketId);
}
