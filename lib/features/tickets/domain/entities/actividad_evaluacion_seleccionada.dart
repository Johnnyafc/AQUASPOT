// lib/features/tickets/domain/entities/actividad_evaluacion_seleccionada.dart
import 'package:image_picker/image_picker.dart';
import '../../../../features/catalogo/domain/entities/actividad_catalogo_entity.dart';
import '../../../../features/catalogo/domain/entities/item_catalogo_entity.dart';

class ActividadEvaluacionSeleccionada {
  final ActividadCatalogoEntity actividad;
  double horasHombre;
  String observacion;
  List<XFile> fotos;
  List<ItemCatalogoEntity> itemsInternos;
  List<ItemCatalogoEntity> itemsComerciales;

  ActividadEvaluacionSeleccionada({
    required this.actividad,
    required this.horasHombre,
    required this.observacion,
    List<XFile>? fotos,
    List<ItemCatalogoEntity>? itemsInternos,
    List<ItemCatalogoEntity>? itemsComerciales,
  })  : fotos = fotos ?? [],
        itemsInternos = itemsInternos ?? List.from(actividad.itemsInternos),
        itemsComerciales = itemsComerciales ?? List.from(actividad.itemsComerciales);

  ActividadEvaluacionSeleccionada copyWith({
    ActividadCatalogoEntity? actividad,
    double? horasHombre,
    String? observacion,
    List<XFile>? fotos,
    List<ItemCatalogoEntity>? itemsInternos,
    List<ItemCatalogoEntity>? itemsComerciales,
  }) {
    return ActividadEvaluacionSeleccionada(
      actividad: actividad ?? this.actividad,
      horasHombre: horasHombre ?? this.horasHombre,
      observacion: observacion ?? this.observacion,
      fotos: fotos ?? List.from(this.fotos),
      itemsInternos: itemsInternos ?? List.from(this.itemsInternos),
      itemsComerciales: itemsComerciales ?? List.from(this.itemsComerciales),
    );
  }

  String get textoIncluyeDinamico {
    if (itemsComerciales.isEmpty) {
      return actividad.incluye;
    }
    final itemsValidos = itemsComerciales.where((it) => it.cantidad > 0).toList();
    if (itemsValidos.isEmpty) return '';

    final partes = itemsValidos.map((it) {
      final cant = it.cantidad;
      final cantStr = (cant % 1 == 0) ? cant.toInt().toString() : cant.toString();
      final desc = it.descripcion.trim();
      final unidad = it.unidad.trim().toUpperCase();

      String unidadStr = unidad;
      if (unidad == 'CENTIMETRO' || unidad == 'CENTÍMETRO' || unidad == 'CENTIMETROS' || unidad == 'CENTÍMETROS') {
        unidadStr = 'CM';
      } else if (unidad == 'METRO' || unidad == 'METROS') {
        unidadStr = 'M';
      }

      if (unidadStr.isNotEmpty &&
          unidadStr != 'UNIDAD' &&
          unidadStr != 'UND' &&
          unidadStr != 'UNIDADES' &&
          !desc.toUpperCase().contains(unidadStr)) {
        return '$cantStr $unidadStr DE $desc';
      }
      return '$cantStr $desc';
    }).toList();

    return 'Incluye: ${partes.join(', ')}.';
  }
}
