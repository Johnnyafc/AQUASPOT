// lib/features/tickets/presentation/pages/evaluacion_mantenimiento_page.dart
//
// 🛠️ EVALUACIÓN TÉCNICA de un MANTENIMIENTO INTERNO (se abre desde la
// Bandeja de Evaluaciones). Actividades del Plan Maestro modificables, con
// una sola lista de repuestos tomados del inventario registrado, y
// "¿Necesita compras?". Solo dibuja: el estado y el envío están en
// EvaluacionMantenimientoCubit y las reglas en EvaluacionMantenimientoService.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../../../../injection_container.dart' as di;
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../catalogo/domain/entities/actividad_catalogo_entity.dart';
import '../../../inventario/domain/entities/item_inventario_entity.dart';
import '../../domain/entities/actividad_mantenimiento.dart';
import '../../domain/entities/archivo_adjunto.dart';
import '../../domain/entities/mantenimiento_interno_entity.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/services/evaluacion_mantenimiento_service.dart';
import '../../domain/services/formulario_mantenimiento_service.dart';
import '../bloc/evaluacion_mantenimiento_cubit.dart';

typedef _S = EvaluacionMantenimientoService;

const _azul = Color(0xFF005A9C);

class EvaluacionMantenimientoPage extends StatelessWidget {
  final TicketEntity ticket;

  const EvaluacionMantenimientoPage({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<EvaluacionMantenimientoCubit>()..cargar(ticket),
      child: const _VistaEvaluacionMantenimiento(),
    );
  }
}

class _VistaEvaluacionMantenimiento extends StatelessWidget {
  const _VistaEvaluacionMantenimiento();

