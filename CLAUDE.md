# Aquaspot Postventa — Contexto del proyecto

App Flutter/Firebase de gestión de postventa (tickets de reparación, garantía,
venta de repuestos, etc.) de Aquaspot. Arquitectura limpia por features
(`lib/features/<feature>/{data,domain,presentation}`), BLoC para estado,
Firestore como backend. Rama de trabajo actual: `aquaspot_optimizado`.

Este archivo resume el contexto acumulado en una sesión larga de trabajo con
Claude (vía Cowork) para que una sesión de Claude Code en esta misma carpeta
arranque con la misma memoria, sin tener que repetir todo desde cero.

## Reglas fijas (NO negociables, confirmadas explícitamente por el dueño del proyecto)

1. **Nunca hacer `git commit` sin una autorización explícita e inequívoca en
   ese mismo turno.** No asumir que "implementar" implica "commitear". Esperar
   a que el usuario pruebe el cambio y confirme antes de ofrecer commitear.
2. **Nunca editar o escribir código sin aprobación explícita en ese turno.**
   Para cambios de alcance abierto o decisiones de arquitectura, primero
   plantear el plan en palabras y esperar confirmación antes de tocar archivos.
3. **Problema conocido de fin de línea (CRLF/LF):** ~242 archivos aparecen
   como "modificados" en `git status` porque el git de este entorno no tiene
   `core.autocrlf` configurado igual que el git de Windows del usuario. **Nunca
   tocar, normalizar, ni hacer `git add -A` / `git add .`** — eso arrastraría
   esos falsos positivos. Al hacer `git add`, listar siempre los archivos
   exactos que de verdad se editaron.
4. Cada commit debe ser independiente y descriptivo; nunca usar `--amend`
   salvo pedido explícito.
5. Identidad git local ya configurada en este repo (NO global):
   `user.name = Johnnyafc`, `user.email = johfcede@espol.edu.ec` (coincide
   con el autor real de los commits anteriores del proyecto).
6. **Flutter SÍ está disponible en Claude Code en la máquina del usuario**
   (`C:\srclutter`): verificar siempre con `flutter analyze` (0 errores;
   hay ~149 avisos previos) y `flutter test`. Las Cloud Functions se compilan
   con `npm run build` en `functions/`; el despliegue lo hace el usuario.
   (En Cowork / la nube NO hay Flutter.)
7. Toda edición debe ser quirúrgica: leer el archivo antes de tocarlo,
   verificar que el string a reemplazar es único antes de escribir, revisar
   balance de llaves/paréntesis/corchetes después, y revisar el `git diff`
   para confirmar que el cambio quedó aislado a lo pedido.
8. **Respaldo antes de cada cambio:** copiar cada archivo a tocar en
   `Claude outputs/respaldos/<fecha>_antes_<tema>/<ruta>.respaldo` (la
   extensión `.respaldo` evita que Dart lo compile) junto con un
   `RESTAURAR.ps1` que los devuelve a su lugar.
9. **Plantear primero.** El usuario aprueba con "actúa", "procede",
   "implementa". "Solo eso" = no agregar nada más. Si dice "plantea" o "no
   hagas nada", solo se plantea.
10. Cuenta administradora maestra: `adminmaster@aquaspot.ec`
    (`correoAdministradorMaestro` en `lib/core/utils/constants.dart`): única
    que ve "Modificar Ticket" e "Inconsistencias de Trazabilidad".
