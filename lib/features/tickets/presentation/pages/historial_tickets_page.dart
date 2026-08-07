// lib/features/tickets/presentation/pages/historial_tickets_page.dart

import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart'; 
import '../../../../core/enum/ticket_enums.dart';
import '../../domain/entities/ticket_entity.dart';
import 'detalle_ticket_page.dart';

class HistorialTicketsPage extends StatefulWidget {
  const HistorialTicketsPage({super.key});

  @override
  State<HistorialTicketsPage> createState() => _HistorialTicketsPageState();
}

class _HistorialTicketsPageState extends State<HistorialTicketsPage> {
  @override
  void initState() {
    super.initState();
    // ⚙️ LLAVE MAESTRA: Solicitamos telemetría GLOBAL
    context.read<TicketBloc>().add(
      const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.ninguno)
    );
  }

  // =========================================================================
  // ⚙️ DECODIFICADORES HMI (Transformación de datos crudos a interfaz visual)
  // =========================================================================

  Color _getColorPorEstado(EstadoTicket estado) {
    switch (estado) {
      case EstadoTicket.creado: return Colors.orange; 
      case EstadoTicket.recepcionFisica: return Colors.green;  
      default: return Colors.grey;   
    }
  }

  String _formatearNombreEstado(String camelCase) {
    RegExp exp = RegExp(r'(?<=[a-z])[A-Z]');
    String conEspacios = camelCase.replaceAllMapped(exp, (m) => ' ${m.group(0)}');
    return conEspacios.toUpperCase();
  }

  IconData _getIconoPorEstado(EstadoTicket estado) {
    switch (estado) {
      case EstadoTicket.creado: return Icons.fiber_new;
      case EstadoTicket.revisionGarantia: return Icons.fiber_new;
      case EstadoTicket.recepcionFisica: return Icons.handyman;
      case EstadoTicket.enCamino: return Icons.handyman;
      case EstadoTicket.comercial: return Icons.point_of_sale;
      case EstadoTicket.cotizado: return Icons.request_quote;
      case EstadoTicket.costos: return Icons.account_balance_wallet;
      case EstadoTicket.compras: return Icons.shopping_cart;
      case EstadoTicket.bodega: return Icons.inventory;
      case EstadoTicket.procesoTrabajo: return Icons.engineering;
      case EstadoTicket.validacionFacturacion: return Icons.loupe;
      case EstadoTicket.finalizado: return Icons.task_alt;
      case EstadoTicket.anulado: return Icons.cancel;
      case EstadoTicket.entrega: return Icons.add_box;
    }
  }

  // =========================================================================
  // 🚀 CONSTRUCTOR DE LA VISTA PRINCIPAL
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    // ⚙️ LONGITUD DINÁMICA: Acoplado directamente al tamaño del Enum
    return DefaultTabController(
      length: EstadoTicket.values.length, 
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel de Historial', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF005A9C),
          foregroundColor: Colors.white,
          
          bottom: TabBar(
            isScrollable: true, // ⚠️ CRÍTICO: Evita el colapso (overflow) de la UI
            tabAlignment: TabAlignment.start, 
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.orange,
            indicatorWeight: 4,
            
            // 🔄 ITERADOR: Generación automática de pestañas
            tabs: EstadoTicket.values.map((estado) {
              return Tab(
                icon: Icon(_getIconoPorEstado(estado)), 
                text: _formatearNombreEstado(estado.name)
              );
            }).toList(),
          ),
        ),
        body: BlocBuilder<TicketBloc, TicketState>(
          buildWhen: (previous, current) => previous.status != current.status,
          builder: (context, state) {
            
            // 1. ESTADO DE TRABAJO (Lectura de sensores en curso)
            if (state.status == TicketStatus.loading) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF005A9C)));
            } 
            
            // 2. ESTADO DE ALARMA (Falla de red o lógica)
            if (state.status == TicketStatus.error) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 50, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(state.message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    TextButton(
                      onPressed: () => context.read<TicketBloc>().add(const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.general)),
                      child: const Text('REINTENTAR CONEXIÓN'),
                    )
                  ],
                ),
              );
            } 
            
            // 3. ESTADO DE LECTURA EXITOSA (Multiplexado de buffers de datos)
            if (state.status == TicketStatus.loaded || state.status == TicketStatus.operationSuccess) {
              
              return TabBarView(
                children: EstadoTicket.values.map((estadoTicketActual) {
                  // Filtro en caliente: Solo dejamos pasar los tickets del estado correspondiente
                  final ticketsFiltrados = state.historial
                      .where((t) => t.estadoActual == estadoTicketActual)
                      .toList();
                  
                  final nombreEstado = _formatearNombreEstado(estadoTicketActual.name);
                  
                  return _buildListaTickets(
                    ticketsFiltrados, 
                    "No hay equipos en fase:\n$nombreEstado"
                  );
                }).toList(),
              );
            }
            
            // 4. ESTADO INICIAL
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildListaTickets(List<TicketEntity> ticketsFiltrados, String mensajeVacio) {
    if (ticketsFiltrados.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => context.read<TicketBloc>().add(const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.general)),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    mensajeVacio, 
                    textAlign: TextAlign.center, 
                    style: const TextStyle(color: Colors.grey, fontSize: 16)
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => context.read<TicketBloc>().add(const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.general)),
      // 📡 SENSOR DE TAMAÑO DE PANTALLA
      child: LayoutBuilder(
        builder: (context, constraints) {
          final anchoDisponible = constraints.maxWidth;

          // 📱 MODO MÓVIL (Pantallas estrechas)
          if (anchoDisponible < 600) {
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: ticketsFiltrados.length,
              itemBuilder: (context, index) {
                return _buildTicketCard(ticketsFiltrados[index]);
              },
            );
          } 
          
          // 💻 MODO TABLET / ESCRITORIO (Pantallas anchas)
          else {
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              // Enrutador de rejilla: Crea columnas de máximo 400px de ancho
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 450, // Ancho ideal de la tarjeta
                mainAxisExtent: 180, // Altura fija de la tarjeta para evitar desbordes
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: ticketsFiltrados.length,
              itemBuilder: (context, index) {
                return _buildTicketCard(ticketsFiltrados[index]);
              },
            );
          }
        },
      ),
    );
  }

  // =========================================================================
  // ⚙️ WIDGET HELPER: Tarjeta de Ticket (Aislada para reutilización responsiva)
  // =========================================================================

  Widget _buildTicketCard(TicketEntity ticket) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4), 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell( 
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => DetalleTicketPage(ticket: ticket)));
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. INDICADOR LED (Avatar)
              CircleAvatar(
                radius: 25,
                backgroundColor: _getColorPorEstado(ticket.estadoActual),
                child: const Icon(Icons.precision_manufacturing, color: Colors.white),
              ),
              const SizedBox(width: 16),
              
              // 2. CUERPO DE DATOS
              Expanded( // ⚙️ Restricción horizontal estricta
                child: Column(
                  mainAxisSize: MainAxisSize.min, // 🚀 CRÍTICO: Evita la expansión infinita vertical
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    Text(
                      '${ticket.id} | ${ticket.equipo.name.toUpperCase()}', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      // ⚠️ Quitamos maxLines para que el texto fluya hacia abajo si falta ancho
                    ),
                    const SizedBox(height: 8),
                    
                    // Detalles 
                    Text(
                      'Cliente: ${ticket.clienteId}\nFalla: ${ticket.fallaReportada}', 
                      // ⚠️ Quitamos maxLines restrictivo para asegurar que se lea todo
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    
                    // ⏱️ INDICADOR DE TIEMPO (Condicional)
                    if (ticket.estadoActual == EstadoTicket.recepcionFisica) ...[
                      const SizedBox(height: 12),
                      Text(
                        ticket.tiempoDePasoARecepcion != null
                            ? '⏱️ LEAD TIME: ${ticket.tiempoDePasoARecepcion!.inDays}d ${ticket.tiempoDePasoARecepcion!.inHours.remainder(24)}h ${ticket.tiempoDePasoARecepcion!.inMinutes.remainder(60)}m'
                            : '⏱️ LEAD TIME: Sin tiempo.',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: Colors.green, 
                          fontSize: 12,
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              
              // 3. ICONO DE ACCIÓN (Alineado siempre a la derecha)
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(Icons.chevron_right, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}