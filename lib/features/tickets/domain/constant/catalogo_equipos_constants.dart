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
      'Chasis macro counter', 'Cabezal contador macro counter', 'Computadora para macro counter', 'Cable LAN de comunicación roscado para la cámara',' Semáforo','Cable repuesto de comunicación sin rosca para la cámara(Cabezal-computadora)','Cable de alimentación semáforo', 'Manguera de succión de 6 pulgadas','Soporte metálico para semaforo en acero inoxidable 316','Antena física para internet','Cable de alimentación hacia la lámpara','Cable de comunicación para conexión USB'
    ],
  };
}