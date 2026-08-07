import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/subir_evidencia_trabajo_page.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BandejaTrabajosPage extends StatefulWidget {
  const BandejaTrabajosPage({super.key});

  @override
  State<BandejaTrabajosPage> createState() => _BandejaTrabajosPageState();
}

class _BandejaTrabajosPageState extends State<BandejaTrabajosPage> {
  @override
  void initState() {
    super.initState();
    // 🚀 DISPARO CRÍTICO: Solicitamos los tickets al montar la estación.
    context.read<TicketBloc>().add(
      const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.ninguno)
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Línea de Trabajo - Operaciones', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey.shade800, // Color distintivo del Taller
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: BlocBuilder<TicketBloc, TicketState>(
          builder: (context, state) {
            // 1. Diagnóstico del bus de datos
            if (state.status == TicketStatus.loading) {
              return Center(child: CircularProgressIndicator(color: Colors.blueGrey.shade800));
            } else if (state.status == TicketStatus.error) {
              return Center(
                child: Text(
                  'Falla de telemetría: ${state.message}',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              );
            }

            // 2. Selección segura de la lista
            final listaAProcesar = state.tickets.isNotEmpty ? state.tickets : (state.historial ?? []);

            // 3. Filtro del multiplexor (Solo Proceso de Trabajo)
            final ticketsTrabajo = listaAProcesar
                .where((t) => t.estadoActual == EstadoTicket.procesoTrabajo)
                .toList();

            // 4. Sensor de presencia (Cola vacía)
            if (ticketsTrabajo.isEmpty) {
              return _buildEmptyState();
            }

            // 🖥️ 5. CHÁSIS ESTRUCTURAL REFORZADO (Contención Web/Móvil)
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        color: Colors.blueGrey,
                        onRefresh: () async {
                          // Recarga manual forzada por el operario
                          context.read<TicketBloc>().add(
                            const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.ninguno)
                          );
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: ticketsTrabajo.length,
                          itemBuilder: (context, index) {
                            final ticket = ticketsTrabajo[index];
                            return _buildTicketCard(context, ticket);
                          },
                        ),
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

  // ⚙️ SUBRUTINA: Tarjeta del Ticket con Testigo y Doble Actuador
  Widget _buildTicketCard(BuildContext context, dynamic ticket) {
    // 🧠 LECTURA DE SENSOR: Testigo de trabajo activo
    final bool estaEnProceso = ticket.trabajoIniciado ?? false;

    return Card(
      elevation: estaEnProceso ? 4 : 2,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: estaEnProceso ? Colors.orange.shade400 : Colors.blueGrey.shade200,
          width: estaEnProceso ? 2 : 1
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- ENCABEZADO: ICONO, ID Y TESTIGO ---
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: estaEnProceso ? Colors.orange.shade100 : Colors.blueGrey.shade100,
                  radius: 20,
                  child: Icon(
                    Icons.build_circle, 
                    color: estaEnProceso ? Colors.orange.shade800 : Colors.blueGrey, 
                    size: 24
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ticket: ${ticket.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF003057)),
                  ),
                ),
                // 🚥 TESTIGO VISUAL DE ESTADO
                if (estaEnProceso)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade600,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.settings, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('EN PROCESO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // --- CUERPO: DATOS TÉCNICOS ---
            Text('Proyecto: ${ticket.codigoProyecto ?? "Sin Asignar"}', style: TextStyle(color: Colors.grey.shade800)),
            Text('Equipo: ${ticket.equipo.toString().toUpperCase()}', style: TextStyle(color: Colors.grey.shade800)),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Falla: ${ticket.fallaReportada}', 
                    maxLines: 2, 
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // --- PIE DE PÁGINA: BANCO DE ACCIONAMIENTO ---
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 1. ACTUADOR DE INICIO (Se oculta o cambia si ya está activo)
                if (!estaEnProceso) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Iniciar Trabajo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey.shade700,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      final authState = context.read<AuthBloc>().state;
                      String operador = 'DESCONOCIDO';
                      String rol = 'SIN_ROL';

                      if (authState is Authenticated) {
                        operador = authState.usuario.nombre;
                        rol = authState.usuario.rol.name.toUpperCase();
                      }

                      // 🚀 DISPARO DEL EVENTO DE INICIO FÍSICO
                      context.read<TicketBloc>().add(
                        IniciarTrabajoFisicoEvent(
                          ticket: ticket,
                          nombreUsuario: operador,
                          rolUsuario: rol,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                ],

                // 2. ACTUADOR DE EVIDENCIA (Independiente)
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Subir evidencia'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey.shade700,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    // 🚀 ENRUTAMIENTO HACIA LA ESTACIÓN DE RECOLECCIÓN
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubirEvidenciaTrabajoPage(ticket: ticket),
                      ),
                    );
                  },
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // ⚙️ SUBRUTINA: Estado Vacío de Taller
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.precision_manufacturing_outlined, size: 80, color: Colors.blueGrey.shade300),
          const SizedBox(height: 16),
          Text(
            'Línea Despejada',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            'No hay equipos en proceso de trabajo en este momento.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.blueGrey.shade500),
          ),
        ],
      ),
    );
  }
}