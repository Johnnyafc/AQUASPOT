import 'package:aquaspot_postventa/features/tickets/domain/constant/catalogo_equipos_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';

import '../../domain/entities/ticket_entity.dart';
import '../../domain/entities/ticket_enums.dart';


// BLoC (El cerebro de la operación)
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';

// Widgets de UI (Los módulos de interfaz)
import '../widgets/section_title_widget.dart';
import '../widgets/read_only_field_widget.dart';
import '../widgets/custom_input_field_widget.dart';
import '../widgets/checklist_dinamico_widget.dart';
import '../widgets/camera_manager_widget.dart';

class FormularioRecepcionPage extends StatefulWidget {
  final TicketEntity ticket;

  const FormularioRecepcionPage({super.key, required this.ticket});

  @override
  State<FormularioRecepcionPage> createState() => _FormularioRecepcionPageState();
}

class _FormularioRecepcionPageState extends State<FormularioRecepcionPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores de UI (Memoria volátil de la vista)
  final _descripcionController = TextEditingController(); 
  late TextEditingController _serieController;
  late TextEditingController _fallaController;
  
  Prioridad _prioridad = Prioridad.media;
  String _tipoRequerimiento = 'Mantenimiento'; 
  final List<XFile> _archivosEvidencia = [];
  final Map<String, bool> _accesoriosSeleccionados = {};

  @override
  void initState() {
    super.initState();
    // Pre-carga de datos
    _serieController = TextEditingController(text: widget.ticket.numeroSerie ?? '');
    _fallaController = TextEditingController(text: widget.ticket.fallaReportada);
    _inicializarAccesorios();
  }

  void _inicializarAccesorios() {
    // Consulta al dominio, no a una variable hardcodeada en la vista
    final accesorios = CatalogoEquiposConstants.accesoriosPorMaquina[widget.ticket.equipo];
    if (accesorios != null) {
      for (var accesorio in accesorios) {
        _accesoriosSeleccionados[accesorio] = false;
      }
    }
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _serieController.dispose();
    _fallaController.dispose();
    super.dispose();
  }

  // Rutina de disparo
  void _onConfirmarRecepcion() {
    if (!_formKey.currentState!.validate()) return;

    // Obtenemos al operario actual del AuthBloc
    final authState = context.read<AuthBloc>().state;
    String nombreOperador = 'SISTEMA';
    String rolOperador = 'TÉCNICO';

    if (authState is Authenticated) {
      nombreOperador = authState.usuario.nombre;
      rolOperador = authState.usuario.rol.name.toUpperCase();
    }

    final ticketActualizado = widget.ticket.copyWith(
      estadoActual: EstadoTicket.recepcionFisica,
      numeroSerie: _serieController.text.trim(), 
      fallaReportada: _fallaController.text.trim(), 
      accesoriosRecibidos: _accesoriosSeleccionados, 
    );

    // 🚀 La UI SOLO despacha el evento. El BLoC se encarga del Firestore y del PDF.
    context.read<TicketBloc>().add(
      ConfirmarRecepcionEvent(
        ticket: ticketActualizado,
        nombreUsuario: nombreOperador,
        rolUsuario: rolOperador,
        tipoRequerimiento: _tipoRequerimiento, // Asegúrate de añadir esto en tu evento
        notasRecepcion: _descripcionController.text.trim(),
        evidencias: _archivosEvidencia,
      )
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
          debugPrint("📡 [MONITOR]: Estado BLoC recibido -> $state");

          if (state is TicketError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red)
            );
          } else if (state is TicketOperationSuccess) { 
            // ⚠️ NOTA ARQUITECTÓNICA: Si cambiaste este estado a TicketRecepcionExitosa(pdfBytes) 
            // como te sugerí, ajusta este 'if' y usa state.pdfBytes en el layoutPdf.
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Acta registrada y respaldada en la nube.'), 
                backgroundColor: Colors.teal
              )
            );
            
            // Si tu BLoC actual te devuelve los bytes del PDF en un estado modificado, 
            // imprimes aquí. Si lo sigues manejando de otra forma, comentalo.
            if (state is TicketRecepcionExitosa) {
                Printing.layoutPdf(
                  onLayout: (format) async => state.pdfBytes,
                  name: 'Acta_Recepcion_${widget.ticket.id}.pdf',
                );
            }

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
                  // BLOQUE 1: DATOS LOGÍSTICOS
                  // ==========================================
                  const SectionTitleWidget(title: '1. Datos del Cliente'),
                  ReadOnlyFieldWidget(
                    label: 'Cliente / Razón Social', 
                    value: widget.ticket.clienteId, 
                    icon: Icons.business
                  ),
                  ReadOnlyFieldWidget(
                    label: 'Contacto', 
                    value: widget.ticket.nombreContacto, 
                    icon: Icons.person
                  ),
                  ReadOnlyFieldWidget(
                    label: 'Tipo de Equipo', 
                    value: widget.ticket.equipo.name.toUpperCase(), 
                    icon: Icons.precision_manufacturing
                  ),
                  
                  const Divider(height: 32, thickness: 2),

                  // ==========================================
                  // BLOQUE 2: CONFIRMACIÓN TÉCNICA
                  // ==========================================
                  const SectionTitleWidget(title: '2. Confirmación de equipo'),
                  CustomInputFieldWidget(
                    label: 'Número de Serie Confirmado',
                    controller: _serieController,
                    icon: Icons.qr_code_scanner,
                  ),
                  
                  ChecklistDinamicoWidget(
                    equipo: widget.ticket.equipo,
                    selecciones: _accesoriosSeleccionados,
                    onChanged: (pieza, valor) {
                      setState(() {
                        _accesoriosSeleccionados[pieza] = valor;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  CustomInputFieldWidget(
                    label: 'Falla Reportada (Editable por técnico)',
                    controller: _fallaController,
                    icon: Icons.report_problem_outlined,
                    lines: 2,
                  ),

                  const Divider(height: 32, thickness: 2),

                  // ==========================================
                  // BLOQUE 3: PRIORIDAD OPERATIVA
                  // ==========================================
                  const SectionTitleWidget(title: '3. Nivel de Prioridad Inicial'),
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
                  // BLOQUE 4: INGRESO FÍSICO
                  // ==========================================
                  const SectionTitleWidget(title: '4. Datos de Ingreso Físico'),
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
                  CustomInputFieldWidget(
                    label: 'Descripción / Notas de Recepción',
                    controller: _descripcionController,
                    icon: Icons.description_outlined,
                    lines: 3,
                    hint: 'Ej: Equipo llega con carcasa rayada, sin cables de alimentación...',
                  ),

                  const Divider(height: 32, thickness: 2),

                  // ==========================================
                  // BLOQUE 5: PERIFÉRICOS DE CÁMARA
                  // ==========================================
                  const SectionTitleWidget(title: '5. Evidencia Fotográfica'),
                  CameraManagerWidget(
                    archivosEvidencia: _archivosEvidencia,
                    onArchivosActualizados: (archivos) {
                      setState(() {
                        _archivosEvidencia.clear();
                        _archivosEvidencia.addAll(archivos);
                      });
                    },
                  ),

                  const Divider(height: 32, thickness: 2),

                  const SectionTitleWidget(title: '6. Registro de Sistema'),
                  ReadOnlyFieldWidget(
                    label: 'Timestamp de Ingreso HMI', 
                    value: DateTime.now().toString().substring(0, 16), 
                    icon: Icons.access_time
                  ),

                  const SizedBox(height: 32),
                  
                  // Botón de Enclavamiento (Submit)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: state is TicketLoading ? null : _onConfirmarRecepcion,
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
}