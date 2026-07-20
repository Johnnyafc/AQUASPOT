import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
// ⚠️ Ajuste estos imports a sus rutas reales
// import '../../domain/entities/ticket_entity.dart';
// import '../widgets/full_photo_widget.dart';
// import '../bloc/ticket_bloc.dart';
// import 'package:url_launcher/url_launcher.dart'; // Necesario para abrir el PDF

class EstacionBodegaPage extends StatelessWidget {
  final TicketEntity ticket;

  const EstacionBodegaPage({super.key, required this.ticket});

  // Función puente para abrir el documento en el navegador/visor nativo
Future<void> _abrirDocumento(BuildContext context, String urlString) async {
  if (urlString.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Error: La URL del documento está vacía.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  final Uri url = Uri.parse(urlString);

  try {
    // LaunchMode.externalApplication fuerza a que el OS decida qué hacer.
    // En Web: Abre una nueva pestaña.
    // En Móvil: Abre el navegador o el visor de PDFs predeterminado del teléfono.
    if (await canLaunchUrl(url)) {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication, 
      );
    } else {
      throw Exception('No se pudo establecer conexión con el puerto de salida.');
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falla de sistema al abrir el documento: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  void _accionarValidacionBodega(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    String nombreOperario = 'SISTEMA';
    String rolOperario = 'DESCONOCIDO';
    
    if (authState is Authenticated) {
      nombreOperario = authState.usuario.nombre; 
      rolOperario = authState.usuario.rol.name.toUpperCase();
    }

  context.read<TicketBloc>().add(
    ProcesarBodegaEvent(
      ticket: ticket,
      nombreUsuario: nombreOperario, // Inyectar desde AuthBloc
      rolUsuario: rolOperario,             // Inyectar desde AuthBloc
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: Text('Estación Bodega: ${ticket.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.brown.shade800, // Color de la zona de Bodega
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      // 🛡️ Bucle de retroalimentación del BLoC
      body: BlocListener<TicketBloc, TicketState>(
        listener: (context, state) {
          if (state.status == TicketStatus.operationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Validación exitosa. Ticket actualizado.'), backgroundColor: Colors.green),
            );
            Navigator.pop(context); // Lazo cerrado, vuelve a la bandeja
          } else if (state.status == TicketStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Falla de sistema: ${state.message}'), backgroundColor: Colors.red),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              // 📦 NUEVO MÓDULO VISUAL: Verificación de Compras
              const Text("Inspección de Compras", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF003366))),
              const SizedBox(height: 12),
              _buildModuloComprasCard(context),

              const SizedBox(height: 24),

              // 🚀 ACTUADOR PRINCIPAL
              BlocBuilder<TicketBloc, TicketState>(
                builder: (context, state) {
                  final bool procesando = state.status == TicketStatus.loading;
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: procesando ? null : () => _accionarValidacionBodega(context),
                      icon: procesando 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline, size: 24),
                      label: Text(
                        procesando ? 'PROCESANDO...' : 'COMPRAS VALIDADO - APROBAR',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 🧩 MÓDULOS DE RENDERIZADO
  // ==========================================

  Widget _buildModuloComprasCard(BuildContext context) {
    // Inspección rigurosa: Si estamos en Bodega, esto NO DEBERÍA ser nulo.
    final compras = ticket.gestionCompras;

    if (compras == null) {
      return Card(
        color: Colors.red.shade50,
        elevation: 2,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(16)
        ),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
              SizedBox(width: 16),
              Expanded(
                child: Text('Falla de integridad: El ticket llegó a Bodega sin registro de Compras.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.brown.shade200),
        borderRadius: BorderRadius.circular(16)
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDatoRow('Aprobación Comercial:', ticket.numeroOrdenVenta ?? 'N/A'),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.receipt_long, color: Colors.brown, size: 32),
              title: const Text('Orden de Compra Generada', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Toque para descargar el PDF validado por Compras.', style: TextStyle(fontSize: 12)),
              trailing: ElevatedButton(
                onPressed: () => _abrirDocumento(context, compras.urlOrdenCompra),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.brown.shade700, foregroundColor: Colors.white),
                child: const Text('VER ORDEN'),
              ),
            ),
            if (compras.observacion != null && compras.observacion!.isNotEmpty) ...[
              const Divider(),
              const Text('Notas del Operador de Compras:', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 4),
              Text(compras.observacion!, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
            ]
          ],
        ),
      ),
    );
  }

  // Los métodos _buildDataCard, _buildEvidenciasCard, _buildTimelineCard y _buildDatoRow
  // se mantienen idénticos a su diseño original, ya que estructuralmente estaban correctos.
  // (Insértelos aquí desde su código base).

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
            _buildDatoRow('Número de Serie:', ticket.numeroSerie ?? 'No Registrado'),
            const Divider(),
            const Text('Falla Reportada e Inspección:', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text(ticket.fallaReportada, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenciasCard() {
    if (ticket.fotosUrls.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text('Sin evidencia fotográfica.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          ),
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
              return Container(
                margin: const EdgeInsets.only(right: 12),
                width: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    ticket.fotosUrls[index],
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Colors.teal));
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
                    },
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
    final eventosOrdenados = List.from(ticket.historialEventos)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

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
                        const SizedBox(height: 4),
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