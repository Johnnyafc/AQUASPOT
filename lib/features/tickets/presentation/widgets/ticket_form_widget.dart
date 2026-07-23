// lib/features/tickets/presentation/widgets/ticket_form_widget.dart

import 'package:aquaspot_postventa/core/enum/marca_equipo.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/cliente_entity.dart';
import '../../../../core/enum/ticket_enums.dart';

// --- Importación de Módulos (Ajusta las rutas) ---
import 'selector_requerimiento_widget.dart';
import 'sections/datos_cliente_section.dart';
import 'sections/confirmacion_equipo_section.dart';
import 'sections/parametros_operativos_section.dart';
import 'camera_manager_widget.dart';
import 'section_title_widget.dart';

class TicketForm extends StatelessWidget {
  // ... (Tus mismas declaraciones de variables, controladores y callbacks se mantienen exactamente igual) ...
  final GlobalKey<FormState> formKey;
  final bool isProcessing;
  final List<ClienteEntity> listaClientes;
  final TextEditingController clienteController;
  final TextEditingController campamentoController;
  final TextEditingController nombreContactoController;
  final TextEditingController emailController;
  final TextEditingController telefonoController;
  final TextEditingController fallaController;
  final TextEditingController customEquipoController;
  final TextEditingController serieController; 
  final TextEditingController notasRecepcionController; 
  final Sede? selectedSede;
  final TipoEquipo? selectedEquipo;
  final String? selectedClienteId;
  final Prioridad? prioridadSeleccionada; 
  final Map<String, bool> accesoriosSeleccionados; 
  final List<XFile> archivosEvidencia; 
  final ValueChanged<Sede?> onSedeChanged;
  final ValueChanged<TipoEquipo?> onEquipoChanged;
  final ValueChanged<ClienteEntity> onClienteSelected;
  final VoidCallback onClienteCleared;
  final ValueChanged<Prioridad?> onPrioridadChanged; 
  final Function(String, bool) onAccesorioChanged; 
  final ValueChanged<List<XFile>> onArchivosActualizados; 
  final VoidCallback onSubmit;
  final TipoRequerimiento tipoRequerimiento;
  final LugarAtencion lugarAtencion;
  final MarcaEquipo? marcaSeleccionada;
 final ValueChanged<MarcaEquipo?> onMarcaChanged;
 final TipoGarantia tipoGarantia;

