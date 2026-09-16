// lib/features/tickets/presentation/pages/detalle_ticket_page.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart'; // ⚙️ LIBRERÍA DE VIDEO
import '../../../../core/enum/ticket_enums.dart';
import '../../domain/entities/ticket_entity.dart';
import '../widgets/full_photo_widget.dart';
import '../widgets/copy_icon_button_widget.dart';
import '../widgets/tarjeta_no_requiere_compras_widget.dart';

class DetalleTicketPage extends StatelessWidget {
  final TicketEntity ticket;

  const DetalleTicketPage({super.key, required this.ticket});

  // 🧠 SENSOR CLASIFICADOR: Identifica si la URL es un video basado en la extensión de la ruta cruda
  bool _esVideo(String url) {
    // Extraemos la ruta pura ignorando los tokens de seguridad de Firebase (?alt=media&token=...)
    final rutaMinuscula = Uri.parse(url).path.toLowerCase();
    return rutaMinuscula.endsWith('.mp4') || 
           rutaMinuscula.endsWith('.mov') || 
           rutaMinuscula.endsWith('.avi') || 
           rutaMinuscula.endsWith('.mkv');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: Text(ticket.id, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      // 📋 SELECCIÓN DE TEXTO: solo en esta pantalla, para que puedas
      // subrayar con el mouse cualquier dato del ticket y copiarlo/pegarlo
      // donde quieras.
      body: SelectionArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TarjetaNoRequiereComprasWidget(ticket: ticket),
            const Text("Datos del Requerimiento", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF003366))),
            const SizedBox(height: 12),
            _buildDataCard(context),

            const SizedBox(height: 24),

