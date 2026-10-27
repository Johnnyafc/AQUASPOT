// lib/features/tickets/presentation/pages/revision_evaluacion_mantenimiento_page.dart
//
// 👀 Revisión del informe técnico y la Solicitud de materiales de un
// MANTENIMIENTO INTERNO antes de subirlos (igual que en reparación). Usa el
// mismo EvaluacionMantenimientoCubit de la evaluación: "Confirmar y subir"
// sube fotos, PDF y Excel y guarda; "Modificar" vuelve a la evaluación.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/services/evaluacion_mantenimiento_service.dart';
import '../bloc/evaluacion_mantenimiento_cubit.dart';

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
                title: Text('Revisión Técnica: $id'),
                backgroundColor: _azul,
                foregroundColor: Colors.white,
                automaticallyImplyLeading: !enviando,
                bottom: const TabBar(
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: [
                    Tab(icon: Icon(Icons.picture_as_pdf), text: 'INFORME TÉCNICO (PDF)'),
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
                  pdfFileName: 'Informe_Tecnico_$id.pdf',
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

  Widget _solicitud(BuildContext context, EvaluacionMantenimientoState s, String id) {
    final repuestos = _S.consolidar(s.actividades);
    final sinCodigo = repuestos.where(_S.esSinCodigo).length;
    final enc = _S.encabezadoSolicitud;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(
                  child: Text('Solicitud de Materiales (.xlsx)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton.icon(
                  onPressed: () => Printing.sharePdf(bytes: excelBytes, filename: 'Solicitud_Materiales_$id.xlsx'),
                  icon: const Icon(Icons.download),
                  label: const Text('Descargar Excel'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                ),
              ]),
              const Divider(height: 20),
              Text('Proyecto: ${enc.proyecto} · Centro de costo: ${enc.centroCosto}'),
              Text('Actividades: ${s.actividades.length} · Repuestos: ${repuestos.length}'),
              Text('Mano de obra total: ${_numero(_S.totalHoras(s.actividades))} HH',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: _azul)),
              if (sinCodigo > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('⚠️ $sinCodigo repuesto(s) SIN CÓDIGO: no están registrados en el inventario.',
                      style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold)),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Repuestos (todas las actividades)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        for (final r in repuestos)
          ListTile(
            dense: true,
            title: Text(r.descripcion),
            subtitle: Text('${_S.esSinCodigo(r) ? 'SIN CÓDIGO' : r.codigo} · ${r.unidad}',
                style: TextStyle(color: _S.esSinCodigo(r) ? Colors.orange.shade900 : null)),
            trailing: Text(_numero(r.cantidad), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        const Divider(height: 24),
        const Text('Actividades', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        for (final a in s.actividades)
          ListTile(
            dense: true,
            title: Text('${a.codigo} — ${a.nombre} (${_numero(a.horasHombre)} HH)'),
            subtitle: Text([_S.textoIncluye(a), 'Hallazgo: ${_S.hallazgo(a)} | ${a.fotos.length} foto(s)']
                .where((t) => t.isNotEmpty)
                .join('\n')),
          ),
      ],
    );
  }
}
