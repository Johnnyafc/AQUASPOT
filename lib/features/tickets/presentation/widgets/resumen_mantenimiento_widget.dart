// lib/features/tickets/presentation/widgets/resumen_mantenimiento_widget.dart
//
// 🛠️ Datos con los que se creó un requerimiento de MANTENIMIENTO INTERNO
// (máquina, marca, especificación, serie / placa, lecturas, fecha, detalle,
// quién lo creó) con las fotos en miniatura (se agrandan al tocarlas) y los
// videos. Se usa en todas las pantallas del flujo en lugar de los datos de
// cliente / contacto / proyecto. Solo dibuja: los datos salen de
// ResumenMantenimientoService.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/services/formulario_mantenimiento_service.dart';
import '../../domain/services/resumen_mantenimiento_service.dart';

typedef _R = ResumenMantenimientoService;

class ResumenMantenimientoWidget extends StatelessWidget {
  final TicketEntity ticket;
  final bool mostrarDetalle;
  final String titulo;

  const ResumenMantenimientoWidget({
    super.key,
    required this.ticket,
    this.mostrarDetalle = true,
    this.titulo = 'Datos del requerimiento (mantenimiento interno)',
  });

  static void _verFoto(BuildContext context, String url, String etiqueta) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text(etiqueta, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ),
          Flexible(
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No se pudo cargar la foto.'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = ticket.mantenimientoInterno;
    final fotos = _R.fotos(ticket);
    final videos = _R.videos(ticket);
    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.build_circle_outlined, color: Color(0xFF005A9C)),
              const SizedBox(width: 8),
              Expanded(child: Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
            ]),
            const Divider(height: 20),
            for (final (etiqueta, valor) in _R.filas(ticket))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    // Etiqueta más angosta en el celular para que el valor no se parta.
                    width: MediaQuery.sizeOf(context).width < 600 ? 120 : 170,
                    child: Text('$etiqueta:', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ),
                  Expanded(child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w600))),
                ]),
              ),
            if (mostrarDetalle && ticket.fallaReportada.trim().isNotEmpty) ...[
              const Divider(height: 20),
              Text(
                m == null ? 'Detalle' : FormularioMantenimientoService.etiquetaDetalle(m.tipoMantenimiento),
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(ticket.fallaReportada, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
            if (fotos.isNotEmpty || videos.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (url, etiqueta) in fotos)
                  Tooltip(
                    message: etiqueta,
                    child: InkWell(
                      onTap: () => _verFoto(context, url, etiqueta),
                      borderRadius: BorderRadius.circular(8),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 96,
                              height: 96,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          width: 96,
                          child: Text(etiqueta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ),
                      ]),
                    ),
                  ),
                for (var i = 0; i < videos.length; i++)
                  ActionChip(
                    avatar: const Icon(Icons.play_circle_outline, size: 18),
                    label: Text('Video ${i + 1}'),
                    onPressed: () => launchUrl(Uri.parse(videos[i]), mode: LaunchMode.externalApplication),
                  ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

/// 🛠️ Para las TARJETAS de las bandejas: todos los datos con los que se creó
/// el requerimiento (sin fotos ni videos), en líneas cortas que se acomodan
/// a lo ancho (una columna en el celular, varias en pantallas anchas).
class DatosMantenimientoTarjetaWidget extends StatelessWidget {
  final TicketEntity ticket;

  const DatosMantenimientoTarjetaWidget({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    // Cada dato con su ancho natural; baja de línea solo si no cabe. Sin
    // LayoutBuilder: la tarjeta del Historial vive en un IntrinsicHeight.
    return Wrap(spacing: 16, runSpacing: 2, children: [
      for (final (etiqueta, valor) in _R.filasTarjeta(ticket))
        Text.rich(
          TextSpan(children: [
            TextSpan(text: '$etiqueta: ', style: TextStyle(color: Colors.grey.shade600)),
            TextSpan(text: valor, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          style: const TextStyle(fontSize: 12.5),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
    ]);
  }
}
