// lib/features/tickets/presentation/pages/bandeja_entregas_page.dart

import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart'; 
import '../../../../core/enum/ticket_enums.dart';
import '../../domain/entities/ticket_entity.dart';
import '../widgets/tiempo_en_curso_widget.dart';
import '../../../../core/theme/ticket_visual_theme.dart';

// 🔌 CONEXIÓN ESTRUCTURAL AL MÓDULO DE DESPACHO
import 'formulario_entrega_page.dart';

class BandejaEntregasPage extends StatefulWidget {
  const BandejaEntregasPage({super.key});

  @override
  State<BandejaEntregasPage> createState() => _BandejaEntregasPageState();
}

class _BandejaEntregasPageState extends State<BandejaEntregasPage> {
  
  @override
  void initState() {
    super.initState();
    // ⚙️ Secuencia de arranque del HMI
    _solicitarTelemetria(); 
  }

  // ⚙️ LÓGICA DE CONTROL CENTRALIZADA
  void _solicitarTelemetria() {
    final authState = context.read<AuthBloc>().state;
    
    if (authState is Authenticated) {
      context.read<TicketBloc>().add(
        const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.ninguno)
      );
    } else {
      debugPrint("⚠️ ALERTA: Intento de lectura de sensores sin credenciales de operador.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) => previous != current && current is Authenticated,
      listener: (context, state) {
        if (state is Authenticated) {
          _solicitarTelemetria();
        }
      },
      // ⚙️ SECCIÓN ÚNICA (SIN TABS)
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Estación de Despachos", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF005A9C)),
              onPressed: _solicitarTelemetria,
              tooltip: 'Refrescar telemetría',
            )
          ],
        ),
        backgroundColor: const Color(0xFFF4F7F6),
        body: BlocBuilder<TicketBloc, TicketState>(
          builder: (context, state) {
            
            // 1. ESTADO DE TRABAJO (Lectura de base de datos)
            if (state.status == TicketStatus.loading) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF005A9C)),
                    const SizedBox(height: 16),
                    Text(state.message.isNotEmpty ? state.message : 'Sincronizando equipos...', style: const TextStyle(color: Colors.grey)),
                  ],
                )
              );
            }
            
            // 2. ESTADO DE ALARMA
            if (state.status == TicketStatus.error) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(state.message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _solicitarTelemetria,
                      icon: const Icon(Icons.sync),
                      label: const Text('REINTENTAR CONEXIÓN', style: TextStyle(color: Color(0xFF005A9C))),
                    )
                  ],
                ),
              );
            }

            // 3. ESTADO DE LECTURA EXITOSA
            if (state.status == TicketStatus.loaded || state.status == TicketStatus.operationSuccess) {
              
              // ⚙️ FILTRO ÚNICO: Solo tickets en estado de entrega
              final entregasPendientes = state.historial
    .where((t) => t.estadoActual != EstadoTicket.finalizado)
    .toList();

              return _buildBandaEntregas(entregasPendientes, context);
            }

            // 4. ESTADO DE REPOSO
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  // =========================================================
  // ⚙️ SUBRUTINA DE DIBUJADO DE LA CINTA
  // =========================================================
  Widget _buildBandaEntregas(List<TicketEntity> tickets, BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFF005A9C),
      onRefresh: () async => _solicitarTelemetria(),
      child: tickets.isEmpty 
        ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No hay equipos pendientes de entrega.", style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  )
                ),
              ),
            ],
          )
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              
              // 🧠 LECTURA DE SENSORES PARA HMI (Vistos o X)
              final bool tieneGuia = ticket.urlGuiaRemision != null && ticket.urlGuiaRemision!.isNotEmpty;
              final bool tieneFactura = ticket.urlFactura != null && ticket.urlFactura!.isNotEmpty;
              
              // Lógica visual de progreso en la línea
              int progreso = 0;
              if (tieneGuia) progreso++;
              if (tieneFactura) progreso++;

              // 🎨 Avatar suave (antes: círculo azul sólido) + insignia de
              // progreso más discreta (antes: círculo naranja sólido).
              return Card(
                key: ValueKey(ticket.id),
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  leading: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      const AvatarSuave(color: kTicketAcento, icono: Icons.local_shipping, radio: 26),
                      if (progreso > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(color: kTicketAlerta, borderRadius: BorderRadius.circular(8)),
                          child: Text('$progreso/2', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                    ],
                  ),
                  title: Text(
                    'Ticket: ${ticket.id}', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('📦 Equipo: ${ticket.equipo.name.toUpperCase()} • Marca: ${ticket.marca.toUpperCase()}'),
                        // 🆕 Cliente (empresa/camaronera) y Contacto (persona) son
                        // datos distintos — se muestran ambos.
                        if (ticket.clienteId.trim().isNotEmpty) Text('🏢 Cliente: ${ticket.clienteId}'),
                        Text('👤 Contacto: ${ticket.nombreContacto}'),
                        const SizedBox(height: 8),
                        
                        // 🚥 PANELES PILOTO DE ESTADO DOCUMENTAL
                        Row(
                          children: [
                            _construirLuzPiloto('Guía', tieneGuia),
                            const SizedBox(width: 8),
                            _construirLuzPiloto('Factura', tieneFactura),
                          ],
                        ),
                        // 🆕 Tiempo en vivo en el estado actual (sin backend: se
                        // recalcula contra la hora real del dispositivo).
                        const SizedBox(height: 8),
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
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 18),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => FormularioEntregaPage(ticket: ticket)),
                    );
                  },
                ),
              );
            },
          ),
    );
  }

  // ⚙️ SUBRUTINA: INDICADORES LED VISUALES (Vistos y X)
  Widget _construirLuzPiloto(String etiqueta, bool activo) {
    return InsigniaSuave(
      color: activo ? kTicketExito : kTicketAlerta,
      icono: activo ? Icons.check_circle : Icons.cancel,
      texto: etiqueta,
    );
  }
}