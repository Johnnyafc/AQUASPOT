// lib/features/fallas/domain/entities/metrica_falla_entity.dart

import 'package:equatable/equatable.dart';

/// Representa una subcategoría o componente dentro de una categoría mayor (ej: "Comap", "Relé", "Cableado")
class SubcategoriaFallaEntity extends Equatable {
  final String nombre; // Ej: "Comap", "Relé", "Cableado"
  final List<String> fallas; // Ej: ["Falla en tarjeta electrónica", "Fallo en borneras"]

  const SubcategoriaFallaEntity({
    required this.nombre,
    required this.fallas,
  });

  SubcategoriaFallaEntity copyWith({
    String? nombre,
    List<String>? fallas,
  }) {
    return SubcategoriaFallaEntity(
      nombre: nombre ?? this.nombre,
      fallas: fallas ?? this.fallas,
    );
  }

  @override
  List<Object?> get props => [nombre, fallas];
}

/// Representa una categoría mayor de fallas (ej: "Eléctrico", "Mecánico", "Software")
class CategoriaFallaEntity extends Equatable {
  final String nombre; // Ej: "Eléctrico", "Mecánico", "Software"
  final List<SubcategoriaFallaEntity> subcategorias; // Lista de componentes o subsistemas

  const CategoriaFallaEntity({
    required this.nombre,
    required this.subcategorias,
  });

  /// Getter auxiliar para compatibilidad con código anterior que requiera lista plana de razones
  List<String> get razones => subcategorias.expand((s) => s.fallas).toList();

  CategoriaFallaEntity copyWith({
    String? nombre,
    List<SubcategoriaFallaEntity>? subcategorias,
  }) {
    return CategoriaFallaEntity(
      nombre: nombre ?? this.nombre,
      subcategorias: subcategorias ?? this.subcategorias,
    );
  }

  @override
  List<Object?> get props => [nombre, subcategorias];
}

/// Representa la matriz completa de fallas configurada para un tipo de equipo (Contador, Caracol, Cosechadora)
class MatrizFallasEquipoEntity extends Equatable {
  final String tipoEquipo; // Ej: "Contador", "Caracol", "Cosechadora"
  final List<CategoriaFallaEntity> categorias;

  const MatrizFallasEquipoEntity({
    required this.tipoEquipo,
    required this.categorias,
  });

  MatrizFallasEquipoEntity copyWith({
    String? tipoEquipo,
    List<CategoriaFallaEntity>? categorias,
  }) {
    return MatrizFallasEquipoEntity(
      tipoEquipo: tipoEquipo ?? this.tipoEquipo,
      categorias: categorias ?? this.categorias,
    );
  }

  @override
  List<Object?> get props => [tipoEquipo, categorias];
}

/// Representa una falla específica diagnosticada en un ticket (Árbol: Categoría > Subcategoría > Falla)
class DiagnosticoFallaEntity extends Equatable {
  final String categoria; // Ej: "Eléctrico"
  final String subcategoria; // Ej: "Comap"
  final String falla; // Ej: "Falla en tarjeta electrónica"

  const DiagnosticoFallaEntity({
    required this.categoria,
    this.subcategoria = '',
    required this.falla,
  });

  /// Getter de retrocompatibilidad para vistas y funciones que accedían a .razon
  String get razon => falla;

  Map<String, dynamic> toJson() {
    return {
      'categoria': categoria,
      'subcategoria': subcategoria,
      'falla': falla,
      'razon': falla, // Preserva compatibilidad con registros históricos de Firestore
    };
  }

  factory DiagnosticoFallaEntity.fromJson(Map<String, dynamic> json) {
    return DiagnosticoFallaEntity(
      categoria: json['categoria']?.toString() ?? '',
      subcategoria: json['subcategoria']?.toString() ?? '',
      falla: json['falla']?.toString() ?? json['razon']?.toString() ?? '',
    );
  }

  @override
  List<Object?> get props => [categoria, subcategoria, falla];
}
