import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
// ⚠️ Importe sus entidades, bloc y rutas

class SubirEvidenciaTrabajoPage extends StatefulWidget {
  final TicketEntity ticket;
  const SubirEvidenciaTrabajoPage({super.key, required this.ticket});

  @override
  State<SubirEvidenciaTrabajoPage> createState() => _SubirEvidenciaTrabajoPageState();
}

class _SubirEvidenciaTrabajoPageState extends State<SubirEvidenciaTrabajoPage> {
  final List<PlatformFile> _fotosSeleccionadas = [];
  final List<PlatformFile> _videosSeleccionados = [];
  final TextEditingController _notasController = TextEditingController();

  Future<void> _seleccionarArchivos(FileType tipo) async {
    final result = await FilePicker.pickFiles(
      type: tipo,
      allowMultiple: true,
      withData: true, // ⚠️ CRÍTICO: Debe ser true para que funcione su validación kIsWeb en el DataSource
    );

    if (result != null) {
      setState(() {
        if (tipo == FileType.image) {
          _fotosSeleccionadas.addAll(result.files);
        } else if (tipo == FileType.video) {
          _videosSeleccionados.addAll(result.files);
        }
      });
    }
  }

  void _ejecutarEnvio() {
    if (_fotosSeleccionadas.isEmpty && _videosSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe adjuntar al menos una evidencia visual.'), backgroundColor: Colors.orange),
      );
      return;
    }
    final authState = context.read<AuthBloc>().state;
    String nombreOperario = 'SISTEMA';
    String rolOperario = 'DESCONOCIDO';
    
    if (authState is Authenticated) {
      nombreOperario = authState.usuario.nombre; 
      rolOperario = authState.usuario.rol.name.toUpperCase();
    }
    context.read<TicketBloc>().add(
      ProcesarEvidenciaTrabajoEvent(
        ticket: widget.ticket,
        fotos: _fotosSeleccionadas,
        videos: _videosSeleccionados,
        notasTecnicas: _notasController.text,
        nombreUsuario: nombreOperario, // Inyectar Auth
        rolUsuario:  rolOperario,             // Inyectar Auth
      )
    );
  }

  @override
  void dispose() {
    _notasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: Text('Ejecución: ${widget.ticket.id}'),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
      ),
      body: BlocListener<TicketBloc, TicketState>(
        listener: (context, state) {
          if (state.status == TicketStatus.operationSuccess) {
            Navigator.pop(context);
          } else if (state.status == TicketStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Datos del Equipo (Bloqueado)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 12),
              _buildDataCardBloqueada(),
              
              const SizedBox(height: 24),
              const Text("Evidencia Multimedia", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 12),
              
              // Selector de Fotos
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blueGrey.shade200)),
                leading: const Icon(Icons.add_a_photo, color: Colors.blueGrey),
                title: const Text('Adjuntar Fotografías'),
                subtitle: Text('${_fotosSeleccionadas.length} fotos seleccionadas'),
                trailing: ElevatedButton(
                  onPressed: () => _seleccionarArchivos(FileType.image),
                  child: const Text('EXAMINAR'),
                ),
              ),
              const SizedBox(height: 12),
              
              // Selector de Videos
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blueGrey.shade200)),
                leading: const Icon(Icons.video_call, color: Colors.blueGrey),
                title: const Text('Adjuntar Videos'),
                subtitle: Text('${_videosSeleccionados.length} videos seleccionados'),
                trailing: ElevatedButton(
                  onPressed: () => _seleccionarArchivos(FileType.video),
                  child: const Text('EXAMINAR'),
                ),
              ),

              const SizedBox(height: 24),
              TextField(
                controller: _notasController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Notas Técnicas de Reparación',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 32),
              BlocBuilder<TicketBloc, TicketState>(
                builder: (context, state) {
                  final procesando = state.status == TicketStatus.loading;
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: procesando ? null : _ejecutarEnvio,
                      icon: procesando ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.cloud_upload),
                      label: Text(procesando ? state.message : 'REGISTRAR TRABAJO Y FINALIZAR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                    ),
                  );
                }
              )
            ],
          ),
        ),
      ),
    );
  }

  // Componente de solo lectura
  Widget _buildDataCardBloqueada() {
    return Card(
      elevation: 1,
      color: Colors.grey.shade100, // Color que sugiere "solo lectura"
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Equipo: ${widget.ticket.equipo.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            Text('Falla Reportada: ${widget.ticket.fallaReportada}', style: TextStyle(color: Colors.grey.shade800)),
            // Agregue aquí los campos que considere estrictamente necesarios
          ],
        ),
      ),
    );
  }
}