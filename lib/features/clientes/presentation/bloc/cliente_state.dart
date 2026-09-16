import 'package:equatable/equatable.dart';
import '../../domain/entities/cliente_entity.dart';

abstract class ClienteState extends Equatable {
  const ClienteState();
  
  @override
  List<Object> get props => [];
}

class ClienteInitial extends ClienteState {}

class ClienteLoading extends ClienteState {}

class ClienteSuccess extends ClienteState {}

class ClienteActualizadoSuccess extends ClienteState {}

class ClientesLoaded extends ClienteState {
  final List<ClienteEntity> clientes;

  const ClientesLoaded(this.clientes);

  @override
  List<Object> get props => [clientes];
}

class ClienteError extends ClienteState {
  final String message;

  const ClienteError(this.message);

  @override
  List<Object> get props => [message];
}