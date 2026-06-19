// lib/features/tickets/presentation/pages/bandeja_recepcion_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../domain/entities/ticket_enums.dart';
import 'formulario_recepcion_page.dart'; // TODO: Crear esta vista en el siguiente paso

class BandejaRecepcionPage extends StatefulWidget {
  const BandejaRecepcionPage({super.key});

  @override
  State<BandejaRecepcionPage> createState() => _BandejaRecepcionPageState();
}

class _BandejaRecepcionPageState extends State<BandejaRecepcionPage> {
  @override
  void initState() {
    super.initState();
    // 1. Energizamos el panel: Solicitamos la telemetría al arrancar
    context.read<TicketBloc>().add(ObtenerHistorialTicketsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recepción Física de Equipos", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      backgroundColor: const Color(0xFFF4F7F6),
      body: BlocBuilder<TicketBloc, TicketState>(
        builder: (context, state) {
          if (state is TicketLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (state is TicketHistorialCargado) {
            // 2. FILTRO MAESTRO: Solo dejamos pasar los equipos recién registrados ('creado')
            final pendientes = state.tickets.where((t) => t.estadoActual == EstadoTicket.evaluacionTecnica).toList();

            if (pendientes.isEmpty) {
              return const Center(
                child: Text(
                  "No hay equipos en tránsito o pendientes de ingreso.", 
                  style: TextStyle(color: Colors.grey, fontSize: 16)
                )
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<TicketBloc>().add(ObtenerHistorialTicketsEvent());
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: pendientes.length,
                itemBuilder: (context, index) {
                  final ticket = pendientes[index];
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      // Usamos un color Teal (verde azulado) para diferenciar el área de logística/bodega
                      leading: const CircleAvatar(
                        backgroundColor: Colors.teal, 
                        child: Icon(Icons.inventory_outlined, color: Colors.white)
                      ),
                      title: Text(ticket.id, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Equipo: ${ticket.equipo.name.toUpperCase()}\nCliente: ${ticket.clienteId}',
                          style: const TextStyle(height: 1.4),
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      onTap: () {
                        // 3. Conmutador a la pantalla de captura de fotos y confirmación
                         Navigator.push(context, MaterialPageRoute(builder: (_) => FormularioRecepcionPage(ticket: ticket)));

                      },
                    ),
                  );
                },
              ),
            );
          }
          
          if (state is TicketError) {
             return Center(child: Text("Error de lectura: ${state.message}", style: const TextStyle(color: Colors.red)));
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}