11. **Arquitectura limpia obligatoria en todo código nuevo (desde 2026-10-14).**
    Flujo: página/widget → Bloc → UseCase → Repositorio (interfaz en
    `domain`) → RepositorioImpl/DataSource (`data`).
    - `domain`: entidades, servicios de reglas puras, use cases e interfaces.
      Sin Flutter UI, sin Firebase, sin importar `data` ni `presentation`.
    - `data`: lo único que conoce Firebase (`FieldValue`, `Timestamp`,
      modelos `toJson`, transacciones).
    - `presentation`: sin `FirebaseFirestore`/`FieldValue`, sin modelos de
      `data`, sin datasources creados a mano; las reglas de negocio van en
      servicios de dominio (con tests), no en las pantallas.
    - Deuda existente (no ampliarla; corregir por tareas aparte): Firestore
      directo en páginas del taller/retiro externo y `core/services`,
      `fallas`/`tecnicos` sin dominio, `TicketBloc` con escrituras Firestore
      y 21 accesos directos al repositorio, `XFile`/`PlatformFile` en domain.

12. **Mantenimiento interno: datos de la creación (desde 2026-10-28).** Toda
    pantalla de un requerimiento de mantenimiento interno muestra los datos
    con los que se creó (tipo de mantenimiento, máquina, marca,
    especificación, serie / placa, horómetro / km, fecha, detalle, quién lo
    creó y sus fotos / videos); **nunca** datos de cliente, contacto ni
    proyecto. Se arman en `ResumenMantenimientoService`. En las **tarjetas**
    de las bandejas (Evaluaciones, Costos, Compras, Validación Bodega,
    Despacho, Proceso de Trabajo, Historial) van **todos** los datos de la
    creación **sin fotos** (`DatosMantenimientoTarjetaWidget`); en las
    pantallas de detalle y en el detalle del Historial, **con** fotos y
    videos (`ResumenMantenimientoWidget`). Marca y especificación solo
    existen en aire acondicionado y herramientas (en aire acondicionado la
    especificación es la **ubicación del equipo**). Desde 2026-10-29: código
    propio **OT-00001** (contador `ot_count`, `CodigoRequerimientoService`);
    cualquier usuario elige Correctivo o Preventivo; series y placas en
    Firestore `catalogos/activos_mantenimiento` (una lista por tipo; el tipo
    que falte usa el catálogo por defecto). Mantenimiento interno **no lleva
    proyecto**: en Costos solo pasa por "Creación de códigos" si tiene
    repuestos sin código ("Creación de proyectos" es para el resto).
    Evaluación Técnica y Proceso de Trabajo tienen tarjetas separadas de
    requerimientos y de OT (`GrupoRequerimientoService`, por tipo, no por
    código). **Bomba de transferencia**: mismos campos que la cosechadora
    (serie del catálogo, horómetro + foto) y su Plan Maestro; Plan Preventivo
    en horas; sus series van en el campo `bombaTransferencia` del catálogo.
    **Reparto de OT por supervisor** (`VisibilidadSegmentoService`, y la
    misma regla en `segmentosDelTicket` de `functions/src/index.ts`): OT de
    contador → Contador; de cosechadora → Cosechadora **y** Caracol; el resto
    (caracol, bomba, vehículo, aire, herramientas) → Caracol. Los
    requerimientos siguen por su equipo. **Borradores** de la creación y de
    la Evaluación Técnica de OT (`BorradorMantenimientoService` +
    `IBorradorRepository`; claves `draft_ot_creacion` y
    `draft_ot_evaluacion_<id>`): se guardan solos, se recuperan con aviso
    "Descartar" y se borran al crear la OT / enviar la evaluación.
13. **"Usa flujo con generación de reportes automáticos"** (campo
    `usaFlujoReportesAutomaticos`, `FlujoReportesAutomaticosService`): se
    marca al guardar la Evaluación Técnica de todo mantenimiento interno y de
    reparación / garantía de Caracol, Cosechadora y Contador (informe
    automático, stock apartado, validación por repuesto, picking). Los
    tickets evaluados antes sin la marca terminan con el flujo con el que
    empezaron (los Caracol antiguos siempre lo usaron). Para habilitarlo en
    otro equipo se cambia solo esa regla.

## Estado del repositorio (actualizado 2026-10-27)

Último commit de código: `7e3a87e` (rama `aquaspot_optimizado`). Lo trabajado
hasta el 27/10/2026 está **commiteado y subido**. Verificación al cierre:
`flutter analyze` 0 errores (151 avisos = línea base), `flutter test`
**246** tests pasando, `flutter build web` compila.

