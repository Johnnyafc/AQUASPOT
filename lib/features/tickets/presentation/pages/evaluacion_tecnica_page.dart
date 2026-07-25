import 'dart:io';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart' as fp;
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../../domain/entities/ticket_entity.dart';

class EvaluacionTecnicaPage extends StatefulWidget {
  final TicketEntity ticket;
  const EvaluacionTecnicaPage({super.key, required this.ticket});

  @override
  State<EvaluacionTecnicaPage> createState() => _EvaluacionTecnicaPageState();
}

class _EvaluacionTecnicaPageState extends State<EvaluacionTecnicaPage> {
  // ⚙️ Memoria volátil base
  fp.PlatformFile? _proformaExcel;
  final List<fp.PlatformFile> _adjuntosPdf = [];
  final TextEditingController _observacionController = TextEditingController();

  // ⚙️ Memoria volátil EXTENDIDA (Módulo de Garantías) - AHORA SOLO UN ARCHIVO
  fp.PlatformFile? _documentoOVGarantia;

  // 🧠 Sensores Lógicos de Estado
  bool get _esGarantiaServicio => widget.ticket.tipoGarantia == 'servicio';
  bool get _esGarantiaMaquina => widget.ticket.tipoGarantia == 'maquinaNueva';
  bool get _requiereCamposGarantia => _esGarantiaServicio || _esGarantiaMaquina;

  @override
  void dispose() {
    _observacionController.dispose();
    super.dispose();
  }

  // 🛡️ ENCLAVAMIENTO DE SEGURIDAD RECALIBRADO
  bool _isFormularioValido(bool isProcesando) {
    if (isProcesando) return false;

    bool baseValida = _observacionController.text.trim().isNotEmpty || 
                      _proformaExcel != null || 
                      _adjuntosPdf.isNotEmpty;

    // Si es garantía, el circuito exige estrictamente el documento de la OV
    if (_requiereCamposGarantia) {
      if (_documentoOVGarantia == null) return false;
    }

    return baseValida;
  }

  // VÁLVULA A: Ingreso estricto de Proforma Excel
  Future<void> _seleccionarExcelCosteo() async {
    fp.FilePickerResult? result = await fp.FilePicker.pickFiles(
      allowMultiple: false, 
      type: fp.FileType.custom, 
      allowedExtensions: ['xls', 'xlsx'],
      withData: true, 
    );
    if (result != null) setState(() => _proformaExcel = result.files.first);
  }

  // VÁLVULA B: Ingreso de Evidencia PDF General
  Future<void> _seleccionarAdjuntosPdf() async {
    fp.FilePickerResult? result = await fp.FilePicker.pickFiles(
      allowMultiple: true, 
      type: fp.FileType.custom, 
      allowedExtensions: ['pdf'],
      withData: true, 
    );
    if (result != null) setState(() => _adjuntosPdf.addAll(result.files));
  }

  // VÁLVULA C: Ingreso ÚNICO de Documento OV de Garantía
  Future<void> _seleccionarDocumentoOV() async {
    fp.FilePickerResult? result = await fp.FilePicker.pickFiles(
      allowMultiple: false, // RESTRICCIÓN: Solo 1 documento permitido
      type: fp.FileType.custom, 
      allowedExtensions: ['pdf'],
      withData: true, 
    );
    if (result != null) setState(() => _documentoOVGarantia = result.files.first);
  }

