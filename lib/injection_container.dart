import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import 'core/network/network_info.dart';

// --- FEATURE: TICKETS ---
import 'features/tickets/data/datasources/ticket_remote_datasource.dart';
import 'features/tickets/data/datasources/webhook_remote_datasource.dart';
import 'features/tickets/data/repositories/ticket_repository_impl.dart';
import 'features/tickets/domain/repositories/ticket_repository.dart';
import 'features/tickets/domain/usecases/aprobar_evaluacion_usecase.dart';
import 'features/tickets/domain/usecases/crear_ticket_usecase.dart';
import 'features/tickets/domain/usecases/notificar_y_generar_acta_usecase.dart';
import 'features/tickets/domain/usecases/obtener_clientes_usecase.dart';
import 'features/tickets/presentation/bloc/ticket_bloc.dart';

// --- FEATURE: AUTH ---
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/cerrar_sesion_usecase.dart';
import 'features/auth/domain/usecases/iniciar_sesion_usecase.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

final sl = GetIt.instance; // sl = Service Locator

Future<void> init() async {
  // ===========================================================================
  // 1. CAPA DE PRESENTACIÓN (El HMI)
  // ===========================================================================
  // Tickets
  sl.registerFactory(() => TicketBloc(
        obtenerClientes: sl(),
        crearTicket: sl(),
        aprobarEvaluacion: sl(),
        notificarYGenerarActa: sl(),
      ));
  
  // Auth
  sl.registerFactory(() => AuthBloc(
        iniciarSesion: sl(),
        cerrarSesion: sl(),
      ));

  // ===========================================================================
  // 2. CAPA DE DOMINIO (El Cerebro)
  // ===========================================================================
  // Tickets
  sl.registerLazySingleton(() => ObtenerClientesUseCase(sl()));
  sl.registerLazySingleton(() => CrearTicketUseCase(sl()));
  sl.registerLazySingleton(() => AprobarEvaluacionUseCase(sl()));
  sl.registerLazySingleton(() => NotificarYGenerarActaUseCase(sl()));
  
  // Auth
  sl.registerLazySingleton(() => IniciarSesionUseCase(sl()));
  sl.registerLazySingleton(() => CerrarSesionUseCase(sl()));

  // ===========================================================================
  // 3. CAPA DE DATOS (El Capataz y los Transductores)
  // ===========================================================================
  // Tickets
  sl.registerLazySingleton<ITicketRepository>(
    () => TicketRepositoryImpl(
      firebaseDataSource: sl(),
      webhookDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton<TicketRemoteDataSource>(
    () => TicketRemoteDataSourceImpl(firestore: sl()),
  );
  sl.registerLazySingleton<WebhookRemoteDataSource>(
    () => WebhookRemoteDataSourceImpl(dio: sl()),
  );

  // Auth
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
      firebaseAuth: sl(),
    ),
  );
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(
      firebaseAuth: sl(),
      firestore: sl(),
    ),
  );

  // ===========================================================================
  // 4. CORE (Herramientas Compartidas)
  // ===========================================================================
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));

  // ===========================================================================
  // 5. EXTERNAL (Dependencias de Terceros)
  // ===========================================================================
  final firestore = FirebaseFirestore.instance;
  final firebaseAuth = FirebaseAuth.instance; // <- NUEVO SENSOR CABLEADO

  sl.registerLazySingleton(() => firestore);
  sl.registerLazySingleton(() => firebaseAuth);
  sl.registerLazySingleton(() => Dio());
  sl.registerLazySingleton(() => InternetConnectionChecker.createInstance());
}