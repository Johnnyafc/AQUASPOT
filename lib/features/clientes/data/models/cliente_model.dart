import '../../domain/entities/cliente_entity.dart';
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
    super.notasRecepcion,
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
      notasRecepcion: json['notasRecepcion'],
    );
  }

  factory ClienteModel.fromEntity(ClienteEntity entity) {
    return ClienteModel(
      id: entity.id,
      camaronera: entity.camaronera,
      celular: entity.celular,
      direccion: entity.direccion,
      emailContacto: entity.emailContacto,
      estadoActual: entity.estadoActual,
      fechaRegistro: entity.fechaRegistro,
      nombreContacto: entity.nombreContacto,
      subSector: entity.subSector,
      notasRecepcion: entity.notasRecepcion,
    );
  }

  // ⚙️ EL CONVERSOR DE SALIDA (Para inyectar en Firestore al crear)
  Map<String, dynamic> toJson() {
    return {
      'camaronera': camaronera,
      'celular': celular,
      'direccion': direccion,
      'emailContacto': emailContacto,
      'estadoActual': 'activo', // Forzamos el alta como activo por defecto
      'fechaRegistro': FieldValue.serverTimestamp(), // Telemetría de tiempo exacta del servidor
      'nombreContacto': nombreContacto,
      'subSector': subSector,
    };
  }

  // 🔄 CONVERSOR PARA ACTUALIZACIONES (Preserva fecha original de registro)
  Map<String, dynamic> toUpdateJson() {
    return {
      'camaronera': camaronera,
      'celular': celular,
      'direccion': direccion,
      'emailContacto': emailContacto,
      'estadoActual': estadoActual,
      'nombreContacto': nombreContacto,
      'subSector': subSector,
      'fechaActualizacion': FieldValue.serverTimestamp(),
    };
  }
}