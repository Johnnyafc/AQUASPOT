import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart'; // Útil para abrir los links de Storage

class RevisionGarantiaPage extends StatelessWidget {
  final TicketEntity ticket;

  const RevisionGarantiaPage({super.key, required this.ticket});

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('No se pudo abrir el enlace: $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    final evaluacion = ticket.evaluacionTecnica;

    return Scaffold(
      appBar: AppBar(
        title: Text('Dictamen de Garantía: ${ticket.id}'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: BlocListener<TicketBloc, TicketState>(
        listener: (context, state) {
          if (state.status == TicketStatus.operationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.green),
            );
            Navigator.pop(context); // Retorna a la bandeja
          } else if (state.status == TicketStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. ENCABEZADO DE INFORMACIÓN
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Equipo: ${ticket.equipo.name} (${ticket.marca})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Cliente ID: ${ticket.clienteId}'),
                      Text('Serie: ${ticket.numeroSerie ?? "No registrada"}'),
                      Text('Responsable Facturación: ${ticket.responsableFacturacion ?? "N/A"}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. REPORTE TÉCNICO (OBSERVACIÓN)
              const Text('Reporte Técnico Inicial', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  evaluacion?.observacion.isNotEmpty == true 
                      ? evaluacion!.observacion 
                      : 'Sin observaciones registradas por el técnico.',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),

              // 3. ARCHIVOS ADJUNTOS Y COSTEO (EXCEL / PDF)
              const Text('Evidencias y Costeo Adjunto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              
              // Botón para Proforma / Costeo Excel
              if (evaluacion?.urlProformaExcel != null)
                ListTile(
                  leading: const Icon(Icons.table_chart, color: Colors.green),
                  title: const Text('Ver Proforma / Costeo (Excel)'),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () => _launchURL(evaluacion!.urlProformaExcel!),
                ),

              // Lista de PDFs adjuntos
              if (evaluacion?.urlsAdjuntosPdf != null && evaluacion!.urlsAdjuntosPdf.isNotEmpty)
                ...evaluacion.urlsAdjuntosPdf.map((pdfUrl) {
                  return ListTile(
                    leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    title: Text('Reporte PDF Adjunto (${evaluacion.urlsAdjuntosPdf.indexOf(pdfUrl) + 1})'),
                    trailing: const Icon(Icons.open_in_new, size: 16),
                    onTap: () => _launchURL(pdfUrl),
                  );
                }),

              const SizedBox(height: 32),

              // 4. BOTONES DE MANDO CRÍTICO (APROBAR / RECHAZAR)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text('NO APROBAR'),
                      onPressed: () => _ejecutarDictamen(context, false),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('APROBAR GARANTÍA'),
                      onPressed: () => _ejecutarDictamen(context, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _ejecutarDictamen(BuildContext context, bool esGarantiaAprobada) {
    // Extraer datos del usuario actual desde el AuthBloc
    final authState = context.read<AuthBloc>().state;
    String nombreUser = 'Sistema';
    String rolUser = 'Operador Garantías';

    if (authState is Authenticated) {
      nombreUser = authState.usuario.nombre;
      rolUser = authState.usuario.rol.name;
    }

    // Disparar el evento al BLoC
    context.read<TicketBloc>().add(
      DictaminarGarantiaEvent(
        ticket: ticket,
        esGarantia: esGarantiaAprobada,
        nombreUsuario: nombreUser,
        rolUsuario: rolUser,
      ),
    );
  }
}