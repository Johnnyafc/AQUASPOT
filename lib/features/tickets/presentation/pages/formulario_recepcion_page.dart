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
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show File;

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
  late TextEditingController _serieController;
  late TextEditingController _fallaController;
  Prioridad _prioridad = Prioridad.media;
  
  String _tipoRequerimiento = 'Mantenimiento'; 

  // Buffer local en la memoria de esta instancia
  final List<XFile> _archivosEvidencia = [];
  Map<String, bool> _accesoriosSeleccionados = {};

  @override
  void initState() {
    super.initState();
    // Pre-cargamos la data del cliente, lista para ser confirmada o editada
    _serieController = TextEditingController(text: widget.ticket.numeroSerie ?? '');
    _fallaController = TextEditingController(text: widget.ticket.fallaReportada);
    if (_catalogoAccesorios.containsKey(widget.ticket.equipo)) {
      for (var accesorio in _catalogoAccesorios[widget.ticket.equipo]!) {
        _accesoriosSeleccionados[accesorio] = false; // Asumimos que no viene hasta que se marque
      }
    }
  }

  // =======================================================
  // ⚙️ CATÁLOGO MAESTRO DE ACCESORIOS POR MÁQUINA
  // =======================================================
  final Map<TipoEquipo, List<String>> _catalogoAccesorios = {
 TipoEquipo.Caracol: [
    'Mangueras largas', 'Manguera interna', 'Serpentín', 'Chasis', 
    'Carcasa', 'Tapa posterior', 'Tapa frontal', 'Motor hidráulico', 'Impulsor'
  ],
  TipoEquipo.Cosechadora_premium: [
    'Sistema de corte', 'Banda transportadora', 'Sensor de humedad', 
    'Tolva principal', 'Panel de control', 'Sistema hidráulico'
  ],
  TipoEquipo.Cosechadora_standart: [
    'Cuchillas', 'Motor principal', 'Tolva', 'Filtros'
  ],
  TipoEquipo.Cosechadora_elevacion: [
    'Sinfín de elevación', 'Motor', 'Estructura metálica', 'Correas'
  ],
  TipoEquipo.Contador: [
    'Sensor óptico', 'Pantalla LCD', 'Fuente de poder', 'Cableado'
  ],
};

  @override
  void dispose() {
    _descripcionController.dispose();
    _serieController.dispose();
    _fallaController.dispose();
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
              children: [
                // UX: Cambiamos el icono y texto si el supervisor está en la Laptop
                Icon(kIsWeb ? Icons.upload_file : Icons.add_a_photo_outlined, color: Colors.teal),
                const SizedBox(width: 12),
                Text(
                  kIsWeb ? 'Añadir Archivo o Evidencia' : 'Añadir Foto o Video', 
                  style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                ),
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
                // Ahora sabemos que file es estrictamente un XFile
                final file = _archivosEvidencia[index]; 
                
                // 🛑 CORRECCIÓN LÓGICA: En web, el path es un Blob. Verificamos la extensión en el 'name'.
                final nombreArchivo = file.name.toLowerCase();
                final esVideo = nombreArchivo.endsWith('.mp4') || nombreArchivo.endsWith('.mov');

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
                            // 🚀 CORRECCIÓN ARQUITECTÓNICA: Renderizado seguro según el entorno
                            child: kIsWeb 
                                ? Image.network(file.path, fit: BoxFit.cover) // Web lee la Blob URL
                                : Image.file(File(file.path), fit: BoxFit.cover), // Nativo lee el Disco
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

  Widget _buildChecklistDinamico() {
    // 1. SEGURIDAD DE CATÁLOGO: Acceso seguro al mapa
    final listaAccesorios = _catalogoAccesorios[widget.ticket.equipo];
    
    // Si no hay lista para este equipo o el mapa es nulo, salimos suavemente
    if (listaAccesorios == null || listaAccesorios.isEmpty) {
      return const SizedBox.shrink();
    }

    // 2. CONSTRUCCIÓN SEGURA
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Inspección de Partes y Accesorios'),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: listaAccesorios.map((String pieza) {
              // Acceso directo a _accesoriosSeleccionados
              final isChecked = _accesoriosSeleccionados[pieza] ?? false;
              
              return CheckboxListTile(
                title: Text(pieza, style: const TextStyle(fontWeight: FontWeight.w500)),
                value: isChecked,
                activeColor: Colors.teal,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                onChanged: (bool? valor) {
                  // Aquí es donde el setState disparaba el rebuild
                  setState(() {
                    _accesoriosSeleccionados[pieza] = valor ?? false;
                  });
                },
              );
            }).toList(),
          ),
        ),
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
        listener: (context, state) {
          debugPrint("📡 [PUNTO B]: El BLoC ha emitido un nuevo estado: $state");

          if (state is TicketError) {
            debugPrint("❌ [PUNTO B]: Error recibido: ${state.message}");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red)
            );
          } else if (state is TicketOperationSuccess) {
            debugPrint("🎉 [PUNTO B]: Operación Exitosa. Redirigiendo a bandeja principal.");
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Acta registrada y respaldada en el sistema.'), 
                backgroundColor: Colors.teal
              )
            );

            if (context.mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            }
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
                  // ==========================================
                  // SECCIÓN 1: DATOS LOGÍSTICOS (Solo Lectura)
                  // ==========================================
                  _buildSectionTitle('1. Datos del Cliente'),
                  _buildReadOnlyField('Cliente / Razón Social', widget.ticket.clienteId, Icons.business),
                  _buildReadOnlyField('Contacto', widget.ticket.nombreContacto, Icons.person),
                  _buildReadOnlyField('Tipo de Equipo', widget.ticket.equipo.name.toUpperCase(), Icons.precision_manufacturing),
                  
                  const Divider(height: 32, thickness: 2),

                  // ==========================================
                  // SECCIÓN 2: CONFIRMACIÓN TÉCNICA (Editables)
                  // ==========================================
                  _buildSectionTitle('2. Confirmación de equipo'),
                  
                  _buildInputField(
                    label: 'Número de Serie Confirmado',
                    controller: _serieController,
                    icon: Icons.qr_code_scanner,
                  ),
                  _buildChecklistDinamico(),
                  const SizedBox(height: 16),
                  
                  _buildInputField(
                    label: 'Falla Reportada (Editable por técnico)',
                    controller: _fallaController,
                    icon: Icons.report_problem_outlined,
                    lines: 2,
                  ),

                  const Divider(height: 32, thickness: 2),

                  // ==========================================
                  // SECCIÓN 3: PRIORIDAD OPERATIVA
                  // ==========================================
                  _buildSectionTitle('3. Nivel de Prioridad Inicial'),
                  
                  DropdownButtonFormField<Prioridad>(
                    value: _prioridad,
                    decoration: InputDecoration(
                      labelText: 'Prioridad de Atención',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.flag_circle_outlined),
                    ),
                    items: Prioridad.values.map((Prioridad p) {
                      return DropdownMenuItem<Prioridad>(
                        value: p,
                        child: Text(
                          p.name.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (Prioridad? newValue) {
                      setState(() {
                        _prioridad = newValue!;
                      });
                    },
                  ),

                  const Divider(height: 32, thickness: 2),

                  // ==========================================
                  // SECCIÓN 4: INGRESO FÍSICO
                  // ==========================================
                  _buildSectionTitle('4. Datos de Ingreso Físico'),
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
    
    // Feedback visual (Bloqueo de HMI)
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
      
      // ✅ CORRECCIÓN CLAVE AQUÍ: Ahora enviamos `accesoriosRecibidos` al clonar
      final ticketActualizado = widget.ticket.copyWith(
        estadoActual: EstadoTicket.recepcionFisica,
        numeroSerie: _serieController.text.trim(), 
        fallaReportada: _fallaController.text.trim(), 
        accesoriosRecibidos: _accesoriosSeleccionados, // <-- El mapa actualizado pasa a la entidad
      );

      // ✅ Generamos el acta con la entidad ACTUALIZADA
      final bytesGenerados = await pdfService.generateActaRecepcion(
        ticket: ticketActualizado, 
        tipoRequerimiento: _tipoRequerimiento,
        descripcion: _descripcionController.text.trim(),
        evidencias: _archivosEvidencia,
      );

      if (context.mounted) {
        Navigator.pop(context); // Retiramos la pantalla de carga

        // ========================================================
        // 🚀 3. DISPARO AL BLoC 
        // ========================================================
        context.read<TicketBloc>().add(ConfirmarRecepcionEvent(
          ticket: ticketActualizado, // Se envía a Firestore con la serie Y los accesorios
          nombreUsuario: nombreOperador, 
          rolUsuario: rolOperador,
          notasRecepcion: _descripcionController.text.trim(),
          evidencias: _archivosEvidencia,
          pdfBytes: bytesGenerados, 
        ));

        // ========================================================
        // 🖨️ 4. LANZAMIENTO DE PERIFÉRICOS
        // ========================================================
        await Printing.layoutPdf(
          onLayout: (format) async => bytesGenerados,
          name: 'Acta_Recepcion_${ticketActualizado.id}.pdf',
        );
      }
    } catch (e, stacktrace) {
      if (context.mounted) {
        Navigator.pop(context); // Importante: quitar el loading si hay fallo crítico
        debugPrint("💥 CRITICAL: Colapso en renderizado o ensamblaje: $e\n$stacktrace");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falla de sistema en generación PDF: $e'), backgroundColor: Colors.red)
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
          // En Web el imageQuality suele fallar o ser ignorado, lo condicionamos
          imageQuality: kIsWeb ? null : 85, 
        );
      }

      if (archivo != null) {
        if (esVideo) {
          // 📹 VIDEOS: Pasan directo a la lista como XFile (sin compresión local)
          setState(() {
            _archivosEvidencia.add(archivo!);
          });
        } else {
          // 📸 IMÁGENES: Bifurcación de Arquitectura (Web vs Nativo)
          
          if (kIsWeb) {
            // 🌐 ENTORNO WEB: El archivo ya está en RAM. 
            // NO usamos dart:io File ni el compresor nativo.
            setState(() {
              _archivosEvidencia.add(archivo!);
            });
          } else {
            // 📱 ENTORNO NATIVO (Android/iOS): Usamos dart:io y comprimimos
            File originalFile = File(archivo!.path);
            File? compressedFile = await _comprimirImagen(originalFile);

            if (compressedFile != null) {
              setState(() {
                // Lo empaquetamos de nuevo como XFile para mantener la consistencia en la lista
                _archivosEvidencia.add(XFile(compressedFile.path));
              });
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error en captura de medio: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}