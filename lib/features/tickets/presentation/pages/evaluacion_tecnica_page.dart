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
  // ⚙️ Memoria volátil separada rigurosamente (Arquitectura Determinista)
  fp.PlatformFile? _proformaExcel;
  final List<fp.PlatformFile> _adjuntosPdf = [];
  final TextEditingController _observacionController = TextEditingController();

  @override
  void dispose() {
    // 🧹 Mantenimiento preventivo: liberar memoria
    _observacionController.dispose();
    super.dispose();
  }

  // 🛡️ ENCLAVAMIENTO DE SEGURIDAD (Safety Interlock)
  // Evalúa en tiempo real si hay carga útil para justificar el encendido del motor de red
  bool _isFormularioValido(bool isProcesando) {
    bool tieneTexto = _observacionController.text.trim().isNotEmpty;
    bool tieneExcel = _proformaExcel != null;
    bool tienePdfs = _adjuntosPdf.isNotEmpty;
    
    return (tieneTexto || tieneExcel || tienePdfs) && !isProcesando;
  }

  // VÁLVULA A: Ingreso estricto de Proforma Excel (Máximo 1 archivo)
  Future<void> _seleccionarExcelCosteo() async {
    fp.FilePickerResult? result = await fp.FilePicker.pickFiles(
      allowMultiple: false, 
      type: fp.FileType.custom, 
      allowedExtensions: ['xls', 'xlsx'],
      withData: true, 
    );

    if (result != null) {
      setState(() {
        _proformaExcel = result.files.first; // Sobrescribe si el operador se equivoca y elige otro
      });
    }
  }

  // VÁLVULA B: Ingreso de Evidencia PDF (Múltiples permitidos)
  Future<void> _seleccionarAdjuntosPdf() async {
    fp.FilePickerResult? result = await fp.FilePicker.pickFiles(
      allowMultiple: true, 
      type: fp.FileType.custom, 
      allowedExtensions: ['pdf'],
      withData: true, 
    );

    if (result != null) {
      setState(() {
        _adjuntosPdf.addAll(result.files);
      });
    }
  }

  void _enviarReporte() {
    // El botón ya previene esto, pero mantenemos una barrera lógica por redundancia
    if (_proformaExcel == null && _adjuntosPdf.isEmpty && _observacionController.text.trim().isEmpty) {
      return; 
    }

    // 1. LECTURA DE LA SESIÓN ACTIVA (Lectura de credenciales)
    final authState = context.read<AuthBloc>().state;
    String operador = 'DESCONOCIDO';
    String rol = 'SIN_ROL';

    if (authState is Authenticated) {
      operador = authState.usuario.nombre;
      rol = authState.usuario.rol.name.toUpperCase();
    }

    // 2. 🚀 DISPARO AL BLoC CON PAYLOAD ESTRUCTURADO
    // ⚠️ ATENCIÓN: Debe actualizar la clase ProcesarEvaluacionDocumentalEvent en su BLoC
    // para que reciba 'proformaExcel' y 'documentosPdf' en lugar del viejo arreglo genérico.
    context.read<TicketBloc>().add(
      ProcesarEvaluacionDocumentalEvent(
        ticket: widget.ticket,
        proformaExcel: _proformaExcel,     // Enlace directo al archivo tabular
        documentosPdf: _adjuntosPdf,       // Arreglo de evidencias
        observacion: _observacionController.text.trim(),
        nombreUsuario: operador, 
        rolUsuario: rol, 
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Evaluación: ${widget.ticket.id}")),
      
      // ⚙️ SENSOR DE ESTADOS + RENDERIZADOR
      body: BlocConsumer<TicketBloc, TicketState>(
        listener: (context, state) {
          if (state.status == TicketStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red)
            );
          } 
          else if (state.status == TicketStatus.operationSuccess) {
            // Limpieza de memoria RAM local
            _proformaExcel = null;
            _adjuntosPdf.clear();
            _observacionController.clear();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reporte técnico enviado con éxito.'), backgroundColor: Colors.green)
            );
            Navigator.pop(context);
          }
        },
        builder: (context, state) {
          final bool isProcesando = state.status == TicketStatus.loading;
          final bool formValido = _isFormularioValido(isProcesando);

          return Padding(
            padding: const EdgeInsets.all(24.0),
            // Cambiamos a SingleChildScrollView para evitar desbordamientos si el operador adjunta muchos PDFs
            child: SingleChildScrollView( 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Documentación Técnica", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  
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
                  // 📂 BLOQUE B: EVIDENCIA PDF
                  // ==========================================
                  const Text("Evidencia Documental", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                    label: const Text("ADJUNTAR PDFs"),
                    onPressed: isProcesando ? null : _seleccionarAdjuntosPdf,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  ),
                  if (_adjuntosPdf.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    // Usamos shrinkWrap para que el ListView conviva dentro del SingleChildScrollView sin romper la HMI
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
                    // Disparamos setState en el onChange para que el enclavamiento del botón se actualice en tiempo real
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
                  // ⚡ ACTUADOR FINAL (Con Enclavamiento)
                  // ==========================================
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF005A9C),
                        disabledBackgroundColor: Colors.grey.shade400, // Framework maneja estado inactivo
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
