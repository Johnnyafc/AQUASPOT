import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DetalleValidacionFacturacionPage extends StatelessWidget {
  final dynamic ticket; // ⚠️ Reemplace dynamic por TicketEntity

  const DetalleValidacionFacturacionPage({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    return BlocListener<TicketBloc, TicketState>(
      listener: (context, state) {
        // 🔄 SENSOR DE RETORNO Y RECARGA (Idéntico a Asignación de Costos)
        if (state.status == TicketStatus.operationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
          Navigator.of(context).pop(); // Vuelve a la bandeja y actualiza el árbol visual
        } else if (state.status == TicketStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error de sistema: ${state.message}')),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white, 
        appBar: AppBar(
          title: Text('Ticket: ${ticket.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF003057),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        // 🖥️ CHÁSIS ESTRUCTURAL: Contención Web/Móvil
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Datos del Requerimiento", 
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.w600, 
                      color: Color(0xFF003057)
                    )
                  ),
                  const SizedBox(height: 16),
                  _buildFormularioRequerimiento(),
                  
                  const SizedBox(height: 32),
                  
                  // ⚡ ACTUADORES: Panel de control con validación de estado de carga
                  _buildPanelControl(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ⚙️ SUBRUTINA: Renderizado del contenedor gris con filtros de Enums
  Widget _buildFormularioRequerimiento() {
    String limpiarDato(dynamic valor) {
      if (valor == null) return 'N/A';
      return valor.toString().split('.').last.toUpperCase();
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Estado Actual:', limpiarDato(ticket.estadoActual)),
          const Divider(height: 24, thickness: 1, color: Color(0xFFE0E0E0)),
          
          _buildInfoRow('Equipo:', limpiarDato(ticket.equipo)),
          const SizedBox(height: 12),
          _buildInfoRow('Lugar de recepción:', limpiarDato(ticket.sede)),
          const Divider(height: 24, thickness: 1, color: Color(0xFFE0E0E0)),
          
          _buildInfoRow('Cliente:', ticket.clienteId.toUpperCase()),
          const SizedBox(height: 12),
          _buildInfoRow('Campamento:', ticket.campamento?.toUpperCase() ?? 'N/A'),
          const SizedBox(height: 12),
          _buildInfoRow('Contacto:', '${ticket.nombreContacto} (${ticket.telefonoContacto})'.toUpperCase()),
          const Divider(height: 24, thickness: 1, color: Color(0xFFE0E0E0)),
          
          _buildInfoRow('Número de Serie:', ticket.numeroSerie ?? 'No Registrado'),
          const Divider(height: 24, thickness: 1, color: Color(0xFFE0E0E0)),
          
          const Text(
            'Falla Reportada e Inspección:', 
            style: TextStyle(color: Color(0xFF757575), fontSize: 13, fontWeight: FontWeight.w500)
          ),
          const SizedBox(height: 8),
          Text(
            ticket.fallaReportada, 
            style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500, height: 1.4)
          ),
        ],
      ),
    );
  }

  // ⚙️ SUBRUTINA: Fila tabulada
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 200, 
          child: Text(
            label, 
            style: const TextStyle(color: Color(0xFF757575), fontSize: 13, fontWeight: FontWeight.w500)
          ),
        ),
        Expanded(
          child: Text(
            value, 
            style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500)
          ),
        ),
      ],
    );
  }

  // ⚙️ SUBRUTINA: Botonera de acciones acoplada al AuthBloc y TicketBloc
  Widget _buildPanelControl(BuildContext context) {
    return BlocBuilder<TicketBloc, TicketState>(
      builder: (context, state) {
        final bool isLoading = state.status == TicketStatus.loading;

        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: isLoading ? null : () {
                // Validación estricta del bus de autenticación
                final authState = context.read<AuthBloc>().state;

                if (authState is! Authenticated) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error: Usuario no autenticado en el sistema.')),
                  );
                  return;
                }

                // Disparo de la orden de validación con credenciales reales
                context.read<TicketBloc>().add(
                  ProcesarFacturacionEvent(
                    ticketId: ticket.id, 
                    aprobado: true,
                    nombreUsuario: authState.usuario.nombre,
                    rolUsuario: authState.usuario.rol.name.toUpperCase(),
                  )
                );
              },
              icon: isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline, size: 20),
              label: Text(isLoading ? 'Procesando...' : 'Validar', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003057),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
            ),
          ],
        );
      },
    );
  }
}