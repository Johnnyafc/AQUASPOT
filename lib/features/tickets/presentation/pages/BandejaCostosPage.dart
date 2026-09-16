import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/AsignacionCostosPage.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart'; // ⚙️ Necesario para el extension getter fechaInicioEstadoActual
import 'package:aquaspot_postventa/features/tickets/presentation/widgets/tiempo_en_curso_widget.dart';
import 'package:aquaspot_postventa/core/theme/ticket_visual_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BandejaCostosPage extends StatefulWidget {
  const BandejaCostosPage({super.key});

  @override
  State<BandejaCostosPage> createState() => _BandejaCostosPageState();
}

class _BandejaCostosPageState extends State<BandejaCostosPage> {
  @override
  void initState() {
    super.initState();
    // 🚀 DISPARO CRÍTICO: Solicitamos los tickets al entrar a la bandeja.
    // VERIFICA: Asegúrate de que el nombre de tu evento sea 'LoadTicketsEvent'. 
    // Si se llama diferente (ej: FetchTicketsEvent), cámbialo aquí.
   context.read<TicketBloc>().add(
  ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.ninguno)
);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bandeja de Costos')),
      body: BlocBuilder<TicketBloc, TicketState>(
        builder: (context, state) {
          // 1. Diagnóstico de estado y campos


          if (state.status == TicketStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. ¿A qué lista le vamos a hacer caso?
          // Si el BLoC usa 'historial', debemos usar 'historial'.
          final listaAProcesar = state.tickets.isNotEmpty ? state.tickets : state.historial;
          
          if (listaAProcesar == null || listaAProcesar.isEmpty) {
            return const Center(child: Text('Lista vacía: Ni tickets ni historial llegaron.'));
          }

          // 3. Filtro industrial
          final ticketsPendientes = listaAProcesar.where((t) {
            final esCostos = t.estadoActual == EstadoTicket.costos;
            return esCostos;
          }).toList();

          if (ticketsPendientes.isEmpty) {
            return const Center(child: Text('Datos cargados, pero el filtro no encontró nada.'));
          }

          return ListView.builder(
            itemCount: ticketsPendientes.length,
            itemBuilder: (context, index) {
              final ticket = ticketsPendientes[index];
              return ListTile(
                key: ValueKey(ticket.id),
                leading: const AvatarSuave(color: kTicketAcento, icono: Icons.assignment_ind),
                title: Text('Ticket: ${ticket.id}'),
                // 🆕 Tiempo en vivo en el estado actual (sin backend: se
                // recalcula contra la hora real del dispositivo).
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🆕 Cliente (empresa/camaronera) y Contacto (persona) son
                    // datos distintos — se muestran ambos.
                    Text(
                      '${ticket.clienteId.trim().isNotEmpty ? 'Cliente: ${ticket.clienteId} | ' : ''}'
                      'Contacto: ${ticket.nombreContacto} | Máquina: ${ticket.equipo.name.toUpperCase()} • Marca: ${ticket.marca.toUpperCase()}',
                    ),
                    const SizedBox(height: 4),
                    TiempoEnCursoWidget(
                      desde: ticket.fechaInicioEstadoActual,
                      builder: (context, texto) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.hourglass_bottom, size: 12, color: kTicketIcono),
                          const SizedBox(width: 4),
                          Text(texto, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTicketTextoSecundario)),
                        ],
                      ),
                    ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AsignacionCostosPage(ticket: ticket),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}