// lib/features/tickets/data/models/ficha_creacion_repuesto_model.dart
//
// Conversión Firestore ↔ FichaCreacionRepuestoEntity (ficha "Solicitud de
// creación de códigos"). La usan Venta de Repuesto y Mantenimiento interno.

import '../../domain/entities/ficha_creacion_repuesto_entity.dart';

class FichaCreacionRepuestoModel {
  static FichaCreacionRepuestoEntity? fromJson(dynamic v) {
    if (v is! Map) return null;
    final m = Map<String, dynamic>.from(v);
    String t(String k, [String d = '']) => m[k]?.toString() ?? d;
    bool b(String k, bool d) => m[k] is bool ? m[k] as bool : d;
    return FichaCreacionRepuestoEntity(
      nombre: t('nombre'),
      familiaPieza: t('familiaPieza'),
      tipo: t('tipo'),
      atributoAcabado: t('atributoAcabado'),
      metrica: t('metrica'),
      equivalencia: t('equivalencia'),
      categoria: t('categoria'),
      udm: t('udm', 'UNIDAD'),
      tipoProducto: t('tipoProducto', 'ARTÍCULO'),
      linkImagen: t('linkImagen'),
      linkDescripcion: t('linkDescripcion'),
      comprado: b('comprado', true),
      vendido: b('vendido', true),
      activo: b('activo', false),
      almacenado: b('almacenado', true),
      gravaIva: b('gravaIva', true),
      fabricado: b('fabricado', false),
    );
  }

  static Map<String, dynamic>? toJson(FichaCreacionRepuestoEntity? f) => f == null
      ? null
      : {
          'nombre': f.nombre,
          'familiaPieza': f.familiaPieza,
          'tipo': f.tipo,
          'atributoAcabado': f.atributoAcabado,
          'metrica': f.metrica,
          'equivalencia': f.equivalencia,
          'categoria': f.categoria,
          'udm': f.udm,
          'tipoProducto': f.tipoProducto,
          'linkImagen': f.linkImagen,
          'linkDescripcion': f.linkDescripcion,
          'comprado': f.comprado,
          'vendido': f.vendido,
          'activo': f.activo,
          'almacenado': f.almacenado,
          'gravaIva': f.gravaIva,
          'fabricado': f.fabricado,
        };
}
