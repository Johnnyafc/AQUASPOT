import 'package:equatable/equatable.dart';

class EvaluacionTecnicaEntity extends Equatable {
  final String? urlProformaExcel;     // 🎯 Canal exclusivo para Compras
  final List<String> urlsAdjuntosPdf; // 📂 Canal de respaldo técnico
  final String observacion;

  const EvaluacionTecnicaEntity({
    this.urlProformaExcel,
    required this.urlsAdjuntosPdf,
    this.observacion = '',
  });

  @override
  List<Object?> get props => [urlProformaExcel, urlsAdjuntosPdf, observacion];
}