// lib/features/tickets/presentation/pages/formulario_recepcion_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/ticket_entity.dart';
import '../../domain/entities/ticket_enums.dart'; // ✅ AÑADIDO: Import del enum para la máquina de estados
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/evento_auditoria_entity.dart';
import '../../../../core/services/pdf_service.dart';
import 'package:printing/printing.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:typed_data';

class FormularioRecepcionPage extends StatefulWidget {
  final TicketEntity ticket;

  const FormularioRecepcionPage({super.key, required this.ticket});

  @override
  State<FormularioRecepcionPage> createState() => _FormularioRecepcionPageState();
}

class _FormularioRecepcionPageState extends State<FormularioRecepcionPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controlador ÚNICO para la inspección física activa en recepción
  final _descripcionController = TextEditingController(); 
  
  String _tipoRequerimiento = 'Mantenimiento'; 

  // Buffer local en la memoria de esta instancia
  final List<File> _archivosEvidencia = [];

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  Widget _buildCameraPlaceholder() {
    return Column(
      children: [
        InkWell(
          onTap: () => _mostrarOpcionesCaptura(context),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.teal.shade200, style: BorderStyle.solid),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.add_a_photo_outlined, color: Colors.teal),
                SizedBox(width: 12),
                Text('Añadir Foto o Video', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        if (_archivosEvidencia.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _archivosEvidencia.length,
              itemBuilder: (context, index) {
                final file = _archivosEvidencia[index];
                final esVideo = file.path.endsWith('.mp4') || file.path.endsWith('.mov');

                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 90,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      esVideo 
                        ? const Icon(Icons.video_file, color: Colors.teal, size: 40)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(file, fit: BoxFit.cover),
                          ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _archivosEvidencia.removeAt(index)),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ]
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acta de Recepción', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
body: BlocConsumer<TicketBloc, TicketState>(
listener: (context, state) async {
  debugPrint("📡 [PUNTO B]: El BLoC ha emitido un nuevo estado: $state");

  if (state is TicketError) {
    debugPrint("❌ [PUNTO B]: El BLoC devolvió un error: ${state.message}");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(state.message), backgroundColor: Colors.red)
    );
  } else if (state is TicketOperationSuccess) {
    debugPrint("🎉 [PUNTO B]: ¡ÉXITO! Estado TicketOperationSuccess recibido. Entrando al bloque del PDF.");
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recepción exitosa, generando acta...'), backgroundColor: Colors.teal)
    );

    try {
      debugPrint("⚙️ [PUNTO C]: Invocando PdfService...");
      final pdfService = PdfService();
      
      final pdfBytes = await pdfService.generateActaRecepcion(
        ticket: widget.ticket,
        tipoRequerimiento: _tipoRequerimiento,
        descripcion: _descripcionController.text,
        evidencias: _archivosEvidencia,
      );
      
      debugPrint("📄 [PUNTO C]: Bytes del PDF generados con éxito (${pdfBytes.length} bytes). Lanzando Printing.layoutPdf...");

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'Acta_Recepcion_${widget.ticket.id}.pdf',
      );
      
      debugPrint("✅ [PUNTO C]: Printing.layoutPdf ejecutado sin excepciones.");
    } catch (e, stacktrace) {
      debugPrint("💥 CRITICAL [PUNTO C]: La generación o renderizado del PDF colapsó de forma nativa: $e");
      debugPrint("$stacktrace");
    }

    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }
},
        builder: (context, state) {
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('1. Datos Heredados (Solo Lectura)'),
                  _buildReadOnlyField('Cliente / Razón Social', widget.ticket.clienteId, Icons.business),
                  _buildReadOnlyField('Contacto / Quien Entrega', widget.ticket.nombreContacto, Icons.person),
                  _buildReadOnlyField('Teléfono', widget.ticket.telefonoContacto ?? 'N/A', Icons.phone),
                  _buildReadOnlyField('Tipo de Equipo', widget.ticket.equipo.name.toUpperCase(), Icons.precision_manufacturing),
                  _buildReadOnlyField('Número de Serie', widget.ticket.numeroSerie ?? 'Serie no registrada', Icons.qr_code),
                  _buildReadOnlyField('Falla Reportada', widget.ticket.fallaReportada, Icons.report_problem, lines: 2),
                  
                  const Divider(height: 32, thickness: 2),

                  _buildSectionTitle('2. Datos de Ingreso Físico'),
                  DropdownButtonFormField<String>(
                    value: _tipoRequerimiento,
                    decoration: InputDecoration(
                      labelText: 'Tipo de Requerimiento',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.build_circle_outlined),
                    ),
                    items: ['Garantía', 'Mantenimiento'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _tipoRequerimiento = newValue!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    label: 'Descripción / Notas de Recepción',
                    controller: _descripcionController,
                    icon: Icons.description_outlined,
                    lines: 3,
                    hint: 'Ej: Equipo llega con carcasa rayada, sin cables de alimentación...',
                  ),

                  const Divider(height: 32, thickness: 2),

                  _buildSectionTitle('3. Evidencia Fotográfica'),
                  _buildCameraPlaceholder(),

                  const Divider(height: 32, thickness: 2),

                  _buildSectionTitle('4. Registro de Sistema'),
                  _buildReadOnlyField('Timestamp de Ingreso', DateTime.now().toString().substring(0, 16), Icons.access_time),

                  const SizedBox(height: 32),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: state is TicketLoading ? null : _procesarRecepcion,
                      child: state is TicketLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('CONFIRMAR RECEPCIÓN', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Subrutinas de Renderizado ---
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon, {int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        initialValue: value,
        maxLines: lines,
        readOnly: true,
        style: const TextStyle(color: Colors.black54), 
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ),
    );
  }


