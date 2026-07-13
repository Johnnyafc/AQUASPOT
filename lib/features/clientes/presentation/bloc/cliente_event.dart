import 'package:equatable/equatable.dart';

abstract class ClienteEvent extends Equatable {
  const ClienteEvent();

  @override
  List<Object> get props => [];
}

class RegistrarClienteSubmitEvent extends ClienteEvent {
  final String camaronera;
  final String celular;
  final String direccion; // Razón Social
  final String emailContacto;
  final String nombreContacto;
  final String subSector;

  const RegistrarClienteSubmitEvent({
    required this.camaronera,
    required this.celular,
    required this.direccion,
    required this.emailContacto,
    required this.nombreContacto,
    required this.subSector,
  });

  @override
  List<Object> get props => [
        camaronera,
        celular,
        direccion,
        emailContacto,
        nombreContacto,
        subSector,
      ];
}