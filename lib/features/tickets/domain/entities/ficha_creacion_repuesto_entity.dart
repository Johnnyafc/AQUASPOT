// lib/features/tickets/domain/entities/ficha_creacion_repuesto_entity.dart
//
// 🧾 Ficha "Solicitud de creación de códigos" (misma plantilla Excel que usa
// Costos). La llena el supervisor en la Evaluación de Venta cuando el
// repuesto NO está en el sistema; Costos la usa para crear el código en el
// ERP. Todo texto libre; obligatorios: nombre, familia, categoría y UDM.

import 'package:equatable/equatable.dart';

class FichaCreacionRepuestoEntity extends Equatable {
  final String nombre;
  final String familiaPieza;
  final String tipo;
  final String atributoAcabado;
  final String metrica;
  final String equivalencia;
  final String categoria;
  final String udm;
  final String tipoProducto;
  final String linkImagen;
  final String linkDescripcion;
  // Parámetros (valores por defecto de la plantilla).
  final bool comprado;
  final bool vendido;
  final bool activo;
  final bool almacenado;
  final bool gravaIva;
  final bool fabricado;

  const FichaCreacionRepuestoEntity({
    this.nombre = '',
    this.familiaPieza = '',
    this.tipo = '',
    this.atributoAcabado = '',
    this.metrica = '',
    this.equivalencia = '',
    this.categoria = '',
    this.udm = 'UNIDAD',
    this.tipoProducto = 'ARTÍCULO',
    this.linkImagen = '',
    this.linkDescripcion = '',
    this.comprado = true,
    this.vendido = true,
    this.activo = false,
    this.almacenado = true,
    this.gravaIva = true,
    this.fabricado = false,
  });

  /// Campos obligatorios que faltan (vacío = ficha completa).
  List<String> get faltantes => [
        if (nombre.trim().isEmpty) 'Nombre',
        if (familiaPieza.trim().isEmpty) 'Familia de pieza',
        if (categoria.trim().isEmpty) 'Categoría',
        if (udm.trim().isEmpty) 'UDM',
      ];

  bool get completa => faltantes.isEmpty;

  /// Pares etiqueta → valor en el orden de la plantilla (para mostrar).
  List<(String, String)> get campos => [
        ('Nombre', nombre),
        ('Familia de pieza', familiaPieza),
        ('Tipo', tipo),
        ('Atributo o acab.', atributoAcabado),
        ('Métrica', metrica),
        ('Equivalencia', equivalencia),
        ('Categoría', categoria),
        ('UDM', udm),
        ('Tipo producto', tipoProducto),
        ('Link imagen', linkImagen),
        ('Link descripción', linkDescripcion),
        ('Comprado', comprado ? 'SI' : 'NO'),
        ('Vendido', vendido ? 'SI' : 'NO'),
        ('Activo', activo ? 'SI' : 'NO'),
        ('Almacenado', almacenado ? 'SI' : 'NO'),
        ('Grava IVA', gravaIva ? 'SI' : 'NO'),
        ('Fabricado', fabricado ? 'SI' : 'NO'),
      ];

  FichaCreacionRepuestoEntity copyWith({
    String? nombre,
    String? familiaPieza,
    String? tipo,
    String? atributoAcabado,
    String? metrica,
    String? equivalencia,
    String? categoria,
    String? udm,
    String? tipoProducto,
    String? linkImagen,
    String? linkDescripcion,
    bool? comprado,
    bool? vendido,
    bool? activo,
    bool? almacenado,
    bool? gravaIva,
    bool? fabricado,
  }) {
    return FichaCreacionRepuestoEntity(
      nombre: nombre ?? this.nombre,
      familiaPieza: familiaPieza ?? this.familiaPieza,
      tipo: tipo ?? this.tipo,
      atributoAcabado: atributoAcabado ?? this.atributoAcabado,
      metrica: metrica ?? this.metrica,
      equivalencia: equivalencia ?? this.equivalencia,
      categoria: categoria ?? this.categoria,
      udm: udm ?? this.udm,
      tipoProducto: tipoProducto ?? this.tipoProducto,
      linkImagen: linkImagen ?? this.linkImagen,
      linkDescripcion: linkDescripcion ?? this.linkDescripcion,
      comprado: comprado ?? this.comprado,
      vendido: vendido ?? this.vendido,
      activo: activo ?? this.activo,
      almacenado: almacenado ?? this.almacenado,
      gravaIva: gravaIva ?? this.gravaIva,
      fabricado: fabricado ?? this.fabricado,
    );
  }

  @override
  List<Object?> get props => [
        nombre, familiaPieza, tipo, atributoAcabado, metrica, equivalencia, categoria, udm,
        tipoProducto, linkImagen, linkDescripcion, comprado, vendido, activo, almacenado, gravaIva, fabricado,
      ];
}
