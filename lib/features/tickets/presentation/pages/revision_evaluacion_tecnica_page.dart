// lib/features/tickets/presentation/pages/revision_evaluacion_tecnica_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:printing/printing.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/entities/actividad_evaluacion_seleccionada.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../widgets/copy_icon_button_widget.dart';
import '../../../catalogo/domain/entities/item_catalogo_entity.dart';

class RevisionEvaluacionTecnicaPage extends StatefulWidget {
  final TicketEntity ticket;
  final List<ActividadEvaluacionSeleccionada> actividadesSeleccionadas;
  final Uint8List excelBytes;
  final Uint8List pdfBytes;
  final bool noRequiereCompras;
  final String? motivoNoRequiereCompras;
  final fp.PlatformFile? documentoOVGarantia;
  final fp.PlatformFile? documentoRevisionAntigua;

  const RevisionEvaluacionTecnicaPage({
    super.key,
    required this.ticket,
    required this.actividadesSeleccionadas,
    required this.excelBytes,
    required this.pdfBytes,
    required this.noRequiereCompras,
    this.motivoNoRequiereCompras,
    this.documentoOVGarantia,
    this.documentoRevisionAntigua,
  });

  @override
  State<RevisionEvaluacionTecnicaPage> createState() => _RevisionEvaluacionTecnicaPageState();
}

