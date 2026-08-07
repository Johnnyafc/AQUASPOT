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
import 'package:file_picker/file_picker.dart' as fp;
import '../../../../core/enum/segmento_operativo.dart';

class GenerarCotizacionPage extends StatefulWidget {
  final TicketEntity ticket;
  const GenerarCotizacionPage({super.key, required this.ticket});

  @override
  State<GenerarCotizacionPage> createState() => _GenerarCotizacionPageState();
}

class _GenerarCotizacionPageState extends State<GenerarCotizacionPage> {
  final TextEditingController _observacionController = TextEditingController();
  final List<fp.PlatformFile> _pdfsSeleccionados = [];
  final List<fp.PlatformFile> _excelsSeleccionados = [];

  // ⚙️ SUBRUTINA: Extracción de la justificación de auditoría
  String _obtenerMotivoModificacion() {
    try {
      final eventoReversion = widget.ticket.historialEventos.lastWhere(
        (e) => e.accion.startsWith('SOLICITUD DE MODIFICACIÓN:'),
      );
      return eventoReversion.accion.replaceAll('SOLICITUD DE MODIFICACIÓN:', '').trim();
    } catch (e) {
      return 'Motivo no registrado en la traza de auditoría.';
    }
  }

  // ⚙️ SUBRUTINA DE APERTURA DE ARCHIVOS TÉCNICOS
  Future<void> _abrirEnlaceTecnico(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Circuito bloqueado por el SO.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al abrir el documento técnico.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _seleccionarPDFs() async {
    final result = await fp.FilePicker.pickFiles(
      allowMultiple: true, 
      type: fp.FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true, 
    );
    if (result != null) {
      setState(() {
        _pdfsSeleccionados.addAll(result.files);
      });
    }
  }

  Future<void> _seleccionarExcels() async {
    final result = await fp.FilePicker.pickFiles(
      allowMultiple: true, 
      type: fp.FileType.custom,
      allowedExtensions: ['xls', 'xlsx'],
      withData: true,
    );
    if (result != null) {
      setState(() {
        _excelsSeleccionados.addAll(result.files);
      });
    }
  }

  void _eliminarArchivo(List<fp.PlatformFile> lista, fp.PlatformFile archivo) {
    setState(() {
      lista.remove(archivo);
    });
  }

  void _finalizarCotizacion() {
    if (_pdfsSeleccionados.isEmpty && _excelsSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El campo documental está vacío. Adjunte al menos un archivo.'), 
          backgroundColor: Colors.red
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
      ProcesarCotizacionEvent(
        ticket: widget.ticket,
        archivosPdf: _pdfsSeleccionados, 
        archivosExcel: _excelsSeleccionados, 
        observacion: _observacionController.text.trim(),
        nombreUsuario: operador,
        rolUsuario: rol,
      ),
    );
  }

 @override
  Widget build(BuildContext context) {
    // 🧠 Sensor lógico: ¿Es un reclamo de garantía?
    final bool esGarantia = widget.ticket.tipoRequerimiento == TipoRequerimiento.reclamoGarantia;

    return Scaffold(
      appBar: AppBar(title: Text('Cotización: ${widget.ticket.id}'), backgroundColor: Colors.green),
      // 🔧 CIRCUITO LIMPIO: Un solo sensor conectado directamente al flujo principal
      body: BlocListener<TicketBloc, TicketState>(
        listener: (context, state) {
          if (state.status == TicketStatus.operationSuccess) { 
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cotización registrada exitosamente. Documentos en Storage.'), 
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              )
            );
            
            context.read<TicketBloc>().add(
              const ObtenerHistorialTicketsEvent(
                segmento: SegmentoOperativo.ninguno, 
              ),
            );
            
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          } else if (state.status == TicketStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red)
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              // ==========================================
              // 🚨 BALIZA DE ADVERTENCIA: TICKET MODIFICADO
              // ==========================================
              if (widget.ticket.fueModificado)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade800, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.red.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
                    ]
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.report_problem, color: Colors.red.shade900, size: 36),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TICKET REVERSADO PARA CORRECCIÓN', 
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900, fontSize: 16)
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Instrucción de Operaciones:',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.red.shade200)
                              ),
                              child: Text(
                                _obtenerMotivoModificacion(),
                                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.red.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // ==========================================
              // 🔍 PANEL DE DIAGNÓSTICO TÉCNICO (Solo Lectura)
              // ==========================================
              if (widget.ticket.evaluacionTecnica != null)
                Card(
                  elevation: 2,
                  color: Colors.blueGrey.shade50,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.blueGrey.shade200, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.engineering, color: Colors.blueGrey),
                            SizedBox(width: 8),
                            Text('Diagnóstico de Servicio Técnico', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
                          ],
                        ),
                        const Divider(),
                        
                        const Text('Observaciones del Taller:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            widget.ticket.evaluacionTecnica!.observacion.isNotEmpty 
                                ? widget.ticket.evaluacionTecnica!.observacion 
                                : 'Sin observaciones reportadas.',
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ==========================================
                        // 🔍 LECTURA DE EVIDENCIA
                        // ==========================================
                        const Text('Archivos Adjuntos de Evaluación:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        
                        Builder(
                          builder: (context) {
                            final evaluacion = widget.ticket.evaluacionTecnica!;
                            final bool tieneExcel = evaluacion.urlProformaExcel != null && evaluacion.urlProformaExcel!.isNotEmpty;
                            final bool tienePdfs = evaluacion.urlsAdjuntosPdf.isNotEmpty;

                            if (!tieneExcel && !tienePdfs) {
                              return const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Text('El técnico no subió documentos estructurales.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                              );
                            }

                            return Column(
                              children: [
                                if (tieneExcel)
                                  ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.table_view, color: Colors.green),
                                    title: const Text('Descargar Proforma Técnica Base', style: TextStyle(decoration: TextDecoration.underline, color: Colors.blue, fontWeight: FontWeight.bold)),
                                    trailing: const Icon(Icons.download, size: 20),
                                    onTap: () => _abrirEnlaceTecnico(evaluacion.urlProformaExcel!),
                                  ),

                                if (tienePdfs)
                                  ...evaluacion.urlsAdjuntosPdf.map((url) {
                                    return ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                                      title: const Text('Ver Evidencia Documental (PDF)', style: TextStyle(decoration: TextDecoration.underline, color: Colors.blue)),
                                      trailing: const Icon(Icons.open_in_new, size: 20),
                                      onTap: () => _abrirEnlaceTecnico(url),
                                    );
                                  }),
                              ],
                            );
                          }
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // ==========================================
              // 🚨 BALIZA DE ADVERTENCIA: FACTURACIÓN DE GARANTÍA
              // ==========================================
              if (esGarantia)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade800, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.orange.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
                    ]
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade900, size: 36),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ATENCIÓN: TICKET DE GARANTÍA', 
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontSize: 16)
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(color: Colors.black87, fontSize: 14),
                                children: [
                                  const TextSpan(text: 'La facturación de esta orden debe emitirse a: '),
                                  TextSpan(
                                    text: (widget.ticket.responsableFacturacion ?? 'NO DEFINIDO').toUpperCase(),
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // ==========================================
              // PANEL DE DOCUMENTOS MULTIPLES (Comercial)
              // ==========================================
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Carga Documental Comercial', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const Divider(),
                      
                      // 📁 SECCIÓN PDF
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Archivos PDF', style: TextStyle(fontWeight: FontWeight.w600)),
                          ElevatedButton.icon(
                            onPressed: _seleccionarPDFs, 
                            icon: const Icon(Icons.add), 
                            label: const Text('Añadir PDF')
                          ),
                        ],
                      ),
                      if (_pdfsSeleccionados.isEmpty)
                        const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('Sin PDFs cargados.', style: TextStyle(color: Colors.grey))),
                      ..._pdfsSeleccionados.map((file) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                        title: Text(file.name, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _eliminarArchivo(_pdfsSeleccionados, file),
                        ),
                      )),

                      const SizedBox(height: 16), 
                      const Divider(), 
                      
                      // 📊 SECCIÓN EXCEL
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Archivos Excel', style: TextStyle(fontWeight: FontWeight.w600)),
                          ElevatedButton.icon(
                            onPressed: _seleccionarExcels,
                            icon: const Icon(Icons.add), 
                            label: const Text('Añadir Excel')
                          ),
                        ],
                      ),
                      if (_excelsSeleccionados.isEmpty)
                        const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('Sin Excels cargados.', style: TextStyle(color: Colors.grey))),
                      ..._excelsSeleccionados.map((file) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.table_chart, color: Colors.green), 
                        title: Text(file.name, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _eliminarArchivo(_excelsSeleccionados, file),
                        ),
                      )),
                      
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // PANEL DE OBSERVACIONES
              TextField(
                controller: _observacionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Observaciones Comerciales',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.comment),
                ),
              ),
              const SizedBox(height: 30),
              
              // BOTÓN ACTUADOR
              BlocBuilder<TicketBloc, TicketState>(
                builder: (context, state) {
                  if (state.status == TicketStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ElevatedButton.icon(
                    onPressed: _finalizarCotizacion,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('FINALIZAR Y ENVIAR COTIZACIÓN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
}