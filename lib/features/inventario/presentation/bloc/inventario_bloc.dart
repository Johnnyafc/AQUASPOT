import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/item_inventario_entity.dart';
import '../../domain/usecases/cargar_stock_desde_excel_usecase.dart';
import '../../domain/usecases/consultar_stock_items_usecase.dart';
import '../../domain/usecases/obtener_stock_inventario_usecase.dart';
import 'inventario_event.dart';
import 'inventario_state.dart';

class InventarioBloc extends Bloc<InventarioEvent, InventarioState> {
  final CargarStockDesdeExcelUseCase cargarStockDesdeExcel;
  final ObtenerStockInventarioUseCase obtenerStockInventario;
  final ConsultarStockItemsUseCase consultarStockItems;

  InventarioBloc({
    required this.cargarStockDesdeExcel,
    required this.obtenerStockInventario,
    required this.consultarStockItems,
  }) : super(const InventarioInitial()) {
    on<CargarInventarioEvent>(_onCargarInventario);
    on<CargarStockExcelEvent>(_onSubirExcel);
    on<FiltrarInventarioEvent>(_onFiltrarInventario);
  }

  Future<void> _onCargarInventario(
    CargarInventarioEvent event,
    Emitter<InventarioState> emit,
  ) async {
    emit(const InventarioLoading('Cargando inventario de bodega...'));
    final result = await obtenerStockInventario();
    result.fold(
      (failure) => emit(InventarioError(failure.message)),
      (items) => _emitirCargado(items, emit),
    );
  }

  Future<void> _onSubirExcel(
    CargarStockExcelEvent event,
    Emitter<InventarioState> emit,
  ) async {
    emit(const InventarioLoading('Importando archivo de stock...'));
    final result = await cargarStockDesdeExcel(event.bytes);
    await result.fold(
      (failure) async {
        emit(InventarioError(failure.message));
      },
      (count) async {
        emit(InventarioOperacionSuccess(
          mensaje: 'Se actualizaron $count ítems en bodega exitosamente',
          totalProcesados: count,
        ));
        final reloadResult = await obtenerStockInventario();
        reloadResult.fold(
          (failure) => emit(InventarioError(failure.message)),
          (items) => _emitirCargado(items, emit),
        );
      },
    );
  }

  void _onFiltrarInventario(
    FiltrarInventarioEvent event,
    Emitter<InventarioState> emit,
  ) {
    if (state is InventarioLoaded) {
      final current = state as InventarioLoaded;
      final query = event.query.trim().toLowerCase();
      if (query.isEmpty) {
        emit(current.copyWith(itemsFiltrados: current.items));
      } else {
        final filtrados = current.items.where((it) {
          return it.codigo.toLowerCase().contains(query) ||
              it.descripcion.toLowerCase().contains(query);
        }).toList();
        emit(current.copyWith(itemsFiltrados: filtrados));
      }
    }
  }

  void _emitirCargado(
    List<ItemInventarioEntity> items,
    Emitter<InventarioState> emit,
  ) {
    final mapaPorCodigo = <String, ItemInventarioEntity>{};
    for (final item in items) {
      mapaPorCodigo[item.codigo.toUpperCase().trim()] = item;
    }
    emit(InventarioLoaded(
      items: items,
      itemsFiltrados: items,
      mapaPorCodigo: mapaPorCodigo,
    ));
  }
}
