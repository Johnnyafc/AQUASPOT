// lib/features/tickets/presentation/pages/asignacion_costos_page.dart

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

class AsignacionCostosPage extends StatefulWidget {
  final TicketEntity ticket;
  const AsignacionCostosPage({super.key, required this.ticket});

  @override
  State<AsignacionCostosPage> createState() => _AsignacionCostosPageState();
}

class _AsignacionCostosPageState extends State<AsignacionCostosPage> {
  final _formKey = GlobalKey<FormState>();
  final _controllerProyecto = TextEditingController();

  @override
  void dispose() {
    _controllerProyecto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🧠 SENSOR MAESTRO DE GARANTÍA ACTIVA
    final bool esGarantiaActiva = widget.ticket.tipoRequerimiento == TipoRequerimiento.reclamoGarantia &&
                                  widget.ticket.tipoGarantia != null && 
                                  widget.ticket.tipoGarantia!.trim().isNotEmpty && 
                                  widget.ticket.tipoGarantia!.toLowerCase() != 'ninguna' &&
                                  widget.ticket.tipoGarantia!.toLowerCase() != 'pendiente' &&
                                  widget.ticket.esGarantia != false; 

    return BlocListener<TicketBloc, TicketState>(
      listener: (context, state) {
        if (state.status == TicketStatus.operationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
          _controllerProyecto.clear();
          Navigator.of(context).pop();
        } else if (state.status == TicketStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error de sistema: ${state.message}')),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Asignación de Proyecto - Costos')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildReadOnlyField("Tipo de requerimiento", widget.ticket.tipoRequerimiento.name),
              
              // ==========================================
              // 🔌 LÍNEA BASE INNEGOCIABLE: LA OV COMERCIAL SIEMPRE SE MUESTRA
              // ==========================================
              _buildReadOnlyField("Orden de Venta (Comercial)", widget.ticket.numeroOrdenVenta ?? 'No asignado'),
              
              if (widget.ticket.codigoOrdenVenta != null && widget.ticket.codigoOrdenVenta!.isNotEmpty)
                _buildPdfDownloadContainer(
                  context: context,
                  titulo: 'Descargar Orden de Venta Comercial',
                  subtitulo: 'Requerimiento comercial de origen.',
                  urlPDF: widget.ticket.codigoOrdenVenta!.first,
                  colorAcento: Colors.blueAccent,
                ),

              // ==========================================
              // 🔌 BLOQUE COMPLEMENTARIO: SI ES GARANTÍA ACTIVA, AÑADIMOS SUS DATOS TÉCNICOS
              // ==========================================
              if (esGarantiaActiva) ...[
                const SizedBox(height: 8),
                _buildReadOnlyField("Tipo de Garantía", widget.ticket.tipoGarantia!.toUpperCase()),
                _buildReadOnlyField(
                  widget.ticket.tipoGarantia == 'servicio' ? "OV de Servicio Antiguo" : "OV de Máquina Nueva", 
                  widget.ticket.evaluacionTecnica?.numeroOVGarantia ?? 'No registrada'
                ),
              ],

              const SizedBox(height: 8),
              _buildReadOnlyField("Cliente", widget.ticket.clienteId),
              _buildReadOnlyField("Máquina", widget.ticket.equipo.name),
              _buildReadOnlyField("Serie", widget.ticket.numeroSerie.toString()),
              _buildReadOnlyField("Marca", widget.ticket.marca ?? 'No especificada'), 
              _buildReadOnlyField("Ubicación", widget.ticket.lugarAtencion.name),
              
              const Divider(height: 32),

              // ==========================================
              // 🚨 PANEL DE AUDITORÍA (Garantía vs Rechazada)
              // ==========================================
              _buildPanelAuditoriaGarantia(esGarantiaActiva),
              
              TextFormField(
                controller: _controllerProyecto,
                decoration: const InputDecoration(
                  labelText: 'Código de Proyecto',
                  hintText: 'Ingrese el código asignado...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.assignment_turned_in),
                ),
                validator: (val) => (val == null || val.isEmpty) 
                    ? 'El código de proyecto es obligatorio para desbloquear Compras' 
                    : null,
              ),
              
              const SizedBox(height: 24),
              
              BlocBuilder<TicketBloc, TicketState>(
                builder: (context, state) {
                  final isLoading = state.status == TicketStatus.loading;

                  return ElevatedButton(
                    onPressed: isLoading ? null : _guardarAsignacion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800], 
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'ASIGNAR Y DESBLOQUEAR COMPRAS', 
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ⚙️ SUBRUTINA VISUAL: Panel adaptativo según el veredicto de ingeniería
  Widget _buildPanelAuditoriaGarantia(bool esGarantiaActiva) {
    final tipoGarantia = widget.ticket.tipoGarantia;
    final bool esReclamoOriginal = widget.ticket.tipoRequerimiento == TipoRequerimiento.reclamoGarantia &&
                                  tipoGarantia != null && 
                                  tipoGarantia.trim().isNotEmpty && 
                                  tipoGarantia.toLowerCase() != 'ninguna' &&
                                  tipoGarantia.toLowerCase() != 'pendiente';

    if (!esReclamoOriginal) {
      return const SizedBox.shrink();
    }

    // CASO A: La garantía fue RECHAZADA
    if (!esGarantiaActiva) {
      final String? ovComercialUrl = (widget.ticket.codigoOrdenVenta != null && widget.ticket.codigoOrdenVenta!.isNotEmpty)
          ? widget.ticket.codigoOrdenVenta!.first
          : null;

      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade700, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'TICKET INICIÓ POR GARANTÍA - FUE NEGADA', 
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14)
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Este requerimiento fue rechazado por ingeniería y devuelto al flujo comercial estándar. Utilice la Orden de Venta original:',
              style: TextStyle(color: Colors.black87, fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (ovComercialUrl != null)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                title: const Text(
                  'Descargar Orden de Venta Comercial', 
                  style: TextStyle(decoration: TextDecoration.underline, color: Colors.blue, fontWeight: FontWeight.bold)
                ),
                trailing: const Icon(Icons.open_in_new, size: 20, color: Colors.blue),
                onTap: () => _abrirEnlaceGarantia(context, ovComercialUrl),
              )
            else
              const Text('⚠️ No se detectó documento de Orden de Venta comercial adjunto.', style: TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ),
      );
    }

    // CASO B: La garantía ESTÁ APROBADA (Flujo normal de garantía)
    final bool esServicio = tipoGarantia!.toLowerCase() == 'servicio';
    final String tituloOV = esServicio ? 'OV de Servicio Antiguo' : 'OV de Máquina Nueva';
    final List<String> urlsGarantia = widget.ticket.evaluacionTecnica?.urlsAdjuntosPdfGarantia ?? [];
    final bool tieneRespaldo = urlsGarantia.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade700, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.policy, color: Colors.amber.shade900),
              const SizedBox(width: 8),
              Text(
                'ES GARANTÍA DE: ${tipoGarantia.toUpperCase()}', 
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 14)
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Para emitir el código de proyecto, verifique el documento de respaldo adjunto por el departamento técnico:',
            style: TextStyle(color: Colors.black87, fontSize: 13),
          ),
          const SizedBox(height: 12),
          
          if (tieneRespaldo)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
              title: Text(
                'Descargar $tituloOV', 
                style: const TextStyle(decoration: TextDecoration.underline, color: Colors.blue, fontWeight: FontWeight.bold)
              ),
              trailing: const Icon(Icons.open_in_new, size: 20, color: Colors.blue),
              onTap: () => _abrirEnlaceGarantia(context, urlsGarantia.first),
            )
          else
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
              child: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'FALLA ESTRUCTURAL: No se detectó documento PDF de respaldo en la base de datos.',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPdfDownloadContainer({
    required BuildContext context, 
    required String titulo, 
    required String subtitulo, 
    required String urlPDF,
    Color colorAcento = Colors.redAccent,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100, 
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.picture_as_pdf, color: colorAcento, size: 28),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Text(subtitulo, style: const TextStyle(fontSize: 11)),
        trailing: ElevatedButton.icon(
          icon: const Icon(Icons.download, size: 16),
          label: const Text('Descargar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onPressed: () => _abrirEnlaceGarantia(context, urlPDF),
        ),
      ),
    );
  }

  Future<void> _abrirEnlaceGarantia(BuildContext context, String urlString) async {
    if (urlString.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Enlace inválido o no disponible.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final Uri url = Uri.parse(urlString);

    try {
      final bool exito = await launchUrl(
        url, 
        mode: LaunchMode.externalApplication,
      );

      if (!exito && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ No se pudo abrir el navegador para descargar el PDF.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error en el motor de descarga: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        readOnly: true,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), filled: true, fillColor: Colors.grey[100]),
      ),
    );
  }

  void _guardarAsignacion() {
    if (_formKey.currentState!.validate()) {
      final authState = context.read<AuthBloc>().state;

      if (authState is! Authenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No se puede asignar proyecto sin usuario autenticado.')),
        );
        return;
      }

      context.read<TicketBloc>().add(CompletarFaseCostosEvent(
        ticket: widget.ticket,
        codigoProyecto: _controllerProyecto.text,
        nombreUsuario: authState.usuario.nombre,
        rolUsuario: authState.usuario.rol.name.toUpperCase(),
      ));
    }
  }
}