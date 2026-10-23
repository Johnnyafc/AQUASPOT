// lib/features/tickets/presentation/widgets/evidencia_retiro_widget.dart
//
// 📸 Evidencia obligatoria del retiro de materiales en Bodega (técnico
// interno y externo): foto de la hoja de materiales firmada y foto de los
// materiales que retira. El padre guarda las listas y decide si puede
// confirmar (ambas con al menos una foto).

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EvidenciaRetiroWidget extends StatelessWidget {
  final List<XFile> fotosHojaFirmada;
  final List<XFile> fotosMateriales;
  final ValueChanged<List<XFile>> onHojaFirmadaCambiada;
  final ValueChanged<List<XFile>> onMaterialesCambiados;
  final bool habilitado;

  const EvidenciaRetiroWidget({
    super.key,
    required this.fotosHojaFirmada,
    required this.fotosMateriales,
    required this.onHojaFirmadaCambiada,
    required this.onMaterialesCambiados,
    this.habilitado = true,
  });

  bool get completa => fotosHojaFirmada.isNotEmpty && fotosMateriales.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: completa ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: completa ? const Color(0xFF2E7D32) : Colors.amber.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_camera_outlined, color: completa ? const Color(0xFF2E7D32) : Colors.amber.shade900),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Evidencia del retiro (obligatoria)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Suba la foto de la hoja de materiales de Bodega ya firmada y la foto de los materiales que retira.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          _SeccionFotos(
            titulo: '📄 Hoja de materiales firmada',
            fotos: fotosHojaFirmada,
            onCambio: onHojaFirmadaCambiada,
            habilitado: habilitado,
          ),
          const SizedBox(height: 12),
          _SeccionFotos(
            titulo: '📦 Materiales retirados',
            fotos: fotosMateriales,
            onCambio: onMaterialesCambiados,
            habilitado: habilitado,
          ),
        ],
      ),
    );
  }
}

class _SeccionFotos extends StatelessWidget {
  final String titulo;
  final List<XFile> fotos;
  final ValueChanged<List<XFile>> onCambio;
  final bool habilitado;

  const _SeccionFotos({required this.titulo, required this.fotos, required this.onCambio, required this.habilitado});

  Future<void> _agregar(BuildContext context, ImageSource origen) async {
    try {
      final picker = ImagePicker();
      if (origen == ImageSource.gallery) {
        final nuevas = await picker.pickMultiImage(imageQuality: 80);
        if (nuevas.isNotEmpty) onCambio([...fotos, ...nuevas]);
      } else {
        final nueva = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
        if (nueva != null) onCambio([...fotos, nueva]);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo tomar la foto: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$titulo (${fotos.length})',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Tomar foto',
              icon: const Icon(Icons.camera_alt, size: 18),
              onPressed: habilitado ? () => _agregar(context, ImageSource.camera) : null,
            ),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              tooltip: 'Galería',
              icon: const Icon(Icons.photo_library, size: 18),
              onPressed: habilitado ? () => _agregar(context, ImageSource.gallery) : null,
            ),
          ],
        ),
        if (fotos.isNotEmpty)
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: fotos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => Stack(
                children: [
                  _Miniatura(foto: fotos[i]),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: InkWell(
                      onTap: habilitado ? () => onCambio([...fotos]..removeAt(i)) : null,
                      child: const CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.red,
                        child: Icon(Icons.close, size: 13, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Miniatura desde los bytes (funciona igual en web y en el celular).
class _Miniatura extends StatelessWidget {
  final XFile foto;
  const _Miniatura({required this.foto});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 76,
        height: 76,
        child: FutureBuilder<Uint8List>(
          future: foto.readAsBytes(),
          builder: (context, snap) => snap.hasData
              ? Image.memory(snap.data!, fit: BoxFit.cover, cacheWidth: 200)
              : Container(color: Colors.grey.shade200),
        ),
      ),
    );
  }
}
