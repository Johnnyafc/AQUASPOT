// lib/features/tickets/presentation/bloc/dashboard_event.dart
//
// Eventos del Dashboard de Tickets. Solo hay uno: pedir que se procesen
// los tickets ya cargados en memoria (sin ninguna lectura nueva a
// Firestore) para armar los datos del panel.

import 'package:equatable/equatable.dart';
import '../../domain/entities/ticket_entity.dart';

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

// 🚀 Dispara el procesamiento pesado (recorrer historialEventos, calcular
// tiempos por ticket y por departamento, armar listas de filtros) DENTRO
// de un isolate separado (ver DashboardBloc), para que la interfaz nunca
// se congele sin importar cuántos tickets haya.
class CargarDashboardEvent extends DashboardEvent {
  final List<TicketEntity> tickets;

  const CargarDashboardEvent(this.tickets);

  @override
  List<Object?> get props => [tickets];
}
