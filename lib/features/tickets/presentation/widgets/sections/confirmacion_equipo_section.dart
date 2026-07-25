import 'package:aquaspot_postventa/core/enum/marca_equipo.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/enum/ticket_enums.dart';
import '../custom_dropdown.dart';
import '../custom_input_field.dart';
import '../custom_input_field_widget.dart';
import '../checklist_dinamico_widget.dart';
import '../section_title_widget.dart';

class ConfirmacionEquipoSection extends StatelessWidget {
  final TipoEquipo? selectedEquipo;
  final Map<String, bool> accesoriosSeleccionados;
  final TextEditingController customEquipoController;
  final TextEditingController serieController;
  final TextEditingController fallaController;
  final ValueChanged<TipoEquipo?> onEquipoChanged;
  final Function(String, bool) onAccesorioChanged;
  final MarcaEquipo? selectedMarca;
  final ValueChanged<MarcaEquipo?> onMarcaChanged;
  final bool mostrarAccesorios; 

  // ==========================================
  // 🔌 NUEVOS PINES DE CONEXIÓN PARA GARANTÍA AGRÍCOLA
  // ==========================================
  final TipoRequerimiento tipoRequerimiento; 
  final TextEditingController horometroController;
  final VoidCallback onAddMedia; // Función para disparar la carga de fotos/videos
  
  final List<XFile> archivosGarantia;
   final ValueChanged<int> onRemoveArchivo;
  const ConfirmacionEquipoSection({
    super.key,
    required this.selectedEquipo,
    required this.accesoriosSeleccionados,
    required this.customEquipoController,
    required this.serieController,
    required this.fallaController,
    required this.onEquipoChanged,
    required this.onAccesorioChanged,
    required this.mostrarAccesorios, 
    this.selectedMarca,
    required this.onMarcaChanged,
    // Inicialización de los nuevos parámetros
    required this.tipoRequerimiento,
    required this.horometroController,
    required this.onAddMedia,
    required this.archivosGarantia,
    required this.onRemoveArchivo,
  });

  @override
  Widget build(BuildContext context) {
    // 🧠 Compuerta Lógica AND: ¿Es garantía Y es una Cosechadora?
    // Nota: Asegúrese de que 'TipoEquipo.Cosechadora' exista en su enum.
    final bool esGarantiaCosechadora = 
        tipoRequerimiento == TipoRequerimiento.reclamoGarantia && 
        selectedEquipo == TipoEquipo.Cosechadora;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitleWidget(title: '2. Confirmación de equipo'),
        const SizedBox(height: 16),
        
        CustomDropdownField<TipoEquipo>(
          label: 'Tipo de Equipo', icon: Icons.precision_manufacturing, items: TipoEquipo.values,
          value: selectedEquipo, onChanged: onEquipoChanged, validator: (value) => null,
        ),
        
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: selectedEquipo == TipoEquipo.Otros
              ? Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: CustomInputField(controller: customEquipoController, label: 'Especifique equipo', icon: Icons.edit_note),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),

        CustomDropdownField<MarcaEquipo>(
          label: 'Marca del Equipo (Opcional)', 
          icon: Icons.sell_outlined, 
          items: MarcaEquipo.values,
          value: selectedMarca, 
          onChanged: onMarcaChanged, 
          validator: (value) => null, 
        ),
        const SizedBox(height: 16),

        CustomInputFieldWidget(label: 'Número de Serie', controller: serieController, icon: Icons.qr_code_scanner, validator: (value) => null,),
        const SizedBox(height: 16),
        
        // ==========================================
        // 🚜 INYECCIÓN DINÁMICA: TELEMETRÍA DE COSECHADORA
        // ==========================================
       if (esGarantiaCosechadora) ...[
  Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.orange.shade50,
      border: Border.all(color: Colors.orange.shade800, width: 2),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.agriculture, color: Colors.orange.shade900),
            const SizedBox(width: 8),
            Text(
              'ESTO ES GARANTÍA: COSECHADORA', 
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontSize: 14)
            ),
          ],
        ),
        const Divider(),
        const SizedBox(height: 8),
        
        // Sensor de Horas de Motor
        CustomInputFieldWidget(
          label: 'Lectura del Horómetro', 
          controller: horometroController, 
          icon: Icons.timer,
          keyboardType: TextInputType.number, 
          validator: (value) => (value == null || value.isEmpty) ? 'Requerido para garantía' : null,
        ),
        const SizedBox(height: 16),
        
        // Actuador Multimedia
        OutlinedButton.icon(
          onPressed: onAddMedia,
          icon: const Icon(Icons.perm_media, color: Colors.blue),
          label: const Text('Adjuntar Evidencia (Fotos/Videos)'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: const BorderSide(color: Colors.blue, width: 1.5),
          ),
        ),

        // =========================================================================
        // 📊 VISOR DINÁMICO DE ARCHIVOS (Lo que faltaba para pintar en pantalla)
        // =========================================================================
        if (archivosGarantia.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Archivos en cola (${archivosGarantia.length}):',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.orange.shade900),
          ),
          const SizedBox(height: 6),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: archivosGarantia.length,
            itemBuilder: (context, index) {
              final archivo = archivosGarantia[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.orange.shade300),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file, size: 18, color: Colors.blueGrey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        archivo.name, // Muestra el nombre real del archivo seleccionado
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Válvula de purga (elimina el archivo de la lista si el operario se equivocó)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.red),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      onPressed: () => onRemoveArchivo(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    ),
  ),
  const SizedBox(height: 16),
],

        // ⚙️ COMPUERTA LÓGICA DE ENCLAVAMIENTO (Accesorios)
        if (selectedEquipo != null && mostrarAccesorios)
          ChecklistDinamicoWidget(
            equipo: selectedEquipo!,
            selecciones: accesoriosSeleccionados,
            onChanged: onAccesorioChanged,
          ),
          
        const SizedBox(height: 16),
        CustomInputFieldWidget(label: 'Falla Reportada', controller: fallaController, icon: Icons.report_problem_outlined, lines: 3),
      ],
    );
  }
}