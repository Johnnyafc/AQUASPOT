import 'package:aquaspot_postventa/features/tickets/data/models/proforma_model.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/item_compra_entity.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../../../core/enum/ticket_enums.dart'; 
import 'evaluacion_tecnica_model.dart';
import 'evento_auditoria_model.dart';
import 'item_compra_model.dart'; // 🔌 CONECTOR SOLDADO

class TicketModel extends TicketEntity {
  const TicketModel({
    required super.id,
    required super.estadoActual,
    required super.sede,
    required super.clienteId,
    required super.campamento,
    required super.nombreContacto,
    required super.telefonoContacto,
    required super.emailContacto,
    required super.equipo,
    super.equipoDetalle,
    required super.fallaReportada,
    super.accesoriosRecibidos,
    super.numeroSerie, 
    super.evaluacionTecnica,
    super.fotosUrls = const [],
    super.pdfActaUrl,
    required super.historialEventos,
    required super.tipoRequerimiento,
    required super.lugarAtencion,
    super.esRegistroCompleto = false, 
    super.notasRecepcion,
    super.proforma,
    super.marca = 'NO ESPECIFICADA',
    super.codigoProyecto,
    super.codigoOrdenVenta = const [],
    super.codigoOrdenCompra = const [],
    super.itemsCompra = const [], 
    super.procesoTrabajoUrls = const [],
    super.isCostosCompletado = false,
    super.isComprasCompletado = false,
    super.numeroOrdenVenta,
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    return TicketModel(
      id: json['id'] ?? '',
      estadoActual: EstadoTicket.values.firstWhere(
        (e) => e.name == json['estadoActual'],
        orElse: () => EstadoTicket.creado,
      ),
      sede: Sede.values.firstWhere(
        (e) => e.name == json['sede'],
        orElse: () => Sede.DURAN,
      ),
      clienteId: json['clienteId'] ?? '',
      campamento: json['campamento'] ?? '',
      nombreContacto: json['nombreContacto'] ?? '',
      telefonoContacto: json['telefonoContacto'] ?? '',
      emailContacto: json['emailContacto'] ?? '',
      equipoDetalle: json['equipoDetalle'] as String?,
      equipo: TipoEquipo.values.firstWhere(
        (e) => e.name == json['equipo'],
        orElse: () => TipoEquipo.Cosechadora,
      ),
      accesoriosRecibidos: json['accesoriosRecibidos'] != null 
          ? Map<String, bool>.from(json['accesoriosRecibidos'] as Map)
          : null,
      fallaReportada: json['fallaReportada'] ?? '',
      numeroSerie: json['numeroSerie'] ?? (json['evaluacionTecnica'] != null ? json['evaluacionTecnica']['serieEquipo'] : null),
      evaluacionTecnica: json['evaluacionTecnica'] != null
          ? EvaluacionTecnicaModel.fromJson(json['evaluacionTecnica'])
          : null,
      fotosUrls: List<String>.from(json['fotosUrls'] ?? []),
      pdfActaUrl: json['pdfActaUrl'],
      historialEventos: (json['historialEventos'] as List?)
              ?.map((e) => EventoAuditoriaModel.fromJson(e))
              .toList() ??
          [],
      tipoRequerimiento: TipoRequerimiento.values.firstWhere(
        (e) => e.name == json['tipoRequerimiento'],
        orElse: () => TipoRequerimiento.ninguno,
      ),
      lugarAtencion: LugarAtencion.values.firstWhere(
        (e) => e.name == json['lugarAtencion'],
        orElse: () => LugarAtencion.noAplica,
      ),
      esRegistroCompleto: json['esRegistroCompleto'] ?? false,
      notasRecepcion: json['notasRecepcion'],
      proforma: json['proforma'] != null
          ? ProformaModel.fromJson(json['proforma'])
          : null,
      
      // 🔌 LECTURA DE SENSORES INDUSTRIALES (Tolerancia a fallos)
      marca: json['marca'] as String? ?? 'NO ESPECIFICADA',
      codigoProyecto: json['codigoProyecto'] as String?,
      codigoOrdenVenta: json['codigoOrdenVenta'] != null ? List<String>.from(json['codigoOrdenVenta']) : const [],
      codigoOrdenCompra: json['codigoOrdenCompra'] != null ? List<String>.from(json['codigoOrdenCompra']) : const [],
      
      // 🚀 REPARACIÓN: Mapeo estricto a ItemCompraModel
      itemsCompra: json['itemsCompra'] != null 
          ? (json['itemsCompra'] as List).map((e) => ItemCompraModel.fromJson(e)).toList() 
          : const [],
          
      procesoTrabajoUrls: json['procesoTrabajoUrls'] != null ? List<String>.from(json['procesoTrabajoUrls']) : const [],
      isCostosCompletado: json['isCostosCompletado'] as bool? ?? false,
      isComprasCompletado: json['isComprasCompletado'] as bool? ?? false,
      numeroOrdenVenta: json['numeroOrdenVenta'],
    );
  }

  factory TicketModel.fromEntity(TicketEntity entity) {
    return TicketModel(
      id: entity.id,
      estadoActual: entity.estadoActual,
      sede: entity.sede,
      clienteId: entity.clienteId,
      campamento: entity.campamento,
      nombreContacto: entity.nombreContacto,
      telefonoContacto: entity.telefonoContacto,
      emailContacto: entity.emailContacto,
      equipo: entity.equipo,
      equipoDetalle: entity.equipoDetalle,
      fallaReportada: entity.fallaReportada,
      accesoriosRecibidos: entity.accesoriosRecibidos,
      numeroSerie: entity.numeroSerie, 
      evaluacionTecnica: entity.evaluacionTecnica != null
          ? EvaluacionTecnicaModel.fromEntity(entity.evaluacionTecnica!)
          : null,
      fotosUrls: entity.fotosUrls,
      pdfActaUrl: entity.pdfActaUrl,
      historialEventos: entity.historialEventos
          .map((e) => EventoAuditoriaModel.fromEntity(e))
          .toList(),
      tipoRequerimiento: entity.tipoRequerimiento,
      lugarAtencion: entity.lugarAtencion,
      esRegistroCompleto: entity.esRegistroCompleto,
      notasRecepcion: entity.notasRecepcion,
      proforma: entity.proforma,
      
      // 🔄 MAPEO DE NUEVOS PINES
      marca: entity.marca,
      codigoProyecto: entity.codigoProyecto,
      codigoOrdenVenta: entity.codigoOrdenVenta,
      codigoOrdenCompra: entity.codigoOrdenCompra,
      itemsCompra: entity.itemsCompra,
      procesoTrabajoUrls: entity.procesoTrabajoUrls,
      isCostosCompletado: entity.isCostosCompletado,
      isComprasCompletado: entity.isComprasCompletado,
      numeroOrdenVenta: entity.numeroOrdenVenta,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'estadoActual': estadoActual.name,
      'sede': sede.name,
      'clienteId': clienteId,
      'campamento': campamento,
      'nombreContacto': nombreContacto,
      'telefonoContacto': telefonoContacto,
      'emailContacto': emailContacto,
      'equipo': equipo.name,
      'equipoDetalle': equipoDetalle,
      'fallaReportada': fallaReportada,
      'numeroSerie': numeroSerie, 
      'accesoriosRecibidos': accesoriosRecibidos,
      'evaluacionTecnica': evaluacionTecnica != null
          ? EvaluacionTecnicaModel.fromEntity(evaluacionTecnica!).toJson()
          : null,
      'fotosUrls': fotosUrls,
      'pdfActaUrl': pdfActaUrl,
      'historialEventos': historialEventos
          .map((e) => EventoAuditoriaModel.fromEntity(e).toJson())
          .toList(),
      'tipoRequerimiento': tipoRequerimiento.name,
      'lugarAtencion': lugarAtencion.name,
      'esRegistroCompleto': esRegistroCompleto,
      'notasRecepcion': notasRecepcion,
      'proforma': proforma != null ? (proforma as ProformaModel).toJson() : null,
      
      // 📤 ESCRITURA HACIA FIREBASE
      'marca': marca,
      'codigoProyecto': codigoProyecto,
      'codigoOrdenVenta': codigoOrdenVenta,
      'codigoOrdenCompra': codigoOrdenCompra,
      
      // 🚀 REPARACIÓN: Empaquetado estricto a JSON (Evita Crash en Firebase)
      'itemsCompra': (itemsCompra as List?)?.map((e) => ItemCompraModel.fromEntity(e as ItemCompraEntity).toJson()).toList() ?? [],
      
      'procesoTrabajoUrls': procesoTrabajoUrls,
      'isCostosCompletado': isCostosCompletado,
      'isComprasCompletado': isComprasCompletado,
       'numeroOrdenVenta': numeroOrdenVenta,
    };
  }
}