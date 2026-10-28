// lib/features/tickets/presentation/pages/revision_evaluacion_mantenimiento_page.dart
//
// 👀 Revisión de la Orden de trabajo (PDF) y la Solicitud de materiales de un
// MANTENIMIENTO INTERNO antes de subirlos (igual que en reparación). Usa el
// mismo EvaluacionMantenimientoCubit de la evaluación: "Confirmar y subir"
// sube fotos, PDF y Excel y guarda; "Modificar" vuelve a la evaluación.

import 'package:flutter/material.dart';
import '../widgets/tabla_desplazable_widget.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/services/evaluacion_mantenimiento_service.dart';
import '../../domain/entities/mantenimiento_interno_entity.dart';
import '../../domain/entities/repuesto_registrado_entity.dart';
import '../bloc/evaluacion_mantenimiento_cubit.dart';
import '../widgets/copy_icon_button_widget.dart';

typedef _S = EvaluacionMantenimientoService;

const _azul = Color(0xFF005A9C);

class RevisionEvaluacionMantenimientoPage extends StatelessWidget {
  final Uint8List pdfBytes;
  final Uint8List excelBytes;

  const RevisionEvaluacionMantenimientoPage({super.key, required this.pdfBytes, required this.excelBytes});

  String _numero(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

  void _confirmar(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    final (nombre, rol) = auth is Authenticated ? (auth.usuario.nombre, auth.usuario.rol) : ('SISTEMA', RolUsuario.desconocido);
    context.read<EvaluacionMantenimientoCubit>().confirmar(
          informePdf: pdfBytes,
          solicitudExcel: excelBytes,
          usuarioNombre: nombre,
          rol: rol,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EvaluacionMantenimientoCubit, EvaluacionMantenimientoState>(
      listenWhen: (a, b) => a.envio != b.envio,
      listener: (context, s) {
        if (s.envio == EnvioEvaluacionMantenimiento.guardada) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ ${s.mensaje}'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pop(true);
        } else if (s.envio == EnvioEvaluacionMantenimiento.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ ${s.mensaje}'), backgroundColor: Colors.red, duration: const Duration(seconds: 8)),
          );
        }
      },
      builder: (context, s) {
        final id = s.ticket?.id ?? '';
        final enviando = s.envio == EnvioEvaluacionMantenimiento.enviando;
        return PopScope(
          canPop: !enviando,
          child: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                title: Text('Orden de trabajo: $id'),
                backgroundColor: _azul,
                foregroundColor: Colors.white,
                automaticallyImplyLeading: !enviando,
                bottom: TabBar(
                  // En el celular las pestañas se desplazan para no cortar el texto.
                  isScrollable: MediaQuery.sizeOf(context).width < 600,
                  tabAlignment: MediaQuery.sizeOf(context).width < 600 ? TabAlignment.start : null,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: const [
                    Tab(icon: Icon(Icons.picture_as_pdf), text: 'ORDEN DE TRABAJO (PDF)'),
                    Tab(icon: Icon(Icons.table_chart), text: 'SOLICITUD MATERIALES (EXCEL)'),
                  ],
                ),
              ),
              body: TabBarView(children: [
                PdfPreview(
                  build: (_) => pdfBytes,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  allowPrinting: true,
                  allowSharing: true,
                  pdfFileName: 'Orden_Trabajo_$id.pdf',
                ),
                _solicitud(context, s, id),
              ]),
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: enviando ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('MODIFICAR'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: enviando ? null : () => _confirmar(context),
                        icon: enviando
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.cloud_upload),
                        label: Text(enviando ? s.mensaje : 'CONFIRMAR Y SUBIR REPORTE'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _azul,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Igual que la pestaña de reparación: encabezado, actividades y la tabla
  /// de Materiales Taller / Bodega (sin propuesta comercial).
  Widget _solicitud(BuildContext context, EvaluacionMantenimientoState s, String id) {
    final repuestos = _S.consolidar(s.actividades);
    final sinCodigo = repuestos.where(_S.esSinCodigo).length;
    final enc = _S.encabezadoSolicitud;
    final ticket = s.ticket;
    final m = ticket?.mantenimientoInterno;
    final totalHoras = _S.totalHoras(s.actividades);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text('Solicitud de Materiales (.xlsx)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => Printing.sharePdf(bytes: excelBytes, filename: 'Solicitud_Materiales_$id.xlsx'),
                        icon: const Icon(Icons.download),
                        label: const Text('Descargar Excel'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Text('Equipo: ${(m?.tipoActivo.etiqueta ?? ticket?.equipo.name ?? '').toUpperCase()}'),
                  Text(m?.placa != null ? 'Placa: ${m!.placa}' : 'Serie: ${ticket?.numeroSerie ?? 'S/N'}'),
                  Text('Centro de costo: ${enc.centroCosto}'),
                  Text('Actividades a realizar: ${s.actividades.length}'),
                  Text('Mano de Obra Total: ${_numero(totalHoras)} HH',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: _azul)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      'Este archivo contiene dos hojas: "MATERIAL" (repuestos de taller consolidados) y "ACTIVIDADES" (alcance de trabajo formal con sus HH).',
                      style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                    ),
                  ),
                  if (sinCodigo > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Text(
                        '⚠️ $sinCodigo repuesto(s) SIN CÓDIGO: no están registrados en el inventario. '
                        'Costos debe crear su código antes de que pasen a Compras.',
                        style: TextStyle(fontSize: 13, color: Colors.orange.shade900, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Actividades Seleccionadas:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          for (final (i, a) in s.actividades.indexed)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _azul,
                  child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
                title: Text('${a.codigo} - ${a.nombre} (${_numero(a.horasHombre)} HH)'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_S.textoIncluye(a).isNotEmpty) ...[
                        Text(_S.textoIncluye(a),
                            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey.shade800, fontSize: 12)),
                        const SizedBox(height: 4),
                      ],
                      Text('Hallazgo: ${_S.hallazgo(a)} | ${a.fotos.length} fotos', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          _TablaMateriales(repuestos: repuestos),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 🔧 Materiales Taller / Bodega: misma tabla que en la revisión de reparación.
class _TablaMateriales extends StatelessWidget {
  final List<RepuestoRegistradoEntity> repuestos;

  const _TablaMateriales({required this.repuestos});

  String _cantidad(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

  void _copiar(BuildContext context, String texto, String aviso) {
    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(aviso), duration: const Duration(milliseconds: 1200), behavior: SnackBarBehavior.floating),
    );
  }

  static const _encabezado = TextStyle(fontWeight: FontWeight.bold, fontSize: 11);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.blueGrey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(children: [
                    const Icon(Icons.warehouse, color: Colors.blueGrey),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text('Materiales Taller / Bodega (${repuestos.length} ítems):',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
                    ),
                  ]),
                ),
                if (repuestos.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.copy_all, size: 14),
                    label: const Text('Copiar Nombres', style: TextStyle(fontSize: 11)),
                    onPressed: () => _copiar(context, repuestos.map((r) => r.descripcion).join('\n'),
                        'Nombres de materiales de taller copiados.'),
                  ),
              ],
            ),
            const Divider(height: 16),
            if (repuestos.isEmpty)
              const Text('No hay materiales requeridos.', style: TextStyle(color: Colors.grey, fontSize: 12))
            else
              // En el celular la tabla se desplaza de lado en vez de apretarse.
              TablaDesplazableWidget(
                child: Table(
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
                        Padding(padding: EdgeInsets.all(6), child: Text('Código', style: _encabezado)),
                        Padding(padding: EdgeInsets.all(6), child: Text('Descripción / Nombre', style: _encabezado)),
                        Padding(padding: EdgeInsets.all(6), child: Text('Cant.', style: _encabezado, textAlign: TextAlign.center)),
                        Padding(padding: EdgeInsets.all(6), child: Text('Unidad', style: _encabezado, textAlign: TextAlign.center)),
                      ],
                    ),
                    for (final r in repuestos)
                      TableRow(
                        decoration: BoxDecoration(
                          color: _S.esSinCodigo(r) ? Colors.orange.shade50 : null,
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: _S.esSinCodigo(r)
                                ? Text('SIN CÓDIGO',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade900))
                                : Row(children: [
                                    Expanded(
                                        child: Text(r.codigo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                                    CopyIconButtonWidget(etiqueta: 'Código', valor: r.codigo),
                                  ]),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Row(children: [
                              Expanded(
                                child: Tooltip(
                                  message: 'Tocar para copiar nombre',
                                  child: InkWell(
                                    onTap: () => _copiar(context, r.descripcion, 'Copiado: ${r.descripcion}'),
                                    child: Text(r.descripcion, style: const TextStyle(fontSize: 11)),
                                  ),
                                ),
                              ),
                              CopyIconButtonWidget(etiqueta: 'Nombre de material', valor: r.descripcion),
                            ]),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(_cantidad(r.cantidad),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                                textAlign: TextAlign.center),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(r.unidad, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
