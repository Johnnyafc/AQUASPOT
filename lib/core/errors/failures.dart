// lib/core/errors/failures.dart

import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  
  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

// Fallo de base de datos o servidor (Firebase/FastAPI caídos o con error de permisos)
class ServerFailure extends Failure {
  const ServerFailure(String message) : super(message);
}

// Fallo de conexión física (El teléfono no tiene señal en la camaronera)
class NetworkFailure extends Failure {
  const NetworkFailure(String message) : super(message);
}