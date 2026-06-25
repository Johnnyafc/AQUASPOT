// domain/entities/cliente_entity.dart
class ClienteEntity {
  final String id;
  final String camaronera;
  final String celular;
  final String direccion;
  final String emailContacto;
  final String estadoActual;
  final DateTime? fechaRegistro; // ⚠️ Ojo, en Firestore es Timestamp, en Dart es DateTime
  final String nombreContacto;
  final String subSector;

  const ClienteEntity({
    required this.id,
    required this.camaronera,
    required this.celular,
    required this.direccion,
    required this.emailContacto,
    required this.estadoActual,
    this.fechaRegistro,
    required this.nombreContacto,
    required this.subSector,
  });
}