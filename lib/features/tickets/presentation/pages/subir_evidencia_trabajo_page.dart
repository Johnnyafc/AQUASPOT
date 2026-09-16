import 'dart:async';
import 'package:aquaspot_postventa/core/enum/rol_usuario.dart';
import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:aquaspot_postventa/core/services/borrador_storage_service.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:aquaspot_postventa/features/tecnicos/data/datasources/tecnico_remote_datasource.dart';
import 'package:aquaspot_postventa/features/tecnicos/domain/entities/tecnico_entity.dart';
import 'package:aquaspot_postventa/features/fallas/data/datasources/metrica_falla_remote_datasource.dart';
import 'package:aquaspot_postventa/features/fallas/data/models/metrica_falla_model.dart';
import 'package:aquaspot_postventa/features/fallas/domain/entities/metrica_falla_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/copy_icon_button_widget.dart';
import '../widgets/tarjeta_no_requiere_compras_widget.dart';

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
  final TextEditingController _tecnicoController = TextEditingController();

  final TecnicoRemoteDataSource _tecnicosDataSource = TecnicoRemoteDataSource();
  final MetricaFallaRemoteDataSource _fallasDataSource = MetricaFallaRemoteDataSource();
  final List<String> _tecnicosAsignados = [];
  final List<DiagnosticoFallaEntity> _diagnosticoFallas = [];
  PlatformFile? _archivoInformeTecnico;
  String? _urlInformeTecnicoExistente;
  Timer? _debounceAutoSave;

  @override
  void initState() {
    super.initState();
    _tecnicosAsignados.addAll(widget.ticket.tecnicosAsignados);
    _diagnosticoFallas.addAll(widget.ticket.diagnosticoFallas);
    _urlInformeTecnicoExistente = widget.ticket.urlInformeTecnico;

    if (widget.ticket.evidenciaTrabajo?.nombreTecnico != null) {
      _tecnicoController.text = widget.ticket.evidenciaTrabajo!.nombreTecnico!;
    } else if (_tecnicosAsignados.isNotEmpty) {
      _tecnicoController.text = _tecnicosAsignados.join(', ');
    }
    if (widget.ticket.evidenciaTrabajo?.notasTecnicas != null) {
      _notasController.text = widget.ticket.evidenciaTrabajo!.notasTecnicas!;
    }
    _cargarBorradorLocal();
    _tecnicoController.addListener(_onTextoModificado);
    _notasController.addListener(_onTextoModificado);
  }

  void _onTextoModificado() {
    _debounceAutoSave?.cancel();
    _debounceAutoSave = Timer(const Duration(milliseconds: 600), () {
      _guardarBorrador();
    });
  }

  bool _puedeSubirInforme(AuthState authState) {
    if (authState is! Authenticated) return false;
    final user = authState.usuario;
    final esAdminOSupervisor = user.rol == RolUsuario.admin || user.rol == RolUsuario.supervisor;
    final esSegmentoContadorOCosechadora =
        user.segmento == SegmentoOperativo.contador || user.segmento == SegmentoOperativo.cosechadora;
    return esAdminOSupervisor || esSegmentoContadorOCosechadora;
  }

  bool get _esEquipoContadorOCosechadora {
    final eq = widget.ticket.equipo;
    final detalle = (widget.ticket.equipoDetalle ?? '').toLowerCase();
    return eq == TipoEquipo.Contador ||
        eq == TipoEquipo.Cosechadora ||
        detalle.contains('contador') ||
        detalle.contains('cosechadora');
  }

  Future<void> _cargarBorradorLocal() async {
    final draft = await BorradorStorageService.obtenerBorrador(
      BorradorStorageService.claveDraftTrabajo(widget.ticket.id),
    );
    if (draft != null && mounted) {
      final String? tec = draft['nombreTecnico'] as String?;
      final String? notas = draft['notasTecnicas'] as String?;
      bool huboCambios = false;

      if (tec != null && tec.isNotEmpty && _tecnicoController.text.isEmpty) {
        _tecnicoController.text = tec;
        huboCambios = true;
      }
      if (notas != null && notas.isNotEmpty && _notasController.text.isEmpty) {
        _notasController.text = notas;
        huboCambios = true;
      }

      // 1. Fotos: Soporte nativo + Base64 en Web con fallback a paths
      if (draft['fotos'] != null && draft['fotos'] is List) {
        final fotos = BorradorStorageService.jsonToPlatformFiles(draft['fotos'] as List);
        if (fotos.isNotEmpty) {
          _fotosSeleccionadas.clear();
          _fotosSeleccionadas.addAll(fotos);
          huboCambios = true;
        }
      } else if (draft['fotosPaths'] != null && draft['fotosPaths'] is List) {
        final fotos = BorradorStorageService.pathsToPlatformFiles(draft['fotosPaths'] as List);
        if (fotos.isNotEmpty) {
          _fotosSeleccionadas.clear();
          _fotosSeleccionadas.addAll(fotos);
          huboCambios = true;
        }
      }

      // 2. Videos: Soporte nativo + Base64 en Web con fallback a paths
      if (draft['videos'] != null && draft['videos'] is List) {
        final videos = BorradorStorageService.jsonToPlatformFiles(draft['videos'] as List);
        if (videos.isNotEmpty) {
          _videosSeleccionados.clear();
          _videosSeleccionados.addAll(videos);
          huboCambios = true;
        }
      } else if (draft['videosPaths'] != null && draft['videosPaths'] is List) {
        final videos = BorradorStorageService.pathsToPlatformFiles(draft['videosPaths'] as List);
        if (videos.isNotEmpty) {
          _videosSeleccionados.clear();
          _videosSeleccionados.addAll(videos);
          huboCambios = true;
        }
      }

      // 3. Técnicos asignados
      if (draft['tecnicosAsignados'] != null && draft['tecnicosAsignados'] is List) {
        final tecs = (draft['tecnicosAsignados'] as List).map((e) => e.toString()).toList();
        if (tecs.isNotEmpty) {
          _tecnicosAsignados.clear();
          _tecnicosAsignados.addAll(tecs);
          _tecnicoController.text = _tecnicosAsignados.join(', ');
          huboCambios = true;
        }
      }

      // 4. Diagnóstico de fallas
      if (draft['diagnosticoFallas'] != null && draft['diagnosticoFallas'] is List) {
        final fallas = (draft['diagnosticoFallas'] as List)
            .map((e) => DiagnosticoFallaModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (fallas.isNotEmpty) {
          _diagnosticoFallas.clear();
          _diagnosticoFallas.addAll(fallas);
          huboCambios = true;
        }
      }

      // 5. Informe Técnico (PDF/Excel)
      if (draft['informeTecnico'] != null) {
        final informe = BorradorStorageService.jsonToPlatformFile(draft['informeTecnico']);
        if (informe != null) {
          _archivoInformeTecnico = informe;
          huboCambios = true;
        }
      } else if (draft['informeTecnicoPath'] != null) {
        final informe = BorradorStorageService.pathToPlatformFile(draft['informeTecnicoPath'] as String);
        if (informe != null) {
          _archivoInformeTecnico = informe;
          huboCambios = true;
        }
      }

      if (huboCambios) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💾 Se restauró el borrador guardado en el dispositivo.'),
            backgroundColor: Color(0xFF005A9C),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _guardarBorrador() {
    _debounceAutoSave?.cancel();
    BorradorStorageService.guardarBorrador(
      clave: BorradorStorageService.claveDraftTrabajo(widget.ticket.id),
      datos: {
        'nombreTecnico': _tecnicoController.text,
        'notasTecnicas': _notasController.text,
        'fotos': BorradorStorageService.platformFilesToJson(_fotosSeleccionadas),
        'videos': BorradorStorageService.platformFilesToJson(_videosSeleccionados),
        'fotosPaths': BorradorStorageService.platformFilesToPaths(_fotosSeleccionadas),
        'videosPaths': BorradorStorageService.platformFilesToPaths(_videosSeleccionados),
        'tecnicosAsignados': _tecnicosAsignados,
        'diagnosticoFallas': _diagnosticoFallas.map((f) => f.toJson()).toList(),
        'informeTecnico': _archivoInformeTecnico != null
            ? BorradorStorageService.platformFileToJson(_archivoInformeTecnico!)
            : null,
        'informeTecnicoPath': _archivoInformeTecnico?.path,
      },
    );
  }

  void _mostrarModalAsignarTecnicos() {
    final Set<String> seleccionados = Set<String>.from(_tecnicosAsignados);
    String busqueda = '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.group_add_outlined, color: Color(0xFF005A9C)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Asignar Técnicos (${widget.ticket.id})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar técnico...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          busqueda = val.trim().toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: StreamBuilder<List<TecnicoEntity>>(
                        stream: _tecnicosDataSource.escucharTecnicos(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}'));
                          }
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final tecnicos = snapshot.data!.where((t) {
                            final match = busqueda.isEmpty ||
                                t.nombre.toLowerCase().contains(busqueda) ||
                                t.rol.toLowerCase().contains(busqueda);
                            return match && (t.activo || seleccionados.contains(t.nombre));
                          }).toList();

                          if (tecnicos.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_off_outlined, size: 40, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No hay técnicos disponibles',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: tecnicos.length,
                            itemBuilder: (context, idx) {
                              final tec = tecnicos[idx];
                              final isSelected = seleccionados.contains(tec.nombre);
                              return CheckboxListTile(
                                value: isSelected,
                                title: Text(tec.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(tec.rol, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                secondary: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFF005A9C).withValues(alpha: 0.1),
                                  child: const Icon(Icons.person, size: 18, color: Color(0xFF005A9C)),
                                ),
                                activeColor: const Color(0xFF005A9C),
                                onChanged: (val) {
                                  setModalState(() {
                                    if (val == true) {
                                      seleccionados.add(tec.nombre);
                                    } else {
                                      seleccionados.remove(tec.nombre);
                                    }
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF005A9C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    setState(() {
                      _tecnicosAsignados.clear();
                      _tecnicosAsignados.addAll(seleccionados);
                      _tecnicoController.text = _tecnicosAsignados.join(', ');
                    });
                    _guardarBorrador();

                    final authState = context.read<AuthBloc>().state;
                    String operador = 'SUPERVISOR';
                    String rol = 'SUPERVISOR';
                    if (authState is Authenticated) {
                      operador = authState.usuario.nombre;
                      rol = authState.usuario.rol.name.toUpperCase();
                    }

                    context.read<TicketBloc>().add(
                      AsignarTecnicosTrabajoEvent(
                        ticket: widget.ticket,
                        tecnicos: seleccionados.toList(),
                        nombreUsuario: operador,
                        rolUsuario: rol,
                      ),
                    );
                    Navigator.pop(ctx);
                  },
                  child: Text('Guardar (${seleccionados.length})'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _mostrarModalDiagnosticoFallas() {
    final List<DiagnosticoFallaEntity> seleccionadas =
        List<DiagnosticoFallaEntity>.from(_diagnosticoFallas);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (bottomSheetCtx, setSheetState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF003057),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.troubleshoot, color: Colors.amber),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Diagnóstico de Fallas: ${widget.ticket.equipo.name}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Ticket ${widget.ticket.id}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<MatrizFallasEquipoEntity>(
                      stream: _fallasDataSource.escucharMatrizEquipo(widget.ticket.equipo.name),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final matriz = snapshot.data!;
                        final categorias = matriz.categorias;

                        if (categorias.isEmpty) {
                          return const Center(
                            child: Text('No hay catálogo de fallas configurado para este equipo.'),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: categorias.length,
                          itemBuilder: (context, catIdx) {
                            final cat = categorias[catIdx];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: ExpansionTile(
                                initiallyExpanded: true,
                                title: Text(
                                  cat.nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xFF003057),
                                  ),
                                ),
                                children: [
                                  if (cat.subcategorias.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: Text(
                                        'Sin componentes configurados en esta categoría.',
                                        style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                                      ),
                                    )
                                  else
                                    ...cat.subcategorias.map((sub) {
                                      return Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF9FBFC),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.blueGrey.shade100),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.blueGrey.shade50,
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.device_hub, size: 15, color: Color(0xFF003057)),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    sub.nombre,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                      color: Color(0xFF003057),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Text(
                                                    '${sub.fallas.length} fallas',
                                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (sub.fallas.isEmpty)
                                              const Padding(
                                                padding: EdgeInsets.all(8.0),
                                                child: Text(
                                                  'Sin fallas definidas en este componente.',
                                                  style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                                                ),
                                              )
                                            else
                                              ...sub.fallas.map((falla) {
                                                final isChecked = seleccionadas.any(
                                                  (f) =>
                                                      f.categoria == cat.nombre &&
                                                      f.subcategoria == sub.nombre &&
                                                      f.falla == falla,
                                                );

                                                return CheckboxListTile(
                                                  dense: true,
                                                  value: isChecked,
                                                  title: Text(falla, style: const TextStyle(fontSize: 13)),
                                                  activeColor: Colors.deepOrange,
                                                  onChanged: (val) {
                                                    setSheetState(() {
                                                      if (val == true) {
                                                        seleccionadas.add(DiagnosticoFallaEntity(
                                                          categoria: cat.nombre,
                                                          subcategoria: sub.nombre,
                                                          falla: falla,
                                                        ));
                                                      } else {
                                                        seleccionadas.removeWhere(
                                                          (f) =>
                                                              f.categoria == cat.nombre &&
                                                              f.subcategoria == sub.nombre &&
                                                              f.falla == falla,
                                                        );
                                                      }
                                                    });
                                                  },
                                                );
                                              }),
                                          ],
                                        ),
                                      );
                                    }),
                                  const SizedBox(height: 6),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          offset: const Offset(0, -2),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${seleccionadas.length} fallas seleccionadas',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey),
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Guardar Diagnóstico'),
                          onPressed: () {
                            setState(() {
                              _diagnosticoFallas.clear();
                              _diagnosticoFallas.addAll(seleccionadas);
                            });
                            _guardarBorrador();

                            final authState = context.read<AuthBloc>().state;
                            String operador = 'SUPERVISOR';
                            String rol = 'SUPERVISOR';
                            if (authState is Authenticated) {
                              operador = authState.usuario.nombre;
                              rol = authState.usuario.rol.name.toUpperCase();
                            }

                            context.read<TicketBloc>().add(
                              GuardarDiagnosticoFallasEvent(
                                ticket: widget.ticket,
                                fallas: seleccionadas,
                                nombreUsuario: operador,
                                rolUsuario: rol,
                              ),
                            );
                            Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _seleccionarInformeTecnico() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      if (!mounted) return;
      final archivo = result.files.first;
      setState(() {
        _archivoInformeTecnico = archivo;
      });
      _guardarBorrador();

      final authState = context.read<AuthBloc>().state;
      String operador = 'OPERADOR';
      String rol = 'TECNICO';
      if (authState is Authenticated) {
        operador = authState.usuario.nombre;
        rol = authState.usuario.rol.name.toUpperCase();
      }

      context.read<TicketBloc>().add(
        SubirInformeTecnicoEvent(
          ticket: widget.ticket,
          archivo: archivo,
          nombreUsuario: operador,
          rolUsuario: rol,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📄 Subiendo informe técnico: ${archivo.name}...'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    }
  }

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
      _guardarBorrador();
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

    final String nombreTecnico = _tecnicosAsignados.isNotEmpty
        ? _tecnicosAsignados.join(', ')
        : (widget.ticket.evidenciaTrabajo?.nombreTecnico?.isNotEmpty == true
            ? widget.ticket.evidenciaTrabajo!.nombreTecnico!
            : nombreOperario);
    final ticketConDatosActuales = widget.ticket.copyWith(
      tecnicosAsignados: _tecnicosAsignados,
      diagnosticoFallas: _diagnosticoFallas,
      urlInformeTecnico: _urlInformeTecnicoExistente,
    );
    context.read<TicketBloc>().add(
      ProcesarEvidenciaTrabajoEvent(
        ticket: ticketConDatosActuales,
        fotos: _fotosSeleccionadas,
        videos: _videosSeleccionados,
        notasTecnicas: _notasController.text,
        nombreTecnico: nombreTecnico,
        nombreUsuario: nombreOperario, 
        rolUsuario:  rolOperario,            
      )
    );
  }

  Future<void> _confirmarDescartarBorrador() async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Descartar Borrador'),
          ],
        ),
        content: const Text(
          '¿Desea eliminar el borrador de trabajo guardado localmente? Se restablecerán las fotos, notas y asignaciones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      await BorradorStorageService.eliminarBorrador(
        BorradorStorageService.claveDraftTrabajo(widget.ticket.id),
      );
      setState(() {
        _fotosSeleccionadas.clear();
        _videosSeleccionados.clear();
        _archivoInformeTecnico = null;
        _notasController.clear();
        if (widget.ticket.evidenciaTrabajo?.notasTecnicas != null) {
          _notasController.text = widget.ticket.evidenciaTrabajo!.notasTecnicas!;
        }
        _tecnicosAsignados.clear();
        _tecnicosAsignados.addAll(widget.ticket.tecnicosAsignados);
        if (_tecnicosAsignados.isNotEmpty) {
          _tecnicoController.text = _tecnicosAsignados.join(', ');
        } else {
          _tecnicoController.clear();
        }
        _diagnosticoFallas.clear();
        _diagnosticoFallas.addAll(widget.ticket.diagnosticoFallas);
        _urlInformeTecnicoExistente = widget.ticket.urlInformeTecnico;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Borrador de trabajo descartado.'),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _debounceAutoSave?.cancel();
    _tecnicoController.removeListener(_onTextoModificado);
    _notasController.removeListener(_onTextoModificado);
    _tecnicoController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ejecución: ${widget.ticket.id}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Text('Autoguardado local activo 💾', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Descartar Borrador',
            onPressed: _confirmarDescartarBorrador,
          ),
        ],
      ),
      body: BlocListener<TicketBloc, TicketState>(
        listener: (context, state) {
          if (state.status == TicketStatus.operationSuccess) {
            if (state.message.contains('Evidencia procesada') || state.message.contains('finalizar')) {
              BorradorStorageService.eliminarBorrador(
                BorradorStorageService.claveDraftTrabajo(widget.ticket.id),
              );
              Navigator.pop(context);
            } else {
              // Notificaciones de éxito para Asignar Técnicos, Diagnóstico o Informe Técnico
              if (state.currentTicket?.urlInformeTecnico != null) {
                setState(() {
                  _urlInformeTecnicoExistente = state.currentTicket!.urlInformeTecnico;
                  _archivoInformeTecnico = null;
                });
                _guardarBorrador();
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green.shade700,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } else if (state.status == TicketStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TarjetaNoRequiereComprasWidget(ticket: widget.ticket),
              const Text("Datos del Equipo (Bloqueado)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 12),
              _buildDataCardBloqueada(),
              
              const SizedBox(height: 20),
              // 🛠️ SECCIÓN DE GESTIÓN OPERATIVA: Técnicos, Diagnóstico e Informe Técnico
              _buildControlOperativoSection(authState),

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
              _buildGaleriaFotos(),
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
              _buildGaleriaVideos(),

              const SizedBox(height: 20),
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

  // Componente de solo lectura actualizado (Soporte dinámico y fallback de Excel)
  Widget _buildDataCardBloqueada() {
    // ⚙️ RUTINA DE ENRUTAMIENTO (Fallback) PARA EL EXCEL
    // Si la matriz principal de proforma no lo tiene, intentamos rescatarlo de evaluacionTecnica.
    String? urlExcelDefinitiva;
    if (widget.ticket.proforma != null && widget.ticket.proforma!.excelUrls.isNotEmpty) {
      urlExcelDefinitiva = widget.ticket.proforma!.excelUrls.first;
    } else if (widget.ticket.evaluacionTecnica != null && 
               widget.ticket.evaluacionTecnica!.urlProformaExcel != null && 
               widget.ticket.evaluacionTecnica!.urlProformaExcel!.isNotEmpty) {
      urlExcelDefinitiva = widget.ticket.evaluacionTecnica!.urlProformaExcel;
    }

    // Validación booleana rápida para saber si imprimimos el Divider inferior
    bool tienePdf = widget.ticket.proforma != null && widget.ticket.proforma!.pdfUrls.isNotEmpty;
    bool tieneDocumentosComerciales = (widget.ticket.numeroOrdenVenta != null && widget.ticket.numeroOrdenVenta!.isNotEmpty) || 
                                      tienePdf || 
                                      urlExcelDefinitiva != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F9), 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 📦 NUEVO: Código de Proyecto insertado en la cabecera operativa
          if (widget.ticket.codigoProyecto != null && widget.ticket.codigoProyecto!.isNotEmpty)
            _buildInfoRow(context, 'Código de Proyecto:', widget.ticket.codigoProyecto!.toUpperCase()),

          _buildInfoRow(context, 'Estado Actual:', widget.ticket.estadoActual.nombreMayusculas),
          _buildInfoRow(context, 'Tipo de requerimiento:', widget.ticket.tipoRequerimiento?.name.toUpperCase() ?? 'NINGUNO'),
          const Divider(height: 24, color: Colors.black12),

          _buildInfoRow(context, 'Equipo:', widget.ticket.equipo.name.toUpperCase()),
          _buildInfoRow(context, 'Lugar de recepción:', widget.ticket.lugarAtencion?.name.toUpperCase() ?? 'NINGUNO'),
          _buildInfoRow(context, 'Marca:', widget.ticket.marca?.toUpperCase() ?? 'NINGUNO'),
          const Divider(height: 24, color: Colors.black12),

          _buildInfoRow(context, 'Cliente:', widget.ticket.clienteId.toUpperCase()),
          _buildInfoRow(context, 'Campamento:', widget.ticket.campamento.toUpperCase()),
          _buildInfoRow(context, 'Contacto:', '${widget.ticket.nombreContacto ?? 'Sin registro'} (${widget.ticket.telefonoContacto ?? 'Sin registro'})'),
          const Divider(height: 24, color: Colors.black12),

          _buildInfoRow(context, 'Número de Serie:', widget.ticket.numeroSerie ?? 'No especificado'),
          const Divider(height: 24, color: Colors.black12),

          // ==================================================================
          // 📦 BLOQUE DE DOCUMENTACIÓN COMERCIAL (Orden de Venta / Compras)
          // ==================================================================
          
          if (widget.ticket.numeroOrdenVenta != null && widget.ticket.numeroOrdenVenta!.isNotEmpty) ...[
            _buildInfoRow(context, 'Orden de Venta:', widget.ticket.numeroOrdenVenta!),
            
            // ⚙️ MATRIZ MULTI-ARCHIVO: Iteramos sobre el List<String>
            if (widget.ticket.gestionCompras?.urlsOrdenCompra != null && widget.ticket.gestionCompras!.urlsOrdenCompra!.isNotEmpty)
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: widget.ticket.gestionCompras!.urlsOrdenCompra!.asMap().entries.map((entry) {
                  int idx = entry.key + 1; // Para enumerar los archivos
                  String url = entry.value;
                  return _buildDocumentoLink(
                    'Descargar Orden $idx', 
                    url, 
                    Icons.receipt_long, 
                    Colors.blueGrey
                  );
                }).toList(),
              ),
              
            const SizedBox(height: 12),
          ],

          // Renderizado condicional Híbrido (Proforma + Evaluación Técnica para Excel)
          if (tienePdf || urlExcelDefinitiva != null) ...[
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (tienePdf)
                  _buildDocumentoLink('Proforma (PDF)', widget.ticket.proforma!.pdfUrls.first, Icons.picture_as_pdf, Colors.red.shade700),
                if (urlExcelDefinitiva != null)
                  _buildDocumentoLink('Proforma (Excel)', urlExcelDefinitiva, Icons.table_view, Colors.green.shade700),
              ],
            ),
            const SizedBox(height: 12),
          ],
          
          if (tieneDocumentosComerciales)
            const Divider(height: 24, color: Colors.black12),

          // ==================================================================
          
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Falla Reportada e Inspección:',
                  style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)
                ),
              ),
              CopyIconButtonWidget(
                etiqueta: 'Falla Reportada e Inspección',
                valor: widget.ticket.fallaReportada ?? 'Sin detalle de falla reportada.',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              widget.ticket.fallaReportada ?? 'Sin detalle de falla reportada.', 
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 500) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
                    ),
                    CopyIconButtonWidget(etiqueta: label, valor: value),
                  ],
                ),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 180,
                child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
              ),
              CopyIconButtonWidget(etiqueta: label, valor: value),
            ],
          );
        },
      ),
    );
  }

  // ⚙️ SUBRUTINA: Renderizador de botones de enlaces web (Tubería de salida)
  Widget _buildDocumentoLink(String etiqueta, String url, IconData icono, Color colorIcono) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: InkWell(
        onTap: () async {
          final Uri uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('💥 Error crítico: Tubería de red rota o URL inválida para $etiqueta'), backgroundColor: Colors.red),
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, color: colorIcono, size: 20),
              const SizedBox(width: 8),
              Text(
                etiqueta, 
                style: const TextStyle(
                  fontSize: 13, 
                  fontWeight: FontWeight.w600, 
                  color: Colors.blueAccent, 
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🛠️ COMPONENTE: Sección de Asignación de Técnicos, Diagnóstico e Informe Técnico
  Widget _buildControlOperativoSection(AuthState authState) {
    final puedeSubirInforme = _puedeSubirInforme(authState);
    final esContadorOCosechadora = _esEquipoContadorOCosechadora;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_suggest, color: Color(0xFF003057), size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Control Operativo del Trabajo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF003057)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Asigne los técnicos encargados, configure el diagnóstico de fallas y cargue el informe técnico correspondiente.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),

          // Botones de acción principales
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // 1. ASIGNAR TÉCNICOS
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: Text(
                  _tecnicosAsignados.isEmpty
                      ? 'Asignar Técnicos'
                      : 'Técnicos (${_tecnicosAsignados.length})',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF005A9C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _mostrarModalAsignarTecnicos,
              ),

              // 2. DIAGNÓSTICO DE FALLAS
              ElevatedButton.icon(
                icon: const Icon(Icons.troubleshoot, size: 18),
                label: Text(
                  _diagnosticoFallas.isEmpty
                      ? 'Diagnóstico de Fallas'
                      : 'Diagnóstico (${_diagnosticoFallas.length})',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _mostrarModalDiagnosticoFallas,
              ),

              // 3. SUBIR INFORME TÉCNICO (Condicional según equipo y rol)
              if (puedeSubirInforme && esContadorOCosechadora)
                ElevatedButton.icon(
                  icon: Icon(
                    (_archivoInformeTecnico != null || (_urlInformeTecnicoExistente != null && _urlInformeTecnicoExistente!.isNotEmpty))
                        ? Icons.refresh
                        : Icons.upload_file,
                    size: 18,
                  ),
                  label: Text(
                    (_archivoInformeTecnico != null || (_urlInformeTecnicoExistente != null && _urlInformeTecnicoExistente!.isNotEmpty))
                        ? 'Actualizar Informe'
                        : 'Subir Informe Técnico',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _seleccionarInformeTecnico,
                ),
            ],
          ),

          // VISTA DE TÉCNICOS ASIGNADOS
          if (_tecnicosAsignados.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.people_outline, size: 16, color: Color(0xFF005A9C)),
                const SizedBox(width: 6),
                const Text(
                  'Técnicos Asignados:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF005A9C)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _tecnicosAsignados.map((tec) {
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: const Color(0xFF005A9C).withValues(alpha: 0.15),
                    child: const Icon(Icons.person, size: 14, color: Color(0xFF005A9C)),
                  ),
                  label: Text(tec, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  backgroundColor: const Color(0xFF005A9C).withValues(alpha: 0.08),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () {
                    setState(() {
                      _tecnicosAsignados.remove(tec);
                      _tecnicoController.text = _tecnicosAsignados.join(', ');
                    });
                    _guardarBorrador();
                    final authState = context.read<AuthBloc>().state;
                    String operador = 'SUPERVISOR';
                    String rol = 'SUPERVISOR';
                    if (authState is Authenticated) {
                      operador = authState.usuario.nombre;
                      rol = authState.usuario.rol.name.toUpperCase();
                    }
                    context.read<TicketBloc>().add(
                      AsignarTecnicosTrabajoEvent(
                        ticket: widget.ticket,
                        tecnicos: List<String>.from(_tecnicosAsignados),
                        nombreUsuario: operador,
                        rolUsuario: rol,
                      ),
                    );
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: const Color(0xFF005A9C).withValues(alpha: 0.3)),
                  ),
                );
              }).toList(),
            ),
          ],

          // VISTA DE FALLAS SELECCIONADAS
          if (_diagnosticoFallas.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.troubleshoot, size: 16, color: Colors.deepOrange),
                const SizedBox(width: 6),
                const Text(
                  'Diagnóstico de Fallas Registrado:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _diagnosticoFallas.map((falla) {
                return Chip(
                  label: Text(
                    falla.subcategoria.isNotEmpty
                        ? '${falla.categoria} > ${falla.subcategoria}: ${falla.falla}'
                        : '${falla.categoria}: ${falla.falla}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.deepOrange),
                  ),
                  backgroundColor: Colors.deepOrange.withValues(alpha: 0.08),
                  deleteIcon: const Icon(Icons.close, size: 14, color: Colors.deepOrange),
                  onDeleted: () {
                    setState(() {
                      _diagnosticoFallas.remove(falla);
                    });
                    _guardarBorrador();
                    final authState = context.read<AuthBloc>().state;
                    String operador = 'SUPERVISOR';
                    String rol = 'SUPERVISOR';
                    if (authState is Authenticated) {
                      operador = authState.usuario.nombre;
                      rol = authState.usuario.rol.name.toUpperCase();
                    }
                    context.read<TicketBloc>().add(
                      GuardarDiagnosticoFallasEvent(
                        ticket: widget.ticket,
                        fallas: List<DiagnosticoFallaEntity>.from(_diagnosticoFallas),
                        nombreUsuario: operador,
                        rolUsuario: rol,
                      ),
                    );
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.deepOrange.withValues(alpha: 0.3)),
                  ),
                );
              }).toList(),
            ),
          ],

          // VISTA DE INFORME TÉCNICO
          if (_archivoInformeTecnico != null || (_urlInformeTecnicoExistente != null && _urlInformeTecnicoExistente!.isNotEmpty)) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description, size: 20, color: Colors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informe Técnico:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                        Text(
                          _archivoInformeTecnico != null
                              ? 'Archivo listo: ${_archivoInformeTecnico!.name}'
                              : 'Informe técnico registrado en el ticket',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_urlInformeTecnicoExistente != null && _urlInformeTecnicoExistente!.isNotEmpty)
                    IconButton(
                      tooltip: 'Ver Informe',
                      icon: const Icon(Icons.open_in_new, size: 18, color: Colors.teal),
                      onPressed: () async {
                        final uri = Uri.parse(_urlInformeTecnicoExistente!);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  if (_archivoInformeTecnico != null)
                    IconButton(
                      tooltip: 'Quitar archivo seleccionado',
                      icon: const Icon(Icons.close, size: 18, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _archivoInformeTecnico = null;
                        });
                        _guardarBorrador();
                      },
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGaleriaFotos() {
    if (_fotosSeleccionadas.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _fotosSeleccionadas.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final foto = _fotosSeleccionadas[index];
          final bytes = foto.bytes;
          final kb = (foto.size / 1024).toStringAsFixed(0);

          return Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                margin: const EdgeInsets.only(top: 6, right: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blueGrey.shade300),
                  color: Colors.grey.shade100,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (bytes != null && bytes.isNotEmpty)
                      Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      )
                    else
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.image, color: Colors.blueGrey, size: 28),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                foto.name,
                                style: const TextStyle(fontSize: 9),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                        color: Colors.black.withValues(alpha: 0.65),
                        child: Text(
                          '${foto.name.split('.').last.toUpperCase()} • $kb KB',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _fotosSeleccionadas.removeAt(index);
                    });
                    _guardarBorrador();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGaleriaVideos() {
    if (_videosSeleccionados.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _videosSeleccionados.asMap().entries.map((entry) {
          final idx = entry.key;
          final video = entry.value;
          final sizeMb = (video.size / (1024 * 1024)).toStringAsFixed(1);
          return Chip(
            avatar: const CircleAvatar(
              backgroundColor: Colors.blueGrey,
              radius: 12,
              child: Icon(Icons.videocam, color: Colors.white, size: 14),
            ),
            label: Text(
              '${video.name} ($sizeMb MB)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.white,
            deleteIcon: const Icon(Icons.close, size: 16, color: Colors.red),
            onDeleted: () {
              setState(() {
                _videosSeleccionados.removeAt(idx);
              });
              _guardarBorrador();
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.blueGrey.shade200),
            ),
          );
        }).toList(),
      ),
    );
  }
}
