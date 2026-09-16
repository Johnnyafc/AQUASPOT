import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/tarjeta_no_requiere_compras_widget.dart';

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
    // ⚙️ Aquí extraemos el sub-módulo donde realmente están los nodos de garantía
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
              TarjetaNoRequiereComprasWidget(ticket: ticket),
              // =====================================================================
              // 1. ENCABEZADO DE INFORMACIÓN Y TRAZABILIDAD
              // =====================================================================
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
                      Text('Responsable Facturación: ${ticket.responsableFacturacionLegible}'),
                      
                      // 🟢 Inyección de la Orden de Venta (Apuntando a evaluacion)
                      if (evaluacion?.numeroOVGarantia != null && evaluacion!.numeroOVGarantia!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            border: Border.all(color: Colors.blue),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'OV Garantía: ${evaluacion.numeroOVGarantia}', 
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // =====================================================================
              // 2. REPORTE TÉCNICO (OBSERVACIÓN DEL CAMPO)
              // =====================================================================
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
                  evaluacion?.observacion != null && evaluacion!.observacion.isNotEmpty 
                      ? evaluacion.observacion 
                      : 'Sin observaciones registradas por el técnico.',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),

              // =====================================================================
              // 3. TUBERÍA DE EVIDENCIAS Y ARCHIVOS ADJUNTOS
              // =====================================================================
              const Text('Evidencias y Costeo Adjunto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              
              // Botón para Proforma / Costeo Excel
              if (evaluacion?.urlProformaExcel != null && evaluacion!.urlProformaExcel!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.table_chart, color: Colors.green),
                  title: const Text('Ver Proforma / Costeo (Excel)'),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () => _launchURL(evaluacion.urlProformaExcel!),
                ),

              // Lista de PDFs adjuntos (Diagnóstico regular)
              if (evaluacion?.urlsAdjuntosPdf != null && evaluacion!.urlsAdjuntosPdf.isNotEmpty)
                ...evaluacion.urlsAdjuntosPdf.map((pdfUrl) {
                  return ListTile(
                    leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    title: Text('Reporte PDF Adjunto (${evaluacion.urlsAdjuntosPdf.indexOf(pdfUrl) + 1})'),
                    trailing: const Icon(Icons.open_in_new, size: 16),
                    onTap: () => _launchURL(pdfUrl),
                  );
                }),

              // 🟢 Tubería de PDFs específicos de Garantía (Apuntando a evaluacion)
              if (evaluacion?.urlsAdjuntosPdfGarantia != null && evaluacion!.urlsAdjuntosPdfGarantia!.isNotEmpty)
                ...evaluacion!.urlsAdjuntosPdfGarantia!.map((pdfGarantiaUrl) {
                  return ListTile(
                    leading: const Icon(Icons.verified_user, color: Colors.blue),
                    title: Text('Documento de Garantía (${evaluacion.urlsAdjuntosPdfGarantia!.indexOf(pdfGarantiaUrl) + 1})'),
                    trailing: const Icon(Icons.open_in_new, size: 16),
                    onTap: () => _launchURL(pdfGarantiaUrl),
                  );
                }),

              // 🟢 PDF de Revisión Técnica Antigua (Garantía de servicio)
              if (evaluacion?.urlPdfRevisionTecnicaAntigua != null && evaluacion!.urlPdfRevisionTecnicaAntigua!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.history_edu, color: Colors.deepOrange),
                  title: const Text('Revisión Técnica Antigua (PDF)'),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () => _launchURL(evaluacion.urlPdfRevisionTecnicaAntigua!),
                ),

              const SizedBox(height: 32),

              // =====================================================================
              // 4. BOTONES DE MANDO CRÍTICO (APROBAR / RECHAZAR)
              // =====================================================================
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
    final authState = context.read<AuthBloc>().state;
    String nombreUser = 'Sistema';
    String rolUser = 'Operador Garantías';

    if (authState is Authenticated) {
      nombreUser = authState.usuario.nombre;
      rolUser = authState.usuario.rol.name.toUpperCase();
    }

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