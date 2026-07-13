import 'package:equatable/equatable.dart';

class ProformaEntity extends Equatable {
final List<String> pdfUrls; // 📦 Ahora es una lista
  final List<String> excelUrls;
  final String observacion;

  const ProformaEntity({
   this.pdfUrls = const [],
    this.excelUrls = const [],
    required this.observacion,
  });

  @override
  List<Object?> get props => [pdfUrls, excelUrls, observacion];
}