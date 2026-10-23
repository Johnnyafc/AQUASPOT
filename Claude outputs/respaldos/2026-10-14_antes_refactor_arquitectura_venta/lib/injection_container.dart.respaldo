// lib/injection_container.dart

import 'package:aquaspot_postventa/features/auth/domain/usecases/verificar_sesion_usecase.dart';
import 'package:aquaspot_postventa/features/clientes/data/datasources/cliente_remote_datasource.dart';
import 'package:aquaspot_postventa/features/clientes/data/datasources/cliente_remote_datasource_impl.dart';
import 'package:aquaspot_postventa/features/clientes/data/repositories/cliente_repository_impl.dart';
import 'package:aquaspot_postventa/features/clientes/domain/repositories/cliente_repository.dart';
import 'package:aquaspot_postventa/features/clientes/domain/usecases/actualizar_cliente_usecase.dart';
import 'package:aquaspot_postventa/features/clientes/domain/usecases/obtener_todos_clientes_usecase.dart';
import 'package:aquaspot_postventa/features/clientes/domain/usecases/registrar_cliente_usecase.dart';
import 'package:aquaspot_postventa/features/clientes/presentation/bloc/cliente_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/SubirOrdenVentaUseCase.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/escuchar_estado_excel_usecase.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/subir_documento_comercial_usecase.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/subir_documento_evaluacion_usecase.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/subir_orden_compra_usecase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'core/network/network_info.dart';
import 'core/services/pdf_service.dart';

// --- FEATURE: TICKETS ---
import 'features/tickets/data/datasources/ticket_remote_datasource_impl.dart';
import 'features/tickets/data/datasources/webhook_remote_datasource.dart';
import 'features/tickets/data/datasources/storage_remote_datasource.dart';
import 'features/tickets/data/datasources/storage_remote_datasource_impl.dart';
import 'features/tickets/data/datasources/ticket_remote_datasource.dart';
import 'features/tickets/data/repositories/ticket_repository_impl.dart';
import 'features/tickets/domain/repositories/ticket_repository.dart';
import 'features/tickets/domain/usecases/ActualizarTicketUseCase.dart';
import 'features/tickets/domain/usecases/crear_ticket_usecase.dart';
import 'features/tickets/domain/usecases/subir_evidencia_usecase.dart';
import 'features/tickets/domain/usecases/subir_acta_pdf_usecase.dart'; 
import 'features/tickets/domain/usecases/notificar_y_generar_acta_usecase.dart';
import 'features/tickets/domain/usecases/obtener_clientes_usecase.dart';
import 'features/tickets/domain/usecases/obtener_tickets_usecase.dart'; 
import 'features/tickets/domain/usecases/generar_acta_pdf_usecase.dart';
import 'features/tickets/presentation/bloc/ticket_bloc.dart';

// --- FEATURE: AUTH ---
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/cerrar_sesion_usecase.dart';
import 'features/auth/domain/usecases/iniciar_sesion_usecase.dart';
import 'features/auth/domain/usecases/registrar_usuario_usecase.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
// --- FEATURE: CLIENTES (Las rutas que definimos) ---

// --- FEATURE: CATALOGO ---
import 'features/catalogo/data/datasources/catalogo_remote_datasource.dart';
import 'features/catalogo/data/repositories/catalogo_repository_impl.dart';
import 'features/catalogo/domain/repositories/catalogo_repository.dart';
import 'features/catalogo/domain/usecases/catalogo_usecases.dart';
import 'features/catalogo/presentation/bloc/catalogo_bloc.dart';