            // ✅ MÓDULO VISUAL: Visualización de telemetría (fotos y videos mezclados)
            const Text("Evidencia Multimedia", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF003366))),
            const SizedBox(height: 12),
            _buildEvidenciasCard(context),

            const SizedBox(height: 24),

            const Text("Trazabilidad y Auditoría", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF003366))),
            const SizedBox(height: 12),
            _buildTimelineCard(context),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildDataCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDatoRow(context, 'Estado Actual:', ticket.estadoActual.nombreMayusculas),
            const Divider(),
            _buildDatoRow(context, 'Equipo y Marca:', '${ticket.equipo.name.toUpperCase()} • ${ticket.marca.toUpperCase()}'),
            _buildDatoRow(context, 'Lugar de recepción:', ticket.sede.name.toUpperCase()),
            const Divider(),
            _buildDatoRow(context, 'Cliente:', ticket.clienteId),
            _buildDatoRow(context, 'Campamento:', ticket.campamento),
            _buildDatoRow(context, 'Contacto:', '${ticket.nombreContacto} (${ticket.telefonoContacto})'),
            const Divider(),
            _buildDatoRow(context, 'Número de Serie:', ticket.numeroSerie ?? 'No Registrado'),
            // 🆕 Código de Proyecto: solo se muestra si el ticket ya tiene uno
            // asignado (se asigna en la fase de Costos, no existe desde el
            // inicio) — mismo criterio condicional que ya se usa en Historial.
            if (ticket.codigoProyecto != null && ticket.codigoProyecto!.trim().isNotEmpty)
              _buildDatoRow(context, 'Código de Proyecto:', ticket.codigoProyecto!),
            const Divider(),
            _buildDatoBloqueMultilinea(context, 'Falla Reportada e Inspección:', ticket.fallaReportada),
            _buildDatoBloqueMultilinea(context, 'Comentarios de recepción:', ticket.notasRecepcion.toString()),
            if (ticket.evidenciaTrabajo?.nombreTecnico != null && ticket.evidenciaTrabajo!.nombreTecnico!.isNotEmpty) ...[
              const Divider(),
              _buildDatoRow(context, 'Técnico Ejecutor:', ticket.evidenciaTrabajo!.nombreTecnico!),
            ],
            if (ticket.evidenciaTrabajo?.notasTecnicas != null && ticket.evidenciaTrabajo!.notasTecnicas!.isNotEmpty)
              _buildDatoBloqueMultilinea(context, 'Notas Técnicas de Trabajo:', ticket.evidenciaTrabajo!.notasTecnicas!),
          ],
        ),
      ),
    );
  }

  // Igual que _buildDatoRow, pero para texto largo: etiqueta arriba (con su
  // botón de copiar) y el valor debajo, en su propia línea.
  Widget _buildDatoBloqueMultilinea(BuildContext context, String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(etiqueta, style: const TextStyle(color: Colors.grey, fontSize: 12))),
              CopyIconButtonWidget(etiqueta: etiqueta, valor: valor),
            ],
          ),
          const SizedBox(height: 4),
          Text(valor, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // =========================================================================
  // ⚙️ COMPONENTE DE RENDERIZADO (Demultiplexor de Archivos Mixtos)
  // =========================================================================
  Widget _buildEvidenciasCard(BuildContext context) {
    // La variable fotosUrls ahora es nuestro ducto genérico de multimedia
    final List<String> multimedia = ticket.fotosUrls;

    if (multimedia.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text('Sin evidencia multimedia registrada.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: multimedia.length,
            itemBuilder: (context, index) {
              final url = multimedia[index];
              final esVideo = _esVideo(url); // 🔍 Lectura del sensor clasificador

              if (esVideo) {
                // 🎬 CANAL DE VIDEO
                return GestureDetector(
                  onTap: () => _mostrarDialogoVideo(context, url),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(Icons.videocam, color: Colors.white38, size: 40),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.teal,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                            child: const Icon(Icons.video_file, color: Colors.white, size: 12),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              } else {
                // 📸 CANAL DE FOTOGRAFÍA
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FullPhotoPage(imageUrl: url),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            url,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator(color: Colors.teal));
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image, color: Colors.grey),
                                    Text('CORS/Error', style: TextStyle(fontSize: 10, color: Colors.red))
                                  ],
                                )
                              );
                            },
                          ),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                              child: const Icon(Icons.photo, color: Colors.white, size: 12),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineCard(BuildContext context) {
    final eventosOrdenados = List.from(ticket.historialEventos)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: eventosOrdenados.map((evento) {
            final fechaStr = evento.timestamp.toString().substring(0, 16);

            // 📋 Copiamos solo lo que viene DESPUÉS del separador en el título
            // del evento: si tiene ":" se separa por ":" (ej. "Código Proyecto
            // Asignado: ABC123" → copia "ABC123"); si tiene "." se separa por
            // "." (ej. "Notas Finales. Quedó operativo" → copia "Quedó
            // operativo"). Cuando aparecen los dos (ej. "CARGA DE FACTURA.
            // Obs: Sin observaciones"), usamos el separador que esté más a la
            // derecha, que es el que antecede al dato real. Si no hay ningún
            // separador, o no queda nada después de él, no hay nada que copiar.
            final indicePunto = evento.accion.lastIndexOf('.');
            final indiceDosPuntos = evento.accion.lastIndexOf(':');
            final indiceSeparador = indicePunto > indiceDosPuntos ? indicePunto : indiceDosPuntos;
            final valorCopiable = indiceSeparador != -1
                ? evento.accion.substring(indiceSeparador + 1).trim()
                : '';
            final tieneDatoCopiable = valorCopiable.isNotEmpty;
            final etiquetaCopiable = tieneDatoCopiable
                ? evento.accion.substring(0, indiceSeparador).trim()
                : '';

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.adjust, color: Color(0xFF005A9C), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(evento.accion, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                            if (tieneDatoCopiable)
                              CopyIconButtonWidget(etiqueta: etiquetaCopiable, valor: valorCopiable),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Operador: ${evento.usuarioNombre} [${evento.usuarioRol}]', style: const TextStyle(fontSize: 13)),
                        Text('Marca de tiempo: $fechaStr', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDatoRow(BuildContext context, String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(etiqueta, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(flex: 3, child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          CopyIconButtonWidget(etiqueta: etiqueta, valor: valor),
        ],
      ),
    );
  }
}

// =========================================================================
// 🎬 SUBSISTEMA DE REPRODUCCIÓN (Dialog Modal Autónomo)
// =========================================================================
void _mostrarDialogoVideo(BuildContext context, String urlVideo) {
  showDialog(
    context: context,
    builder: (context) => _VideoPlayerDialog(urlVideo: urlVideo),
  );
}

class _VideoPlayerDialog extends StatefulWidget {
  final String urlVideo;
  const _VideoPlayerDialog({required this.urlVideo});

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool _inicializado = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.urlVideo))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _inicializado = true;
            _controller.play(); 
          });
        }
      }).catchError((error) {
        if (mounted) {
          setState(() {
            _error = true;
          });
        }
      });
  }

  @override
  void dispose() {
    // 🧹 Mantenimiento de Memoria RAM
    _controller.dispose(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      backgroundColor: Colors.black,
      content: SizedBox(
        width: 600,
        height: 400,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_error)
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 48),
                    SizedBox(height: 16),
                    Text('Falla de decodificación o bloqueo CORS', style: TextStyle(color: Colors.white)),
                  ],
                ),
              )
            else if (_inicializado)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              )
            else
              const Center(child: CircularProgressIndicator(color: Colors.teal)),
            
            // Actuador de cierre
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // Telemetría de reproducción (Play/Pause)
            if (_inicializado && !_error)
              Positioned(
                bottom: 8,
                child: IconButton(
                  icon: Icon(
                    _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 36,
                  ),
                  onPressed: () {
                    setState(() {
                      _controller.value.isPlaying ? _controller.pause() : _controller.play();
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}