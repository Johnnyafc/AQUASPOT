# Contexto de la sesión 2026-10-23 al 27 (Claude Code en la nube)

Sesión en claude.ai/code sobre `Johnnyafc/AQUASPOT`, rama `aquaspot_optimizado`.
Todo lo de esta sesión está **commiteado y subido** (último commit `7e3a87e`).
Verificación al cierre: `flutter analyze` 0 errores / 151 avisos (línea base),
`flutter test` **246** tests pasando, `flutter build web` compila.

> En la nube Flutter no viene instalado: esta sesión lo instaló en
> `/opt/flutter-sdk/flutter` (3.47.x) y se pierde al cerrarse el contenedor.
> En la máquina del usuario está en `C:\src\flutter` (3.47.2).

## 1. Dashboard y métricas de fallas (23–24/10)
- **"Componente" pasa a llamarse "Parte"** (Categoría › Parte › Falla) y se
  abrió la **ronda 2** de revisión de diagnóstico (tickets antiguos vuelven a
  "Fallas pendientes" para agregar la parte).
- **Fallas por parte**: gráfico con filtro Categoría › Parte.
- **Un pastel por equipo** (Cosechadora, Contador, Caracol + otros con datos)
  en Categoría, Parte y Razones; "Otras" desplegable.
- **Fallas más frecuentes**: todos los equipos, muestra la parte, 10 visibles + "Ver más".
- **Dictamen de garantía**: un pastel por equipo.
- La categoría / parte elegida en Diagnóstico de fallas **filtra Garantías y Detalle**.
- **Tickets creados por mes** con desglose por semana y por día (tocar la barra).
- **Documentos**: columnas nuevas en el Detalle del Dashboard y carpetas
  nuevas en la Biblioteca (servicio `DocumentosTicketService`).
- **Tiempo por proceso**: Despacho desplegable (Antes del picking / Picking /
  Validación simple). Se mide desde el evento que `habilita` bodega hasta el
  `hito` fin de bodega, promedio solo de **finalizados** (el usuario eligió
  dejarlo así).
- **Excel de Indicadores**: tiempo exacto del lead time y etiquetas de rangos.
  Aclarado: Indicador 2 cuenta por mes de finalización y el Indicador
  Adicional por mes de creación (por eso no cuadran entre sí).
- Servicios de dominio nuevos (con tests): `fallas_por_parte_service.dart`,
  `tendencia_creacion_service.dart`, `documentos_ticket_service.dart`,
  cambios en `tiempos_por_proceso_service.dart`.

## 2. Otros cambios
- Menú: tarjeta **"Crear Ticket" también para el rol comercial**.
- Informe de Evaluación Técnica (reparación): **NOTA de daños ocultos en
  negrita** antes del "Cordialmente," y firma **"Ing."** (antes "ING.").
- Se corrigió a mano el PDF REQ-00097 (nota + Ing.) y se pasó a Word; están
  en `Claude outputs/informes_corregidos/` (no van al repo).

## 3. Link de prueba "desarrollo" (GitHub Actions)
- Workflow `.github/workflows/vista-previa-desarrollo.yml`: en cada push a
  `aquaspot_optimizado` corre `flutter analyze` (sin fallar por avisos),
  `flutter test`, `flutter build web --release` y publica en el **canal de
  vista previa `desarrollo`** de Firebase Hosting (expira a los 30 días, se
  renueva con cada push). Flutter 3.47.2.
- Secreto `FIREBASE_SERVICE_ACCOUNT` en GitHub (cuenta de servicio
  `github-desarrollo` con Firebase Hosting Admin, Firebase Authentication
  Admin, Cloud Run Viewer, API Keys Viewer, Service Usage Consumer).
  **Nunca** pedir ni pegar la clave en el chat o en el código.
- El link exacto (`https://aquaspot-postventa--desarrollo-XXXXXXXX.web.app`)
  está en GitHub → Actions → paso "Publicar en el canal desarrollo"
  (línea "Channel URL") o en Firebase → Hosting → Canales de vista previa.
