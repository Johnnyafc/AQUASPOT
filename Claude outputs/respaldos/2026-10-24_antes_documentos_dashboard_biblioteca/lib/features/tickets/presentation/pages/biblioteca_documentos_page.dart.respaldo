// lib/features/tickets/presentation/pages/biblioteca_documentos_page.dart
//
// 📚 BIBLIOTECA DE DOCUMENTOS
// Reúne, en una sola pantalla y para CUALQUIER usuario autenticado,
// absolutamente todos los archivos (fotos y documentos) que se han
// subido a cada ticket en toda la app: fotos de recepción, acta PDF,
// órdenes de venta/compra, adjuntos de evaluación técnica, proformas
// (PDF/Excel), órdenes de compra de Gestión de Compras, evidencia de
// trabajo (fotos/videos), evidencias de garantía, guía de remisión y
// factura.
//
// ⚙️ ESTRUCTURA (no es un dump plano):
//   Ticket
//     └── Categoría (ej. "Fotos de Recepción", "Factura")
//           └── Documentos individuales
// Las categorías con varias fotos se muestran como una cuadrícula de
// miniaturas; el resto de categorías (PDF/Excel/Video/otros) se
// muestran como una lista de filas con ícono + nombre corto.
//
// 🏷️ NOMBRES CORTOS: nunca se muestra la URL larga de Firebase Storage
// como texto — cada documento recibe una etiqueta corta derivada de su
// tipo (ej. "Foto 1", "PDF 2", "Excel 1"). La URL completa solo se usa
// para abrir el archivo o copiarlo al portapapeles.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/enum/segmento_operativo.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../../../../core/theme/ticket_visual_theme.dart';
import '../../domain/entities/ticket_entity.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../widgets/copy_icon_button_widget.dart';

// =============================================================================
// 🗂️ MODELOS LOCALES DE PRESENTACIÓN (no tocan el dominio ni Firestore)
// =============================================================================

enum _TipoArchivo { foto, pdf, excel, video, otro }

IconData _iconoTipo(_TipoArchivo t) {
  switch (t) {
    case _TipoArchivo.foto:
      return Icons.image_outlined;
    case _TipoArchivo.pdf:
      return Icons.picture_as_pdf_outlined;
    case _TipoArchivo.excel:
      return Icons.grid_on_outlined;
    case _TipoArchivo.video:
      return Icons.videocam_outlined;
    case _TipoArchivo.otro:
      return Icons.insert_drive_file_outlined;
  }
}

String _nombreTipo(_TipoArchivo t) {
  switch (t) {
    case _TipoArchivo.foto:
      return 'Foto';
    case _TipoArchivo.pdf:
      return 'PDF';
    case _TipoArchivo.excel:
      return 'Excel';
    case _TipoArchivo.video:
      return 'Video';
    case _TipoArchivo.otro:
      return 'Archivo';
  }
}

// 🔎 Clasifica un archivo SOLO por su extensión en la URL — así funciona
// igual sin importar en qué campo del ticket vino guardado (algunos
// campos históricamente mezclan PDF/JPG/PNG en la misma lista).
_TipoArchivo _tipoDesdeUrl(String url) {
  final sinQuery = url.split('?').first.toLowerCase();
  if (sinQuery.endsWith('.jpg') ||
      sinQuery.endsWith('.jpeg') ||
      sinQuery.endsWith('.png') ||
      sinQuery.endsWith('.webp') ||
      sinQuery.endsWith('.gif') ||
      sinQuery.endsWith('.heic')) {
    return _TipoArchivo.foto;
  }
  if (sinQuery.endsWith('.pdf')) return _TipoArchivo.pdf;
  if (sinQuery.endsWith('.xls') || sinQuery.endsWith('.xlsx') || sinQuery.endsWith('.csv')) {
    return _TipoArchivo.excel;
  }
  if (sinQuery.endsWith('.mp4') || sinQuery.endsWith('.mov') || sinQuery.endsWith('.avi') || sinQuery.endsWith('.webm')) {
    return _TipoArchivo.video;
  }
  return _TipoArchivo.otro;
}

