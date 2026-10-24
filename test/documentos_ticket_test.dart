// test/documentos_ticket_test.dart
//
// Documentos del ticket: qué variable va en qué carpeta (Biblioteca) y
// columna (Dashboard), en orden del flujo, sin vacíos ni repetidos; ventas
// de repuesto y Proceso de Trabajo "(anterior)".

import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/actividad_registrada_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/evaluacion_tecnica_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/evidencia_trabajo_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/linea_repuesto_venta_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/orden_recepcion_repuestos_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/registro_despacho_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/documentos_ticket_service.dart';
import 'package:flutter_test/flutter_test.dart';

typedef D = DocumentosTicketService;

TicketEntity ticket({
  TipoRequerimiento tipo = TipoRequerimiento.reparacion,
  List<String> fotos = const [],
  String? acta,
  EvaluacionTecnicaEntity? evaluacion,
  List<RegistroDespachoEntity> despachos = const [],
  List<OrdenRecepcionRepuestosEntity> ordenes = const [],
  List<LineaRepuestoVentaEntity> lineas = const [],
  List<String> cotizacionCompras = const [],
  List<String> audios = const [],
  List<String> procesoTrabajo = const [],
  EvidenciaTrabajoEntity? evidencia,
  String? informe,
}) =>
    TicketEntity(
      id: 'REQ-1',
      estadoActual: EstadoTicket.finalizado,
      sede: Sede.NINGUNO,
      clienteId: 'Cliente',
      campamento: '',
      nombreContacto: 'C',
      telefonoContacto: '',
      emailContacto: '',
      equipo: TipoEquipo.Cosechadora,
      equipoDetalle: null,
      accesoriosRecibidos: null,
      numeroSerie: null,
      fallaReportada: '',
      historialEventos: const [],
      tipoRequerimiento: tipo,
      lugarAtencion: LugarAtencion.values.first,
      esRegistroCompleto: true,
      fotosUrls: fotos,
      pdfActaUrl: acta,
      evaluacionTecnica: evaluacion,
      historialDespachos: despachos,
      ordenesRecepcion: ordenes,
      lineasRepuestoVenta: lineas,
      urlsCotizacionCompras: cotizacionCompras,
      urlsAudiosAsistencia: audios,
      procesoTrabajoUrls: procesoTrabajo,
      evidenciaTrabajo: evidencia,
      urlInformeTecnico: informe,
    );

RegistroDespachoEntity despacho(List<String> fotos) => RegistroDespachoEntity(
      id: 'D${fotos.length}',
      fecha: DateTime(2026, 10, 1),
      usuarioNombre: 'Bodega',
      usuarioId: 'u',
      items: const [],
      fotosEvidenciasUrls: fotos,
    );

OrdenRecepcionRepuestosEntity orden(List<String> hoja, List<String> materiales) => OrdenRecepcionRepuestosEntity(
      id: 'O1',
      ticketId: 'REQ-1',
      tecnicoId: 't',
      tecnicoNombre: 'Técnico',
      supervisorAsigna: 'Sup',
      fechaAsignacion: DateTime(2026, 10, 1),
      urlsHojaFirmada: hoja,
      urlsFotosMateriales: materiales,
    );

LineaRepuestoVentaEntity linea(List<String> cotizacion) => LineaRepuestoVentaEntity(
      codigo: 'R1',
      descripcion: 'Repuesto',
      unidad: 'UNIDAD',
      cantidad: 1,
      urlsCotizacionProveedor: cotizacion,
    );