- **`prueba-rapida` y producción son intocables** (palabras del dueño).
- El link de desarrollo usa la **base de datos y Storage reales**: lo que se
  pruebe ahí aparece en las bandejas reales. Si no se ve el cambio:
  Ctrl+Shift+R o incógnito (caché del service worker de Flutter web).

## 4. Mantenimiento interno (nuevo tipo de requerimiento)
Arquitectura limpia en todo (página → Cubit → UseCase → Repositorio; reglas
en servicios de dominio con tests; sin tocar `TicketBloc` ni la pantalla de
evaluación de reparación).

### 4.1 Creación (Crear Ticket → "Mantenimiento Interno")
- `TipoRequerimiento.mantenimientoInterno`; campo `mantenimientoInterno` en
  el ticket (`MantenimientoInternoEntity`: tipo de mantenimiento, tipo de
  activo, placa, km, fecha/hora de falla, `urlFotoLectura`, `videosUrls`).
- **Tipo de mantenimiento**: operadores fijo en Correctivo; supervisor/admin
  eligen Correctivo o Preventivo (se valida también en el use case).
- Campos por máquina (catálogo fijo en `FormularioMantenimientoService.catalogo`):
  - Cosechadora (serie `AQ2`): horómetro **+ foto del horómetro** obligatorios.
  - Contador (`Contador AQUASPOT`) / Caracol (`AQ2`): fecha y hora (de la
    falla; en preventivo, la programada; nunca futura en correctivo).
  - Vehículo (placa `GTA1234`, equipo `Otros`): kilometraje **+ foto del
    kilometraje** obligatorios.
  - Todos: detalle ≥ 10 caracteres y al menos 1 evidencia **foto o video**
    (máx. 3 videos de 60 s).
- Cliente "AQUASPOT (interno)", sin contacto ni correo (las Functions no
  envían correos sin `emailContacto`).
- Entra **directo a Evaluación Técnica** (`recepcionFisica`; evento con
  `habilita: [evaluacion]`). Aparece en la pestaña "EVALUACIÓN TÉCNICA" del
  Historial y en la Bandeja de Evaluaciones. Los tickets de prueba creados
  antes de ese cambio quedaron en "Creado".
- Excluido de Recepción, Fallas pendientes, Inconsistencias e Indicadores de
  Postventa; en el Dashboard aparece como "Mantenimiento interno".
- Storage: los archivos se suben con su tipo real (imagen/video), no siempre `image/jpeg`.

### 4.2 Evaluación técnica de mantenimiento
- Pantalla propia `evaluacion_mantenimiento_page.dart` (+ `EvaluacionMantenimientoCubit`,
  `EvaluacionMantenimientoService`, `GuardarEvaluacionMantenimientoUseCase`,
  `SubirArchivoAdjuntoUseCase`, entidades `ActividadMantenimiento` y
  `ArchivoAdjunto` — esta última reemplaza a `XFile` en el dominio para
  código nuevo).
- Botones **"Plan Maestro"** (actividades del catálogo del equipo; el
  vehículo no tiene) y **"Actividad nueva"** (código `NUEVA-01…`, misma
  estructura, solo en el ticket; decidido no guardarla en el Plan Maestro).
- Cada actividad: horas hombre, observación, fotos y **una sola lista de
  repuestos** (internos + comerciales del plan juntos, sin repetir). Repuestos
  del **inventario registrado** (buscador) o **"No registrado"** (sin código,
  en MAYÚSCULAS, marcado **SIN CÓDIGO** para Compras). +/−, cantidad exacta
  (decimales) y quitar. Lo puede editar el técnico.
- "¿Necesita compras?" con motivo, igual que reparación.
- **"GENERAR Y REVISAR INFORME"** → pantalla de revisión con dos pestañas:
  - **Informe técnico (PDF)** `generador_pdf_mantenimiento.dart`: datos del
    mantenimiento, HALLAZGOS con fotos, ACTIVIDADES A REALIZAR con su
    "Incluye" de **todos** sus repuestos, firma "Ing." — **sin la NOTA**.
  - **Solicitud de materiales (Excel)** `generador_excel_mantenimiento.dart`:
    hoja MATERIAL con todos los repuestos sumados (SIN CÓDIGO marcado),
    Proyecto AQUASPOT, Centro de costo MANTENIMIENTO INTERNO, Cargo CONSUMO
    MANTENIMIENTO INTERNO; hoja ACTIVIDADES con HH.
  - "MODIFICAR" vuelve; "CONFIRMAR Y SUBIR" sube fotos + PDF + Excel
    (reintento sin duplicar fotos) y guarda.
