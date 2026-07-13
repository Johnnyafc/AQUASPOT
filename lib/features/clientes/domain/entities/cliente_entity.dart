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
      ];
}