import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/widgets/panel_documentos_comerciales.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/ticket_entity.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_state.dart';
import '../widgets/full_photo_widget.dart';
// 🔌 IMPORTACIÓN DEL NUEVO MÓDULO INDUSTRIAL
import '../widgets/modal_aprobacion_comercial.dart'; 
// Importa tus dependencias necesarias

class DetalleProformaPage extends StatelessWidget {
  final TicketEntity ticket;

  const DetalleProformaPage({super.key, required this.ticket});

  // ⚙️ SUBRUTINA: Modal de confirmación para MODIFICAR o ANULAR (Rechazos)
void _mostrarDialogoAccion(BuildContext context, String accion) {
  print("estamos en anular");
    if (accion == 'ANULAR') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('⚠️ Confirmación de Seguridad'),
          content: const Text('¿Está seguro de anular este ticket? Esta acción es irreversible y quedará registrada en el historial.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(ctx); // Cerramos el dialogo
                _ejecutarAnulacion(context); // Disparamos la lógica al BLoC
              },
              child: const Text('Confirmar Anulación', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }else if (accion == 'MODIFICAR') {
    // 🛠️ Controlador para capturar la justificación del operador
    final TextEditingController observacionController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false, // Evita cierres accidentales tocando fuera
      builder: (ctx) => AlertDialog(
        title: const Text('🔄 Reversar a Comercial'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'El ticket regresará a estado Comercial para su modificación. '
              'Ingrese el motivo (Obligatorio para auditoría):'
            ),
            const SizedBox(height: 12),
            TextField(
              controller: observacionController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Motivo de modificación',
                hintText: 'Ej. Corrección de precios en motor...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              final observacion = observacionController.text.trim();
              
              // ⚠️ HARD STOP: Validación innegociable
              if (observacion.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ ERROR: La observación es obligatoria para la auditoría.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return; // Cortocircuito, no avanza.
              }

              Navigator.pop(ctx); // Cerramos el modal
              _ejecutarModificacion(context, observacion); // Disparamos al BLoC
            },
            child: const Text('Confirmar Modificación', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  }


  void _ejecutarModificacion(BuildContext context, String observacion) {
  // ⚠️ ATENCIÓN ARQUITECTO: 
  // 'widget.ticket' asume que este Stateful/Stateless widget recibe el ticket actual.
  // Los campos 'nombreUsuario' y 'rolUsuario' idealmente deben venir de su AuthBloc o Singleton de sesión.
     final authState = context.read<AuthBloc>().state;
    String nombreOperario = 'SISTEMA';
    String rolOperario = 'DESCONOCIDO';
    
    if (authState is Authenticated) {
      nombreOperario = authState.usuario.nombre; 
      rolOperario = authState.usuario.rol.name.toUpperCase();
    }
  context.read<TicketBloc>().add(
    ReversarAComercialEvent(
      ticketActual: ticket, // Reemplace con la variable que contenga su ticket en esta vista
      observacion: observacion,
      nombreUsuario:nombreOperario , // 🚨 TODO: Conectar con datos de sesión reales
      rolUsuario: rolOperario,        // 🚨 TODO: Conectar con datos de sesión reales
    ),
  );
}

  void _ejecutarAnulacion(BuildContext context) {
  // 1. Extracción de Telemetría de Auth
  final authState = context.read<AuthBloc>().state;
  
  // 2. CORRECCIÓN: Usamos 'ticket' directamente (la propiedad del widget) 
  // en lugar de depender de 'context.read<TicketBloc>().state.currentTicket'
  // Si el widget tiene el objeto 'ticket', úselo:
  final ticketActual = ticket; 

  // 3. Validación de Auth
  if (authState is! Authenticated) {
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('Error: No se puede auditar la acción sin usuario activo.')),
     );
     return;
  }

  print("Estamos bloc.");
  
  // 4. Disparo del Evento
  context.read<TicketBloc>().add(AnularTicketEvent(
    ticket: ticketActual,
    nombreUsuario: authState.usuario.nombre,
    rolUsuario: authState.usuario.rol.name.toUpperCase(), 
  ));
}

 @override
Widget build(BuildContext context) {
  return BlocListener<TicketBloc, TicketState>(
    listener: (context, state) {
      if (state.status == TicketStatus.operationSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message), 
            backgroundColor: Colors.green, 
            duration: const Duration(seconds: 2)
          )
        );
        // Retiramos la pantalla HMI y devolvemos al usuario
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      } else if (state.status == TicketStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.message), backgroundColor: Colors.red)
        );
      }
    },
    child: Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: Text('Proforma: ${ticket.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Datos del Requerimiento", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF003366))),
            const SizedBox(height: 12),
            _buildDataCard(),
            const SizedBox(height: 24),
            const Text("Evidencia Fotográfica", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF003366))),
            const SizedBox(height: 12),
            _buildEvidenciasCard(context),
            const SizedBox(height: 24),
            const Text("Carga Documental (Cotización)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF003366))),
            const SizedBox(height: 12),
            PanelDocumentosComerciales(urls: ticket.proforma?.pdfUrls ?? []),
            const SizedBox(height: 24),
            const Text("Trazabilidad y Auditoría", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF003366))),
            const SizedBox(height: 12),
            _buildTimelineCard(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton.icon(
                onPressed: () => _mostrarDialogoAccion(context, 'MODIFICAR'),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Modificar'),
              ),
              ElevatedButton.icon(
                onPressed: () => ModalAprobacionComercial.show(context, ticket),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Aceptar'),
              ),
              ElevatedButton.icon(
                onPressed: () => _mostrarDialogoAccion(context, 'ANULAR'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                icon: const Icon(Icons.cancel, size: 18),
                label: const Text('Anular'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildDataCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDatoRow('Estado Actual:', ticket.estadoActual.name.toUpperCase()),
            const Divider(),
            _buildDatoRow('Equipo:', ticket.equipo.name.toUpperCase()),
            _buildDatoRow('Lugar de recepción:', ticket.sede.name.toUpperCase()),
            const Divider(),
            _buildDatoRow('Cliente:', ticket.clienteId),
            _buildDatoRow('Campamento:', ticket.campamento),
            _buildDatoRow('Contacto:', '${ticket.nombreContacto} (${ticket.telefonoContacto})'),
            const Divider(),
            const Text('Falla Reportada:', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text(ticket.fallaReportada, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenciasCard(BuildContext context) {
    if (ticket.fotosUrls.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('Sin evidencia fotográfica.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))),
        ),
      );
    }
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: ticket.fotosUrls.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullPhotoPage(imageUrl: ticket.fotosUrls[index]))),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 120,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ticket.fotosUrls[index].toLowerCase().contains('.mp4')
                        ? Container(
                            color: Colors.black87,
                            child: const Center(
                              child: Icon(Icons.videocam, color: Colors.white, size: 40),
                            ),
                          )
                        : Image.network(ticket.fotosUrls[index], fit: BoxFit.cover),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineCard() {
    final eventosOrdenados = List.from(ticket.historialEventos)..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: eventosOrdenados.map((evento) {
            final fechaStr = evento.timestamp.toString().substring(0, 16);
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.adjust, color: Color(0xFF005A9C), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(evento.accion, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('Operador: ${evento.usuarioNombre} [${evento.usuarioRol}]', style: const TextStyle(fontSize: 13)),
                        Text('Marca de tiempo: $fechaStr', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDatoRow(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(etiqueta, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(flex: 3, child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }
}