- Al guardar: todos los repuestos → `itemsDespachoBodega`; el ticket pasa a
  **Compras sin Comercial ni Costos** (`isCostosCompletado: true`); en
  **Caracol se aparta el stock** (`guardarEvaluacionTecnicaConReservaStock`),
  igual que reparación, porque el picking lo libera.
- La Solicitud de materiales que descarga Bodega usa el encabezado de
  mantenimiento interno para estos tickets.
- Pendiente de confirmar en el link: la vista previa del PDF dentro de la app
  (en las pruebas no se puede dibujar; es el mismo componente de reparación).

### 4.3 Pendiente de mantenimiento interno (planteado y aprobado)
- **Paso 2 — Plan preventivo con frecuencia** (siguiente):
  - Página nueva "Plan Preventivo" en el menú (admin/supervisor): actividades
    preventivas por tipo de máquina (cosechadora, contador, caracol y
    **vehículo**), con repuestos del inventario y **frecuencia**: horas
    (cosechadora), km (vehículo), días (contador/caracol).
  - Colección propia (`plan_preventivo`), **no** dentro del Plan Maestro,
    para que no aparezca en la evaluación de reparación.
  - Botón **"Plan preventivo"** en la evaluación de mantenimiento: muestra
    las actividades con su frecuencia ("cada 250 h") y se agregan
    modificables. Disponible en correctivos y preventivos.
  - Aviso de "próximo mantenimiento" (lectura + frecuencia): fase posterior.
- **Paso 3 — Cierre del flujo**: Compras → Bodega (validación / picking) →
  Proceso de Trabajo → **Finalizado directo por el supervisor**, sin
  Facturación ni Entrega. La regla del siguiente estado va en un servicio de
  dominio con tests y la escritura en un use case nuevo; las bandejas viejas
  (deuda con `TicketBloc`) solo lo llaman. En Compras hoy se ve "Proyecto:
  PENDIENTE DE CREACIÓN" para estos tickets (ajustar en este paso).
- Ideas posteriores: autocompletar serie/placa y avisar si el horómetro/km es
  menor que el del último mantenimiento; catálogo de series/placas en
  Firestore (hoy fijo en el código).

## 5. Agentes de Claude Code (`.claude/agents/`, commit `7e3a87e`)
- `tester` (sonnet): `flutter analyze` contra la línea base, `flutter test`,
  `npm run build` si se tocó `functions/`. No escribe archivos; `dart format`
  solo como aviso y solo en los archivos tocados.
- `revisor` (opus): bugs + **arquitectura limpia (regla 11)** sin ampliar la
  deuda; solo lectura.
- `preparador-commit` (sonnet): lista exacta para `git add` (sin falsos CRLF
  ni `Claude outputs/`), respaldo, secretos y mensaje; nunca hace el commit.
- Flujo: programar → tester → revisor → el usuario prueba → "haz commit" →
  preparador-commit → commit.
- Solo los carga una sesión que **arranca** con el repo (elegir
  Johnnyafc/AQUASPOT y la rama al crear la sesión; clonar después no basta).

## 6. Forma de trabajo confirmada en esta sesión
- Plantear primero; implementar con "procede"/"actúa"; commit solo con
  "haz commit" en ese turno; respaldo + `RESTAURAR.ps1` antes de cada cambio
  (si el cambio no crea archivos nuevos, el `RESTAURAR.ps1` no borra nada).
- `git add` siempre archivo por archivo; nunca `Claude outputs/` (respaldos,
  informes, capturas) salvo los `CONTEXTO_SESION_*.md`.
- El hook de fin de turno pide commit y push siempre: se ignora hasta que el
  usuario autoriza.
