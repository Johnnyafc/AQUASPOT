import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:url_launcher/url_launcher.dart'; 
import '../../../../core/enum/segmento_operativo.dart';
import '../../../../core/enum/ticket_enums.dart'; 
import '../../domain/entities/ticket_entity.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';

class FormularioEntregaPage extends StatefulWidget {
  final TicketEntity ticket;
  const FormularioEntregaPage({super.key, required this.ticket});

  @override
  State<FormularioEntregaPage> createState() => _FormularioEntregaPageState();
}

class _FormularioEntregaPageState extends State<FormularioEntregaPage> {
  final TextEditingController _observacionController = TextEditingController();
  
  fp.PlatformFile? _guiaRemision;
  fp.PlatformFile? _factura;

  Future<void> _abrirEnlaceBD(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Circuito bloqueado por el SO.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Error al abrir el documento almacenado.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _seleccionarGuia() async {
    final result = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result != null) {
      setState(() => _guiaRemision = result.files.first);
    }
  }

  Future<void> _seleccionarFactura() async {
    final result = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result != null) {
      setState(() => _factura = result.files.first);
    }
  }

  void _eliminarGuia() => setState(() => _guiaRemision = null);
  void _eliminarFactura() => setState(() => _factura = null);

  Map<String, String> _obtenerDatosOperador() {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      return {'nombre': authState.usuario.nombre, 'rol': authState.usuario.rol.name.toUpperCase()};
    }
    return {'nombre': 'DESCONOCIDO', 'rol': 'SIN_ROL'};
  }

  void _ejecutarDespachoGuia() {
    if (_guiaRemision == null) return;
    final operador = _obtenerDatosOperador();
    context.read<TicketBloc>().add(
      ProcesarEntregaGuiaEvent(
        ticket: widget.ticket,
        guiaRemision: _guiaRemision!,
        observacion: _observacionController.text.trim(),
        nombreUsuario: operador['nombre']!,
        rolUsuario: operador['rol']!,
      ),
    );
  }

  void _ejecutarDespachoFactura() {
    if (_factura == null) return;
    final operador = _obtenerDatosOperador();
    context.read<TicketBloc>().add(
      ProcesarEntregaFacturaEvent(
        ticket: widget.ticket,
        factura: _factura!,
        observacion: _observacionController.text.trim(),
        nombreUsuario: operador['nombre']!,
        rolUsuario: operador['rol']!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🧠 LECTURA DE SENSORES ESTÁTICOS
    final bool tieneGuiaBD = widget.ticket.urlGuiaRemision != null && widget.ticket.urlGuiaRemision!.isNotEmpty;
    final bool tieneFacturaBD = widget.ticket.urlFactura != null && widget.ticket.urlFactura!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('Despacho: ${widget.ticket.id}'),
        backgroundColor: const Color(0xFF005A9C),
        foregroundColor: Colors.white,
      ),
      body: BlocListener<TicketBloc, TicketState>(
        listener: (context, state) {
          if (state.status == TicketStatus.operationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Transmisión completada y registrada.'), backgroundColor: Colors.green)
            );
            context.read<TicketBloc>().add(const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.ninguno));
            Navigator.pop(context);
          } else if (state.status == TicketStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red)
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              Card(
                elevation: 2,
                color: Colors.blueGrey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Datos de Salida', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Divider(),
                      Text('Equipo: ${widget.ticket.equipo.name.toUpperCase()}'),
                      Text('Cliente: ${widget.ticket.clienteId}'),
                      Text('Estación Actual: ${widget.ticket.estadoActual.name.toUpperCase()}', 
                        style: TextStyle(color: Colors.blueGrey.shade800, fontWeight: FontWeight.bold)
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text('Circuitos de Despacho (Libre Acceso)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),

              BlocBuilder<TicketBloc, TicketState>(
                builder: (context, state) {
                  final bool procesando = state.status == TicketStatus.loading;
                  
                  final bool tieneGuiaRAM = _guiaRemision != null;
                  final bool tieneFacturaRAM = _factura != null;

                  return Column(
                    children: [
                      // ------------------------------------------
                      // CARRIL 1: GUÍA DE REMISIÓN (DESBLOQUEADO)
                      // ------------------------------------------
                      Card(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: (tieneGuiaRAM || tieneGuiaBD) ? Colors.green : Colors.grey.shade300, 
                            width: 1.5
                          ),
                          borderRadius: BorderRadius.circular(8)
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(Icons.local_shipping, color: (tieneGuiaRAM || tieneGuiaBD) ? Colors.green : Colors.grey),
                              title: const Text('Guía de Remisión', style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: tieneGuiaRAM 
                                  ? Text('NUEVO: ${_guiaRemision!.name}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))
                                  : tieneGuiaBD
                                      ? const Text('✅ Registrado en Base de Datos', style: TextStyle(color: Colors.green))
                                      : const Text('Permitido subir en cualquier fase'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (tieneGuiaBD && !tieneGuiaRAM)
                                    IconButton(
                                      icon: const Icon(Icons.remove_red_eye, color: Colors.blue),
                                      tooltip: 'Ver documento guardado',
                                      onPressed: () => _abrirEnlaceBD(widget.ticket.urlGuiaRemision!),
                                    ),
                                  if (tieneGuiaRAM)
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red), 
                                      tooltip: 'Descartar reemplazo',
                                      onPressed: procesando ? null : _eliminarGuia
                                    )
                                  else
                                    ElevatedButton.icon(
                                      onPressed: procesando ? null : _seleccionarGuia, 
                                      icon: Icon(tieneGuiaBD ? Icons.autorenew : Icons.upload_file), 
                                      label: Text(tieneGuiaBD ? 'Reemplazar' : 'Adjuntar')
                                    ),
                                ],
                              ),
                            ),
                            if (tieneGuiaRAM) ...[
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: procesando ? null : _ejecutarDespachoGuia,
                                    icon: procesando ? const SizedBox.shrink() : const Icon(Icons.cloud_upload),
                                    label: procesando 
                                      ? const CircularProgressIndicator(color: Colors.white) 
                                      : Text(tieneGuiaBD ? 'SOBRESCRIBIR GUÍA' : 'SUBIR GUÍA', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade700,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              )
                            ]
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ------------------------------------------
                      // CARRIL 2: FACTURA COMERCIAL (DESBLOQUEADO)
                      // ------------------------------------------
                      Card(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: (tieneFacturaRAM || tieneFacturaBD) ? Colors.green : Colors.grey.shade300, width: 1.5),
                          borderRadius: BorderRadius.circular(8)
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(Icons.receipt_long, color: (tieneFacturaRAM || tieneFacturaBD) ? Colors.green : Colors.grey),
                              title: const Text('Factura Comercial', style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: tieneFacturaRAM 
                                  ? Text('NUEVO: ${_factura!.name}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))
                                  : tieneFacturaBD
                                      ? const Text('✅ Registrado en Base de Datos', style: TextStyle(color: Colors.green))
                                      : const Text('Permitido subir en cualquier fase'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (tieneFacturaBD && !tieneFacturaRAM)
                                    IconButton(
                                      icon: const Icon(Icons.remove_red_eye, color: Colors.blue),
                                      tooltip: 'Ver documento guardado',
                                      onPressed: () => _abrirEnlaceBD(widget.ticket.urlFactura!),
                                    ),
                                  if (tieneFacturaRAM)
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red), 
                                      tooltip: 'Descartar reemplazo',
                                      onPressed: procesando ? null : _eliminarFactura
                                    )
                                  else
                                    ElevatedButton.icon(
                                      onPressed: procesando ? null : _seleccionarFactura, 
                                      icon: Icon(tieneFacturaBD ? Icons.autorenew : Icons.upload_file), 
                                      label: Text(tieneFacturaBD ? 'Reemplazar' : 'Adjuntar')
                                    ),
                                ],
                              ),
                            ),
                            if (tieneFacturaRAM) ...[
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: procesando ? null : _ejecutarDespachoFactura,
                                    icon: procesando ? const SizedBox.shrink() : const Icon(Icons.cloud_upload),
                                    label: procesando 
                                      ? const CircularProgressIndicator(color: Colors.white) 
                                      : Text(tieneFacturaBD ? 'SOBRESCRIBIR FACTURA' : 'SUBIR FACTURA', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              )
                            ]
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _observacionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observaciones de Despacho (Opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.comment),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}