// ⚙️ FILTRO DE COMPRESIÓN INDUSTRIAL
  Future<File?> _comprimirImagen(File file) async {
    final filePath = file.absolute.path;
    
    // Generamos una nueva ruta temporal para el archivo comprimido
    final outPath = filePath.replaceAll(
      RegExp(r'\.(png|jpg|jpeg)$', caseSensitive: false), 
      '_comprimido.jpg'
    );

    // Ejecutamos la reducción de resolución y calidad
    final XFile? result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      outPath,
      quality: 60,        // 60% es el punto dulce entre legibilidad y peso
      minWidth: 1024,     // Limitamos a 1 Megapíxel aprox. No necesitamos 4K para un acta.
      minHeight: 1024,
      format: CompressFormat.jpeg, // Forzamos formato estándar
    );

    if (result == null) return null;

    final compressedFile = File(result.path);
    
    // Telemetría para depuración (opcional, para que veas la magia)
    debugPrint("📉 Tamaño Original: ${(file.lengthSync() / 1024).toStringAsFixed(2)} KB");
    debugPrint("📉 Tamaño Comprimido: ${(compressedFile.lengthSync() / 1024).toStringAsFixed(2)} KB");

    return compressedFile;
  }


  Widget _buildInputField({
    required String label, 
    required TextEditingController controller, 
    required IconData icon, 
    int lines = 1,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.teal),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
      ),
      validator: (value) => (value == null || value.trim().isEmpty) ? 'Dato requerido para control de calidad.' : null,
    );
  }

  // --- Lógica de Control ---
