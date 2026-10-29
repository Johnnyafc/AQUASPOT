// test/catalogo_activos_mantenimiento_test.dart
import 'package:aquaspot_postventa/core/errors/failures.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/mantenimiento_interno_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/repositories/catalogo_activos_mantenimiento_repository.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/obtener_catalogo_activos_mantenimiento_usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements ICatalogoActivosMantenimientoRepository {
  final Either<Failure, Map<String, List<String>>> r;
  _Repo(this.r);
  @override
  Future<Either<Failure, Map<String, List<String>>>> obtener() async => r;
}

void main() {
  test('Combina lo guardado en Firestore con el catálogo por defecto', () async {
    final r = await ObtenerCatalogoActivosMantenimientoUseCase(_Repo(const Right({'cosechadora': ['AQ2', 'AQ5']})))();
    final c = r.getOrElse(() => const {});
    expect(c[TipoActivoMantenimiento.cosechadora], ['AQ2', 'AQ5']);
    expect(c[TipoActivoMantenimiento.vehiculo], ['GTA1234']);
  });

  test('Sin documento en Firestore: catálogo por defecto', () async {
    final r = await ObtenerCatalogoActivosMantenimientoUseCase(_Repo(const Right({})))();
    expect(r.getOrElse(() => const {})[TipoActivoMantenimiento.caracol], ['AQ2']);
  });

  test('Si falla la lectura, devuelve el error', () async {
    final r = await ObtenerCatalogoActivosMantenimientoUseCase(_Repo(const Left(ServerFailure('sin red'))))();
    expect(r.isLeft(), isTrue);
  });
}
