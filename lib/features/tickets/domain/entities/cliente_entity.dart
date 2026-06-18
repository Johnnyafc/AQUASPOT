// lib/features/tickets/domain/entities/cliente_entity.dart

import 'package:equatable/equatable.dart';
import 'ticket_enums.dart';

class ClienteEntity extends Equatable {
  final String id; // ID que viene del ERP
  final String nombreCliente;
  final Sede sede;
  final List<String> campamentos;
  final String contactoPrincipal;
  final String telefono;

  const ClienteEntity({
    required this.id,
    required this.nombreCliente,
    required this.sede,
    required this.campamentos,
    required this.contactoPrincipal,
    required this.telefono,
  });

  @override
  List<Object?> get props => [
        id,
        nombreCliente,
        sede,
        campamentos,
        contactoPrincipal,
        telefono,
      ];
}