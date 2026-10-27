// lib/features/tickets/domain/services/documentos_ticket_service.dart
//
// 📂 Un solo lugar que define qué archivos tiene un ticket y en qué carpeta
// (Biblioteca de documentos) y columna (tabla "Detalle de tickets" del
// Dashboard) va cada uno, en el orden del flujo. Solo lectura de campos que
// ya se guardan; sin Flutter ni Firebase; probado en
// test/documentos_ticket_test.dart.
//
// Variables (revisadas el 2026-10-24 contra lo que cada pantalla guarda hoy):
// - Venta de repuesto: sus evidencias se guardan en `fotosUrls` (y repetidas
//   por repuesto en lineasRepuestoVenta[].urlsEvidencia) y sus audios en
//   `urlsAudiosAsistencia` (y por repuesto en .urlsAudios). Se usan solo los
//   campos del ticket para no mostrar todo doble, y en una venta `fotosUrls`
//   son "Venta de Repuesto — Evidencias", no fotos de recepción.
// - `procesoTrabajoUrls` ya no se escribe (CompletarProcesoTrabajoEvent no lo
//   dispara ninguna pantalla); se muestra como "(anterior)" para no perder
//   lo de tickets viejos.
// - `codigoOrdenVenta` / `codigoOrdenCompra` guardan URLs de los documentos
//   de OV / OC (al aprobar la proforma), no códigos.
// - Mantenimiento interno: sus fotos van en `fotosUrls` (como las de
//   recepción); la foto del horómetro / kilometraje y los videos, en
//   `mantenimientoInterno`.

import '../../../../core/enum/ticket_enums.dart';
import '../entities/ticket_entity.dart';

/// Columnas de documentos de la tabla del Dashboard, en el orden en que se
/// muestran.
enum ColumnaDocumentos {
  acta('Acta'),
  evidenciaRecepcion('Evidencia recepción'),
  evaluacion('Evaluación'),
  proforma('Proforma'),
  ordenVentaCompra('OV / OC'),
  cotizacionCompras('Cotización compras'),
  compras('Compras'),
  pickingDespacho('Picking / despacho'),
  retiroMateriales('Retiro materiales'),
  evidenciaTrabajo('Evidencia trabajo'),
  informeTecnico('Informe técnico'),
  entrega('Entrega'),
  fotoHorometro('Foto horómetro'),
  evidenciaVenta('Evidencia venta'),
  audios('Audios');

  final String titulo;
  const ColumnaDocumentos(this.titulo);
}

/// Una carpeta de la Biblioteca: su título, la columna del Dashboard a la
/// que pertenece y sus archivos (sin vacíos ni repetidos).
class CarpetaDocumentos {
  final String id;
  final String titulo;
  final ColumnaDocumentos columna;
  final List<String> urls;

  const CarpetaDocumentos({required this.id, required this.titulo, required this.columna, required this.urls});
}

class DocumentosTicketService {
  static List<String> _limpiar(Iterable<String?> urls) {
    final vistas = <String>{};
    return [
      for (final u in urls)
        if (u != null && u.trim().isNotEmpty && vistas.add(u.trim())) u.trim(),
    ];
  }