class _RevisionEvaluacionTecnicaPageState extends State<RevisionEvaluacionTecnicaPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _descargarExcel() async {
    final fileName = 'Solicitud_Materiales_${widget.ticket.id}.xlsx';
    await Printing.sharePdf(bytes: widget.excelBytes, filename: fileName);
  }

  void _confirmarYSubir() {
    final authState = context.read<AuthBloc>().state;
    String nombreOperador = 'TECNICO_SERVICIO';
    String rolOperador = 'TECNICO';

    if (authState is Authenticated) {
      nombreOperador = authState.usuario.nombre;
      rolOperador = authState.usuario.rol.name.toUpperCase();
    }

    final excelFile = fp.PlatformFile(
      name: 'Solicitud_Materiales_${widget.ticket.id}.xlsx',
      size: widget.excelBytes.length,
      bytes: widget.excelBytes,
    );

    final pdfFile = fp.PlatformFile(
      name: 'Informe_Tecnico_${widget.ticket.id}.pdf',
      size: widget.pdfBytes.length,
      bytes: widget.pdfBytes,
    );

    // Disparar evento oficial al BLoC
    context.read<TicketBloc>().add(
      ProcesarEvaluacionDocumentalEvent(
        ticket: widget.ticket,
        proformaExcel: excelFile,
        documentosPdf: [pdfFile],
        observacion: 'Evaluación técnica generada automáticamente a partir del Plan Maestro de ${widget.ticket.equipo.name.toUpperCase()}.',
        nombreUsuario: nombreOperador,
        rolUsuario: rolOperador,
        numeroOVGarantia: null,
        documentosPdfGarantia: widget.documentoOVGarantia != null ? [widget.documentoOVGarantia!] : null,
        documentoRevisionAntigua: widget.documentoRevisionAntigua,
        noRequiereCompras: widget.noRequiereCompras,
        motivoNoRequiereCompras: widget.motivoNoRequiereCompras,
        actividadesSeleccionadas: widget.actividadesSeleccionadas,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TicketBloc, TicketState>(
      listener: (context, state) {
        if (state.status == TicketStatus.operationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Reporte Técnico e informe subidos exitosamente.'),
              backgroundColor: Colors.green,
            ),
          );
          // Retornar al menú o bandeja
          Navigator.of(context).pop(true);
        } else if (state.status == TicketStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error al subir reporte: ${state.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        final isProcesando = state.status == TicketStatus.loading;

        return Scaffold(
          appBar: AppBar(
            title: Text('Revisión Técnica: ${widget.ticket.id}'),
            backgroundColor: const Color(0xFF005A9C),
            foregroundColor: Colors.white,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(icon: Icon(Icons.picture_as_pdf), text: 'INFORME TÉCNICO (PDF)'),
                Tab(icon: Icon(Icons.table_chart), text: 'SOLICITUD MATERIALES (EXCEL)'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // 📑 PESTAÑA 1: VISOR PDF
              PdfPreview(
                build: (format) => widget.pdfBytes,
                canChangePageFormat: false,
                canChangeOrientation: false,
                allowPrinting: true,
                allowSharing: true,
                pdfFileName: 'Informe_Tecnico_${widget.ticket.id}.pdf',
              ),

              // 📊 PESTAÑA 2: RESUMEN EXCEL CONSOLIDADO
              _buildDetalleExcelTab(),
            ],
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isProcesando ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('MODIFICAR'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: isProcesando ? null : _confirmarYSubir,
                      icon: isProcesando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload),
                      label: Text(isProcesando ? 'SUBIENDO...' : 'CONFIRMAR Y SUBIR REPORTE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF005A9C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetalleExcelTab() {
    // Consolidar ítems comerciales e internos
    final Map<String, ItemCatalogoEntity> mapaComerciales = {};
    final Map<String, ItemCatalogoEntity> mapaTaller = {};
    double totalHorasHombre = 0.0;

    for (final actSel in widget.actividadesSeleccionadas) {
      totalHorasHombre += actSel.horasHombre;
      for (final it in actSel.itemsComerciales) {
        if (it.cantidad <= 0) continue;
        final cod = it.codigo.trim().toUpperCase();
        final key = cod.isNotEmpty ? cod : it.descripcion.trim().toUpperCase();
        if (mapaComerciales.containsKey(key)) {
          final ant = mapaComerciales[key]!;
          mapaComerciales[key] = ant.copyWith(cantidad: ant.cantidad + it.cantidad);
        } else {
          mapaComerciales[key] = it;
        }
      }
      for (final it in actSel.itemsInternos) {
        if (it.cantidad <= 0) continue;
        final cod = it.codigo.trim().toUpperCase();
        final key = cod.isNotEmpty ? cod : it.descripcion.trim().toUpperCase();
        if (mapaTaller.containsKey(key)) {
          final ant = mapaTaller[key]!;
          mapaTaller[key] = ant.copyWith(cantidad: ant.cantidad + it.cantidad);
        } else {
          mapaTaller[key] = it;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Solicitud de Materiales (.xlsx)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: _descargarExcel,
                        icon: const Icon(Icons.download),
                        label: const Text('Descargar Excel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Text('Equipo: ${widget.ticket.equipo.name.toUpperCase()}'),
                  Text('Serie: ${widget.ticket.numeroSerie ?? "S/N"}'),
                  Text('Actividades a realizar: ${widget.actividadesSeleccionadas.length}'),
                  Text('Mano de Obra Total: ${totalHorasHombre.toStringAsFixed(1)} HH', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF005A9C))),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Este archivo contiene dos hojas: "MATERIAL" (repuestos de taller consolidados y cotización comercial) y "ACTIVIDADES" (alcance de trabajo formal).',
                      style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Actividades Seleccionadas:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...widget.actividadesSeleccionadas.map((act) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF005A9C),
                    child: Text(
                      act.actividad.codigo.replaceAll('MO', ''),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  title: Text('${act.actividad.codigo} - ${act.actividad.nombre} (${(act.horasHombre % 1 == 0) ? act.horasHombre.toInt() : act.horasHombre} HH)'),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (act.textoIncluyeDinamico.isNotEmpty) ...[
                          Text(
                            act.textoIncluyeDinamico,
                            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey.shade800, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text('Hallazgo: ${act.observacion} | ${act.fotos.length} fotos', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              )),

          // 💼 TABLA DE PROPUESTA COMERCIAL CONSOLIDADA
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.green.shade400),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.receipt_long, color: Colors.green.shade800),
                          const SizedBox(width: 8),
                          Text(
                            'Propuesta Comercial (${mapaComerciales.length} ítems):',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green.shade900),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (mapaComerciales.isNotEmpty)
                            TextButton.icon(
                              icon: const Icon(Icons.copy_all, size: 14),
                              label: const Text('Copiar Nombres', style: TextStyle(fontSize: 11)),
                              onPressed: () {
                                final buffer = StringBuffer();
                                for (final r in mapaComerciales.values) {
                                  buffer.writeln(r.descripcion);
                                }
                                Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Nombres de repuestos comerciales copiados.'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade600),
                            ),
                            child: Text(
                              '${totalHorasHombre.toStringAsFixed(1)} HH',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  if (mapaComerciales.isEmpty)
                    const Text('No hay repuestos comerciales requeridos.', style: TextStyle(color: Colors.grey, fontSize: 12))
                  else
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2.5),
                        1: FlexColumnWidth(5.0),
                        2: FlexColumnWidth(2.0),
                        3: FlexColumnWidth(2.0),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey.shade100),
                          children: const [
                            Padding(padding: EdgeInsets.all(6), child: Text('Código', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: EdgeInsets.all(6), child: Text('Descripción / Nombre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: EdgeInsets.all(6), child: Text('Cant.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(6), child: Text('Unidad', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                          ],
                        ),
                        ...mapaComerciales.values.map((it) {
                          final cantStr = (it.cantidad % 1 == 0) ? it.cantidad.toInt().toString() : it.cantidad.toString();
                          return TableRow(
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(it.codigo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                                    CopyIconButtonWidget(etiqueta: 'Código', valor: it.codigo),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Tooltip(
                                        message: 'Tocar para copiar nombre',
                                        child: InkWell(
                                          onTap: () {
                                            Clipboard.setData(ClipboardData(text: it.descripcion));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Copiado: ${it.descripcion}'),
                                                duration: const Duration(milliseconds: 1200),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          },
                                          child: Text(it.descripcion, style: const TextStyle(fontSize: 11)),
                                        ),
                                      ),
                                    ),
                                    CopyIconButtonWidget(etiqueta: 'Nombre de repuesto', valor: it.descripcion),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  cantStr,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF005A9C)),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(padding: const EdgeInsets.all(6), child: Text(it.unidad, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                            ],
                          );
                        }),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // 🔧 TABLA DE REPUESTOS TALLER / BODEGA
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.blueGrey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warehouse, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Text(
                            'Materiales Taller / Bodega (${mapaTaller.length} ítems):',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey),
                          ),
                        ],
                      ),
                      if (mapaTaller.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(Icons.copy_all, size: 14),
                          label: const Text('Copiar Nombres', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            final buffer = StringBuffer();
                            for (final r in mapaTaller.values) {
                              buffer.writeln(r.descripcion);
                            }
                            Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Nombres de materiales de taller copiados.'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  const Divider(height: 16),
                  if (mapaTaller.isEmpty)
                    const Text('No hay materiales internos requeridos.', style: TextStyle(color: Colors.grey, fontSize: 12))
                  else
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2.5),
                        1: FlexColumnWidth(5.0),
                        2: FlexColumnWidth(2.0),
                        3: FlexColumnWidth(2.0),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey.shade100),
                          children: const [
                            Padding(padding: EdgeInsets.all(6), child: Text('Código', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: EdgeInsets.all(6), child: Text('Descripción / Nombre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: EdgeInsets.all(6), child: Text('Cant.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(6), child: Text('Unidad', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                          ],
                        ),
                        ...mapaTaller.values.map((it) {
                          final cantStr = (it.cantidad % 1 == 0) ? it.cantidad.toInt().toString() : it.cantidad.toString();
                          return TableRow(
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(it.codigo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                                    CopyIconButtonWidget(etiqueta: 'Código', valor: it.codigo),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Tooltip(
                                        message: 'Tocar para copiar nombre',
                                        child: InkWell(
                                          onTap: () {
                                            Clipboard.setData(ClipboardData(text: it.descripcion));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Copiado: ${it.descripcion}'),
                                                duration: const Duration(milliseconds: 1200),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          },
                                          child: Text(it.descripcion, style: const TextStyle(fontSize: 11)),
                                        ),
                                      ),
                                    ),
                                    CopyIconButtonWidget(etiqueta: 'Nombre de material', valor: it.descripcion),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  cantStr,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(padding: const EdgeInsets.all(6), child: Text(it.unidad, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                            ],
                          );
                        }),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
