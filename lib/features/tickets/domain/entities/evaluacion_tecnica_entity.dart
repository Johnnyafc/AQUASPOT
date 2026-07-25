import 'package:equatable/equatable.dart';

class EvaluacionTecnicaEntity extends Equatable {
  final String? urlProformaExcel;     // 🎯 Canal exclusivo para Compras
  final List<String> urlsAdjuntosPdf; // 📂 Canal de respaldo técnico
  final String observacion;
  final String? numeroOVGarantia;
final List<String>? urlsAdjuntosPdfGarantia;

  const EvaluacionTecnicaEntity({
    this.urlProformaExcel,
    required this.urlsAdjuntosPdf,
    this.observacion = '',
    this.numeroOVGarantia,
    this.urlsAdjuntosPdfGarantia,
  });

  @override
  List<Object?> get props => [urlProformaExcel, urlsAdjuntosPdf, observacion,numeroOVGarantia,urlsAdjuntosPdf];
}