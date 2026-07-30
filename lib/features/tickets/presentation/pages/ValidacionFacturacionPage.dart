import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart'; 
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/DetalleValidacionFacturacionPage.dart';
// import 'package:aquaspot_postventa/features/tickets/presentation/pages/detalle_validacion_facturacion_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BandejaValidacionFacturacionPage extends StatefulWidget {
  const BandejaValidacionFacturacionPage({super.key});

  @override
  State<BandejaValidacionFacturacionPage> createState() => _BandejaValidacionFacturacionPageState();
}

class _BandejaValidacionFacturacionPageState extends State<BandejaValidacionFacturacionPage> {
  @override
  void initState() {
    super.initState();
    // 🚀 DISPARO CRÍTICO: Solicitamos los tickets al entrar a la bandeja.
    context.read<TicketBloc>().add(
      ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.ninguno)
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9), // Fondo industrial limpio
      appBar: AppBar(
        title: const Text('Bandeja Comercial: Facturación', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF003057), // Tono corporativo
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: BlocBuilder<TicketBloc, TicketState>(
          builder: (context, state) {
            // 1. Diagnóstico de estado
            if (state.status == TicketStatus.loading) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF005A9C)));
            }

            // 2. Selección de lista
            final listaAProcesar = state.tickets.isNotEmpty ? state.tickets : (state.historial ?? []);
            
            if (listaAProcesar.isEmpty) {
              return _buildEmptyState('Lista vacía: Ni tickets ni historial llegaron del servidor.');
            }

            // 3. Filtro industrial estricto
            final ticketsPendientes = listaAProcesar.where((t) {
              return t.estadoActual == EstadoTicket.validacionFacturacion; 
            }).toList();

            if (ticketsPendientes.isEmpty) {
              return _buildEmptyState('Datos cargados, pero el filtro no encontró tickets pendientes de facturación.');
            }

            // 🖥️ CHÁSIS ESTRUCTURAL REFORZADO (Adiós Unbounded Constraints)
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  children: [
                    // El Expanded obliga al ListView a respetar los límites del dispositivo, evitando el desbordamiento.
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: ticketsPendientes.length,
                        itemBuilder: (context, index) {
                          final ticket = ticketsPendientes[index];
                          return _buildTicketCard(context, ticket);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ⚙️ SUBRUTINA: Tarjeta del Ticket (Diseño unificado)
  Widget _buildTicketCard(BuildContext context, dynamic ticket) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // ⚡ ACTUADOR: Navegar al detalle para facturar
           Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DetalleValidacionFacturacionPage(ticket: ticket),
            ),
          ); 
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "TICKET: ${ticket.id}", 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF003057))
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.shade700),
                    ),
                    child: Text(
                      "PENDIENTE FACTURACIÓN", 
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900)
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildDataRow(Icons.business, "Cliente:", ticket.clienteId),
              _buildDataRow(Icons.precision_manufacturing, "Equipo:", ticket.equipo.toString()),
            ],
          ),
        ),
      ),
    );
  }

  // ⚙️ SUBRUTINA: Fila de datos para la tarjeta
  Widget _buildDataRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value, 
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            )
          ),
        ],
      ),
    );
  }

  // ⚙️ SUBRUTINA: Estado vacío dinámico
  Widget _buildEmptyState(String mensaje) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
            const SizedBox(height: 16),
            const Text(
              "Bandeja Limpia",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}