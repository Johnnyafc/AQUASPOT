import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

import '../../../../core/utils/media_helper.dart';

class CameraManagerWidget extends StatelessWidget {
  final List<XFile> archivosEvidencia;
  final ValueChanged<List<XFile>> onArchivosActualizados;

  const CameraManagerWidget({
    super.key,
    required this.archivosEvidencia,
    required this.onArchivosActualizados,
  });

  Future<void> _capturarMedio(BuildContext context, ImageSource source, {required bool esVideo}) async {
    final ImagePicker picker = ImagePicker();
    XFile? archivo;

    try {
      if (esVideo) {
        archivo = await picker.pickVideo(
          source: source,
          maxDuration: const Duration(seconds: 30), 
        );
      } else {
        // Pedimos el archivo crudo (sin imageQuality/maxWidth/maxHeight):
        // la compresión la hacemos nosotros después con MediaHelper, una
        // vez confirmado que el archivo terminó de escribirse en disco
        // (ver _esperarArchivoDeCamaraListo más abajo).
        archivo = await picker.pickImage(source: source);
      }

      if (archivo != null) {
        final nuevaLista = List<XFile>.from(archivosEvidencia);

        if (esVideo || kIsWeb) {
          // Videos o entorno Web van directos
          nuevaLista.add(archivo);
          onArchivosActualizados(nuevaLista);
        } else {
          // 🩺 DIAGNÓSTICO: el cuadro negro solo ocurre con fotos tomadas
          // en vivo con la cámara de este equipo (nunca con galería), lo
          // que apunta a una condición de carrera: el archivo aún se está
          // escribiendo en el almacenamiento lento cuando la cámara ya nos
          // devolvió el control. Solo esperamos esto para ImageSource.camera;
          // un archivo de galería ya está completo, no hace falta esperarlo.
          final XFile? archivoListo = source == ImageSource.camera
              ? await MediaHelper.esperarArchivoDeCamaraListo(archivo)
              : archivo;

          if (archivoListo == null) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '⚠️ La foto no se guardó completa (almacenamiento lento del equipo). Vuelva a tomarla.',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }

          // Ya validado que el archivo es un JPEG completo: ahora sí lo
          // comprimimos de forma aislada del hardware.
          final XFile? archivoComprimido = await MediaHelper.comprimirImagenNativa(archivoListo);
          nuevaLista.add(archivoComprimido ?? archivoListo);
          onArchivosActualizados(nuevaLista);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de hardware/captura: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _mostrarOpcionesCaptura(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.teal),
              title: const Text('Tomar Foto'),
              onTap: () {
                Navigator.pop(ctx);
                _capturarMedio(context, ImageSource.camera, esVideo: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.teal),
              title: const Text('Grabar Video'),
              onTap: () {
                Navigator.pop(ctx);
                _capturarMedio(context, ImageSource.camera, esVideo: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.grey),
              title: const Text('Seleccionar de Galería'),
              onTap: () {
                Navigator.pop(ctx);
                _capturarMedio(context, ImageSource.gallery, esVideo: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _eliminarArchivo(int index) {
    final nuevaLista = List<XFile>.from(archivosEvidencia)..removeAt(index);
    onArchivosActualizados(nuevaLista);
  }

  @override
  Widget build(BuildContext context) {
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
        if (archivosEvidencia.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: archivosEvidencia.length,
              itemBuilder: (context, index) {
                final file = archivosEvidencia[index]; 
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
                            child: kIsWeb 
                                ? Image.network(file.path, fit: BoxFit.cover) 
                                : Image.file(File(file.path), fit: BoxFit.cover),
                          ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _eliminarArchivo(index),
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
}