  const TicketForm({
    super.key,
    required this.formKey,
    required this.isProcessing,
    required this.listaClientes,
    required this.clienteController,
    required this.campamentoController,
    required this.nombreContactoController,
    required this.emailController,
    required this.telefonoController,
    required this.fallaController,
    required this.customEquipoController,
    required this.serieController,
    required this.notasRecepcionController,
    required this.selectedSede,
    required this.selectedEquipo,
    required this.selectedClienteId,
    required this.prioridadSeleccionada,
    required this.accesoriosSeleccionados,
    required this.archivosEvidencia,
    required this.onSedeChanged,
    required this.onEquipoChanged,
    required this.onClienteSelected,
    required this.onClienteCleared,
    required this.onPrioridadChanged,
    required this.onAccesorioChanged,
    required this.onArchivosActualizados,
    required this.onSubmit,
    required this.tipoRequerimiento,
    required this.lugarAtencion,
    required this.marcaSeleccionada,
    required this.onMarcaChanged,
    required this.tipoGarantia
  });

@override
Widget build(BuildContext context) {
  // 🧠 ECUACIÓN LÓGICA INTERNA (PROCESAMIENTO DE SEÑALES)
  
  // 1. CONTACTOR MAESTRO (Calibrado con interlock de garantía):
  final bool esReparacion = tipoRequerimiento == TipoRequerimiento.reparacion && 
                            (lugarAtencion == LugarAtencion.taller || lugarAtencion == LugarAtencion.campo);
                            
  final bool esGarantia = tipoRequerimiento == TipoRequerimiento.reclamoGarantia && 
                          (lugarAtencion == LugarAtencion.taller || lugarAtencion == LugarAtencion.campo) && 
                          tipoGarantia != TipoGarantia.pendiente; // 🛑 El bloqueo estricto ocurre aquí

  final bool esServicioTecnicoDefinido = esReparacion || esGarantia;

  // 2. RELÉ DE ACCESORIOS: Solo se energiza si el equipo ingresa físicamente al Taller
  final bool mostrarAccesorios = lugarAtencion == LugarAtencion.taller;

  // 🚀 3. SENSOR DE MÓDULOS EN DESARROLLO (Nueva compuerta estricta)
  final bool esModuloEnConstruccion = tipoRequerimiento == TipoRequerimiento.ventaRepuesto || 
                                      tipoRequerimiento == TipoRequerimiento.alquilerPrueba || 
                                      tipoRequerimiento == TipoRequerimiento.ventaMaquina;

  return Form(
    key: formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 🚀 MÓDULO DINÁMICO (Panel Principal de Control)
        const Text('REQUERIMIENTO', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Color(0xFF005A9C))),
        const SizedBox(height: 16),
        const SelectorRequerimientoWidget(), 
        const Padding(padding: EdgeInsets.symmetric(vertical: 24.0), child: Divider(thickness: 1.5, color: Colors.black12)),

        // 🛑 VÁLVULA DE SEGURIDAD (LOTO)
        // Deja pasar la corriente si es Reparación o Garantía (con ubicación y tipo de garantía confirmados)
        if (esServicioTecnicoDefinido) ...[
          
          // ⚙️ MÓDULO A: CLIENTE
          DatosClienteSection(
            listaClientes: listaClientes,
            selectedSede: selectedSede,
            selectedClienteId: selectedClienteId,
            clienteController: clienteController,
            campamentoController: campamentoController,
            nombreContactoController: nombreContactoController,
            emailController: emailController,
            telefonoController: telefonoController,
            onSedeChanged: onSedeChanged,
            onClienteSelected: onClienteSelected,
            onClienteCleared: onClienteCleared,
            showSede: lugarAtencion != LugarAtencion.campo,
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 24.0), child: Divider(thickness: 1.5, color: Colors.black12)),

          // ⚙️ MÓDULO B: EQUIPO 
          ConfirmacionEquipoSection(
            selectedEquipo: selectedEquipo,
            accesoriosSeleccionados: accesoriosSeleccionados,
            customEquipoController: customEquipoController,
            serieController: serieController,
            fallaController: fallaController,
            onEquipoChanged: onEquipoChanged,
            onAccesorioChanged: onAccesorioChanged,
            mostrarAccesorios: mostrarAccesorios, // 🚀 Responde automáticamente a Taller/Campo
            selectedMarca: marcaSeleccionada,
            onMarcaChanged: onMarcaChanged,
          ),
          
          // 🚪 COMPUERTA DE AISLAMIENTO: Ocultar Parámetros y Telemetría en Campo
          if (lugarAtencion != LugarAtencion.campo) ...[
            const Padding(padding: EdgeInsets.symmetric(vertical: 24.0), child: Divider(thickness: 1.5, color: Colors.black12)),

            // ⚙️ MÓDULO C: PARÁMETROS
            ParametrosOperativosSection(
              notasRecepcionController: notasRecepcionController,
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 24.0), child: Divider(thickness: 1.5, color: Colors.black12)),

            // ⚙️ MÓDULO D: TELEMETRÍA (Cámara)
            const SectionTitleWidget(title: '4. Evidencia Fotográfica'),
            const SizedBox(height: 16),
            CameraManagerWidget(archivosEvidencia: archivosEvidencia, onArchivosActualizados: onArchivosActualizados),
          ],

          const SizedBox(height: 32),

          // ⚡ TRANSMISOR
          SizedBox(
            width: double.infinity, height: 55,
            child: ElevatedButton(
              onPressed: isProcessing ? null : onSubmit,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005A9C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: isProcessing ? const CircularProgressIndicator(color: Colors.orange) : const Text('REGISTRAR INGRESO', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          
        // ⚙️ ESTA ES LA REPARACIÓN: Solo mostramos la advertencia si el sensor de construcción da positivo
        ] else if (esModuloEnConstruccion) ...[
          // ⚠️ ADVERTENCIA DE MÓDULO EN CONSTRUCCIÓN (Para Venta y Alquiler)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: const Column(
              children: [
                Icon(Icons.construction, color: Colors.orange, size: 48),
                SizedBox(height: 16),
                Text(
                  'MÓDULO EN CONSTRUCCIÓN',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'El formulario para este tipo de requerimiento está siendo calibrado y estará disponible en la próxima actualización.',
                  style: TextStyle(color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        ]
      ],
    ),
  );
}
}