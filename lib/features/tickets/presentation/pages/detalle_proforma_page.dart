import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/widgets/panel_documentos_comerciales.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/ticket_entity.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_state.dart';
import '../widgets/full_photo_widget.dart';
import 'package:url_launcher/url_launcher.dart';
// Importa tus dependencias necesarias

class DetalleProformaPage extends StatelessWidget {
  final TicketEntity ticket;

  const DetalleProformaPage({super.key, required this.ticket});

  // ⚙️ SUBRUTINA: Modal de confirmación segura (HMI)
  void _mostrarDialogoAccion(BuildContext context, String accion) {
    final TextEditingController observacionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (contextDialog) {
        return AlertDialog(
          title: Text('$accion Proforma: ${ticket.id}'),
          content: TextField(
            controller: observacionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Observación (Obligatoria/Opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contextDialog),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
  onPressed: () {
    final observacion = observacionController.text.trim();
    
    // 🛑 CONTROL DE CALIDAD INDUSTRIAL: 
    // Si la acción es MODIFICAR, la observación es OBLIGATORIA.
    if (accion == 'MODIFICAR' && observacion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Debe ingresar un motivo para justificar la modificación.'), backgroundColor: Colors.orange)
      );
      return; // Cortamos la corriente, no se cierra el modal ni se dispara nada
    }

    // 🚀 DISPARO DE SEÑAL
    if (accion == 'MODIFICAR') {
      context.read<TicketBloc>().add(
        ReversarAComercialEvent(
          ticketActual: ticket,
          // ⚠️ ATENCIÓN: Extrae estos datos de tu AuthBloc o SharedPreferences 
          nombreUsuario: 'Operador Comercial', 
          rolUsuario: 'Comercial',
          observacion: observacion,
        )
      );
    }
    // TODO: Más adelante pondrás aquí los IF para 'ACEPTAR' o 'ANULAR'

    Navigator.pop(contextDialog); // Cerramos el modal de texto
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: accion == 'ANULAR' ? Colors.red : Colors.green,
  ),
  child: Text('CONFIRMAR $accion'),
),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TicketBloc, TicketState>(
      listener: (context, state) {
        if (state.status == TicketStatus.operationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.green, duration: const Duration(seconds: 2))
          );
          
          // 🚀 Retiramos la pantalla HMI y devolvemos al usuario a la lista
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
            
            // 📸 PANEL DE FOTOS (Heredado de tu diseño)
            const Text("Evidencia Fotográfica", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF003366))),
            const SizedBox(height: 12),
            _buildEvidenciasCard(context),

            const SizedBox(height: 24),
            
            // 📄 NUEVO PANEL: DOCUMENTOS COMERCIALES
            const Text("Carga Documental (Cotización)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF003366))),
            const SizedBox(height: 12),
            PanelDocumentosComerciales(
  // Extraemos las URLs de la entidad y las mandamos por el bus de datos
  urls: ticket.proforma?.pdfUrls ?? [], 
),

            const SizedBox(height: 24),
            
            const Text("Trazabilidad y Auditoría", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF003366))),
            const SizedBox(height: 12),
            _buildTimelineCard(),
          ],
        ),
      ),
      // 🕹️ CONSOLA DE ACTUADORES (Fija en la parte inferior)
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
                // 🔌 CABLE CONECTADO AL MODAL DE SEGURIDAD
                onPressed: () => _mostrarDialogoAccion(context, 'MODIFICAR'), 
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Modificar'),
              ),
              ElevatedButton.icon(
                onPressed: () => _mostrarDialogoAccion(context, 'ACEPTAR'),
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
    ));
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
            _buildDatoRow('Sede Operativa:', ticket.sede.name.toUpperCase()),
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
                    child: Image.network(ticket.fotosUrls[index], fit: BoxFit.cover),
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