import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/widgets/tiempo_en_curso_widget.dart';
import 'package:aquaspot_postventa/core/theme/ticket_visual_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Asegúrese de importar sus modelos, enums y blocs

class BandejaRecepcionGuaboPage extends StatelessWidget {
  const BandejaRecepcionGuaboPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bandeja de Tránsito - EL GUABO', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey[900], // Color industrial clásico
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200), // ⚙️ Restricción de chasis
            child: BlocBuilder<TicketBloc, TicketState>(
              builder: (context, state) {
                if (state.status == TicketStatus.loading && state.historial.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                // =========================================================
                // 🧠 FILTRO LÓGICO DE PRESENTACIÓN
                // Nota: Idealmente, el BLoC ya le entrega esta lista limpia
                // desde un query optimizado de Firestore.
                // =========================================================
                final ticketsEnTransito = state.historial.where((t) {
                  final esGuabo = t.sede.toString().toUpperCase().contains('EL_GUABO');
                  final estaEnCamino = t.estadoActual == EstadoTicket.enCamino;
                  return esGuabo && estaEnCamino;
                }).toList();

                if (ticketsEnTransito.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                        SizedBox(height: 16),
                        Text(
                          'Bandeja limpia. No hay equipos en tránsito.',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // =========================================================
                // 📐 HMI RESPONSIVO (Tablet vs Desktop)
                // =========================================================
                return LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 800) {
                      return _buildGridView(ticketsEnTransito, context);
                    } else {
                      return _buildListView(ticketsEnTransito, context);
                    }
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------
  // 📱 VISTA COMPACTA (Tablets / Móviles)
  // -----------------------------------------------------
  Widget _buildListView(List<TicketEntity> tickets, BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tickets.length,
      itemBuilder: (context, index) {
        return _TicketCard(key: ValueKey(tickets[index].id), ticket: tickets[index]);
      },
    );
  }

  // -----------------------------------------------------
  // 🖥️ VISTA EXPANDIDA (Monitores de Sala de Control)
  // -----------------------------------------------------
  // 🔧 ANTES: GridView con `childAspectRatio: 2.5` (altura de celda calculada
  // a partir del ancho, fija). Al agregar más datos a la tarjeta (equipo,
  // cliente, reloj en vivo) el contenido pasó de esa altura fija y Flutter
  // mostraba el aviso de "overflow" (franjas amarillas/negras).
  //
  // ✅ AHORA: se arman filas de 2 tarjetas con `Row` + `Expanded` (sin
  // `mainAxisExtent`/`childAspectRatio`), así cada fila crece exactamente lo
  // que necesite su tarjeta más alta — sin importar cuánto crezca el
  // contenido en el futuro, nunca vuelve a recortarse.
  Widget _buildGridView(List<TicketEntity> tickets, BuildContext context) {
    const columnas = 2;
    final filas = <List<TicketEntity>>[];
    for (var i = 0; i < tickets.length; i += columnas) {
      final fin = (i + columnas > tickets.length) ? tickets.length : i + columnas;
      filas.add(tickets.sublist(i, fin));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filas.length,
      itemBuilder: (context, index) {
        final fila = filas[index];
        final hijos = <Widget>[];
        for (var i = 0; i < columnas; i++) {
          if (i > 0) hijos.add(const SizedBox(width: 16));
          hijos.add(i < fila.length ? Expanded(child: _TicketCard(key: ValueKey(fila[i].id), ticket: fila[i])) : const Expanded(child: SizedBox.shrink()));
        }
        return Padding(
          padding: EdgeInsets.only(bottom: index == filas.length - 1 ? 0 : 16),
          // 🔧 `stretch` (antes `start`): las 2 tarjetas de la fila quedan con
          // el mismo alto, así los bordes no se ven "desalineados" cuando
          // una tiene más datos que la otra.
          // 🔧 `IntrinsicHeight`: esta fila vive dentro de un ListView.builder
          // (alto no acotado). `stretch` solo puede estirar a los hijos si
          // la fila ya tiene un alto definido — sin esto Flutter lanza
          // "BoxConstraints forces an infinite height". IntrinsicHeight le
          // da a la fila el alto de su hijo más alto y RECIÉN AHÍ stretch
          // iguala a los demás a ese alto.
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: hijos),
          ),
        );
      },
    );
  }
}

// =========================================================
// 🎫 COMPONENTE AISLADO: TARJETA DE TICKET
// =========================================================
class _TicketCard extends StatelessWidget {
  final TicketEntity ticket;

  const _TicketCard({Key? key, required this.ticket}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Evita RenderFlex exceptions
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ID: ${ticket.id}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                // 🎨 Insignia suave con el color único del estado (antes: naranja
                // fijo, sin relación con el resto de la app).
                InsigniaSuave(color: colorPorEstadoTicket(ticket.estadoActual), texto: 'EN CAMINO'),
              ],
            ),
            const Divider(),
            Text('Equipo: ${ticket.equipo.name} - ${ticket.marca}', style: const TextStyle(fontSize: 14, color: kTicketTextoPrincipal)),
            // 🆕 Cliente (camaronera/empresa, ej. "Acuarios del Golfo") y
            // Contacto (persona, ej. "Jose Montalvo") son datos distintos —
            // se muestran ambos.
            if (ticket.clienteId.trim().isNotEmpty)
              Text('Cliente: ${ticket.clienteId}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTicketTextoPrincipal)),
            Text('Contacto: ${ticket.nombreContacto}', style: const TextStyle(fontSize: 14, color: kTicketTextoPrincipal)),
            Text('Falla: ${ticket.fallaReportada}', style: const TextStyle(color: kTicketTextoPrincipal), maxLines: 2, overflow: TextOverflow.ellipsis),
            // 🆕 Tiempo en vivo en el estado actual (sin backend: se
            // recalcula contra la hora real del dispositivo).
            const SizedBox(height: 6),
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
            const SizedBox(height: 16),// Aquí es seguro usar Spacer porque el Card tiene tamaño definido por el padre
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // 🚀 DISPARADOR DE TRANSICIÓN DE ESTADO
                  _confirmarRecepcion(context, ticket);
                },
                style: ElevatedButton.styleFrom(
                  // 🎨 Acento único de la app (antes: blueAccent, un azul
                  // distinto al del resto de las bandejas).
                  backgroundColor: kTicketAcento,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.download_done, color: Colors.white),
                label: const Text('CONFIRMAR RECEPCIÓN EN TALLER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

void _confirmarRecepcion(BuildContext context, TicketEntity ticket) {
    // ⚡ 1. Lectura de los sensores de identidad (AuthBloc)
    final authState = context.read<AuthBloc>().state;
    String nombreOperario = 'OPERARIO_DESCONOCIDO';
    String rolOperario = 'SISTEMA';

    if (authState is Authenticated) { 
      nombreOperario = authState.usuario.nombre; 
      rolOperario = authState.usuario.rol.name; 
    }

    // 🚀 2. Disparo del actuador hacia el bus de datos
    context.read<TicketBloc>().add(
      ActualizarEstadoTicketEvent(
        ticket: ticket, 
        nuevoEstado: EstadoTicket.recepcionFisica,
        accionAuditoria: 'EQUIPO ENVIADO DESDE EL GUABO RECIBIDO EN TALLER',
        nombreUsuario: nombreOperario, 
        rolUsuario: rolOperario,       
      )
    );
    
    // 🔔 3. Feedback visual local
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Comando de recepción enviado para ${ticket.id}'),
        backgroundColor: kTicketAcento, // Color estándar para acciones de proceso
        duration: const Duration(seconds: 2),
      ),
    );
  }
}