void main() {
  test('1. Ticket sin archivos: sin carpetas ni columnas', () {
    expect(D.carpetas(ticket()), isEmpty);
    expect(D.porColumna(ticket()), isEmpty);
  });

  test('2. Archivos nuevos: picking, retiro, informe técnico, fotos de actividades y cotización', () {
    final t = ticket(
      acta: 'acta.pdf',
      evaluacion: const EvaluacionTecnicaEntity(
        urlsAdjuntosPdf: [],
        actividades: [
          ActividadRegistradaEntity(codigo: 'A1', nombre: 'Act', horasHombre: 1, observacion: '', fotosUrls: ['act1.jpg']),
        ],
      ),
      despachos: [despacho(['pick1.jpg']), despacho(['pick2.jpg', 'pick3.jpg'])],
      ordenes: [orden(['hoja.jpg'], ['mat.jpg'])],
      cotizacionCompras: ['cot.pdf'],
      lineas: [linea(['prov.pdf', 'cot.pdf'])],
      informe: 'informe.pdf',
    );
    final ids = D.carpetas(t).map((c) => c.id).toList();
    // Orden del flujo.
    expect(ids, [
      'actaRecepcion',
      'evaluacionFotosActividades',
      'cotizacionCompras',
      'pickingEvidencias',
      'retiroHoja',
      'retiroFotos',
      'informeTecnico',
    ]);
    final col = D.porColumna(t);
    expect(col[ColumnaDocumentos.pickingDespacho], ['pick1.jpg', 'pick2.jpg', 'pick3.jpg']);
    expect(col[ColumnaDocumentos.retiroMateriales], ['hoja.jpg', 'mat.jpg']);
    expect(col[ColumnaDocumentos.evaluacion], ['act1.jpg']);
    // Compras + proveedor, sin repetir el mismo enlace.
    expect(col[ColumnaDocumentos.cotizacionCompras], ['cot.pdf', 'prov.pdf']);
    expect(col[ColumnaDocumentos.informeTecnico], ['informe.pdf']);
  });

  test('3. Venta de repuesto: fotosUrls son evidencias de venta, no de recepción; audios aparte', () {
    final venta = ticket(tipo: TipoRequerimiento.ventaRepuesto, fotos: ['ev1.jpg'], audios: ['a1.m4a']);
    final ids = D.carpetas(venta).map((c) => c.id);
    expect(ids, ['ventaEvidencias', 'audios']);
    final col = D.porColumna(venta);
    expect(col.containsKey(ColumnaDocumentos.evidenciaRecepcion), isFalse);
    expect(col[ColumnaDocumentos.evidenciaVenta], ['ev1.jpg']);
    expect(col[ColumnaDocumentos.audios], ['a1.m4a']);

    // En un ticket que no es venta, las mismas fotos son de recepción.
    final reparacion = ticket(fotos: ['ev1.jpg']);
    expect(D.carpetas(reparacion).single.id, 'fotosRecepcion');
    expect(D.porColumna(reparacion)[ColumnaDocumentos.evidenciaRecepcion], ['ev1.jpg']);
  });

  test('4. Proceso de Trabajo anterior va con la evidencia de trabajo; vacíos y espacios se descartan', () {
    final t = ticket(
      procesoTrabajo: ['viejo.jpg', ' ', ''],
      evidencia: const EvidenciaTrabajoEntity(fotosUrls: [' nueva.jpg '], videosUrls: []),
    );
    final carpetas = D.carpetas(t);
    expect(carpetas.map((c) => c.titulo), ['Evidencia de Trabajo — Fotos', 'Proceso de Trabajo (anterior)']);
    expect(D.porColumna(t)[ColumnaDocumentos.evidenciaTrabajo], ['nueva.jpg', 'viejo.jpg']);
  });

  test('5. Columnas en el orden del flujo', () {
    expect(ColumnaDocumentos.values.map((c) => c.titulo), [
      'Acta',
      'Evidencia recepción',
      'Evaluación',
      'Proforma',
      'OV / OC',
      'Cotización compras',
      'Compras',
      'Picking / despacho',
      'Retiro materiales',
      'Evidencia trabajo',
      'Informe técnico',
      'Entrega',
      'Foto horómetro',
      'Evidencia venta',
      'Audios',
    ]);
  });
}
