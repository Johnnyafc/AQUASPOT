// lib/features/tickets/data/models/cliente_model.dart

import '../../domain/entities/cliente_entity.dart';
// data/models/cliente_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ClienteModel extends ClienteEntity {
  const ClienteModel({
    required super.id,
    required super.camaronera,
    required super.celular,
    required super.direccion,
    required super.emailContacto,
    required super.estadoActual,
    super.fechaRegistro,
    required super.nombreContacto,
    required super.subSector,
  });

  factory ClienteModel.fromJson(Map<String, dynamic> json, String documentId) {
    return ClienteModel(
      id: documentId,
      camaronera: json['camaronera'] ?? '',
      // Filtramos la basura del '.0' que dejó el script de Python al leer Excel
      celular: (json['celular'] ?? '').toString().replaceAll('.0', ''), 
      direccion: json['direccion'] ?? '',
      emailContacto: json['emailContacto'] ?? '',
      estadoActual: json['estadoActual'] ?? 'inactivo',
      // Conversión industrial de Timestamp a DateTime
      fechaRegistro: (json['fechaRegistro'] as Timestamp?)?.toDate(), 
      nombreContacto: json['nombreContacto'] ?? '',
      subSector: json['subSector'] ?? '',
    );
  }
}