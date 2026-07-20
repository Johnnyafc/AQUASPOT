import 'package:equatable/equatable.dart';

class EvidenciaTrabajoEntity extends Equatable {
  final List<String> fotosUrls;
  final List<String> videosUrls;
  final String? notasTecnicas;

  const EvidenciaTrabajoEntity({
    required this.fotosUrls,
    required this.videosUrls,
    this.notasTecnicas,
  });

  @override
  List<Object?> get props => [fotosUrls, videosUrls, notasTecnicas];
}