**Link de prueba "desarrollo":** cada push a `aquaspot_optimizado` lo
publica solo (GitHub Actions → canal `desarrollo` de Firebase Hosting; usa la
base de datos REAL). `prueba-rapida` y producción son **intocables**.

**Agentes** en `.claude/agents/`: `tester` → `revisor` después de cada cambio;
`preparador-commit` solo cuando el usuario autoriza el commit.

**Leer antes de continuar, en este orden:**
1. `Claude outputs/CONTEXTO_SESION_2026-10-05_al_07.md` — Venta de Repuesto
   (fases 1–3), Validación simple de Bodega, trazabilidad por proceso,
   opciones de admin, Dashboard.
2. `Claude outputs/CONTEXTO_SESION_2026-10-08_al_13.md`:
   - **Revisión de Códigos del Plan Maestro** (tarjeta en menú, colección
     `historial_plan_maestro`).
   - **Borrador completo de Evaluación Técnica** (IndexedDB en web).
   - **Indicadores de Postventa** (botones por equipo en el Dashboard →
     Excel con pasteles; librería `syncfusion_officechart`).
   - **Picking en Bodega**: campo `estadoDespacho`, botones Iniciar /
     Finalizar picking, código `PICK-0X`; solo "Finalizar picking" pasa el
     ticket a Proceso de Trabajo.
   - **Retiro de materiales**: evidencia obligatoria (hoja firmada + fotos),
     cada retiro = un picking, anular orden. **Taller secuencial + guardado
     parcial** (13/10): las 5 acciones del taller solo escriben órdenes,
     marcas y evento (`_camposTaller`), un picking con evidencia a la vez y
     el siguiente solo con el anterior retirado y validado. (La versión con
     transacción se probó y el usuario la deshizo.)
   - **Cambios de materiales** de Comercial en registro aparte de la auditoría.
   - Auditoría: "TALLER: INICIO DE TRABAJO…" (solo eventos nuevos); marca y
     número de serie se guardan en MAYÚSCULAS (tipo de equipo no).
   - Comercial: chip "Costo M.O." = Total HH × $25 en la propuesta (solo
     se muestra, no se guarda).
   - Cloud Functions nuevas/cambiadas **sin desplegar**.
3. `Claude outputs/CONTEXTO_SESION_2026-10-23_al_27.md` — **lo más reciente**:
   - Dashboard: fallas por **Parte** (antes Componente) con pasteles por
     equipo, garantías por equipo y filtradas por falla, creados por mes →
     semana → día, documentos nuevos, Despacho con tiempo de picking.
   - Link de prueba "desarrollo" con GitHub Actions.
   - **Mantenimiento interno**: creación (videos, foto de horómetro / km),
     entra directo a Evaluación Técnica, evaluación propia (Plan Maestro +
     actividades nuevas, repuestos del inventario o SIN CÓDIGO), informe PDF
     y Solicitud de materiales; pasa a Compras sin Comercial ni Costos.
   - **Siguiente:** paso 2 Plan preventivo con frecuencia (horas / km / días)
     y paso 3 cierre del flujo (Proceso de Trabajo → Finalizado directo).

Pendiente inmediato (anterior al 23/10, por confirmar si sigue vigente): Excel "Baja ERP" del menú "Excels" de la ventana de
picking trae todos los repuestos (plan hecho, falta confirmación); reglas de
Storage para el enlace externo (`Claude outputs/storage_rules_con_retiro_externo.txt`)
y rol IAM "Firebase Rules Firestore Service Agent".

Pendientes generales: commits por tema, desplegar functions, Venta fases 4–5,
regla "datos de garantía cruzados", limpieza de código muerto, inventario
por bodega, contraseña SMTP en `functions/src/index.ts` (mover a Secret
Manager), proyecto Firebase de pruebas (planteado, sin decidir).
