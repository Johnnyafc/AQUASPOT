// lib/features/tickets/presentation/pages/formulario_recepcion_page.dart

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

    // Extraemos al operario (Esto sí es válido en UI porque el AuthBloc provee el contexto de sesión)
    final authState = context.read<AuthBloc>().state;
    String nombreOperador = 'SISTEMA';
    String rolOperador = 'TÉCNICO';

    if (authState is Authenticated) {
      nombreOperador = authState.usuario.nombre;
      rolOperador = authState.usuario.rol.name.toUpperCase();
    }

    // 🚀 La UI dispara señales crudas. Cero lógica de negocio aquí.
    context.read<TicketBloc>().add(
      ConfirmarRecepcionEvent(
        ticket: widget.ticket, // Mandamos el ticket base intacto
        numeroSerie: _serieController.text.trim(),
        fallaReportada: _fallaController.text.trim(),
        accesoriosRecibidos: _accesoriosSeleccionados,
        tipoRequerimiento: _tipoRequerimiento,
        prioridad: _prioridad,
        notasRecepcion: _descripcionController.text.trim(),
        evidencias: _archivosEvidencia,
        nombreUsuario: nombreOperador,
        rolUsuario: rolOperador,
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
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status == TicketStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          } else if (state.status == TicketStatus.operationSuccess) { 
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Acta registrada en la nube.'), backgroundColor: Colors.teal));
            
            if (state.pdfBytes != null && state.pdfBytes!.isNotEmpty) {
                Printing.layoutPdf(
                  onLayout: (format) async => state.pdfBytes!,
                  name: 'Acta_Recepcion_${widget.ticket.id}.pdf',
                );
            }
            if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          }
        },
        builder: (context, state) {
          final isProcessing = state.status == TicketStatus.loading;

          return Form(
            key: _formKey,
            child: AbsorbPointer(
              absorbing: isProcessing, // ⚙️ Enclavamiento de seguridad
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ⚙️ MÓDULO 1: LOGÍSTICA
                    const SectionTitleWidget(title: '1. Datos del Cliente'),
                    ReadOnlyFieldWidget(label: 'Cliente', value: widget.ticket.clienteId, icon: Icons.business),
                    ReadOnlyFieldWidget(label: 'Contacto', value: widget.ticket.nombreContacto, icon: Icons.person),
                    ReadOnlyFieldWidget(label: 'Tipo de Equipo', value: widget.ticket.equipo.name.toUpperCase(), icon: Icons.precision_manufacturing),
                    const Divider(height: 32, thickness: 2),

                    // ⚙️ MÓDULO 2: INSPECCIÓN
                    const SectionTitleWidget(title: '2. Confirmación de equipo'),
                    CustomInputFieldWidget(label: 'Número de Serie Confirmado', controller: _serieController, icon: Icons.qr_code_scanner),
                    ChecklistDinamicoWidget(
                      equipo: widget.ticket.equipo,
                      selecciones: _accesoriosSeleccionados,
                      onChanged: (pieza, valor) => setState(() => _accesoriosSeleccionados[pieza] = valor),
                    ),
                    const SizedBox(height: 16),
                    CustomInputFieldWidget(label: 'Falla Reportada', controller: _fallaController, icon: Icons.report_problem_outlined, lines: 2),
                    const Divider(height: 32, thickness: 2),

                    // ⚙️ MÓDULO 3: PARAMETRIZACIÓN (Prioridad y Tipo)
                    const SectionTitleWidget(title: '3. Parámetros Operativos'),
                    DropdownButtonFormField<Prioridad>(
                      value: _prioridad,
                      decoration: const InputDecoration(labelText: 'Prioridad', border: OutlineInputBorder(), prefixIcon: Icon(Icons.flag_circle_outlined)),
                      items: Prioridad.values.map((p) => DropdownMenuItem(value: p, child: Text(p.name.toUpperCase()))).toList(),
                      onChanged: (val) => setState(() => _prioridad = val!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _tipoRequerimiento,
                      decoration: const InputDecoration(labelText: 'Tipo de Requerimiento', border: OutlineInputBorder(), prefixIcon: Icon(Icons.build_circle_outlined)),
                      items: ['Garantía', 'Mantenimiento'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: (val) => setState(() => _tipoRequerimiento = val!),
                    ),
                    const SizedBox(height: 16),
                    CustomInputFieldWidget(
                      label: 'Notas de Recepción', 
                      controller: _descripcionController, 
                      icon: Icons.description_outlined, 
                      lines: 3, 
                      hint: 'Ej: Equipo llega con carcasa rayada...'
                    ),
                    const Divider(height: 32, thickness: 2),

                    // ⚙️ MÓDULO 4: TELEMETRÍA VISUAL
                    const SectionTitleWidget(title: '4. Evidencia Fotográfica'),
                    CameraManagerWidget(
                      archivosEvidencia: _archivosEvidencia,
                      onArchivosActualizados: (archivos) => setState(() {
                        _archivosEvidencia.clear();
                        _archivosEvidencia.addAll(archivos);
                      }),
                    ),
                    const Divider(height: 32, thickness: 2),

                    // ⚙️ ACTUADOR FINAL
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        onPressed: isProcessing ? null : _onConfirmarRecepcion,
                        child: isProcessing 
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                SizedBox(width: 12),
                                Text('TRANSMITIENDO DATOS...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                              ],
                            )
                          : const Text('CONFIRMAR RECEPCIÓN', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}