  /// Carpetas del ticket con al menos un archivo, en el orden del flujo.
  static List<CarpetaDocumentos> carpetas(TicketEntity t) {
    final esVenta = t.tipoRequerimiento == TipoRequerimiento.ventaRepuesto;
    final ev = t.evaluacionTecnica;
    final mi = t.mantenimientoInterno;
    final definicion = <(String, String, ColumnaDocumentos, Iterable<String?>)>[
      // Recepción
      ('fotosRecepcion', 'Fotos de Recepción', ColumnaDocumentos.evidenciaRecepcion, esVenta ? const [] : t.fotosUrls),
      ('actaRecepcion', 'Acta de Recepción (PDF)', ColumnaDocumentos.acta, [t.pdfActaUrl]),
      ('evidenciasGarantia', 'Evidencias de Garantía', ColumnaDocumentos.fotoHorometro, t.urlsEvidenciasGarantia ?? const []),
      // Mantenimiento interno
      ('mantenimientoFotoLectura', 'Mantenimiento Interno — Foto de horómetro / kilometraje', ColumnaDocumentos.fotoHorometro,
          [mi?.urlFotoLectura]),
      ('mantenimientoVideos', 'Mantenimiento Interno — Videos', ColumnaDocumentos.evidenciaRecepcion,
          mi?.videosUrls ?? const []),
      // Venta de repuesto
      ('ventaEvidencias', 'Venta de Repuesto — Evidencias', ColumnaDocumentos.evidenciaVenta, esVenta ? t.fotosUrls : const []),
      ('audios', 'Audios (venta / asistencia técnica)', ColumnaDocumentos.audios, t.urlsAudiosAsistencia),
      // Evaluación técnica
      ('evaluacionExcel', 'Evaluación Técnica — Proforma Excel', ColumnaDocumentos.evaluacion, [ev?.urlProformaExcel]),
      ('evaluacionAdjuntos', 'Evaluación Técnica — Adjuntos', ColumnaDocumentos.evaluacion, ev?.urlsAdjuntosPdf ?? const []),
      ('evaluacionGarantia', 'Evaluación Técnica — Adjuntos de Garantía', ColumnaDocumentos.evaluacion,
          ev?.urlsAdjuntosPdfGarantia ?? const []),
      ('evaluacionRevisionAntigua', 'Evaluación Técnica — Revisión Antigua (Garantía)', ColumnaDocumentos.evaluacion,
          [ev?.urlPdfRevisionTecnicaAntigua]),
      ('evaluacionFotosActividades', 'Evaluación Técnica — Fotos de actividades', ColumnaDocumentos.evaluacion,
          [for (final a in ev?.actividades ?? const []) ...a.fotosUrls]),
      // Comercial
      ('proformaPdf', 'Proforma Comercial — PDF', ColumnaDocumentos.proforma, t.proforma?.pdfUrls ?? const []),
      ('proformaExcel', 'Proforma Comercial — Excel', ColumnaDocumentos.proforma, t.proforma?.excelUrls ?? const []),
      ('ordenVenta', 'Orden de Venta', ColumnaDocumentos.ordenVentaCompra, t.codigoOrdenVenta),
      ('ordenCompraCostos', 'Orden de Compra (Costos)', ColumnaDocumentos.ordenVentaCompra, t.codigoOrdenCompra),
      // Compras
      ('cotizacionCompras', 'Cotización de Compras / Proveedor', ColumnaDocumentos.cotizacionCompras, [
        ...t.urlsCotizacionCompras,
        for (final l in t.lineasRepuestoVenta) ...l.urlsCotizacionProveedor,
      ]),
      ('ordenCompra', 'Gestión de Compras — Orden de Compra', ColumnaDocumentos.compras,
          t.gestionCompras?.urlsOrdenCompra ?? const []),
      // Bodega
      ('pickingEvidencias', 'Picking en Bodega — Evidencias', ColumnaDocumentos.pickingDespacho,
          [for (final d in t.historialDespachos) ...d.fotosEvidenciasUrls]),
      ('retiroHoja', 'Retiro de Materiales — Hoja firmada', ColumnaDocumentos.retiroMateriales,
          [for (final o in t.ordenesRecepcion) ...o.urlsHojaFirmada]),
      ('retiroFotos', 'Retiro de Materiales — Fotos', ColumnaDocumentos.retiroMateriales,
          [for (final o in t.ordenesRecepcion) ...o.urlsFotosMateriales]),
      // Proceso de trabajo
      ('evidenciaFotos', 'Evidencia de Trabajo — Fotos', ColumnaDocumentos.evidenciaTrabajo,
          t.evidenciaTrabajo?.fotosUrls ?? const []),
      ('evidenciaVideos', 'Evidencia de Trabajo — Videos', ColumnaDocumentos.evidenciaTrabajo,
          t.evidenciaTrabajo?.videosUrls ?? const []),
      ('procesoTrabajoAnterior', 'Proceso de Trabajo (anterior)', ColumnaDocumentos.evidenciaTrabajo, t.procesoTrabajoUrls),
      ('informeTecnico', 'Informe Técnico', ColumnaDocumentos.informeTecnico, [t.urlInformeTecnico]),
      // Entrega
      ('guiaRemision', 'Guía de Remisión', ColumnaDocumentos.entrega, [t.urlGuiaRemision]),
      ('factura', 'Factura', ColumnaDocumentos.entrega, [t.urlFactura]),
    ];
    return [
      for (final (id, titulo, columna, urls) in definicion)
        if (_limpiar(urls) case final limpias when limpias.isNotEmpty)
          CarpetaDocumentos(id: id, titulo: titulo, columna: columna, urls: limpias),
    ];
  }

  /// Archivos del ticket por columna del Dashboard (solo columnas con algo).
  static Map<ColumnaDocumentos, List<String>> porColumna(TicketEntity t) {
    final mapa = <ColumnaDocumentos, List<String>>{};
    for (final c in carpetas(t)) {
      mapa.putIfAbsent(c.columna, () => []).addAll(c.urls);
    }
    return {for (final e in mapa.entries) e.key: _limpiar(e.value)};
  }
}