Future<void> _procesarRecepcion() async {
    // 1. Validaciones de la HMI
    if (!_formKey.currentState!.validate()) return;

    final authState = context.read<AuthBloc>().state;
    String nombreOperador = 'SISTEMA';
    String rolOperador = 'TÉCNICO';

    if (authState is Authenticated) {
      nombreOperador = authState.usuario.nombre;
      rolOperador = authState.usuario.rol.name.toUpperCase();
    }
    
    // Feedback visual para evitar doble toque
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.teal)),
    );

    try {
      // ========================================================
      // ⚙️ 2. ZONA DE FABRICACIÓN (Scope local)
      // ========================================================
      final pdfService = PdfService();
      
      // Declaramos la variable AQUÍ adentro
      final bytesGenerados = await pdfService.generateActaRecepcion(
        ticket: widget.ticket,
        tipoRequerimiento: _tipoRequerimiento,
        descripcion: _descripcionController.text,
        evidencias: _archivosEvidencia,
      );

      final ticketActualizado = TicketEntity(
        id: widget.ticket.id,
        estadoActual: EstadoTicket.recepcionFisica, 
        sede: widget.ticket.sede,
        clienteId: widget.ticket.clienteId,
        campamento: widget.ticket.campamento,
        nombreContacto: widget.ticket.nombreContacto,
        telefonoContacto: widget.ticket.telefonoContacto,
        emailContacto: widget.ticket.emailContacto,
        equipo: widget.ticket.equipo,
        fallaReportada: '${widget.ticket.fallaReportada}\n[RECEPCIÓN]: ${_descripcionController.text}',
        numeroSerie: widget.ticket.numeroSerie,
        historialEventos: widget.ticket.historialEventos, 
        fotosUrls: widget.ticket.fotosUrls, 
      );

      if (context.mounted) {
        Navigator.pop(context); // Retiramos el loading

        // ========================================================
        // 🚀 3. DISPARO AL BLoC (Dentro del mismo Scope)
        // ========================================================
        // Como seguimos dentro del 'try', bytesGenerados existe y está viva.
        context.read<TicketBloc>().add(ConfirmarRecepcionEvent(
          ticket: ticketActualizado,
          nombreUsuario: nombreOperador, 
          rolUsuario: rolOperador,
          notasRecepcion: _descripcionController.text,
          evidencias: _archivosEvidencia,
          pdfBytes: bytesGenerados, // ✅ Conexión sólida y sin fugas
        ));
      }
    } catch (e) {
      // Si el PDF falla, caemos aquí
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al empaquetar PDF: $e'), backgroundColor: Colors.red)
        );
      }
    }
  }
  
  void _mostrarOpcionesCaptura(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.teal),
              title: const Text('Tomar Foto'),
              onTap: () {
                Navigator.pop(context);
                _capturarMedio(ImageSource.camera, esVideo: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.teal),
              title: const Text('Grabar Video'),
              onTap: () {
                Navigator.pop(context);
                _capturarMedio(ImageSource.camera, esVideo: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.grey),
              title: const Text('Seleccionar de Galería'),
              onTap: () {
                Navigator.pop(context);
                _capturarMedio(ImageSource.gallery, esVideo: false);
              },
            ),
          ],
        ),
      ),
    );
  }

Future<void> _capturarMedio(ImageSource source, {required bool esVideo}) async {
    final ImagePicker picker = ImagePicker();
    XFile? archivo;

    try {
      if (esVideo) {
        archivo = await picker.pickVideo(
          source: source,
          maxDuration: const Duration(seconds: 30), 
        );
      } else {
        archivo = await picker.pickImage(
          source: source,
          // Ya no dependemos del quality del picker, pero lo dejamos como pre-filtro
          imageQuality: 85, 
        );
      }

      if (archivo != null) {
        if (esVideo) {
          // Los videos no van al PDF, pasan directo a la lista para el BLoC/Storage
          setState(() {
            _archivosEvidencia.add(File(archivo!.path));
          });
        } else {
          // ⚙️ ENRUTAMOS LA IMAGEN AL COMPRESOR ANTES DE GUARDARLA
          File originalFile = File(archivo.path);
          File? compressedFile = await _comprimirImagen(originalFile);

          if (compressedFile != null) {
            setState(() {
              _archivosEvidencia.add(compressedFile);
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error hardware cámara: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}