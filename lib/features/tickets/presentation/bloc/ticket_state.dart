// lib/features/tickets/presentation/bloc/ticket_state.dart

import 'package:equatable/equatable.dart';
import 'dart:typed_data'; // ✅ Requerido para Uint8List
import '../../domain/entities/cliente_entity.dart';
import '../../domain/entities/ticket_entity.dart';

// ... (Todo tu código anterior queda exactamente igual hasta TicketEvidenciaSubida) ...

class TicketEvidenciaSubida extends TicketState {
  final String url;
  const TicketEvidenciaSubida({required this.url});

  @override
  List<Object> get props => [url];
}

// ⚙️ NUEVO ESTADO: Señal de control para el periférico de impresión
class TicketRecepcionExitosa extends TicketState {
  final Uint8List pdfBytes;
  
  const TicketRecepcionExitosa({required this.pdfBytes});

  @override
  List<Object> get props => [pdfBytes];
}