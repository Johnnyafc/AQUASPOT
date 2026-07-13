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
  // ⚙️ Memoria volátil para archivos y texto
  final List<fp.PlatformFile> _archivosSeleccionados = [];
  final TextEditingController _observacionController = TextEditingController(); // 🔌 Nuevo sensor

  @override
  void dispose() {
    // 🧹 Mantenimiento preventivo: liberar memoria
    _observacionController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarDocumentos() async {
  fp.FilePickerResult? result = await fp.FilePicker.pickFiles(
    allowMultiple: true,
    type: fp.FileType.custom, 
    allowedExtensions: ['pdf', 'xls', 'xlsx'],
    withData: true, // 🔌 CRÍTICO PARA WEB: Obliga al sensor a leer los bytes en RAM
  );

  if (result != null) {
    setState(() {
      // ✅ Extraemos directamente los objetos PlatformFile, sin importar la ruta
      _archivosSeleccionados.addAll(result.files);
    });
  }
}

  void _enviarReporte() {
    if (_archivosSeleccionados.isEmpty && _observacionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe adjuntar un documento o ingresar una observación.'), backgroundColor: Colors.orange)
      );
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

    // 2. 🚀 DISPARO EN CRUDO AL BLoC CON METADATA COMPLETA
    context.read<TicketBloc>().add(
      ProcesarEvaluacionDocumentalEvent(
        ticket: widget.ticket,
        documentos: _archivosSeleccionados,
        observacion: _observacionController.text.trim(),
        nombreUsuario: operador, // 📡 Transmisión del badge
        rolUsuario: rol,         // 📡 Transmisión del nivel de acceso
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Evaluación: ${widget.ticket.id}")),
      
      // ⚙️ INSTALAMOS EL BLOC CONSUMER (Sensor de estados + Renderizador)
      body: BlocConsumer<TicketBloc, TicketState>(
        listener: (context, state) {
          // 🚨 ALARMA DE FALLO
          if (state.status == TicketStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red)
            );
          } 
          // ✅ CONFIRMACIÓN DE CICLO COMPLETADO
          else if (state.status == TicketStatus.operationSuccess) {
            // 1. Limpieza de memoria RAM local (HMI)
            _archivosSeleccionados.clear();
            _observacionController.clear();

            // 2. Notificación visual
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reporte técnico enviado con éxito.'), backgroundColor: Colors.green)
            );

            // 3. Regreso a la bandeja base (Destruye esta pantalla)
            Navigator.pop(context);
          }
        },
        builder: (context, state) {
          // 🔒 ENCLAVAMIENTO DE SEGURIDAD: Bloquear HMI si el motor está trabajando
          final bool isProcesando = state.status == TicketStatus.loading;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Adjuntar Documentación Técnica", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("Formatos admitidos: PDF, Excel (.xls, .xlsx)", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                
                // ⚡ ACTUADOR DE ADQUISICIÓN DE ARCHIVOS
                OutlinedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text("SELECCIONAR ARCHIVOS"),
                  onPressed: isProcesando ? null : _seleccionarDocumentos, // Se bloquea si está cargando
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                ),
                
                const SizedBox(height: 16),
                
                // 📊 VISOR DE TELEMETRÍA (Archivos en cola)
                Expanded(
                  child: ListView.builder(
                    itemCount: _archivosSeleccionados.length,
                    itemBuilder: (context, index) {
                      final file = _archivosSeleccionados[index];
                      final fileName = file.name; 
                      return Card(
                        child: ListTile(
                          leading: Icon(fileName.endsWith('.pdf') ? Icons.picture_as_pdf : Icons.table_chart, color: Colors.blueGrey),
                          title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: isProcesando ? null : () => setState(() => _archivosSeleccionados.removeAt(index)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 📝 SENSOR DE OBSERVACIÓN (Campo de texto)
                TextField(
                  controller: _observacionController,
                  maxLines: 4,
                  enabled: !isProcesando, // Se bloquea si está cargando
                  decoration: const InputDecoration(
                    labelText: 'Observación Técnica (Opcional)',
                    hintText: 'Ingrese detalles adicionales, estado de las piezas, etc.',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.engineering),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // ⚡ ACTUADOR FINAL
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isProcesando ? Colors.grey : const Color(0xFF005A9C)
                    ),
                    onPressed: isProcesando ? null : _enviarReporte,
                    child: isProcesando 
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                              SizedBox(width: 12),
                              Text("TRANSMITIENDO...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          )
                        : const Text("ENVIAR REPORTE TÉCNICO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}