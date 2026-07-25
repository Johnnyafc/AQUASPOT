// lib/features/tickets/presentation/pages/gestion_compras_page.dart

import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_state.dart';
import '../../domain/entities/ticket_entity.dart';
import 'package:url_launcher/url_launcher.dart';

class GestionComprasPage extends StatefulWidget {
  final TicketEntity ticket;

  const GestionComprasPage({Key? key, required this.ticket}) : super(key: key);

  @override
  State<GestionComprasPage> createState() => _GestionComprasPageState();
}

class _GestionComprasPageState extends State<GestionComprasPage> {
  final TextEditingController _observacionController = TextEditingController();
  XFile? _archivoOrdenCompra;

  @override
  void dispose() {
    _observacionController.dispose();
    super.dispose();
  }

  // ⚙️ ACTUADOR: Selector de archivos
  Future<void> _seleccionarArchivo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _archivoOrdenCompra = XFile(result.files.single.path!);
      });
    }
  }

  // ⚙️ LECTURA: Abrir proforma en el navegador/app externa
  Future<void> _abrirProformaExcel(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No se pudo abrir el enlace de telemetría.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 🚀 EJECUCIÓN: Disparo del evento al BLoC
  void _ejecutarPasoABodega() {
    if (_archivoOrdenCompra == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('FALLA DE SECUENCIA: Debe adjuntar la Orden de Compra física o digital.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final authState = context.read<AuthBloc>().state;
    String operador = 'DESCONOCIDO';
    String rol = 'SIN_ROL';

    if (authState is Authenticated) {
      operador = authState.usuario.nombre;
      rol = authState.usuario.rol.name.toUpperCase();
    } 
    
    context.read<TicketBloc>().add(
      ProcesarGestionComprasEvent(
        ticket: widget.ticket,
        archivoOrdenCompra: _archivoOrdenCompra!,
        observacion: _observacionController.text,
        nombreUsuario: operador,
        rolUsuario: rol,
      ),
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transmitiendo orden de compra al servidor...'), backgroundColor: Colors.teal),
    );
  }

  Future<void> _abrirDocumentoOV(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Falla de hardware: No se pudo abrir el documento.'),
            backgroundColor: Colors.red,
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🧠 SENSOR MAESTRO: Evaluación de garantía activa
    final bool esGarantiaActiva = widget.ticket.tipoRequerimiento == TipoRequerimiento.reclamoGarantia &&
                                  widget.ticket.tipoGarantia != null && 
                                  widget.ticket.tipoGarantia!.trim().isNotEmpty && 
                                  widget.ticket.tipoGarantia!.toLowerCase() != 'ninguna' &&
                                  widget.ticket.tipoGarantia!.toLowerCase() != 'pendiente' &&
                                  widget.ticket.esGarantia != false; 

    // Detección si el ticket inició como garantía pero fue rechazado
    final bool esReclamoNegado = widget.ticket.tipoRequerimiento == TipoRequerimiento.reclamoGarantia &&
                                 widget.ticket.esGarantia == false;

    final String codigoProyecto = widget.ticket.codigoProyecto ?? 'SIN ASIGNAR';
    final String ordenVenta = widget.ticket.numeroOrdenVenta ?? 'N/A';
    final String? urlProforma = widget.ticket.evaluacionTecnica?.urlProformaExcel;
    final List<String> urlsGarantia = widget.ticket.evaluacionTecnica?.urlsAdjuntosPdfGarantia ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('Estación Compras: ${widget.ticket.id}'),
        backgroundColor: Colors.teal.shade800,
      ),
      body: BlocListener<TicketBloc, TicketState>(
        listener: (context, state) {
          if (state.status == TicketStatus.operationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Orden procesada. Ticket transferido a Bodega.'), backgroundColor: Colors.green),
            );
            Navigator.pop(context);
          } else if (state.status == TicketStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==========================================
              // 🔍 PANEL DE TELEMETRÍA (Solo Lectura)
              // ==========================================
              Card(
                elevation: 3,
                color: esReclamoNegado ? Colors.red.shade50 : Colors.blueGrey.shade50,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: esReclamoNegado ? Colors.red.shade300 : Colors.blueGrey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            esReclamoNegado ? Icons.warning_amber_rounded : Icons.monitor, 
                            color: esReclamoNegado ? Colors.red.shade900 : Colors.blueGrey
                          ),
                          const SizedBox(width: 8),
                          Text(
                            esReclamoNegado ? 'GARANTÍA NEGADA - FLUJO COMERCIAL' : 'Datos Base y Trazabilidad', 
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 16,
                              color: esReclamoNegado ? Colors.red.shade900 : Colors.black87,
                            )
                          ),
                        ],
                      ),
                      const Divider(),
                      
                      if (esReclamoNegado) ...[
                        const Text(
                          '⚠️ Este ticket inició por garantía pero fue rechazado por ingeniería. Se procesa con la Orden de Venta comercial original.',
                          style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 12),
                      ],

                      _buildReadoutRow('Código de Proyecto (Costos):', codigoProyecto, isHighlighted: true),
                      const SizedBox(height: 12),
                      
                      // ==========================================
                      // 🔌 LÍNEA BASE INNEGOCIABLE: LA OV COMERCIAL SIEMPRE SE MUESTRA
                      // ==========================================
                      _buildReadoutRow('Orden de Venta (Comercial):', ordenVenta),
                      const SizedBox(height: 8),
                      
                      if (widget.ticket.codigoOrdenVenta.isNotEmpty)
                        _buildPdfDownloadContainer(
                          context: context,
                          titulo: 'Orden de Venta (OV) Comercial Adjunta',
                          subtitulo: 'Requerimiento comercial base para compras.',
                          urlPDF: widget.ticket.codigoOrdenVenta!.first,
                        )
                      else
                        const Text('⚠️ No se detectó documento de Orden de Venta comercial adjunto.', style: TextStyle(color: Colors.red, fontSize: 12)),

                      // ==========================================
                      // 🔌 BLOQUE COMPLEMENTARIO: SI ES GARANTÍA APROBADA, AÑADIMOS SU RESPALDO TÉCNICO
                      // ==========================================
                      if (esGarantiaActiva) ...[
                        const Divider(height: 24),
                        Row(
                          children: [
                            Icon(Icons.policy, size: 18, color: Colors.amber.shade900),
                            const SizedBox(width: 6),
                            Text(
                              'RESPALDO DE GARANTÍA (${widget.ticket.tipoGarantia!.toUpperCase()})',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildReadoutRow(
                          widget.ticket.tipoGarantia == 'servicio' ? 'OV de Servicio Antiguo:' : 'OV de Máquina Nueva:',
                          widget.ticket.evaluacionTecnica?.numeroOVGarantia ?? 'No registrada'
                        ),
                        const SizedBox(height: 8),

                        if (urlsGarantia.isNotEmpty)
                          _buildPdfDownloadContainer(
                            context: context,
                            titulo: widget.ticket.tipoGarantia == 'servicio' ? 'Descargar OV de Servicio' : 'Descargar OV de Máquina',
                            subtitulo: 'Documento técnico de respaldo de garantía.',
                            urlPDF: urlsGarantia.first,
                            colorAcento: Colors.amber.shade900,
                          ),
                      ],

                      const SizedBox(height: 8),
                      const Divider(),
                      // Enlace a la proforma técnica
                      const Text('Matriz de Costeo (Taller):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 4),
                      if (urlProforma != null && urlProforma.isNotEmpty)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.table_view, color: Colors.green),
                          title: const Text('Descargar Proforma Técnica (Excel)', style: TextStyle(decoration: TextDecoration.underline, color: Colors.blue)),
                          trailing: const Icon(Icons.download, size: 20),
                          onTap: () => _abrirProformaExcel(urlProforma), 
                        )
                      else
                        const Text('⚠️ No se detectó archivo de costeo.', style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),

              // ==========================================
              // 🎛️ PANEL DE CONTROL (Actuadores Compras)
              // ==========================================
              const Text('Carga Documental (Orden de Compra)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Divider(),
              const SizedBox(height: 8),
              
              InkWell(
                onTap: _seleccionarArchivo,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _archivoOrdenCompra != null ? Colors.teal : Colors.grey.shade400, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _archivoOrdenCompra != null ? Icons.check_circle : Icons.upload_file,
                        size: 40,
                        color: _archivoOrdenCompra != null ? Colors.teal : Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _archivoOrdenCompra != null 
                            ? 'Archivo cargado:\n${_archivoOrdenCompra!.name}' 
                            : 'Toque aquí para adjuntar Orden de Compra (Requerido)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _archivoOrdenCompra != null ? Colors.teal.shade800 : Colors.grey.shade700,
                          fontWeight: _archivoOrdenCompra != null ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: _observacionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Observaciones de Compras (Opcional)',
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.teal.shade700, width: 2)),
                ),
              ),

              const SizedBox(height: 32),

              // ==========================================
              // 🚀 BOTÓN DE TRANSFERENCIA (A Bodega)
              // ==========================================
              BlocBuilder<TicketBloc, TicketState>(
                builder: (context, state) {
                  final bool procesando = state.status == TicketStatus.loading;
                  final bool procesadoPorCostos = widget.ticket.estadoActual == EstadoTicket.compras || 
                                                  widget.ticket.isCostosCompletado;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!procesadoPorCostos)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock, color: Colors.red),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'ACCIÓN BLOQUEADA: El departamento de Costos debe generar el código de proyecto y aprobar la proforma antes de enviar a Bodega.',
                                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),

                      ElevatedButton.icon(
                        onPressed: (procesando || !procesadoPorCostos) ? null : _ejecutarPasoABodega,
                        icon: procesando 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.move_to_inbox),
                        label: Text(
                          procesando ? 'TRANSMITIENDO...' : 'REGISTRAR ORDEN Y ENVIAR A BODEGA', 
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          disabledBackgroundColor: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
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
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade100, 
        border: Border.all(color: Colors.blueGrey.shade300),
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
          onPressed: () => _abrirDocumentoOV(context, urlPDF),
        ),
      ),
    );
  }

  Widget _buildReadoutRow(String label, String value, {bool isHighlighted = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.blueGrey))),
        Expanded(
          flex: 3, 
          child: Text(
            value, 
            style: TextStyle(
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              color: isHighlighted ? Colors.black : Colors.black87,
              fontSize: 14
            ),
          )
        ),
      ],
    );
  }
}