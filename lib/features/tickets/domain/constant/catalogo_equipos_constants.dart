import '../entities/ticket_enums.dart';

class CatalogoEquiposConstants {
  static const Map<TipoEquipo, List<String>> accesoriosPorMaquina = {
    TipoEquipo.Caracol: [
      'Mangueras largas', 'Manguera interna', 'Serpentín', 'Chasis', 
      'Carcasa', 'Tapa posterior', 'Tapa frontal', 'Motor hidráulico', 'Impulsor'
    ],
    TipoEquipo.Cosechadora_premium: [
      'Sistema de corte', 'Banda transportadora', 'Sensor de humedad', 
      'Tolva principal', 'Panel de control', 'Sistema hidráulico'
    ],
    TipoEquipo.Cosechadora_standart: [
      'Cuchillas', 'Motor principal', 'Tolva', 'Filtros'
    ],
    TipoEquipo.Cosechadora_elevacion: [
      'Sinfín de elevación', 'Motor', 'Estructura metálica', 'Correas'
    ],
    TipoEquipo.Contador: [
      'Sensor óptico', 'Pantalla LCD', 'Fuente de poder', 'Cableado'
    ],
  };
}