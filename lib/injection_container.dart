// lib/injection_container.dart

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
// ✅ CAMBIO: Importamos el nuevo caso de uso unificado (Eliminado el de aprobar_evaluacion)
import 'features/tickets/domain/usecases/ActualizarTicketUseCase.dart';
import 'features/tickets/domain/usecases/crear_ticket_usecase.dart';
import 'features/tickets/domain/usecases/subir_evidencia_usecase.dart';
import 'features/tickets/domain/usecases/notificar_y_generar_acta_usecase.dart';
import 'features/tickets/domain/usecases/obtener_clientes_usecase.dart';
import 'features/tickets/domain/usecases/obtener_tickets_usecase.dart'; 
import 'features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'features/tickets/data/datasources/storage_remote_datasource.dart';
import 'features/tickets/data/datasources/storage_remote_datasource_impl.dart';

// --- FEATURE: AUTH ---
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/cerrar_sesion_usecase.dart';
import 'features/auth/domain/usecases/iniciar_sesion_usecase.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

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
  // 2. CORE
  // ===========================================================================
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));

  // ===========================================================================
  // 3. CAPA DE DATOS (Repositories & DataSources)
  // ===========================================================================
  // Tickets
  sl.registerLazySingleton<TicketRemoteDataSource>(
    () => TicketRemoteDataSourceImpl(firestore: sl()),
  );
  sl.registerLazySingleton<WebhookRemoteDataSource>(
    () => WebhookRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<ITicketRepository>(
    () => TicketRepositoryImpl(
      firebaseDataSource: sl(),
      webhookDataSource: sl(),
      storageDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Auth
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(firebaseAuth: sl(), firestore: sl()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
      firebaseAuth: sl(),
    ),
  );
  sl.registerLazySingleton<StorageRemoteDataSource>(
  () => StorageRemoteDataSourceImpl(storage: sl<FirebaseStorage>()),
);

  // ===========================================================================
  // 4. CAPA DE DOMINIO (UseCases)
  // ===========================================================================
  // Tickets
  sl.registerLazySingleton(() => ObtenerClientesUseCase(sl()));
  sl.registerLazySingleton(() => CrearTicketUseCase(sl()));
  // ✅ CAMBIO: Registramos el actuador universal
  sl.registerLazySingleton(() => ActualizarTicketUseCase(sl()));
  sl.registerLazySingleton(() => NotificarYGenerarActaUseCase(sl()));
  sl.registerLazySingleton(() => ObtenerTicketsUseCase(sl())); 
  
  // Auth
  sl.registerLazySingleton(() => IniciarSesionUseCase(sl()));
  sl.registerLazySingleton(() => CerrarSesionUseCase(sl()));
  

  sl.registerLazySingleton(() => SubirEvidenciaUseCase(sl()));
  // ===========================================================================
  // 5. CAPA DE PRESENTACIÓN (Blocs) - REGISTRAR AL FINAL
  // ===========================================================================
  sl.registerFactory(() => TicketBloc(
        obtenerClientes: sl(),
        crearTicket: sl(),
        // ✅ CAMBIO: Inyectamos el nuevo caso de uso al BLoC
        actualizarTicket: sl(),
        notificarYGenerarActa: sl(),
        obtenerTickets: sl(),
        subirEvidenciaUseCase: sl(), 
      ));
  
  sl.registerFactory(() => AuthBloc(
        iniciarSesion: sl(),
        cerrarSesion: sl(),
      ));
}