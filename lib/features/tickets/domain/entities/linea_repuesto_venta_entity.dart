// lib/features/tickets/domain/entities/linea_repuesto_venta_entity.dart
//
// Una línea de repuesto dentro de una Venta de Repuesto: una "foto" del
// ítem de inventario elegido (código, descripción, unidad) más la
// cantidad pedida. Es una copia congelada al momento de agregarla, no una
// referencia viva al catálogo -- así el registro de la venta no cambia si
// después se edita o se borra ese ítem del inventario.

import 'package:equatable/equatable.dart';
import 'ficha_creacion_repuesto_entity.dart';

class LineaRepuestoVentaEntity extends Equatable {
  final String codigo;
  final String descripcion;
  final String unidad;
  final double cantidad;

  // Stock neto que había en inventario al momento de registrar/evaluar el
  // requerimiento (null = todavía no se ha evaluado). Con esto se decide
  // si el requerimiento pasa a Comercial o a Cotizando Repuesto, y Compras
  // ve en rojo las líneas que no alcanzan.
  final double? stockDisponibleAlEvaluar;

  // 🔧 Repuesto "por determinar": el cliente no sabe cuál es y lo define el
  // técnico en Evaluación. Va sin código; lleva la descripción del cliente
  // y su propia evidencia (fotos/videos y notas de voz).
  final bool porDeterminar;
  final String descripcionCliente;
  final List<String> urlsEvidencia;
  final List<String> urlsAudios;

  // false = el repuesto no está en el inventario (lo registra el técnico
  // con el código que conozca). Se trata como sin stock: pasa a Compras.
  final bool existeEnSistema;

  // 🔧 Evaluación de venta (supervisor): cotización del proveedor cuando el
  // repuesto no está en el sistema, y quién/cuándo definió la línea.
  final List<String> urlsCotizacionProveedor;
  final String? definidoPor;
  final DateTime? definidoEn;

  // 🛒 Compras ya cotizó esta línea (puede ocurrir en paralelo a la
  // Evaluación técnica de otra línea del mismo requerimiento).
  final bool cotizadaPorCompras;
  final String? cotizadaPor;
  final DateTime? cotizadaEn;

  // 🧾 Repuesto que no estaba en el sistema: ficha de creación (la llena el
  // supervisor) y código oficial que crea Costos en el ERP.
  final FichaCreacionRepuestoEntity? fichaCreacion;
  final bool codigoCreadoPorCostos;
  final String? codigoCreadoPor;
  final DateTime? codigoCreadoEn;

  const LineaRepuestoVentaEntity({
    required this.codigo,
    required this.descripcion,
    required this.unidad,
    required this.cantidad,
    this.stockDisponibleAlEvaluar,
    this.porDeterminar = false,
    this.descripcionCliente = '',
    this.urlsEvidencia = const [],
    this.urlsAudios = const [],
    this.existeEnSistema = true,
    this.urlsCotizacionProveedor = const [],
    this.definidoPor,
    this.definidoEn,
    this.cotizadaPorCompras = false,
    this.cotizadaPor,
    this.cotizadaEn,
    this.fichaCreacion,
    this.codigoCreadoPorCostos = false,
    this.codigoCreadoPor,
    this.codigoCreadoEn,
  });

  bool get tieneStockSuficiente => (stockDisponibleAlEvaluar ?? 0) >= cantidad;

  /// Ya tiene cotización: la hizo Compras o la subió el supervisor en la
  /// Evaluación (cotización de proveedor). No necesita pasar por Compras.
  bool get tieneCotizacion => cotizadaPorCompras || urlsCotizacionProveedor.isNotEmpty;

  /// Descripción para mostrar: la del inventario o, si aún está por
  /// determinar, la que dio el cliente.
  String get descripcionVisible => descripcion.trim().isNotEmpty ? descripcion : descripcionCliente;

  /// Cantidad que no cubre el stock (0 si alcanza).
  double get cantidadFaltante {
    final faltante = cantidad - (stockDisponibleAlEvaluar ?? 0);
    return faltante > 0 ? faltante : 0;
  }

  LineaRepuestoVentaEntity copyWith({
    String? codigo,
    String? descripcion,
    String? unidad,
    double? cantidad,
    double? stockDisponibleAlEvaluar,
    bool? porDeterminar,
    String? descripcionCliente,
    List<String>? urlsEvidencia,
    List<String>? urlsAudios,
    bool? existeEnSistema,
    List<String>? urlsCotizacionProveedor,
    String? definidoPor,
    DateTime? definidoEn,
    bool? cotizadaPorCompras,
    String? cotizadaPor,
    DateTime? cotizadaEn,
    FichaCreacionRepuestoEntity? fichaCreacion,
    bool? codigoCreadoPorCostos,
    String? codigoCreadoPor,
    DateTime? codigoCreadoEn,
  }) {
    return LineaRepuestoVentaEntity(
      codigo: codigo ?? this.codigo,
      descripcion: descripcion ?? this.descripcion,
      unidad: unidad ?? this.unidad,
      cantidad: cantidad ?? this.cantidad,
      stockDisponibleAlEvaluar: stockDisponibleAlEvaluar ?? this.stockDisponibleAlEvaluar,
      porDeterminar: porDeterminar ?? this.porDeterminar,
      descripcionCliente: descripcionCliente ?? this.descripcionCliente,
      urlsEvidencia: urlsEvidencia ?? this.urlsEvidencia,
      urlsAudios: urlsAudios ?? this.urlsAudios,
      existeEnSistema: existeEnSistema ?? this.existeEnSistema,
      urlsCotizacionProveedor: urlsCotizacionProveedor ?? this.urlsCotizacionProveedor,
      definidoPor: definidoPor ?? this.definidoPor,
      definidoEn: definidoEn ?? this.definidoEn,
      cotizadaPorCompras: cotizadaPorCompras ?? this.cotizadaPorCompras,
      cotizadaPor: cotizadaPor ?? this.cotizadaPor,
      cotizadaEn: cotizadaEn ?? this.cotizadaEn,
      fichaCreacion: fichaCreacion ?? this.fichaCreacion,
      codigoCreadoPorCostos: codigoCreadoPorCostos ?? this.codigoCreadoPorCostos,
      codigoCreadoPor: codigoCreadoPor ?? this.codigoCreadoPor,
      codigoCreadoEn: codigoCreadoEn ?? this.codigoCreadoEn,
    );
  }

  @override
  List<Object?> get props => [
        codigo, descripcion, unidad, cantidad, stockDisponibleAlEvaluar,
        porDeterminar, descripcionCliente, urlsEvidencia, urlsAudios, existeEnSistema,
        urlsCotizacionProveedor, definidoPor, definidoEn,
        cotizadaPorCompras, cotizadaPor, cotizadaEn,
        fichaCreacion, codigoCreadoPorCostos, codigoCreadoPor, codigoCreadoEn,
      ];
}
