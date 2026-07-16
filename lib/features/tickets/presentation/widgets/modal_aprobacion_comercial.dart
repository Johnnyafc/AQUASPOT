import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../../domain/entities/ticket_entity.dart';
// Asumo que tienes tu AuthBloc y TicketBloc importados aquí
// import '../bloc/ticket_bloc.dart';
// import '../../../auth/presentation/bloc/auth_bloc.dart';

class ModalAprobacionComercial extends StatefulWidget {
  final TicketEntity ticket;

  const ModalAprobacionComercial({Key? key, required this.ticket}) : super(key: key);

  // ⚙️ Actuador estático para invocar el modal fácilmente desde cualquier pantalla
  static Future<void> show(BuildContext context, TicketEntity ticket) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Para que el teclado no aplaste la UI
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<TicketBloc>(),
        child: ModalAprobacionComercial(ticket: ticket),
      ),
    );
  }

  @override
  State<ModalAprobacionComercial> createState() => _ModalAprobacionComercialState();
}

class _ModalAprobacionComercialState extends State<ModalAprobacionComercial> {
  // 📥 Bandejas de carga de archivos (Sensores)
  final List<dynamic> _ordenesVenta = [];
  final List<dynamic> _ordenesCompra = [];

  // 🔒 Enclavamiento mecánico: Solo se libera si hay al menos 1 orden de venta
  bool get _isBotonHabilitado => _ordenesVenta.isNotEmpty;

  void _dispararAprobacion() {
    if (!_isBotonHabilitado) return; // Doble seguro

    // Extracción de telemetría del operador
    final authState = context.read<AuthBloc>().state;
    String nombreOp = 'SISTEMA';
    String rolOp = 'COMERCIAL';

    if (authState is Authenticated) {
      nombreOp = authState.usuario.nombre;
      rolOp = authState.usuario.rol.name.toUpperCase();
    }

    // 🚀 Activación del PLC
    context.read<TicketBloc>().add(
      AprobarProformaComercialEvent(
        ticket: widget.ticket,
        ordenesVentaArchivos: _ordenesVenta,
        ordenesCompraArchivos: _ordenesCompra,
        nombreUsuario: nombreOp,
        rolUsuario: rolOp,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Amortiguador para el teclado en pantalla
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 24,
      ),
      child: BlocConsumer<TicketBloc, TicketState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          // 🛑 PARADA DE EMERGENCIA (Fallo en la nube)
          if (state.status == TicketStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          } 
          // ✅ OPERACIÓN EXITOSA (El relé cerró correctamente)
          else if (state.status == TicketStatus.operationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Transición comercial exitosa'), backgroundColor: Colors.green),
            );
            if (context.mounted) Navigator.pop(context); // Evacuamos el modal
          }
        },
        builder: (context, state) {
          final isProcessing = state.status == TicketStatus.loading;

          return AbsorbPointer(
            absorbing: isProcessing, // Bloqueamos la pantalla entera si está procesando
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🏷️ CABECERA DE LA ESTACIÓN
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Aprobar Ticket ${widget.ticket.id}', 
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF005A9C))
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const Divider(thickness: 2),
                const SizedBox(height: 16),

                // ⚠️ ADVERTENCIA OPERATIVA
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('Al confirmar, el ticket se derivará simultáneamente a Costos y Compras. Asegúrese de adjuntar la documentación correcta.', 
                          style: TextStyle(fontSize: 13, color: Colors.black87)
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ⚙️ MÓDULO DE CARGA 1: ORDEN DE VENTA (Obligatorio)
                const Text('Orden de Venta (Obligatorio) *', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                // 🔌 AQUÍ: Inserta tu widget de selección de archivos (FilePicker o CameraManager)
                // Reemplaza esto con tu componente real que llena la lista _ordenesVenta
                Container(
                  height: 80,
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child: const Center(child: Text('[ COMPONENTE SELECTOR DE ARCHIVOS ]')),
                ),
                const SizedBox(height: 24),

                // ⚙️ MÓDULO DE CARGA 2: ORDEN DE COMPRA (Opcional)
                const Text('Orden de Compra Cliente (Opcional)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                // 🔌 AQUÍ: Inserta tu widget de selección de archivos 
                // Reemplaza esto con tu componente real que llena la lista _ordenesCompra
                Container(
                  height: 80,
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child: const Center(child: Text('[ COMPONENTE SELECTOR DE ARCHIVOS ]')),
                ),
                const SizedBox(height: 32),

                // ⚡ ACTUADOR PRINCIPAL
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isBotonHabilitado ? Colors.green.shade700 : Colors.grey,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: isProcessing ? null : _dispararAprobacion,
                    icon: isProcessing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: Text(
                      isProcessing ? 'PROCESANDO TRÁMITE...' : 'CONFIRMAR Y DERIVAR', 
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}