class _Doc {
  final String url;
  final String etiqueta; // 🏷️ nombre corto para mostrar (nunca la URL)
  final _TipoArchivo tipo;
  const _Doc({required this.url, required this.etiqueta, required this.tipo});
}

class _Categoria {
  final String titulo;
  final IconData icono;
  final List<_Doc> documentos;
  const _Categoria({required this.titulo, required this.icono, required this.documentos});

  bool get esGaleriaFotos => documentos.every((d) => d.tipo == _TipoArchivo.foto);
}

List<_Doc> _docsDesde(List<String> urls) {
  final limpias = urls.where((u) => u.trim().isNotEmpty).toList();
  final docs = <_Doc>[];
  for (var i = 0; i < limpias.length; i++) {
    final tipo = _tipoDesdeUrl(limpias[i]);
    final etiqueta = limpias.length > 1 ? '${_nombreTipo(tipo)} ${i + 1}' : _nombreTipo(tipo);
    docs.add(_Doc(url: limpias[i], etiqueta: etiqueta, tipo: tipo));
  }
  return docs;
}

// 🧠 EXTRACTOR ÚNICO: recorre TODOS los campos del ticket (y sus objetos
// anidados) que pueden contener una URL de Firebase Storage. Si mañana se
// agrega un campo nuevo de archivo, solo hay que añadir una línea aquí.
List<_Categoria> _extraerCategorias(TicketEntity t) {
  final categorias = <_Categoria>[];

  void agregar(String titulo, IconData icono, List<String> urls) {
    final docs = _docsDesde(urls);
    if (docs.isNotEmpty) {
      categorias.add(_Categoria(titulo: titulo, icono: icono, documentos: docs));
    }
  }

  agregar('Fotos de Recepción', Icons.photo_camera_outlined, t.fotosUrls);
  agregar('Acta de Recepción (PDF)', Icons.description_outlined, [if (t.pdfActaUrl != null) t.pdfActaUrl!]);
  agregar('Orden de Venta', Icons.point_of_sale_outlined, t.codigoOrdenVenta);
  agregar('Orden de Compra (Costos)', Icons.request_quote_outlined, t.codigoOrdenCompra);
  agregar('Proceso de Trabajo', Icons.build_circle_outlined, t.procesoTrabajoUrls);
  agregar(
    'Evaluación Técnica — Proforma Excel',
    Icons.grid_on_outlined,
    [if (t.evaluacionTecnica?.urlProformaExcel != null) t.evaluacionTecnica!.urlProformaExcel!],
  );
  agregar('Evaluación Técnica — Adjuntos', Icons.attach_file_outlined, t.evaluacionTecnica?.urlsAdjuntosPdf ?? const []);
  agregar(
    'Evaluación Técnica — Adjuntos de Garantía',
    Icons.shield_outlined,
    t.evaluacionTecnica?.urlsAdjuntosPdfGarantia ?? const [],
  );
  agregar(
    'Evaluación Técnica — Revisión Antigua (Garantía)',
    Icons.history_edu_outlined,
    [if (t.evaluacionTecnica?.urlPdfRevisionTecnicaAntigua != null) t.evaluacionTecnica!.urlPdfRevisionTecnicaAntigua!],
  );
  agregar('Proforma Comercial — PDF', Icons.picture_as_pdf_outlined, t.proforma?.pdfUrls ?? const []);
  agregar('Proforma Comercial — Excel', Icons.grid_on_outlined, t.proforma?.excelUrls ?? const []);
  agregar('Gestión de Compras — Orden de Compra', Icons.shopping_cart_outlined, t.gestionCompras?.urlsOrdenCompra ?? const []);
  agregar('Evidencia de Trabajo — Fotos', Icons.photo_library_outlined, t.evidenciaTrabajo?.fotosUrls ?? const []);
  agregar('Evidencia de Trabajo — Videos', Icons.videocam_outlined, t.evidenciaTrabajo?.videosUrls ?? const []);
  agregar('Evidencias de Garantía', Icons.verified_user_outlined, t.urlsEvidenciasGarantia ?? const []);
  agregar('Guía de Remisión', Icons.local_shipping_outlined, [if (t.urlGuiaRemision != null) t.urlGuiaRemision!]);
  agregar('Factura', Icons.receipt_long_outlined, [if (t.urlFactura != null) t.urlFactura!]);

  return categorias;
}