  ({String nombre, RolUsuario rol}) _usuario(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    if (auth is Authenticated) return (nombre: auth.usuario.nombre, rol: auth.usuario.rol);
    return (nombre: 'SISTEMA', rol: RolUsuario.desconocido);
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
            SnackBar(content: Text(s.mensaje), backgroundColor: Colors.red, duration: const Duration(seconds: 8)),
          );
        }
      },
      builder: (context, s) {
        final ticket = s.ticket;
        final cubit = context.read<EvaluacionMantenimientoCubit>();
        final enviando = s.envio == EnvioEvaluacionMantenimiento.enviando;
        return Scaffold(
          appBar: AppBar(
            title: Text('Evaluación Técnica — Mantenimiento: ${ticket?.id ?? ''}'),
            backgroundColor: _azul,
            foregroundColor: Colors.white,
          ),
          body: ticket == null || s.carga == CargaEvaluacionMantenimiento.cargando
              ? const Center(child: CircularProgressIndicator())
              : AbsorbPointer(
                  absorbing: enviando,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 850),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (s.carga == CargaEvaluacionMantenimiento.error)
                              _Aviso(texto: 'No se pudo cargar todo:\n${s.mensaje}', color: Colors.red),
                            _FichaMantenimiento(ticket: ticket),
                            const SizedBox(height: 20),
                            _SeccionActividades(estado: s),
                            const SizedBox(height: 20),
                            _TarjetaCompras(estado: s),
                            if (s.errores.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _Aviso(texto: s.errores.map((e) => '• $e').join('\n'), color: Colors.red),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: _azul, foregroundColor: Colors.white),
                                icon: enviando
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(enviando ? s.mensaje : 'GUARDAR EVALUACIÓN TÉCNICA'),
                                onPressed: () {
                                  final u = _usuario(context);
                                  cubit.enviar(usuarioNombre: u.nombre, rol: u.rol);
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

// ============================================================ Ficha
class _FichaMantenimiento extends StatelessWidget {
  final TicketEntity ticket;

  const _FichaMantenimiento({required this.ticket});

  String _dos(int v) => v.toString().padLeft(2, '0');
  String _fecha(DateTime f) => '${_dos(f.day)}/${_dos(f.month)}/${f.year} ${_dos(f.hour)}:${_dos(f.minute)}';
  String _numero(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

  Future<void> _abrir(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final m = ticket.mantenimientoInterno;
    final tipo = m?.tipoActivo;
    final creador = ticket.historialEventos.isEmpty ? null : ticket.historialEventos.first.usuarioNombre;
    final filas = <(String, String)>[
      if (m != null) ('Tipo de mantenimiento:', m.tipoMantenimiento.etiqueta),
      if (tipo != null) ('Máquina:', tipo.etiqueta),
      (FormularioMantenimientoService.etiquetaSerieOPlaca(tipo), m?.placa ?? ticket.numeroSerie ?? '—'),
      if (ticket.horometro != null) ('Horómetro:', '${_numero(ticket.horometro!)} h'),
      if (m?.kilometraje != null) ('Kilometraje:', '${_numero(m!.kilometraje!)} km'),
      if (m?.fechaHoraFalla != null)
        (FormularioMantenimientoService.etiquetaFechaHora(m!.tipoMantenimiento), _fecha(m.fechaHoraFalla!)),
      if (creador != null) ('Creado por:', creador),
    ];
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Datos del requerimiento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            for (final (etiqueta, valor) in filas)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 190, child: Text(etiqueta, style: const TextStyle(fontSize: 13, color: Colors.grey))),
                    Expanded(child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            const Divider(height: 24),
            Text(
              m == null ? 'Detalle' : FormularioMantenimientoService.etiquetaDetalle(m.tipoMantenimiento),
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(ticket.fallaReportada, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (m?.urlFotoLectura != null)
                ActionChip(
                  avatar: const Icon(Icons.speed, size: 18),
                  label: Text(FormularioMantenimientoService.etiquetaFotoLectura(tipo)),
                  onPressed: () => _abrir(m!.urlFotoLectura!),
                ),
              for (var i = 0; i < ticket.fotosUrls.length; i++)
                ActionChip(
                  avatar: const Icon(Icons.photo_outlined, size: 18),
                  label: Text('Foto ${i + 1}'),
                  onPressed: () => _abrir(ticket.fotosUrls[i]),
                ),
              for (var i = 0; i < (m?.videosUrls.length ?? 0); i++)
                ActionChip(
                  avatar: const Icon(Icons.play_circle_outline, size: 18),
                  label: Text('Video ${i + 1}'),
                  onPressed: () => _abrir(m!.videosUrls[i]),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ============================================================ Actividades
class _SeccionActividades extends StatelessWidget {
  final EvaluacionMantenimientoState estado;

  const _SeccionActividades({required this.estado});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EvaluacionMantenimientoCubit>();
    final sinPlan = _S.equipoCatalogo(estado.ticket!) == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Expanded(
            child: Text('ACTIVIDADES A REALIZAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _azul)),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Agregar actividad'),
            onPressed: sinPlan
                ? null
                : () async {
                    final elegida = await _elegirActividad(context, _S.disponibles(estado.catalogo, estado.actividades));
                    if (elegida != null) cubit.agregarActividad(elegida);
                  },
          ),
        ]),
        if (sinPlan)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Este equipo aún no tiene Plan Maestro: sus actividades vendrán del Plan preventivo.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        if (estado.actividades.isEmpty && !sinPlan)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Agregue las actividades del Plan Maestro que se realizarán.', style: TextStyle(color: Colors.grey)),
          ),
        for (var i = 0; i < estado.actividades.length; i++)
          _TarjetaActividad(
            key: ValueKey('act_${estado.actividades[i].codigo}'),
            indice: i,
            actividad: estado.actividades[i],
            inventario: estado.inventario,
          ),
      ],
    );
  }

  Future<ActividadCatalogoEntity?> _elegirActividad(BuildContext context, List<ActividadCatalogoEntity> lista) {
    var texto = '';
    return showDialog<ActividadCatalogoEntity>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final filtradas = _S.buscarActividades(lista, texto);
          return AlertDialog(
            title: const Text('Agregar actividad del Plan Maestro'),
            content: SizedBox(
              width: 560,
              height: 460,
              child: Column(children: [
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar por código o nombre'),
                  onChanged: (v) => setState(() => texto = v),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtradas.isEmpty
                      ? const Center(child: Text('Sin actividades disponibles.', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: filtradas.length,
                          itemBuilder: (context, i) {
                            final a = filtradas[i];
                            final repuestos = _S.desdeCatalogo(a).repuestos.length;
                            return ListTile(
                              dense: true,
                              title: Text('${a.codigo} — ${a.nombre}'),
                              subtitle: Text('${a.horasHombre == null ? 'HH variable' : '${a.horasHombre! % 1 == 0 ? a.horasHombre!.toInt() : a.horasHombre} HH'} · '
                                  '$repuestos repuesto(s)'),
                              onTap: () => Navigator.of(context).pop(a),
                            );
                          },
                        ),
                ),
              ]),
            ),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar'))],
          );
        },
      ),
    );
  }
}

