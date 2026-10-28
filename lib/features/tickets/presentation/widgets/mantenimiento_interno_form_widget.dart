// lib/features/tickets/presentation/widgets/mantenimiento_interno_form_widget.dart
//
// 🛠️ Formulario de MANTENIMIENTO INTERNO en Crear Ticket. Dinámico según el
// tipo de máquina (ver FormularioMantenimientoService): solo dibuja y le
// pasa lo que se llena a MantenimientoInternoCubit.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/mantenimiento_interno_entity.dart';
import '../../domain/services/formulario_mantenimiento_service.dart';
import '../bloc/mantenimiento_interno_cubit.dart';
import 'selector_requerimiento_widget.dart';

typedef _F = FormularioMantenimientoService;

class MantenimientoInternoFormWidget extends StatefulWidget {
  const MantenimientoInternoFormWidget({super.key});

  @override
  State<MantenimientoInternoFormWidget> createState() => _MantenimientoInternoFormWidgetState();
}

class _MantenimientoInternoFormWidgetState extends State<MantenimientoInternoFormWidget> {
  final _horometroCtrl = TextEditingController();
  final _kilometrajeCtrl = TextEditingController();
  final _serieCtrl = TextEditingController();
  final _detalleCtrl = TextEditingController();

  static const _azul = Color(0xFF005A9C);

  @override
  void dispose() {
    _horometroCtrl.dispose();
    _kilometrajeCtrl.dispose();
    _serieCtrl.dispose();
    _detalleCtrl.dispose();
    super.dispose();
  }

  ({String nombre, RolUsuario rol}) _usuario() {
    final auth = context.read<AuthBloc>().state;
    if (auth is Authenticated) return (nombre: auth.usuario.nombre, rol: auth.usuario.rol);
    return (nombre: 'SISTEMA', rol: RolUsuario.desconocido);
  }

