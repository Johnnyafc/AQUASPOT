// lib/features/tickets/presentation/pages/formulario_recepcion_page.dart

import 'package:aquaspot_postventa/features/tickets/domain/constant/catalogo_equipos_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';

import '../../domain/entities/ticket_entity.dart';
import '../../../../core/enum/ticket_enums.dart';

// BLoC 
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';

// Widgets de UI 
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
  
  // Controladores de UI (Memoria volátil para campos editables)
  late TextEditingController _descripcionController; 
  late TextEditingController _serieController;
  
  Prioridad _prioridad = Prioridad.media;
  final List<XFile> _archivosEvidenciaNuevos = [];
  final Map<String, bool> _accesoriosSeleccionados = {};

  @override
  void initState() {
    super.initState();
    // ⚙️ PRECARGA DE DATOS: Inyectamos el estado previo del ticket
    _serieController = TextEditingController(text: widget.ticket.numeroSerie ?? '');
    _descripcionController = TextEditingController(text: widget.ticket.notasRecepcion ?? '');
    _inicializarAccesorios();
  }

  void _inicializarAccesorios() {
    // 1. Buscamos el catálogo ideal de la máquina
    final accesoriosCatalogo = CatalogoEquiposConstants.accesoriosPorMaquina[widget.ticket.equipo];
    // 2. Traemos la memoria de lo que se guardó en la creación (si lo hay)
    final accesoriosPrevios = widget.ticket.accesoriosRecibidos ?? {};

    if (accesoriosCatalogo != null) {
      for (var accesorio in accesoriosCatalogo) {
        // Si el ticket ya traía el accesorio marcado, lo respetamos. Si no, false.
        _accesoriosSeleccionados[accesorio] = accesoriosPrevios[accesorio] ?? false;
      }
    } else {
      // Si por alguna razón es "Otros" y no hay catálogo, volcamos la memoria pura
      _accesoriosSeleccionados.addAll(accesoriosPrevios);
    }
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _serieController.dispose();
    super.dispose();
  }

 void _onConfirmarRecepcion() {
    if (!_formKey.currentState!.validate()) return;

    final authState = context.read<AuthBloc>().state;
    String nombreOperador = 'SISTEMA';
    String rolOperador = 'TÉCNICO';

    if (authState is Authenticated) {
      nombreOperador = authState.usuario.nombre;
      rolOperador = authState.usuario.rol.name.toUpperCase();
    }

    // 🚀 DISPARO: El tipo de requerimiento ya no se altera, usamos el original
    context.read<TicketBloc>().add(
      ConfirmarRecepcionEvent(
        ticket: widget.ticket, 
        numeroSerie: _serieController.text.trim(),
        fallaReportada: widget.ticket.fallaReportada, // Inmutable
        accesoriosRecibidos: _accesoriosSeleccionados,
        tipoRequerimiento: widget.ticket.tipoRequerimiento.name, // Inmutable
        prioridad: _prioridad,
        
        // 🚨 CABLE REPARADO: Leemos el HMI (el controlador), NO el ticket viejo
        notasRecepcion: _descripcionController.text.trim(), 
        
        evidencias: _archivosEvidenciaNuevos, // Solo mandamos las nuevas para subirse
        nombreUsuario: nombreOperador,
        rolUsuario: rolOperador,
        
        // 🔌 SEÑAL DE ENCLAVAMIENTO MAESTRO (Marcamos como completado)
        esRegistroCompleto: true, 
      )
    );
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Recepción: ${widget.ticket.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF005A9C),
        foregroundColor: Colors.white,
      ),
      body: BlocConsumer<TicketBloc, TicketState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) async { // ⚙️ CRÍTICO: El listener ahora es async
          if (state.status == TicketStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          } else if (state.status == TicketStatus.operationSuccess) { 
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Acta registrada exitosamente.'), backgroundColor: Colors.teal));
            
            // 🖨️ INTERLOCK DE IMPRESIÓN SINCRONIZADO (Importado de Creación)
            if (state.pdfBytes != null && state.pdfBytes!.isNotEmpty) {
                // 🛑 El 'await' detiene el código aquí hasta que el técnico cierre la vista de impresión
                await Printing.layoutPdf(
                  onLayout: (format) async => state.pdfBytes!,
                  name: 'Acta_Recepcion_${widget.ticket.id}.pdf',
                );
            }
            
            // 🚪 Solo después de imprimir (o cancelar), procedemos con la evacuación de la pantalla
            if (!context.mounted) return;
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          }
        },
        builder: (context, state) {
          final isProcessing = state.status == TicketStatus.loading;
          
          // ⚙️ SENSOR LÓGICO DE LAZO CERRADO (Real-Time Feedback)
          // Ignoramos la foto vieja de 'widget.ticket'. Buscamos la pieza actual 
          // en la cinta transportadora (el historial del BLoC).
   final TicketEntity ticketEnVivo = state.historial.cast<TicketEntity>().firstWhere(
            (t) => t.id == widget.ticket.id,
            orElse: () => widget.ticket, // Ahora el conector encaja perfectamente
          );

          // 🔒 Ahora el enclavamiento es absoluto. Si el BLoC ya lo marcó como completo, 
          // se bloquea para siempre, sin importar qué pase con el TicketStatus.
          final bool estaBloqueado = ticketEnVivo.esRegistroCompleto;
          print('El estado de bloque es: $estaBloqueado');
          return Form(
            key: _formKey,
            child: AbsorbPointer(
              absorbing: isProcessing,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🛑 MÓDULO 1: DATOS DE INGRESO (STRICT READ-ONLY)
                    const SectionTitleWidget(title: '1. Información Base (Bloqueada)'),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                      child: Column(
                        children: [
                          ReadOnlyFieldWidget(label: 'Cliente / Razón Social', value: widget.ticket.clienteId, icon: Icons.business),
                          ReadOnlyFieldWidget(label: 'Contacto', value: '${widget.ticket.nombreContacto} (${widget.ticket.telefonoContacto})', icon: Icons.person),
                          ReadOnlyFieldWidget(label: 'Campamento', value: widget.ticket.campamento.isNotEmpty ? widget.ticket.campamento : 'N/A', icon: Icons.map),
                          const Divider(),
                          ReadOnlyFieldWidget(label: 'Requerimiento', value: widget.ticket.tipoRequerimiento.name.toUpperCase(), icon: Icons.build_circle_outlined),
                          ReadOnlyFieldWidget(label: 'Lugar de Atención', value: widget.ticket.lugarAtencion.name.toUpperCase(), icon: Icons.location_on),
                          ReadOnlyFieldWidget(label: 'Equipo', value: widget.ticket.equipo.name.toUpperCase(), icon: Icons.precision_manufacturing),
                          const SizedBox(height: 8),
                          ReadOnlyFieldWidget(label: 'Falla Reportada Original', value: widget.ticket.fallaReportada, icon: Icons.report_problem, isMultiline: true),
                        ],
                      ),
                    ),
                    const Divider(height: 32, thickness: 2),

                    // 🔒 ENCLAVAMIENTO PARA MÓDULOS EDITABLES (2 y 3)
                    IgnorePointer(
                      ignoring: estaBloqueado,
                      child: Opacity(
                        opacity: estaBloqueado ? 0.5 : 1.0, // Oscurece al 50% si está bloqueado
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ⚙️ MÓDULO 2: INSPECCIÓN FÍSICA TALLER 
                            const SectionTitleWidget(title: '2. Inspección y Confirmación'),
                            CustomInputFieldWidget(label: 'Número de Serie Confirmado', controller: _serieController, icon: Icons.qr_code_scanner),
                            const SizedBox(height: 12),
                            ChecklistDinamicoWidget(
                              equipo: widget.ticket.equipo,
                              selecciones: _accesoriosSeleccionados,
                              onChanged: (pieza, valor) => setState(() => _accesoriosSeleccionados[pieza] = valor),
                            ),
                            const Divider(height: 32, thickness: 2),

                            // ⚙️ MÓDULO 3: PARAMETRIZACIÓN TALLER 
                            const SectionTitleWidget(title: '3. Parámetros de Taller'),
                            const SizedBox(height: 16),
                            CustomInputFieldWidget(
                              label: 'Notas de Recepción / Observaciones', 
                              controller: _descripcionController, 
                              icon: Icons.description_outlined, 
                              lines: 3, 
                              hint: 'Ej: Equipo llega con carcasa rayada, falta perno lateral...'
                            ),
                            const Divider(height: 32, thickness: 2),
                          ],
                        ),
                      ),
                    ),

                    // ⚙️ MÓDULO 4: TELEMETRÍA VISUAL (MIXTO)
                    const SectionTitleWidget(title: '4. Evidencia Fotográfica'),
                    
                    // 📸 Sub-módulo (FUERA DEL BLOQUEO): Para poder hacer scroll a fotos viejas
                    if (widget.ticket.fotosUrls.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text('Evidencia Previa (En Campo):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      ),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.ticket.fotosUrls.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  widget.ticket.fotosUrls[index],
                                  height: 100, width: 100, fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) => progress == null ? child : const SizedBox(width: 100, child: Center(child: CircularProgressIndicator())),
                                  errorBuilder: (context, error, stackTrace) => Container(width: 100, color: Colors.grey.shade300, child: const Icon(Icons.broken_image, color: Colors.grey)),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 🔒 ENCLAVAMIENTO PARA NUEVAS FOTOS
                    IgnorePointer(
                      ignoring: estaBloqueado,
                      child: Opacity(
                        opacity: estaBloqueado ? 0.5 : 1.0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Añadir nueva evidencia (Taller):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 8),
                            CameraManagerWidget(
                              archivosEvidencia: _archivosEvidenciaNuevos,
                              onArchivosActualizados: (archivos) => setState(() {
                                _archivosEvidenciaNuevos.clear();
                                _archivosEvidenciaNuevos.addAll(archivos);
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 32, thickness: 2),

                    // ⚡ ACTUADOR FINAL HMI
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: estaBloqueado ? Colors.grey : const Color(0xFF005A9C), 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                        ),
                        onPressed: (isProcessing || estaBloqueado) ? null : _onConfirmarRecepcion,
                        child: isProcessing 
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2)),
                                SizedBox(width: 12),
                                Text('PROCESANDO ACTA...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                              ],
                            )
                          : Text(
                              estaBloqueado ? 'REGISTRO YA COMPLETADO' : 'GENERAR ACTA DE RECEPCIÓN', 
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                            ),
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