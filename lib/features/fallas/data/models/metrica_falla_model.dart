// lib/features/fallas/data/models/metrica_falla_model.dart

import '../../domain/entities/metrica_falla_entity.dart';

class DiagnosticoFallaModel extends DiagnosticoFallaEntity {
  const DiagnosticoFallaModel({
    required super.categoria,
    super.subcategoria = '',
    required super.falla,
  });

  factory DiagnosticoFallaModel.fromJson(Map<String, dynamic> json) {
    return DiagnosticoFallaModel(
      categoria: json['categoria']?.toString() ?? '',
      subcategoria: json['subcategoria']?.toString() ?? '',
      falla: json['falla']?.toString() ?? json['razon']?.toString() ?? '',
    );
  }

  factory DiagnosticoFallaModel.fromEntity(DiagnosticoFallaEntity entity) {
    return DiagnosticoFallaModel(
      categoria: entity.categoria,
      subcategoria: entity.subcategoria,
      falla: entity.falla,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'categoria': categoria,
      'subcategoria': subcategoria,
      'falla': falla,
      'razon': falla,
    };
  }
}

class SubcategoriaFallaModel extends SubcategoriaFallaEntity {
  const SubcategoriaFallaModel({
    required super.nombre,
    required super.fallas,
  });

  factory SubcategoriaFallaModel.fromJson(Map<String, dynamic> json) {
    return SubcategoriaFallaModel(
      nombre: json['nombre']?.toString() ?? '',
      fallas: (json['fallas'] as List?)?.map((e) => e.toString()).toList() ??
              (json['razones'] as List?)?.map((e) => e.toString()).toList() ??
              [],
    );
  }

  factory SubcategoriaFallaModel.fromEntity(SubcategoriaFallaEntity entity) {
    return SubcategoriaFallaModel(
      nombre: entity.nombre,
      fallas: entity.fallas,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'fallas': fallas,
    };
  }
}

class CategoriaFallaModel extends CategoriaFallaEntity {
  const CategoriaFallaModel({
    required super.nombre,
    required super.subcategorias,
  });

  factory CategoriaFallaModel.fromJson(Map<String, dynamic> json) {
    final nombre = json['nombre']?.toString() ?? '';
    List<SubcategoriaFallaModel> subs = [];

    if (json['subcategorias'] != null && json['subcategorias'] is List) {
      subs = (json['subcategorias'] as List)
          .map((s) => SubcategoriaFallaModel.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList();
    } else if (json['razones'] != null && json['razones'] is List) {
      // Retrocompatibilidad automática si un documento antiguo tenía razones planas:
      final razones = (json['razones'] as List).map((e) => e.toString()).toList();
      if (razones.isNotEmpty) {
        subs.add(SubcategoriaFallaModel(nombre: 'General', fallas: razones));
      }
    }

    return CategoriaFallaModel(
      nombre: nombre,
      subcategorias: subs,
    );
  }

  factory CategoriaFallaModel.fromEntity(CategoriaFallaEntity entity) {
    return CategoriaFallaModel(
      nombre: entity.nombre,
      subcategorias: entity.subcategorias.map((s) {
        if (s is SubcategoriaFallaModel) return s;
        return SubcategoriaFallaModel.fromEntity(s);
      }).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'subcategorias': subcategorias.map((s) {
        if (s is SubcategoriaFallaModel) return s.toJson();
        return SubcategoriaFallaModel(nombre: s.nombre, fallas: s.fallas).toJson();
      }).toList(),
    };
  }
}

class MatrizFallasEquipoModel extends MatrizFallasEquipoEntity {
  const MatrizFallasEquipoModel({
    required super.tipoEquipo,
    required super.categorias,
  });

  factory MatrizFallasEquipoModel.fromJson(Map<String, dynamic> json) {
    return MatrizFallasEquipoModel(
      tipoEquipo: json['tipoEquipo']?.toString() ?? '',
      categorias: (json['categorias'] as List?)
              ?.map((c) => CategoriaFallaModel.fromJson(Map<String, dynamic>.from(c as Map)))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tipoEquipo': tipoEquipo,
      'categorias': categorias.map((c) {
        if (c is CategoriaFallaModel) return c.toJson();
        return CategoriaFallaModel.fromEntity(c).toJson();
      }).toList(),
    };
  }
}
