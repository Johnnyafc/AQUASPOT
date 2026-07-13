import 'package:equatable/equatable.dart';

abstract class ClienteState extends Equatable {
  const ClienteState();
  
  @override
  List<Object> get props => [];
}

class ClienteInitial extends ClienteState {}

class ClienteLoading extends ClienteState {}

class ClienteSuccess extends ClienteState {}

class ClienteError extends ClienteState {
  final String message;

  const ClienteError(this.message);

  @override
  List<Object> get props => [message];
}