// --- FEATURE: INVENTARIO ---
import 'features/inventario/data/datasources/inventario_remote_datasource.dart';
import 'features/inventario/data/datasources/inventario_remote_datasource_impl.dart';
import 'features/inventario/data/repositories/inventario_repository_impl.dart';
import 'features/inventario/domain/repositories/inventario_repository.dart';
import 'features/inventario/domain/usecases/cargar_stock_desde_excel_usecase.dart';
import 'features/inventario/domain/usecases/obtener_stock_inventario_usecase.dart';
import 'features/inventario/domain/usecases/consultar_stock_items_usecase.dart';
import 'features/inventario/presentation/bloc/inventario_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // ===========================================================================
  // 1. EXTERNAL (Dependencias de Terceros)
  // ===========================================================================
  final firestore = FirebaseFirestore.instance;
  final firebaseAuth = FirebaseAuth.instance;

  sl.registerLazySingleton(() => firestore);
  sl.registerLazySingleton(() => firebaseAuth);
  sl.registerLazySingleton(() => Dio());
  sl.registerLazySingleton(() => InternetConnectionChecker.createInstance());
  sl.registerLazySingleton(() => FirebaseStorage.instance);

  // ===========================================================================
  // 2. CORE (Servicios de Infraestructura Base)
  // ===========================================================================
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));
  sl.registerLazySingleton(() => PdfService());

  // ===========================================================================
  // 3. CAPA DE DATOS (DataSources & Repositories)
  //    (Nota Industrial: Primero se registran las fuentes, luego los repos)
  // ===========================================================================
  
  // --- TICKETS ---
  sl.registerLazySingleton<TicketRemoteDataSource>(
    () => TicketRemoteDataSourceImpl(firestore: sl()),
  );
  sl.registerLazySingleton<WebhookRemoteDataSource>(
    () => WebhookRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<StorageRemoteDataSource>(
    () => StorageRemoteDataSourceImpl(storage: sl<FirebaseStorage>()),
  );
  sl.registerLazySingleton<ITicketRepository>(
    () => TicketRepositoryImpl(
      firebaseDataSource: sl(),
      webhookDataSource: sl(),
      storageDataSource: sl(),
      networkInfo: sl(),
      pdfService: sl(), 
    ),
  );

  // --- AUTH ---
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(firebaseAuth: sl(), firestore: sl()),
  );

  sl.registerLazySingleton(() => VerificarSesionUseCase(sl()));

  
  
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
      firebaseAuth: sl(),
    ),
  );

  // --- CLIENTES ---
  // ⚙️ CORRECCIÓN: Faltaba registrar la fuente de datos física antes del repositorio
  sl.registerLazySingleton<ClienteRemoteDataSource>(
    () => ClienteRemoteDataSourceImpl(firestore: sl()),
  );
  sl.registerLazySingleton<ClienteRepository>(
    () => ClienteRepositoryImpl(remoteDataSource: sl()),
  );

  // --- CATALOGO ---
  sl.registerLazySingleton<CatalogoRemoteDataSource>(
    () => CatalogoRemoteDataSourceImpl(firestore: sl()),
  );
  sl.registerLazySingleton<CatalogoRepository>(
    () => CatalogoRepositoryImpl(remoteDataSource: sl()),
  );

  // --- INVENTARIO ---
  sl.registerLazySingleton<InventarioRemoteDataSource>(
    () => InventarioRemoteDataSourceImpl(firestore: sl()),
  );
  sl.registerLazySingleton<InventarioRepository>(
    () => InventarioRepositoryImpl(remoteDataSource: sl()),
  );

  // ===========================================================================
  // 4. CAPA DE DOMINIO (UseCases)
  // ===========================================================================
  
  // --- TICKETS ---
  sl.registerLazySingleton(() => ObtenerClientesUseCase(sl()));
  sl.registerLazySingleton(() => CrearTicketUseCase(sl()));
  sl.registerLazySingleton(() => ActualizarTicketUseCase(sl()));
  sl.registerLazySingleton(() => NotificarYGenerarActaUseCase(sl()));
  sl.registerLazySingleton(() => ObtenerTicketsUseCase(sl())); 
  sl.registerLazySingleton(() => SubirEvidenciaUseCase(sl()));
  sl.registerLazySingleton(() => SubirActaPdfUseCase(sl())); 
  sl.registerLazySingleton(() => GenerarActaPdfUseCase(sl()));

  // --- AUTH ---
  sl.registerLazySingleton(() => IniciarSesionUseCase(sl()));
  sl.registerLazySingleton(() => CerrarSesionUseCase(sl()));
  sl.registerLazySingleton(() => RegistrarUsuarioUseCase(sl()));
  
  // --- CLIENTES ---
  sl.registerLazySingleton(() => RegistrarClienteUseCase(sl()));
  sl.registerLazySingleton(() => ObtenerTodosClientesUseCase(sl()));
  sl.registerLazySingleton(() => ActualizarClienteUseCase(sl()));
  sl.registerLazySingleton(() => SubirDocumentoEvaluacionUseCase(sl()));

  sl.registerLazySingleton(() => SubirDocumentoComercialUseCase(sl()));

  sl.registerLazySingleton(() => SubirOrdenVentaUseCase(sl()));
sl.registerLazySingleton(() => SubirOrdenCompraUseCase(sl()));
sl.registerLazySingleton(() => EscucharEstadoExcelUseCase(sl()));

  // ===========================================================================
  // 5. CAPA DE PRESENTACIÓN (Blocs)
  // ===========================================================================
  sl.registerFactory(() => TicketBloc(
        obtenerClientes: sl(),
        crearTicket: sl(),
        actualizarTicket: sl(),
        notificarYGenerarActa: sl(),
        obtenerTickets: sl(),
        subirEvidenciaUseCase: sl(),
        subirActaPdfUseCase: sl(), 
        generarActaPdfUseCase: sl(), 
        notificarYGenerarActaUseCase: sl(),
        subirDocumentoEvaluacionUseCase: sl(),
        subirDocumentoComercialUseCase: sl(),
        subirOrdenVentaUseCase: sl(), 
        subirOrdenCompraUseCase: sl(),
        ticketRepository: sl(),
        
      ));

  sl.registerFactory(() => AuthBloc(
        iniciarSesion: sl(),
        cerrarSesion: sl(),
        registrarUsuarioUseCase: sl(),
        verificarSesionUseCase: sl(),
      ));
      
  // --- CLIENTES ---
  sl.registerFactory(() => ClienteBloc(
        registrarClienteUseCase: sl(),
        obtenerTodosClientesUseCase: sl(),
        actualizarClienteUseCase: sl(),
      ));

  // --- CATALOGO ---
  sl.registerLazySingleton(() => ObtenerActividadesPorEquipoUseCase(sl()));
  sl.registerLazySingleton(() => GuardarActividadCatalogoUseCase(sl()));
  sl.registerLazySingleton(() => EliminarActividadCatalogoUseCase(sl()));
  sl.registerLazySingleton(() => CargarCatalogoInicialUseCase(sl()));

  sl.registerFactory(() => CatalogoBloc(
        obtenerActividadesPorEquipo: sl(),
        guardarActividadCatalogo: sl(),
        eliminarActividadCatalogo: sl(),
        cargarCatalogoInicial: sl(),
      ));

  // --- INVENTARIO ---
  sl.registerLazySingleton(() => CargarStockDesdeExcelUseCase(sl()));
  sl.registerLazySingleton(() => ObtenerStockInventarioUseCase(sl()));
  sl.registerLazySingleton(() => ConsultarStockItemsUseCase(sl()));

  sl.registerFactory(() => InventarioBloc(
        cargarStockDesdeExcel: sl(),
        obtenerStockInventario: sl(),
        consultarStockItems: sl(),
      ));
}