import 'package:flutter/services.dart';
import '../../../inventario/presentation/bloc/inventario_bloc.dart';
import '../../../inventario/presentation/bloc/inventario_state.dart';
// lib/features/tickets/presentation/pages/gestion_compras_page.dart

import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import '../../domain/entities/item_despacho_bodega_entity.dart';
import '../../../inventario/domain/entities/item_inventario_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_state.dart';
import '../../domain/entities/ticket_entity.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/utils/web_previsualizador.dart';
import '../widgets/tarjeta_no_requiere_compras_widget.dart';

class GestionComprasPage extends StatefulWidget {
  final TicketEntity ticket;

  const GestionComprasPage({Key? key, required this.ticket}) : super(key: key);

  @override
  State<GestionComprasPage> createState() => _GestionComprasPageState();
}

class _GestionComprasPageState extends State<GestionComprasPage> {
  final TextEditingController _observacionController = TextEditingController();
  
  // ⚙️ MATRIZ DE ALMACENAMIENTO TEMPORAL (Bornera múltiple)
  List<XFile> _archivosOrdenCompra = [];

  @override
  void dispose() {
    _observacionController.dispose();
    super.dispose();
  }

  // ⚙️ ACTUADOR: Selector de archivos múltiples (Calibrado para WEB)
  Future<void> _seleccionarArchivos() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
      allowMultiple: true, 
      withData: true, // ⚠️ CRÍTICO: Obliga al navegador a leer la RAM en entorno web
    );

    if (result != null) {
      setState(() {
        for (var file in result.files) {
          // Sensor anti-colisiones validando el nombre real
          if (!_archivosOrdenCompra.any((x) => x.name == file.name)) {
            if (file.bytes != null) {
              // Ensamblamos el XFile inyectando explícitamente los bytes y el nombre para entorno Web
              _archivosOrdenCompra.add(
                XFile.fromData(
                  file.bytes!, 
                  name: file.name, 
                  path: file.path, 
                ),
              );
            }
          }
        }
      });
    }
  }

  // ⚙️ LECTURA: Pre-visualización de archivos forzando el MIME Type
  // ⚙️ LECTURA: Pre-visualización Web (Estándar Wasm / package:web)
  Future<void> _previsualizarArchivoLocal(XFile archivo) async {
    try {
      // 1. Extraemos los bytes puros de la RAM
      final bytes = await archivo.readAsBytes();

      // 2. Calibración del Sensor MIME
      String mimeType = 'application/pdf'; 
      final extension = archivo.name.toLowerCase();
      
      if (extension.endsWith('.jpg') || extension.endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      } else if (extension.endsWith('.png')) {
        mimeType = 'image/png';
      }

      // 3. Delegamos la parte de JS Interop al helper aislado (solo se
      // compila en Web; en Android/iOS ni siquiera existe package:web).
      await abrirBlobEnNuevaPestana(bytes, mimeType);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cortocircuito de memoria al abrir documento: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🗑️ DESCONEXIÓN: Remueve un archivo de la cola
  void _removerArchivo(int index) {
    setState(() {
      _archivosOrdenCompra.removeAt(index);
    });
  }

  // ⚙️ LECTURA: Abrir proforma en el navegador/app externa
  Future<void> _abrirProformaExcel(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No se pudo abrir el enlace de telemetría.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 🚀 EJECUCIÓN: Disparo del evento al BLoC
  void _ejecutarPasoABodega() {
    // ⚙️ SENSOR DE VACÍO DESACTIVADO (Bypass autorizado)
    // Se elimina el bloqueo estricto de 'archivosOrdenCompra'. 
    // Si la lista está vacía, el sistema asumirá abastecimiento desde stock local.

    final authState = context.read<AuthBloc>().state;
    String operador = 'DESCONOCIDO';
    String rol = 'SIN_ROL';

    if (authState is Authenticated) {
      operador = authState.usuario.nombre;
      rol = authState.usuario.rol.name.toUpperCase();
    } 

    // 🔍 Sincronización en vivo con el catálogo de inventario en bodega
    final invState = context.read<InventarioBloc>().state;
    final Map<String, ItemInventarioEntity> mapaStock =
        invState is InventarioLoaded ? invState.mapaPorCodigo : {};

    final baseItems = widget.ticket.itemsDespachoBodega.isNotEmpty
        ? widget.ticket.itemsDespachoBodega
        : (widget.ticket.evaluacionTecnica?.repuestosTaller ?? []).map((r) => ItemDespachoBodegaEntity(
            codigo: r.codigo,
            descripcion: r.descripcion,
            unidad: r.unidad,
            cantidadSolicitada: r.cantidad,
            stockDisponibleAlEvaluar: 0.0,
            validadoPorCompras: false,
            cantidadDespachada: 0.0,
            fechaSolicitud: widget.ticket.historialEventos.isNotEmpty
                ? widget.ticket.historialEventos.first.timestamp
                : DateTime.now(),
          )).toList();

    final itemsActualizados = baseItems.map((i) {
      final codKey = i.codigo.trim().toUpperCase();
      final stockItem = mapaStock[codKey];
      final double stockReal = stockItem?.stockDisponible ?? i.stockDisponibleAlEvaluar;
      final bool tieneStock = stockReal >= i.cantidadSolicitada;
      return i.copyWith(
        stockDisponibleAlEvaluar: stockReal > i.stockDisponibleAlEvaluar ? stockReal : i.stockDisponibleAlEvaluar,
        validadoPorCompras: i.validadoPorCompras || tieneStock || widget.ticket.noRequiereCompras,
      );
    }).toList();
    
    context.read<TicketBloc>().add(
      ProcesarGestionComprasEvent(
        ticket: widget.ticket,
        // ⚙️ BUS DE DATOS: Transmite la matriz (llena o vacía)
        archivosOrdenCompra: _archivosOrdenCompra, 
        observacion: _observacionController.text,
        nombreUsuario: operador,
        rolUsuario: rol,
        itemsActualizados: itemsActualizados,
      ),
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ejecutando secuencia: Transfiriendo ticket a Bodega...'), backgroundColor: Colors.teal),
    );
  }

  Future<void> _abrirDocumentoOV(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Falla de hardware: No se pudo abrir el documento.'),
            backgroundColor: Colors.red,
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🧠 SENSOR MAESTRO: Evaluación de garantía activa
    final bool esGarantiaActiva = widget.ticket.tipoRequerimiento == TipoRequerimiento.reclamoGarantia &&
                                  widget.ticket.tipoGarantia != null && 
                                  widget.ticket.tipoGarantia!.trim().isNotEmpty && 
                                  widget.ticket.tipoGarantia!.toLowerCase() != 'ninguna' &&
                                  widget.ticket.tipoGarantia!.toLowerCase() != 'pendiente' &&
                                  widget.ticket.esGarantia != false; 

    // Detección si el ticket inició como garantía pero fue rechazado
    final bool esReclamoNegado = widget.ticket.tipoRequerimiento == TipoRequerimiento.reclamoGarantia &&
                                 widget.ticket.esGarantia == false;

    final String codigoProyecto = widget.ticket.codigoProyecto ?? 'SIN ASIGNAR';
    final String ordenVenta = widget.ticket.numeroOrdenVenta ?? 'N/A';
    final List<String> urlsGarantia = widget.ticket.evaluacionTecnica?.urlsAdjuntosPdfGarantia ?? [];

    // ==============================================================================
    // 🧠 MULTIPLEXOR DE TELEMETRÍA (Prioridad al array nuevo, fallback al string)
    // ==============================================================================
    final List<String> excelUrls = widget.ticket.proforma?.excelUrls ?? [];
    final String? urlProformaLegacy = widget.ticket.evaluacionTecnica?.urlProformaExcel;
    
    final String? urlProformaDefinitiva = excelUrls.isNotEmpty 
        ? excelUrls.first 
        : (urlProformaLegacy != null && urlProformaLegacy.trim().isNotEmpty ? urlProformaLegacy : null);

    return Scaffold(
      appBar: AppBar(
        title: Text('Estación Compras: ${widget.ticket.id}'),
        backgroundColor: Colors.teal.shade800,
      ),
      body: BlocListener<TicketBloc, TicketState>(
        listener: (context, state) {
          if (state.status == TicketStatus.operationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Órdenes procesadas. Ticket transferido a Bodega.'), backgroundColor: Colors.green),
            );
            Navigator.pop(context);
          } else if (state.status == TicketStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TarjetaNoRequiereComprasWidget(ticket: widget.ticket),
              // ==========================================
              // 🔍 PANEL DE TELEMETRÍA (Solo Lectura)
              // ==========================================
              Card(
                elevation: 3,
                color: esReclamoNegado ? Colors.red.shade50 : Colors.blueGrey.shade50,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: esReclamoNegado ? Colors.red.shade300 : Colors.blueGrey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            esReclamoNegado ? Icons.warning_amber_rounded : Icons.monitor, 
                            color: esReclamoNegado ? Colors.red.shade900 : Colors.blueGrey
                          ),
                          const SizedBox(width: 8),
                          Text(
                            esReclamoNegado ? 'GARANTÍA NEGADA - FLUJO COMERCIAL' : 'Datos Base y Trazabilidad', 
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 16,
                              color: esReclamoNegado ? Colors.red.shade900 : Colors.black87,
                            )
                          ),
                        ],
                      ),
                      const Divider(),
                      
                      if (esReclamoNegado) ...[
                        const Text(
                          '⚠️ Este ticket inició por garantía pero fue rechazado por ingeniería. Se procesa con la Orden de Venta comercial original.',
                          style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 12),
                      ],

                      _buildReadoutRow('Equipo y Marca:', '${widget.ticket.equipo.name.toUpperCase()} • Marca: ${widget.ticket.marca.toUpperCase()}'),
                      const SizedBox(height: 8),
                      _buildReadoutRow('Código de Proyecto (Costos):', codigoProyecto, isHighlighted: true),
                      const SizedBox(height: 12),
                      
                      // ==========================================
                      // 🔌 LÍNEA BASE INNEGOCIABLE: LA OV COMERCIAL SIEMPRE SE MUESTRA
                      // ==========================================
                      _buildReadoutRow('Orden de Venta (Comercial):', ordenVenta),
                      const SizedBox(height: 8),
                      
                      if (widget.ticket.codigoOrdenVenta.isNotEmpty)
                        _buildPdfDownloadContainer(
                          context: context,
                          titulo: 'Orden de Venta (OV) Comercial Adjunta',
                          subtitulo: 'Requerimiento comercial base para compras.',
                          urlPDF: widget.ticket.codigoOrdenVenta.first,
                        )
                      else
                        const Text('⚠️ No se detectó documento de Orden de Venta comercial adjunto.', style: TextStyle(color: Colors.red, fontSize: 12)),

                      // ==========================================
                      // 🔌 BLOQUE COMPLEMENTARIO: SI ES GARANTÍA APROBADA, AÑADIMOS SU RESPALDO TÉCNICO
                      // ==========================================
                      if (esGarantiaActiva) ...[
                        const Divider(height: 24),
                        Row(
                          children: [
                            Icon(Icons.policy, size: 18, color: Colors.amber.shade900),
                            const SizedBox(width: 6),
                            Text(
                              'RESPALDO DE GARANTÍA (${widget.ticket.tipoGarantia!.toUpperCase()})',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildReadoutRow(
                          widget.ticket.tipoGarantia == 'servicio' ? 'OV de Servicio Antiguo:' : 'OV de Máquina Nueva:',
                          widget.ticket.evaluacionTecnica?.numeroOVGarantia ?? 'No registrada'
                        ),
                        const SizedBox(height: 8),

                        if (urlsGarantia.isNotEmpty)
                          _buildPdfDownloadContainer(
                            context: context,
                            titulo: widget.ticket.tipoGarantia == 'servicio' ? 'Descargar OV de Servicio' : 'Descargar OV de Máquina',
                            subtitulo: 'Documento técnico de respaldo de garantía.',
                            urlPDF: urlsGarantia.first,
                            colorAcento: Colors.amber.shade900,
                          ),

                        if (widget.ticket.evaluacionTecnica?.urlPdfRevisionTecnicaAntigua != null && widget.ticket.evaluacionTecnica!.urlPdfRevisionTecnicaAntigua!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildPdfDownloadContainer(
                            context: context,
                            titulo: 'Descargar Revisión Técnica Antigua',
                            subtitulo: 'Respaldo del servicio anterior en garantía.',
                            urlPDF: widget.ticket.evaluacionTecnica!.urlPdfRevisionTecnicaAntigua!,
                            colorAcento: Colors.deepOrange.shade800,
                          ),
                        ],
                      ],

                      const SizedBox(height: 8),
                      const Divider(),
                      
                      // ==========================================
                      // Enlace a la proforma técnica (Multiplexado)
                      // ==========================================
                      const Text('Matriz de Costeo (Taller):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 4),
                      if (urlProformaDefinitiva != null)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.table_view, color: Colors.green),
                          title: const Text('Descargar Proforma Técnica (Excel)', style: TextStyle(decoration: TextDecoration.underline, color: Colors.blue)),
                          trailing: const Icon(Icons.download, size: 20),
                          onTap: () => _abrirProformaExcel(urlProformaDefinitiva), 
                        )
                      else
                        const Text('⚠️ No se detectó archivo de costeo.', style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ),
              
              _buildTablaMaterialesInternos(),

              const SizedBox(height: 24),

              // ==========================================
              // 🎛️ PANEL DE CONTROL (Actuadores Compras)
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Carga Documental (Órdenes de Compra)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ElevatedButton.icon(
                    onPressed: _seleccionarArchivos,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Añadir'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade50,
                      foregroundColor: Colors.teal.shade800,
                      elevation: 0,
                      side: BorderSide(color: Colors.teal.shade200),
                    ),
                  ),
                ],
              ),
              const Divider(),
              
              // INDICADOR DE ESTADO VACÍO
              if (_archivosOrdenCompra.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'No hay documentos en cola.\n(Opcional) Toque "Añadir" si requiere inyectar una Orden de Compra externa.', 
                      textAlign: TextAlign.center, 
                      style: TextStyle(color: Colors.grey)
                    ),
                  ),
                )
              else
                // 📋 LISTA DE ARCHIVOS EN COLA (Bornera de visualización)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _archivosOrdenCompra.length,
                  itemBuilder: (context, index) {
                    final archivo = _archivosOrdenCompra[index];
                    return Card(
                      elevation: 0,
                      color: Colors.teal.shade50,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.teal.shade200),
                        borderRadius: BorderRadius.circular(6)
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.insert_drive_file, color: Colors.teal),
                        title: Text(archivo.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: const Text('Toque para pre-visualizar', style: TextStyle(fontSize: 11, color: Colors.teal)),
                        onTap: () => _previsualizarArchivoLocal(archivo), // Actuador de lectura local (Bypass activado)
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: 'Remover de la cola',
                          onPressed: () => _removerArchivo(index), // Actuador de desconexión
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 20),

              TextField(
                controller: _observacionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Observaciones de Compras (Opcional)',
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.teal.shade700, width: 2)),
                ),
              ),

              const SizedBox(height: 32),

              // ==========================================
              // 🚀 BOTÓN DE TRANSFERENCIA (A Bodega)
              // ==========================================
              BlocBuilder<TicketBloc, TicketState>(
                builder: (context, state) {
                  final bool procesando = state.status == TicketStatus.loading;
                  final bool procesadoPorCostos = widget.ticket.estadoActual == EstadoTicket.compras || 
                                                  widget.ticket.isCostosCompletado;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!procesadoPorCostos)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock, color: Colors.red),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'ACCIÓN BLOQUEADA: El departamento de Costos debe generar el código de proyecto y aprobar la proforma antes de enviar a Bodega.',
                                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),

                      ElevatedButton.icon(
                        onPressed: (procesando || !procesadoPorCostos) ? null : _ejecutarPasoABodega,
                        icon: procesando 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.move_to_inbox),
                        label: Text(
                          procesando 
                              ? 'TRANSMITIENDO...' 
                              : (widget.ticket.noRequiereCompras 
                                  ? 'ENVIAR A BODEGA (SIN COMPRAS)' 
                                  : 'REGISTRAR ÓRDENES Y ENVIAR A BODEGA'), 
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.ticket.noRequiereCompras ? Colors.deepOrange.shade800 : Colors.teal.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          disabledBackgroundColor: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPdfDownloadContainer({
    required BuildContext context, 
    required String titulo, 
    required String subtitulo, 
    required String urlPDF,
    Color colorAcento = Colors.redAccent,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade100, 
        border: Border.all(color: Colors.blueGrey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.picture_as_pdf, color: colorAcento, size: 28),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Text(subtitulo, style: const TextStyle(fontSize: 11)),
        trailing: ElevatedButton.icon(
          icon: const Icon(Icons.download, size: 16),
          label: const Text('Descargar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onPressed: () => _abrirDocumentoOV(context, urlPDF),
        ),
      ),
    );
  }

  Widget _buildReadoutRow(String label, String value, {bool isHighlighted = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.blueGrey))),
        Expanded(
          flex: 3, 
          child: Text(
            value, 
            style: TextStyle(
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              color: isHighlighted ? Colors.black : Colors.black87,
              fontSize: 14
            ),
          )
        ),
      ],
    );
  }

  // ==========================================================================
  // 🔩 TABLA DE MATERIALES INTERNOS DE TALLER / BODEGA (SOLO LECTURA)
  // ==========================================================================
  Widget _buildTablaMaterialesInternos() {
    final repuestosTaller = widget.ticket.itemsDespachoBodega.isNotEmpty
        ? widget.ticket.itemsDespachoBodega.map((i) => {
            'codigo': i.codigo,
            'descripcion': i.descripcion,
            'unidad': i.unidad,
            'cantidad': i.cantidadSolicitada,
          }).toList()
        : (widget.ticket.evaluacionTecnica?.repuestosTaller ?? []).map((r) => {
            'codigo': r.codigo,
            'descripcion': r.descripcion,
            'unidad': r.unidad,
            'cantidad': r.cantidad,
          }).toList();

    return BlocBuilder<InventarioBloc, InventarioState>(
      builder: (context, invState) {
        final mapaStock = invState is InventarioLoaded ? invState.mapaPorCodigo : {};

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.blueGrey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warehouse_outlined, color: Color(0xFF005A9C), size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Materiales Internos de Taller / Bodega',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF005A9C),
                        ),
                      ),
                    ),
                    if (repuestosTaller.isNotEmpty) ...[
                      TextButton.icon(
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('Copiar Códigos', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          final cods = repuestosTaller
                              .map((r) => r['codigo']?.toString() ?? '')
                              .where((c) => c.isNotEmpty)
                              .join('\n');
                          Clipboard.setData(ClipboardData(text: cods));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Códigos copiados al portapapeles'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.copy_all, size: 14),
                        label: const Text('Copiar Todo', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          final text = repuestosTaller
                              .map((r) => '${r['codigo']} - ${r['descripcion']} (${r['cantidad']} ${r['unidad']})')
                              .join('\n');
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Listado completo copiado al portapapeles'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Listado de solo lectura de los repuestos e insumos requeridos por taller, contrastados con el stock en bodega:',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Divider(height: 16),
                if (repuestosTaller.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'No hay materiales internos registrados para este ticket.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: repuestosTaller.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (context, index) {
                      final r = repuestosTaller[index];
                      final codigo = r['codigo']?.toString() ?? '';
                      final desc = r['descripcion']?.toString() ?? '';
                      final cant = (r['cantidad'] as num?)?.toDouble() ?? 0.0;
                      final und = r['unidad']?.toString() ?? 'UND';

                      final stockItem = mapaStock[codigo.toUpperCase().trim()];
                      final stock = stockItem?.stockDisponible ?? 0.0;
                      final bool tieneStock = stock >= cant;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Código con botón de copiado
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: codigo));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Código $codigo copiado'),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    codigo.isNotEmpty ? codigo : 'S/C',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: Color(0xFF0D47A1),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Icon(Icons.copy, size: 10, color: Color(0xFF0D47A1)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Descripción
                          Expanded(
                            child: Text(
                              desc,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Cantidad requerida
                          Text(
                            '$cant $und',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Badge de Stock
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: tieneStock
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: tieneStock
                                    ? const Color(0xFF81C784)
                                    : Colors.red.shade300,
                              ),
                            ),
                            child: Text(
                              tieneStock
                                  ? 'Stock: ${stock.toInt() == stock ? stock.toInt() : stock.toStringAsFixed(1)}'
                                  : 'Falta: ${(cant - stock).clamp(0, double.infinity).toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: tieneStock
                                    ? const Color(0xFF2E7D32)
                                    : Colors.red.shade800,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

}
