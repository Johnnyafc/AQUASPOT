import 'package:aquaspot_postventa/core/services/borrador_storage_service.dart';
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
import '../widgets/copy_icon_button_widget.dart';
import '../widgets/tarjeta_no_requiere_compras_widget.dart';

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

  @override
  void initState() {
    super.initState();
    _observacionController.addListener(_guardarBorrador);
    _cargarBorradorLocal();
  }

  void _guardarBorrador() {
    BorradorStorageService.guardarBorrador(
      clave: BorradorStorageService.claveDraftEntrega(widget.ticket.id),
      datos: {
        'observacion': _observacionController.text,
        'guiaPath': _guiaRemision?.path,
        'facturaPath': _factura?.path,
      },
    );
  }

  Future<void> _cargarBorradorLocal() async {
    final draft = await BorradorStorageService.obtenerBorrador(
      BorradorStorageService.claveDraftEntrega(widget.ticket.id),
    );
    if (draft != null && mounted) {
      setState(() {
        if (draft['observacion'] != null && (draft['observacion'] as String).isNotEmpty) {
          _observacionController.text = draft['observacion'] as String;
        }
        if (draft['guiaPath'] != null) {
          _guiaRemision = BorradorStorageService.pathToPlatformFile(draft['guiaPath'] as String);
        }
        if (draft['facturaPath'] != null) {
          _factura = BorradorStorageService.pathToPlatformFile(draft['facturaPath'] as String);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💾 Borrador de entrega restaurado.'),
          backgroundColor: Color(0xFF005A9C),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _observacionController.removeListener(_guardarBorrador);
    _observacionController.dispose();
    super.dispose();
  }

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
      _guardarBorrador();
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
      _guardarBorrador();
    }
  }

  void _eliminarGuia() {
    setState(() => _guiaRemision = null);
    _guardarBorrador();
  }

  void _eliminarFactura() {
    setState(() => _factura = null);
    _guardarBorrador();
  }

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

  // ⚙️ SUBRUTINA: Fila de dato con botón de copiar
  Widget _buildFilaDato(BuildContext context, String etiqueta, String valor, {TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        children: [
          Expanded(
            child: Text('$etiqueta $valor', style: style),
          ),
          CopyIconButtonWidget(etiqueta: etiqueta, valor: valor),
        ],
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
              TarjetaNoRequiereComprasWidget(ticket: widget.ticket),
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
                      _buildFilaDato(context, 'Ticket:', widget.ticket.id),
                      _buildFilaDato(context, 'Numero de serie:', '${widget.ticket.numeroSerie}'),
                      _buildFilaDato(context, 'Marca:', '${widget.ticket.marca}'),
                      _buildFilaDato(context, 'Equipo:', widget.ticket.equipo.name.toUpperCase()),
                      _buildFilaDato(context, 'Cliente:', widget.ticket.clienteId),
                      _buildFilaDato(
                        context,
                        'Estación Actual:',
                        widget.ticket.estadoActual.name.toUpperCase(),
                        style: TextStyle(color: Colors.blueGrey.shade800, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ==========================================
              // 🚨 BALIZA: SE FACTURA COMO GARANTÍA
              // ==========================================
              if (widget.ticket.esGarantia == true)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    border: Border.all(color: Colors.amber.shade700, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.policy, color: Colors.amber.shade900, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Se factura como garantía',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),

              // ==========================================
              // 📎 ADJUNTO: ORDEN DE VENTA
              // ==========================================
              if (widget.ticket.codigoOrdenVenta.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long, color: Colors.blueAccent, size: 28),
                    title: const Text('Orden de Venta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Documento comercial adjunto al requerimiento.', style: TextStyle(fontSize: 11)),
                    trailing: ElevatedButton.icon(
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Ver'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => _abrirEnlaceBD(widget.ticket.codigoOrdenVenta.first),
                    ),
                  ),
                ),

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