  void _enviarReporte() {
    if (!_isFormularioValido(false)) return; 

    final authState = context.read<AuthBloc>().state;
    String operador = 'DESCONOCIDO';
    String rol = 'SIN_ROL';

    if (authState is Authenticated) {
      operador = authState.usuario.nombre;
      rol = authState.usuario.rol.name.toUpperCase();
    }

    // 🔬 EXTRACCIÓN DEL NÚMERO DE OV (Lógica de Parseo)
    String? numeroOVExtraido;
    if (_requiereCamposGarantia && _documentoOVGarantia != null) {
      // Tomamos el nombre del archivo y le quitamos la extensión ".pdf"
      // Ejemplo: "OV-98745.pdf" se convierte en "OV-98745"
      numeroOVExtraido = _documentoOVGarantia!.name.split('.').first;
    }

    // 🚀 DISPARO AL BLoC CON PAYLOAD EXTENDIDO
    context.read<TicketBloc>().add(
      ProcesarEvaluacionDocumentalEvent(
        ticket: widget.ticket,
        proformaExcel: _proformaExcel,
        documentosPdf: _adjuntosPdf,
        observacion: _observacionController.text.trim(),
        nombreUsuario: operador, 
        rolUsuario: rol, 
        // Inyectamos el valor extraído y el archivo único empaquetado en una lista
        // (por si su evento actual espera un List<PlatformFile>)
        numeroOVGarantia: numeroOVExtraido,
        documentosPdfGarantia: _documentoOVGarantia != null ? [_documentoOVGarantia!] : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Evaluación: ${widget.ticket.id}")),
      body: BlocConsumer<TicketBloc, TicketState>(
        listener: (context, state) {
          if (state.status == TicketStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          } else if (state.status == TicketStatus.operationSuccess) {
            _proformaExcel = null;
            _adjuntosPdf.clear();
            _documentoOVGarantia = null; // Limpieza
            _observacionController.clear();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporte técnico enviado con éxito.'), backgroundColor: Colors.green));
            Navigator.pop(context);
          }
        },
        builder: (context, state) {
          final bool isProcesando = state.status == TicketStatus.loading;
          final bool formValido = _isFormularioValido(isProcesando);

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView( 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Documentación Técnica", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  
                  // ==========================================
                  // 📂 MÓDULO DINÁMICO DE GARANTÍAS (OV ÚNICA)
                  // ==========================================
                  if (_requiereCamposGarantia) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.orange.shade700, width: 2),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.orange.shade50,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
                              const SizedBox(width: 8),
                              const Text("REQUISITOS DE GARANTÍA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 8),
                          
                          // Título dinámico basado en el tipo de garantía
                          Text(
                            _esGarantiaServicio 
                                ? "Adjunte documento de OV (Servicio Antiguo)" 
                                : "Adjunte documento de OV (Máquina Nueva)", 
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)
                          ),
                          const SizedBox(height: 8),
                          
                          OutlinedButton.icon(
                            icon: const Icon(Icons.receipt_long, color: Colors.orange),
                            label: const Text("SELECCIONAR PDF DE ORDEN DE VENTA"),
                            onPressed: isProcesando ? null : _seleccionarDocumentoOV,
                            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.white),
                          ),
                          
                          // Renderizado del archivo único seleccionado
                          if (_documentoOVGarantia != null) ...[
                            const SizedBox(height: 8),
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.picture_as_pdf, color: Colors.orange),
                                title: Text(_documentoOVGarantia!.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: isProcesando ? null : () => setState(() => _documentoOVGarantia = null),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ==========================================
                  // 📂 BLOQUE A: PROFORMA EXCEL
                  // ==========================================
                  const Text("Proforma de Costos", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.table_view, color: Colors.green),
                    label: const Text("ADJUNTAR EXCEL (.xls, .xlsx)"),
                    onPressed: isProcesando ? null : _seleccionarExcelCosteo,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  ),
                  if (_proformaExcel != null) ...[
                    const SizedBox(height: 8),
                    Card(
                      color: Colors.green.shade50,
                      child: ListTile(
                        leading: const Icon(Icons.check_circle, color: Colors.green),
                        title: Text(_proformaExcel!.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: isProcesando ? null : () => setState(() => _proformaExcel = null),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ==========================================
                  // 📂 BLOQUE B: EVIDENCIA PDF REGULAR
                  // ==========================================
                  const Text("Evidencia Documental (General)", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                    label: const Text("ADJUNTAR PDFs"),
                    onPressed: isProcesando ? null : _seleccionarAdjuntosPdf,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  ),
                  if (_adjuntosPdf.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _adjuntosPdf.length,
                      itemBuilder: (context, index) {
                        final file = _adjuntosPdf[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.picture_as_pdf, color: Colors.blueGrey),
                            title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: isProcesando ? null : () => setState(() => _adjuntosPdf.removeAt(index)),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ==========================================
                  // 📝 SENSOR DE OBSERVACIÓN 
                  // ==========================================
                  TextField(
                    controller: _observacionController,
                    maxLines: 4,
                    enabled: !isProcesando, 
                    onChanged: (_) => setState(() {}), 
                    decoration: const InputDecoration(
                      labelText: 'Observación Técnica (Opcional)',
                      hintText: 'Ingrese detalles adicionales, estado de las piezas, etc.',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.engineering),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // ==========================================
                  // ⚡ ACTUADOR FINAL
                  // ==========================================
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF005A9C),
                        disabledBackgroundColor: Colors.grey.shade400,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                      ),
                      onPressed: formValido ? _enviarReporte : null,
                      child: isProcesando 
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                                SizedBox(width: 12),
                                Text("TRANSMITIENDO...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                              ],
                            )
                          : const Text("ENVIAR REPORTE TÉCNICO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

