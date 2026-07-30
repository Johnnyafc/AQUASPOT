import '../../../../core/enum/ticket_enums.dart';

class CatalogoEquiposConstants {
  static const Map<TipoEquipo, List<String>> accesoriosPorMaquina = {
    TipoEquipo.Caracol: [
      'Mangueras largas', 'Manguera interna', 'Serpentín', 'Chasis', 
      'Carcasa', 'Tapa posterior', 'Tapa frontal', 'Motor hidráulico', 'Impulsor'
    ],
    TipoEquipo.Cosechadora: [
      'Acoples rapidos', 'comAp', 'Bomba hidraulica', 
      'Motor diesel', 'Serpentin', 'Mangueras internas'
    ],
    TipoEquipo.Contador: [
      'Cámara', 'Monitor', 'Estructura', 'Cables'
    ],
  };
}