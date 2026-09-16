import 'package:equatable/equatable.dart';

class ClienteEntity extends Equatable {
  final String id;
  final String camaronera;     // En la UI será "Campamento / Finca"
  final String celular;        // En la UI será "Teléfono"
  final String direccion;      // En la UI será "Razón Social / Cliente"
  final String emailContacto;
  final String estadoActual;
  final DateTime? fechaRegistro; 
  final String nombreContacto;
  final String subSector;      // En la UI será la "Sede"
  final String? notasRecepcion;

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
    this.notasRecepcion,
  });

  ClienteEntity copyWith({
    String? id,
    String? camaronera,
    String? celular,
    String? direccion,
    String? emailContacto,
    String? estadoActual,
    DateTime? fechaRegistro,
    String? nombreContacto,
    String? subSector,
    String? notasRecepcion,
  }) {
    return ClienteEntity(
      id: id ?? this.id,
      camaronera: camaronera ?? this.camaronera,
      celular: celular ?? this.celular,
      direccion: direccion ?? this.direccion,
      emailContacto: emailContacto ?? this.emailContacto,
      estadoActual: estadoActual ?? this.estadoActual,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      nombreContacto: nombreContacto ?? this.nombreContacto,
      subSector: subSector ?? this.subSector,
      notasRecepcion: notasRecepcion ?? this.notasRecepcion,
    );
  }

  @override
  List<Object?> get props => [
        id,
        camaronera,
        celular,
        direccion,
        emailContacto,
        estadoActual,
        fechaRegistro,
        nombreContacto,
        subSector,
        notasRecepcion,
      ];
}