  double? _numero(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));

  Future<void> _elegirFechaHora(MantenimientoInternoState s) async {
    final cubit = context.read<MantenimientoInternoCubit>();
    final ahora = DateTime.now();
    final actual = s.datos.fechaHora ?? ahora;
    final esPreventivo = s.datos.tipoMantenimiento == TipoMantenimiento.preventivo;
    final fecha = await showDatePicker(
      context: context,
      initialDate: actual,
      firstDate: DateTime(ahora.year - 2),
      // Correctivo: la falla ya ocurrió (nunca futura). Preventivo: se programa.
      lastDate: esPreventivo ? DateTime(ahora.year + 2) : ahora,
    );
    if (fecha == null || !mounted) return;
    final hora = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(actual));
    if (hora == null) return;
    cubit.cambiarFechaHora(DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute));
  }

  /// Solo fecha (aire acondicionado / herramientas).
  Future<void> _elegirFecha(MantenimientoInternoState s) async {
    final cubit = context.read<MantenimientoInternoCubit>();
    final ahora = DateTime.now();
    final esPreventivo = s.datos.tipoMantenimiento == TipoMantenimiento.preventivo;
    final fecha = await showDatePicker(
      context: context,
      initialDate: s.datos.fechaHora ?? ahora,
      firstDate: DateTime(ahora.year - 2),
      lastDate: esPreventivo ? DateTime(ahora.year + 2) : ahora,
    );
    if (fecha == null || !mounted) return;
    cubit.cambiarFechaHora(DateTime(fecha.year, fecha.month, fecha.day));
  }

  Future<void> _agregarFotos({required bool camara}) async {
    final cubit = context.read<MantenimientoInternoCubit>();
    try {
      final picker = ImagePicker();
      if (camara) {
        final foto = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
        if (foto != null) cubit.agregarFotos([foto]);
      } else {
        final fotos = await picker.pickMultiImage(imageQuality: 70);
        if (fotos.isNotEmpty) cubit.agregarFotos(fotos);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🛑 Error al adjuntar fotos: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _agregarVideo({required bool camara}) async {
    final cubit = context.read<MantenimientoInternoCubit>();
    if (cubit.state.videos.length >= _F.maximoVideos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Máximo ${_F.maximoVideos} videos de evidencia.')),
      );
      return;
    }
    try {
      final video = await ImagePicker().pickVideo(
        source: camara ? ImageSource.camera : ImageSource.gallery,
        maxDuration: _F.duracionMaximaVideo,
      );
      if (video != null) cubit.agregarVideos([video]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🛑 Error al adjuntar el video: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _fotoLectura({required bool camara}) async {
    final cubit = context.read<MantenimientoInternoCubit>();
    try {
      final foto = await ImagePicker()
          .pickImage(source: camara ? ImageSource.camera : ImageSource.gallery, imageQuality: 70);
      if (foto != null) cubit.ponerFotoLectura(foto);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🛑 Error al adjuntar la foto: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Foto obligatoria del horómetro / kilometraje: botones o la miniatura.
  Widget _seccionFotoLectura(MantenimientoInternoState s, TipoActivoMantenimiento tipo) {
    final cubit = context.read<MantenimientoInternoCubit>();
    final foto = s.fotoLectura;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo('${_F.etiquetaFotoLectura(tipo)} (obligatoria)'),
        if (foto != null)
          _MiniaturaFoto(foto: foto, onQuitar: cubit.quitarFotoLectura)
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Tomar foto'),
              onPressed: () => _fotoLectura(camara: true),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Desde archivos'),
              onPressed: () => _fotoLectura(camara: false),
            ),
          ]),
      ],
    );
  }

  String _dosDigitos(int v) => v.toString().padLeft(2, '0');
  String _fmtFechaHora(DateTime f) =>
      '${_dosDigitos(f.day)}/${_dosDigitos(f.month)}/${f.year} ${_dosDigitos(f.hour)}:${_dosDigitos(f.minute)}';

  Widget _titulo(String texto) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(texto, style: const TextStyle(fontWeight: FontWeight.bold, color: _azul)),
      );

  @override
  Widget build(BuildContext context) {
    final usuario = _usuario();
    return BlocConsumer<MantenimientoInternoCubit, MantenimientoInternoState>(
      listenWhen: (a, b) => a.envio != b.envio,
      listener: (context, s) {
        if (s.envio == EstadoEnvioMantenimiento.creado) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ ${s.mensaje}'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        } else if (s.envio == EstadoEnvioMantenimiento.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.mensaje), backgroundColor: Colors.red, duration: const Duration(seconds: 8)),
          );
        }
      },
      builder: (context, s) {
        final cubit = context.read<MantenimientoInternoCubit>();
        final d = s.datos;
        final tipo = d.tipoActivo;
        final enviando = s.envio == EstadoEnvioMantenimiento.enviando;
        final opciones = tipo == null ? const <String>[] : _F.opcionesDe(tipo);

        return AbsorbPointer(
          absorbing: enviando,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SelectorRequerimientoWidget(),
              const Divider(height: 32),

              // 1. Tipo de mantenimiento (supervisor / admin eligen; el resto, Correctivo).
              _titulo('Tipo de mantenimiento'),
              if (_F.puedeElegirTipo(usuario.rol))
                Wrap(spacing: 8, children: [
                  for (final t in TipoMantenimiento.values)
                    ChoiceChip(
                      label: Text(t.etiqueta),
                      selected: d.tipoMantenimiento == t,
                      onSelected: (_) => cubit.elegirTipoMantenimiento(t),
                    ),
                ])
              else
                Row(children: [
                  Chip(
                    avatar: const Icon(Icons.lock_outline, size: 16),
                    label: Text(TipoMantenimiento.correctivo.etiqueta),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text('Solo un supervisor puede crear un mantenimiento preventivo.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ),
                ]),

              // 2. Tipo de máquina.
              _titulo('Tipo de máquina'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in TipoActivoMantenimiento.values)
                  ChoiceChip(
                    avatar: Icon(
                      switch (t) {
                        TipoActivoMantenimiento.cosechadora => Icons.agriculture,
                        TipoActivoMantenimiento.contador => Icons.calculate_outlined,
                        TipoActivoMantenimiento.caracol => Icons.water_outlined,
                        TipoActivoMantenimiento.vehiculo => Icons.local_shipping_outlined,
                        TipoActivoMantenimiento.aireAcondicionado => Icons.ac_unit,
                        TipoActivoMantenimiento.herramientas => Icons.handyman_outlined,
                      },
                      size: 18,
                    ),
                    label: Text(t.etiqueta),
                    selected: tipo == t,
                    onSelected: (_) {
                      _horometroCtrl.clear();
                      _kilometrajeCtrl.clear();
                      _serieCtrl.clear();
                      cubit.elegirTipoActivo(t);
                    },
                  ),
              ]),

              // 3. Campos según la máquina.
              if (tipo != null) ...[
                if (_F.pideMarcaYEspecificacion(tipo)) ...[
                  _titulo('Marca'),
                  TextField(
                    key: const ValueKey('marca_mantenimiento'),
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Ej.: JOHN DEERE, TOYOTA, LG'),
                    onChanged: cubit.cambiarMarca,
                  ),
                  _titulo('Especificación del equipo'),
                  TextField(
                    key: const ValueKey('especificacion_mantenimiento'),
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Modelo, capacidad, año… Ej.: MOTOR YANMAR 3TNV88, 2019',
                    ),
                    onChanged: cubit.cambiarEspecificacion,
                  ),
                ],
                _titulo(_F.serieManual(tipo) ? 'Serie (opcional)' : _F.etiquetaSerieOPlaca(tipo)),
                if (_F.serieManual(tipo))
                  TextField(
                    controller: _serieCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Escriba la serie si la tiene',
                    ),
                    onChanged: cubit.elegirSerieOPlaca,
                  )
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey('serie_${tipo.name}'),
                    initialValue: opciones.contains(d.serieOPlaca) ? d.serieOPlaca : null,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: 'Seleccione la ${_F.etiquetaSerieOPlaca(tipo).toLowerCase()}',
                    ),
                    items: [for (final o in opciones) DropdownMenuItem(value: o, child: Text(o))],
                    onChanged: (v) {
                      if (v != null) cubit.elegirSerieOPlaca(v);
                    },
                  ),
                if (_F.pideHorometro(tipo)) ...[
                  _titulo('Horómetro'),
                  TextField(
                    controller: _horometroCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: const InputDecoration(border: OutlineInputBorder(), suffixText: 'h'),
                    onChanged: (v) => cubit.cambiarHorometro(_numero(v)),
                  ),
                ],
                if (_F.pideKilometraje(tipo)) ...[
                  _titulo('Kilometraje'),
                  TextField(
                    controller: _kilometrajeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: const InputDecoration(border: OutlineInputBorder(), suffixText: 'km'),
                    onChanged: (v) => cubit.cambiarKilometraje(_numero(v)),
                  ),
                ],
                if (_F.pideFotoLectura(tipo)) _seccionFotoLectura(s, tipo),
                if (_F.pideFechaHora(tipo)) ...[
                  _titulo(_F.etiquetaFechaHora(d.tipoMantenimiento)),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    icon: const Icon(Icons.event),
                    label: Text(d.fechaHora == null ? 'Seleccionar fecha y hora' : _fmtFechaHora(d.fechaHora!)),
                    onPressed: () => _elegirFechaHora(s),
                  ),
                ],
                if (_F.pideFecha(tipo)) ...[
                  _titulo(_F.etiquetaFecha(d.tipoMantenimiento)),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    icon: const Icon(Icons.event),
                    label: Text(d.fechaHora == null ? 'Seleccionar fecha' : _F.textoFecha(tipo, d.fechaHora!)),
                    onPressed: () => _elegirFecha(s),
                  ),
                ],
              ],

              // 4. Detalle y evidencias.
              _titulo(_F.etiquetaDetalle(d.tipoMantenimiento)),
              TextField(
                controller: _detalleCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: d.tipoMantenimiento == TipoMantenimiento.preventivo
                      ? 'Qué trabajo se debe realizar'
                      : 'Describa la falla observada',
                ),
                onChanged: cubit.cambiarDetalle,
              ),
              _titulo('Evidencias (mínimo 1 foto o video)'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Tomar foto'),
                  onPressed: () => _agregarFotos(camara: true),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Desde archivos'),
                  onPressed: () => _agregarFotos(camara: false),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.videocam_outlined),
                  label: const Text('Grabar video'),
                  onPressed: () => _agregarVideo(camara: true),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.video_library_outlined),
                  label: const Text('Video desde archivos'),
                  onPressed: () => _agregarVideo(camara: false),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Videos: máximo ${_F.maximoVideos}, de hasta ${_F.duracionMaximaVideo.inSeconds} segundos.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
              if (s.fotos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    for (var i = 0; i < s.fotos.length; i++)
                      _MiniaturaFoto(foto: s.fotos[i], onQuitar: () => cubit.quitarFoto(i)),
                  ]),
                ),
              if (s.videos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    for (var i = 0; i < s.videos.length; i++)
                      InputChip(
                        avatar: const Icon(Icons.play_circle_outline),
                        label: Text('Video ${i + 1}'),
                        onDeleted: () => cubit.quitarVideo(i),
                      ),
                  ]),
                ),

              // Errores de validación.
              if (s.errores.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 18),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [for (final e in s.errores) Text('• $e', style: TextStyle(color: Colors.red.shade800))],
                  ),
                ),

              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _azul,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: enviando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.build_circle_outlined),
                label: Text(enviando ? s.mensaje : 'Crear requerimiento de mantenimiento'),
                onPressed: () => cubit.enviar(usuarioNombre: usuario.nombre, rol: usuario.rol),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniaturaFoto extends StatelessWidget {
  final XFile foto;
  final VoidCallback onQuitar;

  const _MiniaturaFoto({required this.foto, required this.onQuitar});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FutureBuilder<Uint8List>(
            future: foto.readAsBytes(),
            builder: (context, snap) => SizedBox(
              width: 84,
              height: 84,
              child: snap.hasData
                  ? Image.memory(snap.data!, fit: BoxFit.cover)
                  : Container(color: Colors.grey.shade200, child: const Icon(Icons.image_outlined)),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: InkWell(
            onTap: onQuitar,
            child: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
