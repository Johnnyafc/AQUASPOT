// lib/features/tickets/presentation/widgets/sections/asistencia_tecnica_section.dart
//
// Sección opcional de Venta de Repuesto: un switch "¿Necesita asistencia
// de Servicio Técnico?" -- apagado, el formulario queda tal cual (solo
// elegir repuestos). Al activarlo, se habilita subir evidencia para que
// el técnico pueda orientar qué necesita el cliente.
//
// Reutiliza lo que ya existe, sin tocarlo:
// - CameraManagerWidget (el mismo de "Evidencia Fotográfica" en
//   Reparación) para fotos y video -- cero código nuevo para eso.
// - El mismo patrón de FilePicker que ya usa la carga de Excel en
//   Bodega (gestion_stock_bodega_page.dart), aquí con extensiones de
//   audio, para adjuntar una nota de voz ya grabada (no se graba nada
//   dentro de la app).

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../camera_manager_widget.dart';
import '../section_title_widget.dart';

class AsistenciaTecnicaSection extends StatelessWidget {
  final bool necesitaAsistencia;
  final ValueChanged<bool> onNecesitaAsistenciaChanged;
  final List<XFile> evidenciasMultimedia;
  final ValueChanged<List<XFile>> onEvidenciasMultimediaActualizadas;
  final List<PlatformFile> audiosAdjuntos;
  final ValueChanged<List<PlatformFile>> onAudiosActualizados;

  const AsistenciaTecnicaSection({
    super.key,
    required this.necesitaAsistencia,
    required this.onNecesitaAsistenciaChanged,
    required this.evidenciasMultimedia,
    required this.onEvidenciasMultimediaActualizadas,
    required this.audiosAdjuntos,
    required this.onAudiosActualizados,
  });

  Future<void> _adjuntarAudio(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg'],
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final nuevaLista = List<PlatformFile>.from(audiosAdjuntos)..addAll(result.files);
      onAudiosActualizados(nuevaLista);
    }
  }

  void _quitarAudio(int index) {
    final nuevaLista = List<PlatformFile>.from(audiosAdjuntos)..removeAt(index);
    onAudiosActualizados(nuevaLista);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: necesitaAsistencia ? const Color(0xFFFFF3E0) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: necesitaAsistencia ? Colors.orange.shade200 : Colors.grey.shade300),
          ),
          child: SwitchListTile(
            value: necesitaAsistencia,
            onChanged: onNecesitaAsistenciaChanged,
            activeColor: const Color(0xFF005A9C),
            title: const Text('¿Necesita asistencia de Servicio Técnico?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text(
              'Actívelo si no está seguro de qué repuesto necesita el cliente: podrá adjuntar fotos, video o audio para que el técnico lo oriente.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),

        if (necesitaAsistencia) ...[
          const SizedBox(height: 20),
          const SectionTitleWidget(title: 'Evidencia para Servicio Técnico'),

          CameraManagerWidget(
            archivosEvidencia: evidenciasMultimedia,
            onArchivosActualizados: onEvidenciasMultimediaActualizadas,
          ),

          const SizedBox(height: 16),

          InkWell(
            onTap: () => _adjuntarAudio(context),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic_none_outlined, color: Colors.teal),
                  SizedBox(width: 12),
                  Text('Adjuntar Nota de Voz', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

          if (audiosAdjuntos.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (int i = 0; i < audiosAdjuntos.length; i++) _tarjetaAudio(i, audiosAdjuntos[i]),
          ],
        ],
      ],
    );
  }

  Widget _tarjetaAudio(int index, PlatformFile archivo) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.audiotrack, color: Colors.teal),
        title: Text(archivo.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
          onPressed: () => _quitarAudio(index),
        ),
      ),
    );
  }
}