// =============================================================================
// 🗄️ COLOR ÚNICO DE "CARPETA" — el amarillo/ámbar clásico de explorador de
// archivos, reservado solo para las carpetas (tickets y categorías). Los
// archivos individuales usan el color por tipo (_iconoTipo/kTicketAcento).
// =============================================================================
const Color _kColorCarpeta = Color(0xFFC98A2E);

// =============================================================================
// 📚 NIVEL 1 — LISTA DE TICKETS (cada ticket es una "carpeta")
// Al tocar una carpeta se ABRE OTRA PANTALLA (Navigator.push), igual que un
// explorador de archivos: no se despliega en el mismo lugar.
// =============================================================================
class BibliotecaDocumentosPage extends StatefulWidget {
  const BibliotecaDocumentosPage({super.key});

  @override
  State<BibliotecaDocumentosPage> createState() => _BibliotecaDocumentosPageState();
}

class _BibliotecaDocumentosPageState extends State<BibliotecaDocumentosPage> {
  final TextEditingController _buscadorController = TextEditingController();
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    // ⚙️ Misma fuente de datos que "Historial": telemetría GLOBAL, sin
    // restricción de segmento — así la biblioteca ve absolutamente todos
    // los tickets, sin importar el rol de quien la abre.
    context.read<TicketBloc>().add(const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.ninguno));
  }

  @override
  void dispose() {
    _buscadorController.dispose();
    super.dispose();
  }

  String _normalizar(String texto) {
    return texto
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u');
  }

  // 🧠 ESCANEO TOTAL: Evalúa absolutamente TODOS los parámetros del ticket y sus documentos
  bool _ticketCumpleBusquedaGlobal(TicketEntity t, List<_Categoria> categorias, String filtro) {
    if (filtro.trim().isEmpty) return true;

    final tokens = _normalizar(filtro)
        .split(RegExp(r'\s+'))
        .where((tok) => tok.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return true;

    // Nombres de categorías y etiquetas de documentos de la biblioteca
    final nombresCategorias = categorias.map((c) => c.titulo).join(' ');
    final etiquetasDocs = categorias.expand((c) => c.documentos.map((d) => '${d.etiqueta} ${_nombreTipo(d.tipo)}')).join(' ');

    // Accesorios activos
    final accesorios = t.accesoriosRecibidos != null
        ? t.accesoriosRecibidos!.entries.where((e) => e.value).map((e) => e.key).join(' ')
        : '';

    // Trazabilidad y usuarios de auditoría
    final eventos = t.historialEventos
        .map((e) => '${e.accion} ${e.usuarioNombre} ${e.usuarioRol}')
        .join(' ');

    // Etiqueta legible del estado (ej. "Evaluación técnica", "Revisión de pagos", etc.)
    final etiquetaEstado = t.estadoActual.nombreLegible;

    final corpus = _normalizar('''
      ${t.id}
      ${t.clienteId}
      ${t.campamento}
      ${t.nombreContacto}
      ${t.emailContacto}
      ${t.telefonoContacto}
      ${t.equipo.name}
      ${t.equipoDetalle ?? ''}
      ${t.marca}
      ${t.numeroSerie ?? ''}
      ${t.fallaReportada}
      ${t.sede.name}
      ${t.estadoActual.name}
      $etiquetaEstado
      ${t.tipoRequerimiento.name}
      ${t.lugarAtencion.name}
      ${t.notasRecepcion ?? ''}
      ${t.codigoProyecto ?? ''}
      ${t.numeroOrdenVenta ?? ''}
      ${t.codigoOrdenVenta.join(' ')}
      ${t.codigoOrdenCompra.join(' ')}
      ${t.tipoGarantia ?? ''}
      ${t.responsableFacturacion ?? ''}
      ${t.horometro != null ? t.horometro.toString() : ''}
      ${t.esGarantia == true ? 'garantia' : ''}
      $accesorios
      ${t.evaluacionTecnica?.observacion ?? ''}
      ${t.evaluacionTecnica?.numeroOVGarantia ?? ''}
      ${t.evidenciaTrabajo?.nombreTecnico ?? ''}
      ${t.evidenciaTrabajo?.notasTecnicas ?? ''}
      ${t.proforma?.observacion ?? ''}
      ${t.gestionCompras?.observacion ?? ''}
      $eventos
      $nombresCategorias
      $etiquetasDocs
    ''');

    return tokens.every((tok) => corpus.contains(tok));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text('Biblioteca de Documentos', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kTicketAcento),
            tooltip: 'Refrescar',
            onPressed: () => context.read<TicketBloc>().add(const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.ninguno)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _buscadorController,
              onChanged: (v) => setState(() => _filtro = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar por cualquier parámetro del ticket (ID, cliente, serie, técnico, etc.)...',
                hintStyle: const TextStyle(fontSize: 13, color: kTicketTextoSecundario),
                prefixIcon: const Icon(Icons.search, color: kTicketIcono),
                suffixIcon: _filtro.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, color: kTicketIcono),
                        onPressed: () {
                          _buscadorController.clear();
                          setState(() => _filtro = '');
                        },
                      ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<TicketBloc, TicketState>(
              builder: (context, state) {
                if (state.status == TicketStatus.loading && state.historial.isEmpty) {
                  return const Center(child: CircularProgressIndicator(color: kTicketAcento));
                }

                if (state.status == TicketStatus.error && state.historial.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text('Falla de sistema:\n${state.message}', textAlign: TextAlign.center, style: const TextStyle(color: kTicketError)),
                    ),
                  );
                }

                // 🧠 Construimos, por cada ticket, sus categorías de
                // documentos — y descartamos los tickets que no tengan
                // ningún archivo adjunto.
                final entradas = <MapEntry<TicketEntity, List<_Categoria>>>[];
                for (final ticket in state.historial) {
                  final categorias = _extraerCategorias(ticket);
                  if (categorias.isEmpty) continue;
                  if (_filtro.isNotEmpty) {
                    if (!_ticketCumpleBusquedaGlobal(ticket, categorias, _filtro)) {
                      continue;
                    }
                  }
                  entradas.add(MapEntry(ticket, categorias));
                }

                if (entradas.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.folder_off_outlined, size: 64, color: kTicketIcono),
                        const SizedBox(height: 16),
                        Text(
                          _filtro.isEmpty ? 'Todavía no hay documentos subidos.' : 'Ningún ticket coincide con "$_filtro".',
                          style: const TextStyle(color: kTicketTextoSecundario, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final totalDocs = entradas.fold<int>(
                  0,
                  (acc, e) => acc + e.value.fold<int>(0, (a, c) => a + c.documentos.length),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        '$totalDocs ${totalDocs == 1 ? 'documento' : 'documentos'} en ${entradas.length} ${entradas.length == 1 ? 'ticket' : 'tickets'}',
                        style: const TextStyle(color: kTicketTextoSecundario, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                        itemCount: entradas.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final ticket = entradas[index].key;
                          final categorias = entradas[index].value;
                          final totalTicket = categorias.fold<int>(0, (a, c) => a + c.documentos.length);
                          return _FilaCarpeta(
                            key: ValueKey(ticket.id),
                            titulo: 'Ticket: ${ticket.id}',
                            subtitulo: [
                              if (ticket.clienteId.trim().isNotEmpty) ticket.clienteId,
                              if (ticket.campamento.trim().isNotEmpty) ticket.campamento,
                              if (ticket.equipo.name.isNotEmpty) ticket.equipo.name,
                              if (ticket.nombreContacto.trim().isNotEmpty) ticket.nombreContacto,
                            ].where((s) => s.trim().isNotEmpty).join(' · '),
                            totalArchivos: totalTicket,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => _CarpetaTicketPage(ticket: ticket, categorias: categorias)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 🗂️ NIVEL 2 — DENTRO DE UN TICKET: LISTA DE CATEGORÍAS (cada categoría es
// también una "carpeta", ej. "Fotos de Recepción", "Factura"). Pantalla
// aparte, con su propia flecha de "atrás" — igual que entrar a una
// subcarpeta en el explorador de Windows.
// =============================================================================
class _CarpetaTicketPage extends StatelessWidget {
  final TicketEntity ticket;
  final List<_Categoria> categorias;

  const _CarpetaTicketPage({required this.ticket, required this.categorias});

  @override
  Widget build(BuildContext context) {
    final totalTicket = categorias.fold<int>(0, (a, c) => a + c.documentos.length);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: Text('Ticket: ${ticket.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              '$totalTicket ${totalTicket == 1 ? 'documento' : 'documentos'} en ${categorias.length} ${categorias.length == 1 ? 'carpeta' : 'carpetas'}',
              style: const TextStyle(color: kTicketTextoSecundario, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              itemCount: categorias.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final categoria = categorias[index];
                return _FilaCarpeta(
                  titulo: categoria.titulo,
                  subtitulo: categoria.esGaleriaFotos ? 'Galería de fotos' : 'Documentos',
                  totalArchivos: categoria.documentos.length,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => _ArchivosCategoriaPage(ticketId: ticket.id, categoria: categoria)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 📄 NIVEL 3 — DENTRO DE UNA CATEGORÍA: LOS ARCHIVOS DE VERDAD (fotos en
// cuadrícula o lista de documentos). Última pantalla de la navegación.
// =============================================================================
class _ArchivosCategoriaPage extends StatelessWidget {
  final String ticketId;
  final _Categoria categoria;

  const _ArchivosCategoriaPage({required this.ticketId, required this.categoria});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: Text(categoria.titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ticket $ticketId · ${categoria.documentos.length} ${categoria.documentos.length == 1 ? 'archivo' : 'archivos'}',
              style: const TextStyle(color: kTicketTextoSecundario, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (categoria.esGaleriaFotos) _GaleriaFotos(documentos: categoria.documentos) else _ListaDocumentos(documentos: categoria.documentos),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 📁 FILA DE CARPETA — misma apariencia para tickets (nivel 1) y categorías
// (nivel 2): ícono de carpeta ámbar, nombre, contador de archivos y flecha
// para "entrar".
// =============================================================================
class _FilaCarpeta extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final int totalArchivos;
  final VoidCallback onTap;

  const _FilaCarpeta({super.key, required this.titulo, required this.subtitulo, required this.totalArchivos, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: const AvatarSuave(color: _kColorCarpeta, icono: Icons.folder_rounded),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: subtitulo.trim().isEmpty
          ? null
          : Text(subtitulo, style: const TextStyle(fontSize: 12, color: kTicketTextoSecundario), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InsigniaSuave(color: _kColorCarpeta, texto: '$totalArchivos', icono: Icons.attachment),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: kTicketIcono),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 🖼️ CUADRÍCULA DE MINIATURAS (categorías con varias fotos — bien
// estructuradas en grilla, no en una lista plana de enlaces)
// -----------------------------------------------------------------------------
class _GaleriaFotos extends StatelessWidget {
  final List<_Doc> documentos;
  const _GaleriaFotos({required this.documentos});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final doc in documentos) _MiniaturaFoto(doc: doc, todas: documentos),
      ],
    );
  }
}

class _MiniaturaFoto extends StatelessWidget {
  final _Doc doc;
  final List<_Doc> todas;
  const _MiniaturaFoto({required this.doc, required this.todas});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _abrirVisorFotos(context, todas, todas.indexOf(doc)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 76,
          height: 76,
          color: Colors.grey.shade200,
          child: Image.network(
            doc.url,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: kTicketAcento)));
            },
            errorBuilder: (context, error, stack) => const Icon(Icons.broken_image_outlined, color: kTicketIcono, size: 22),
          ),
        ),
      ),
    );
  }
}

void _abrirVisorFotos(BuildContext context, List<_Doc> fotos, int indiceInicial) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) => _VisorFotosDialog(fotos: fotos, indiceInicial: indiceInicial),
  );
}

class _VisorFotosDialog extends StatefulWidget {
  final List<_Doc> fotos;
  final int indiceInicial;
  const _VisorFotosDialog({required this.fotos, required this.indiceInicial});

  @override
  State<_VisorFotosDialog> createState() => _VisorFotosDialogState();
}

class _VisorFotosDialogState extends State<_VisorFotosDialog> {
  late final PageController _pageController;
  late int _indiceActual;

  @override
  void initState() {
    super.initState();
    _indiceActual = widget.indiceInicial;
    _pageController = PageController(initialPage: widget.indiceInicial);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actual = widget.fotos[_indiceActual];
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: double.infinity,
            height: 480,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.fotos.length,
              onPageChanged: (i) => setState(() => _indiceActual = i),
              itemBuilder: (context, i) => InteractiveViewer(
                child: Image.network(
                  widget.fotos[i].url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stack) =>
                      const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48)),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${actual.etiqueta}  (${_indiceActual + 1}/${widget.fotos.length})',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.open_in_new, color: Colors.white, size: 18),
                    tooltip: 'Abrir en pestaña nueva',
                    onPressed: () => _abrirDocumento(context, actual.url),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                    tooltip: 'Copiar enlace',
                    onPressed: () => _copiarEnlace(context, actual.etiqueta, actual.url),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 📄 LISTA DE DOCUMENTOS (PDF / Excel / Video / otros)
// -----------------------------------------------------------------------------
class _ListaDocumentos extends StatelessWidget {
  final List<_Doc> documentos;
  const _ListaDocumentos({required this.documentos});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final doc in documentos)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _abrirDocumento(context, doc.url),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(_iconoTipo(doc.tipo), size: 18, color: kTicketAcento),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(doc.etiqueta, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTicketTextoPrincipal)),
                    ),
                    CopyIconButtonWidget(etiqueta: doc.etiqueta, valor: doc.url),
                    IconButton(
                      icon: const Icon(Icons.open_in_new, size: 16),
                      color: kTicketIcono,
                      tooltip: 'Abrir',
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _abrirDocumento(context, doc.url),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// 🚀 UTILITARIO COMPARTIDO: abrir un documento en una pestaña/app externa
// =============================================================================
Future<void> _abrirDocumento(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  final abierto = await canLaunchUrl(uri) ? await launchUrl(uri, mode: LaunchMode.externalApplication) : false;
  if (!abierto && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir el documento.'), backgroundColor: kTicketError),
    );
  }
}

// 🔧 Usado por el visor de fotos (overlay oscuro), donde no encaja el
// estilo fijo de CopyIconButtonWidget (ícono gris sobre fondo claro) —
// misma acción (copiar al portapapeles + confirmación), distinto ícono.
Future<void> _copiarEnlace(BuildContext context, String etiqueta, String url) async {
  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$etiqueta copiado'), duration: const Duration(milliseconds: 1200), behavior: SnackBarBehavior.floating),
  );
}
