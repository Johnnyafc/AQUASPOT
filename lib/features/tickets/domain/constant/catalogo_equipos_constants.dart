import '../../../../core/enum/ticket_enums.dart';

class CatalogoEquiposConstants {
  static const Map<TipoEquipo, List<String>> accesoriosPorMaquina = {
    TipoEquipo.Caracol: [
      'Mangueras largas', 'Manguera interna', 'Serpentín', 'Chasis', 
      'Carcasa', 'Tapa posterior', 'Tapa frontal', 'Motor hidráulico', 'Impulsor'
    ],
    TipoEquipo.Cosechadora: [
      'Sistema de corte', 'Banda transportadora', 'Sensor de humedad', 
      'Tolva principal', 'Panel de control', 'Sistema hidráulico'
    ],
    TipoEquipo.Contador: [
      'Sensor óptico', 'Pantalla LCD', 'Fuente de poder', 'Cableado'
    ],
  };
}