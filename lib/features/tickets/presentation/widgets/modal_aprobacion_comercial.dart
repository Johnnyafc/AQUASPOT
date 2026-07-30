import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// ⚠️ Ajusta estas importaciones a tus rutas reales si es necesario
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../../domain/entities/ticket_entity.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:cross_file/cross_file.dart'; // O 'package:image_picker/image_picker.dart' si ya lo tienes

class ModalAprobacionComercial extends StatefulWidget {
  final TicketEntity ticket;

  const ModalAprobacionComercial({Key? key, required this.ticket}) : super(key: key);

  // ⚙️ Actuador estático
  static Future<void> show(BuildContext context, TicketEntity ticket) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<TicketBloc>()),
          BlocProvider.value(value: context.read<AuthBloc>()),
        ],
        child: ModalAprobacionComercial(ticket: ticket),
      ),
    );
  }

  @override
  State<ModalAprobacionComercial> createState() => _ModalAprobacionComercialState();
}

class _ModalAprobacionComercialState extends State<ModalAprobacionComercial> {
  // 📥 Bandejas de carga
  final List<dynamic> _ordenesVenta = [];
  final List<dynamic> _ordenesCompra = [];
  String _numeroOrdenExtraido = '';

  // 🔒 Enclavamiento mecánico
  bool get _isBotonHabilitado => _ordenesVenta.isNotEmpty;

  // 🔌 Conecta aquí tu FilePicker o CameraManager
// 🔌 ACTUADOR REAL: Lector de archivos del dispositivo
Future<void> _seleccionarOrdenVenta() async {
  FilePickerResult? result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    withData: true, 
  );

  if (result != null && result.files.isNotEmpty) {
    final file = result.files.single;
    final nombreCompleto = file.name;

    // 1. Decapado de la extensión del archivo
    final nombreSinExtension = nombreCompleto.contains('.')
        ? nombreCompleto.substring(0, nombreCompleto.lastIndexOf('.'))
        : nombreCompleto;

    // 2. Transacción sin restricciones: Se acepta cualquier nomenclatura
    setState(() {
      _ordenesVenta.add(file);
      _numeroOrdenExtraido = nombreSinExtension.toUpperCase(); 
    });
  }
}

  Future<void> _seleccionarOrdenCompra() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
     
    if (result != null && result.files.single != null) {
      setState(() {
        _ordenesCompra.add(result.files.single);
      });
    }
  }

void _dispararAprobacion() {
    if (!_isBotonHabilitado) return; 

    final authState = context.read<AuthBloc>().state;
    String nombreOp = 'SISTEMA';
    String rolOp = 'COMERCIAL';

    if (authState is Authenticated) {
      nombreOp = authState.usuario.nombre;
      rolOp = authState.usuario.rol.name.toUpperCase();
    }
   context.read<TicketBloc>().add(
      AprobarProformaComercialEvent(
        ticket: widget.ticket,
        // Pasamos la lista de objetos PlatformFile directamente
        ordenesVentaArchivos: _ordenesVenta, 
        ordenesCompraArchivos: _ordenesCompra,
        nombreUsuario: nombreOp,
        rolUsuario: rolOp,
        numeroOrdenVenta: _numeroOrdenExtraido,
      ),
    );
  }
  // 🏭 Sub-ensamble visual para las cajas de subida
  Widget _buildBandejaArchivos({
    required String titulo,
    required bool obligatorio,
    required List<dynamic> archivos,
    required VoidCallback onAdd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, color: obligatorio ? Colors.black87 : Colors.grey)),
            if (obligatorio) const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              if (archivos.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Ningún archivo adjuntado', style: TextStyle(color: Colors.grey)),
                ),
              ...archivos.map((archivo) => ListTile(
                dense: true,
                leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                // ⚙️ Extracción del metadato original del nombre
                title: Text(archivo is PlatformFile ? archivo.name : archivo.toString(), style: const TextStyle(fontSize: 13)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.grey, size: 20),
                  onPressed: () => setState(() => archivos.remove(archivo)),
                ),
              )).toList(),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.upload_file),
                label: const Text('Adjuntar Archivo'),
              )
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 24,
      ),
      child: BlocConsumer<TicketBloc, TicketState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status == TicketStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          } else if (state.status == TicketStatus.operationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transición comercial exitosa'), backgroundColor: Colors.green));
            if (context.mounted) Navigator.pop(context);
          }
        },
        builder: (context, state) {
          final isProcessing = state.status == TicketStatus.loading;

          return AbsorbPointer(
            absorbing: isProcessing,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Aprobar Ticket ${widget.ticket.id}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF005A9C))),
                      IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context))
                    ],
                  ),
                  const Divider(thickness: 2),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        SizedBox(width: 12),
                        Expanded(child: Text('Al confirmar, el ticket se derivará simultáneamente a Costos y Compras.', style: TextStyle(fontSize: 13))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ⚙️ MÓDULO 1: ORDEN DE VENTA
                  _buildBandejaArchivos(
                    titulo: 'Orden de Venta',
                    obligatorio: true,
                    archivos: _ordenesVenta,
                    onAdd: _seleccionarOrdenVenta,
                  ),
                  const SizedBox(height: 24),

                  // ⚙️ MÓDULO 2: ORDEN DE COMPRA
                  _buildBandejaArchivos(
                    titulo: 'Orden de Compra Cliente',
                    obligatorio: false,
                    archivos: _ordenesCompra,
                    onAdd: _seleccionarOrdenCompra,
                  ),
                  const SizedBox(height: 32),

                  // ⚡ ACTUADOR PRINCIPAL
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isBotonHabilitado ? Colors.green.shade700 : Colors.grey,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: isProcessing ? null : _dispararAprobacion,
                      icon: isProcessing 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline, color: Colors.white),
                      label: Text(
                        isProcessing ? 'PROCESANDO TRÁMITE...' : 'CONFIRMAR Y DERIVAR', 
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}