class _TarjetaActividad extends StatelessWidget {
  final int indice;
  final ActividadMantenimiento actividad;
  final List<ItemInventarioEntity> inventario;

  const _TarjetaActividad({super.key, required this.indice, required this.actividad, required this.inventario});

  String _numero(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

  Future<void> _agregarFotos(BuildContext context, {required bool camara}) async {
    final cubit = context.read<EvaluacionMantenimientoCubit>();
    try {
      final picker = ImagePicker();
      final elegidas = camara
          ? [?await picker.pickImage(source: ImageSource.camera, imageQuality: 70)]
          : await picker.pickMultiImage(imageQuality: 70);
      final adjuntos = [
        for (final f in elegidas)
          ArchivoAdjunto(
            bytes: await f.readAsBytes(),
            nombre: f.name.isNotEmpty ? f.name : 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg',
            tipoContenido: f.mimeType,
          ),
      ];
      if (adjuntos.isNotEmpty) cubit.agregarFotos(indice, adjuntos);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🛑 Error al adjuntar fotos: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _editarCantidad(BuildContext context, int j) async {
    final cubit = context.read<EvaluacionMantenimientoCubit>();
    final r = actividad.repuestos[j];
    final ctrl = TextEditingController(text: _numero(r.cantidad));
    final valor = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(r.descripcion, style: const TextStyle(fontSize: 15)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          decoration: InputDecoration(labelText: 'Cantidad', suffixText: r.unidad),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(double.tryParse(ctrl.text.trim().replaceAll(',', '.'))),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    if (valor != null) cubit.cambiarCantidad(indice, j, valor);
  }

  Future<ItemInventarioEntity?> _elegirRepuesto(BuildContext context) {
    var texto = '';
    return showDialog<ItemInventarioEntity>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final resultados = _S.buscarInventario(inventario, texto);
          return AlertDialog(
            title: const Text('Agregar repuesto del inventario'),
            content: SizedBox(
              width: 560,
              height: 460,
              child: Column(children: [
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Código o descripción'),
                  onChanged: (v) => setState(() => texto = v),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: texto.trim().isEmpty
                      ? const Center(child: Text('Escriba para buscar en lo registrado en bodega.', style: TextStyle(color: Colors.grey)))
                      : resultados.isEmpty
                          ? const Center(child: Text('Sin resultados.', style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              itemCount: resultados.length,
                              itemBuilder: (context, i) {
                                final it = resultados[i];
                                return ListTile(
                                  dense: true,
                                  title: Text(it.descripcion),
                                  subtitle: Text('${it.codigo} · ${it.unidad} · Stock: ${_numero(it.stockNetoDisponible)}'),
                                  onTap: () => Navigator.of(context).pop(it),
                                );
                              },
                            ),
                ),
              ]),
            ),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar'))],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EvaluacionMantenimientoCubit>();
    final a = actividad;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: Text('${indice + 1}. ${a.codigo} — ${a.nombre}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              IconButton(
                tooltip: 'Quitar actividad',
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => cubit.quitarActividad(indice),
              ),
            ]),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 130,
                child: TextFormField(
                  initialValue: a.horasHombre > 0 ? _numero(a.horasHombre) : '',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(labelText: 'Horas hombre', border: OutlineInputBorder(), isDense: true),
                  onChanged: (v) => cubit.cambiarHoras(indice, double.tryParse(v.trim().replaceAll(',', '.'))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: a.observacion,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Observación', border: OutlineInputBorder(), isDense: true),
                  onChanged: (v) => cubit.cambiarObservacion(indice, v),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Tomar foto'),
                onPressed: () => _agregarFotos(context, camara: true),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Desde archivos'),
                onPressed: () => _agregarFotos(context, camara: false),
              ),
              for (var j = 0; j < a.fotos.length; j++)
                Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(a.fotos[j].bytes, width: 56, height: 56, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(width: 56, height: 56, color: Colors.grey.shade200)),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: InkWell(
                      onTap: () => cubit.quitarFoto(indice, j),
                      child: const CircleAvatar(radius: 9, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 12, color: Colors.white)),
                    ),
                  ),
                ]),
              if (a.fotosUrls.isNotEmpty) Text('${a.fotosUrls.length} foto(s) ya subida(s)', style: const TextStyle(fontSize: 12)),
            ]),
            const Divider(height: 24),
            Row(children: [
              Text('Repuestos (${a.repuestos.length})', style: const TextStyle(fontWeight: FontWeight.bold, color: _azul)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Agregar repuesto'),
                onPressed: () async {
                  final item = await _elegirRepuesto(context);
                  if (item != null) cubit.agregarRepuesto(indice, item);
                },
              ),
            ]),
            if (a.repuestos.isEmpty)
              const Text('Sin repuestos.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            for (var j = 0; j < a.repuestos.length; j++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.repuestos[j].descripcion, style: const TextStyle(fontSize: 13)),
                      Text('${a.repuestos[j].codigo.isEmpty ? 'S/C' : a.repuestos[j].codigo} · ${a.repuestos[j].unidad}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'Restar 1',
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: a.repuestos[j].cantidad > 1
                        ? () => cubit.cambiarCantidad(indice, j, a.repuestos[j].cantidad - 1)
                        : null,
                  ),
                  InkWell(
                    onTap: () => _editarCantidad(context, j),
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
                      child: Text(_numero(a.repuestos[j].cantidad), textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold, color: a.repuestos[j].cantidad > 0 ? null : Colors.red)),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sumar 1',
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    onPressed: () => cubit.cambiarCantidad(indice, j, a.repuestos[j].cantidad + 1),
                  ),
                  IconButton(
                    tooltip: 'Quitar repuesto',
                    icon: const Icon(Icons.close, size: 20, color: Colors.red),
                    onPressed: () => cubit.quitarRepuesto(indice, j),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================ Compras
class _TarjetaCompras extends StatelessWidget {
  final EvaluacionMantenimientoState estado;

  const _TarjetaCompras({required this.estado});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EvaluacionMantenimientoCubit>();
    final necesita = estado.necesitaCompras;
    return Card(
      color: necesita ? Colors.white : const Color(0xFFFFF3E0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: necesita ? Colors.grey.shade300 : Colors.orange.shade800, width: necesita ? 1 : 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(children: [
          CheckboxListTile(
            value: necesita,
            contentPadding: EdgeInsets.zero,
            activeColor: _azul,
            title: const Text('¿Necesita compras?', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(necesita
                ? 'Sí, este mantenimiento necesita compras de repuestos o insumos.'
                : 'NO necesita compras (se alertará al flujo en naranja).'),
            onChanged: (v) => cubit.cambiarNecesitaCompras(v ?? true),
          ),
          if (!necesita)
            TextFormField(
              initialValue: estado.motivoNoCompras,
              decoration: const InputDecoration(
                labelText: 'Motivo por el cual NO requiere compras (opcional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: cubit.cambiarMotivoNoCompras,
            ),
        ]),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final String texto;
  final MaterialColor color;

  const _Aviso({required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Text(texto, style: TextStyle(color: color.shade800)),
    );
  }
}
