# Contexto de la sesión con Claude Code (08 al 13 de octubre de 2026)

Proyecto: **Aquaspot Postventa** (Flutter/Firebase), rama `aquaspot_optimizado`.
Último commit: `0f1c1f0`. **Nada de esta sesión (ni de la del 05–07/10) está commiteado.**
Continúa a `CONTEXTO_SESION_2026-10-05_al_07.md` (leer ambos).

Verificación al cierre: `flutter analyze` 0 errores (151 avisos previos),
`flutter test` **111 tests pasando**, `functions/` compila con `npm run build`.

---

## 0. Forma de trabajo (sin cambios)

- Plantear primero; el usuario aprueba con "procede / actúa / implementa".
  "Solo eso" = solo eso. Si dice "plantea", no tocar nada.
- Respaldo antes de cada cambio en `Claude outputs/respaldos/<fecha>_antes_<tema>/`
  (`.respaldo` + `RESTAURAR.ps1`, que también borra los archivos nuevos).
- Nunca commitear sin autorización; `git add` con archivos exactos (ruido CRLF).
- Ediciones con scripts Python que respetan CRLF/LF. Ojo: el tool Write
  borra espacios al final de línea → anclar por posición cuando el texto
  original los tenga.
- Respuestas al usuario: cortas cuando pregunta algo puntual ("respóndeme
  sin tanto texto").
- El usuario publica él mismo: reglas de Firestore/Storage (consola),
  Cloud Functions (`firebase deploy --only functions:...`) y hosting.

---

## 1. Revisión de Códigos del Plan Maestro (08/10)

- Tarjeta en menú principal (admin y supervisor) → `RevisionCodigosPlanMaestroPage`
  (`features/catalogo/presentation/pages/`), servicio
  `catalogo/domain/services/revision_codigos_plan_maestro_service.dart`.
- Compara ítems del plan (repuestos e insumos, internos y comerciales) contra
  `inventario_bodega`. Excluye servicios y mano de obra (prefijos `SER`, `MO`,
  o descripción "SERVICIO"/"MANO DE OBRA"). Estados 🔴 no existe / 🟠
  descripción distinta (umbral 80 %) / ⚪ sin código / 🟢 coincide.
- Pestañas por equipo; supervisor de un segmento solo ve el suyo.
- Botones "Editar" y "Buscar coincidencias y asignar" (top 5 por similitud
  de código y descripción). Guardado en transacción; historial en colección
  `historial_plan_maestro` (regla agregada en `firestore.rules`, sección 6.1)
  con "Deshacer" del último cambio.

## 2. Borrador completo de Evaluación Técnica (08/10)

- `evaluacion_tecnica_page.dart` guarda TODO (actividades Caracol con horas,
  hallazgo, repuestos editados y fotos; documentos) con pausa de 1 s.
- Web: archivos en IndexedDB (`core/services/archivos_borrador_store*.dart`,
  import condicional como `web_previsualizador`). Celular: base64 + ruta.
- Botón "Descartar borrador"; limpieza de borradores > 30 días.
- Codificador: `tickets/domain/services/borrador_evaluacion_codec.dart`.
- Pendiente detectado (no tocado): miniaturas de fotos en web usan FileImage.

## 3. Indicadores de Postventa (Dashboard → Excel) (08/10)

- Botones en el AppBar del Dashboard: admin y supervisor General/sin segmento
  ven 3 ("Indicadores Caracol/Contador/Cosechadora"); supervisor de un equipo
  solo el suyo; otros roles ninguno. Rango de fechas con día.
- Servicio `tickets/domain/services/indicadores_postventa_service.dart`,
  generador `tickets/presentation/services/generador_excel_indicadores_postventa.dart`
  (librería nueva `syncfusion_officechart`; xlsio subió a 34.2.9).
- Hojas: `Indicador_1` (servicios que terminaron Proceso de Trabajo, por mes
  de salida de taller), `Indicador_2` (lead time de finalizados), `Indicador_3`
  (cascada de pasteles sistema → falla → razón + tablas mes a mes, por mes de
  creación), `Indicador_Adicional` (todos los creados en el rango, anulados
  diferenciados, sin ventas), `Detalle I1/I2/I3/IA`. Encabezado solo con
  título + equipo + período. Nombres de hoja SIN espacios (la librería de
  gráficos no los cita).
- Inconsistencias señaladas (sin resolver, pendiente decisión): ventas no
  excluidas en Ind. 1–3; "recurrencia" mide distribución; sistemas no son
  los 4 pedidos (Mecánico/Eléctrico/Hidráulico/Estructural).

## 4. Picking en Bodega (12/10)

- Campo nuevo en ticket `estadoDespacho`: `pendiente → pickingEnCurso →
  despachoParcial → pickingFinalizado`, más `pickingIniciadoPor/En`,
  `pickingFinalizadoPor/En`. NO se escriben en `toJson` (solo updates
  puntuales). Tickets viejos: estado deducido y escrito al abrir la bandeja.
  Lógica: `tickets/domain/services/estado_despacho_service.dart`.
- Tarjeta de Despacho: botón **Iniciar picking**, indicador **Guía** (no es
  botón) y botón **Finalizar picking** (activo con todo despachado al 100 %
  y todas las entregas con evidencia). Solo "Finalizar picking" pasa el
  ticket a Proceso de Trabajo (antes era automático). La ventana de picking
  solo se abre con el picking iniciado.
- `requiereValidacionSimpleBodega`: el caso "despacho cerrado sin traspaso"
  ahora solo aplica a tickets sin `estadoDespacho`.
- Textos de la ventana cambiados a "picking" (diálogo "¿Confirmar picking
  listo para retiro?", "Pickings realizados", etc.). Código nuevo de cada
  picking: `REQ-…-PICK-0X` (los viejos conservan `DESP-0X`).
- Cada picking descarga Excel Baja ERP + Solicitud de Materiales y exige
  evidencia; para registrar otro picking o finalizar, se exige la evidencia.
- "Finalizar trabajo" (`subir_evidencia_trabajo_page`) bloqueado si Bodega
  no finalizó el picking (`EstadoDespachoService.materialesDespachados`).

## 5. Retiro de materiales (técnico) (12–13/10)

- Evidencia obligatoria al confirmar retiro (hoja de materiales firmada +
  foto de materiales) en `recepcion_repuestos_tecnico_page.dart` (interno) y
  `recepcion_externa_page.dart` (externo, por enlace). Widget
  `presentation/widgets/evidencia_retiro_widget.dart`. Campos en la orden:
  `urlsHojaFirmada`, `urlsFotosMateriales`. Retiros anteriores eximidos.
- Externo sin sesión: sube a `tickets/{ticket}/retiros_externos/{token}/`;
  requiere reglas de Storage nuevas (archivo
  `Claude outputs/storage_rules_con_retiro_externo.txt`, sección 4) y que la
  cuenta de Storage tenga el rol "Firebase Rules Firestore Service Agent".
  El usuario vio `[firebase_storage/unauthorized]`: revisar ese rol. Tipo de
  imagen deducido por extensión si el navegador lo manda vacío.
- **Cada retiro = un picking**: al enviar a retirar se elige el picking y la
  orden lleva solo sus repuestos (`pickingId` en la orden). Servicio
  `tickets/domain/services/retiro_picking_service.dart` (órdenes viejas sin
  picking se reparten FIFO). Estado de la orden nuevo `anulada` + botón
  **Anular orden** (motivo obligatorio; quema el enlace externo).
- **Problema de fondo (13/10):** las acciones del taller guardaban el ticket
  COMPLETO (`actualizarTicket` → `update(toJson())`, 60+ campos) con la copia
  de la pantalla; si Bodega registraba un picking/evidencia mientras tanto,
  se perdía (y también eventos de auditoría, estado, etc.). Siempre existió;
  los pickings parciales lo dejaron a la vista.
  - Se probó una versión con **transacción** (`OrdenesRetiroService`); el
    usuario la **deshizo** (respaldo `2026-10-13_antes_transaccion_ordenes_retiro`,
    se puede reaplicar si se quiere seguridad total).
  - **Solución vigente (13/10, "taller secuencial + guardado parcial"):**
    1. Las 5 acciones del taller (asignar técnico, confirmar retiro interno,
       validar consumo de lote, consumo general, anular) usan
       `actualizarCampos` con `_camposTaller(...)` en `ticket_bloc.dart`:
       solo `ordenesRecepcion`, las marcas de certificación (al validar) y el
       evento con `arrayUnion`. Nunca el ticket completo.
    2. Taller secuencial (`RetiroPickingService.motivoBloqueoAsignacion`):
       solo se asigna técnico a un picking **con evidencia de Bodega**
       (`pickingsAsignables`) y el siguiente solo si todas las órdenes
       anteriores (sin anuladas) están **retiradas y con consumo validado**.
       El botón "Asignar técnico" se deshabilita con el motivo.
    3. Bodega sigue libre de hacer varios pickings en paralelo.
  - Riesgo residual mínimo: dos supervisores sobre el mismo ticket en el
    mismo segundo (las órdenes aún se escriben completas desde la pantalla).
- Consumo general certifica también todos los lotes retirados pendientes.
- Corregido: el enlace externo borraba la certificación del supervisor al
  serializar órdenes a mano (ahora usa `OrdenRecepcionRepuestosModel`).

## 5.1 Auditoría de Taller y mayúsculas (13/10)

- "INICIO DE TRABAJO EN CAMPO / TALLER" ahora se guarda como
  **"TALLER: INICIO DE TRABAJO EN CAMPO / TALLER"** (solo eventos nuevos; la
  auditoría anterior NO se modifica, decisión del usuario).
  `TiemposPorProcesoService.subprocesoPorTexto` acepta ambos textos.
- Se evaluó prefijar todas las áreas (COMPRAS/COSTOS/COMERCIAL…) y el
  usuario decidió **no** hacerlo por ahora.
- **Marca** se guarda con `MarcaEquipo.valor` (AQUASPOT, SEINMEX…) en vez
  del nombre del enum en minúsculas; **Número de serie** en MAYÚSCULAS y
  sin espacios (`_enMayusculas` en `ticket_bloc.dart`, creación y
  recepción). **Tipo de equipo NO** (enum que leen app, Functions y filtros).
  Tickets viejos no se migran: el Dashboard agrupa la marca sin distinguir
  mayúsculas (`dashboard_bloc.dart`).
- Verificado: los tiempos por proceso de tickets nuevos se calculan por
  etiqueta `proceso`/`hito` (no por texto); test `auditoria_etiquetada`
  pasa. Sin etiqueta solo queda código muerto. El tiempo de Despacho
  empieza al habilitar Bodega (no al "Iniciar picking"); separar "espera
  antes del picking" es una mejora opcional no hecha.

## 6. Comercial: registro "Cambios de materiales" (12/10)

- Campo `historialCambiosMateriales` en el ticket (solo arrayUnion, no en
  toJson), entidad `tickets/domain/entities/cambio_material_entity.dart`,
  widget `cambios_materiales_widget.dart` (en Comercial y Detalle de Ticket).
- Registra agregó/quitó/cambió cantidad de materiales de taller y repuestos
  comerciales, al guardar y al finalizar. La auditoría ya no recibe
  "COMERCIAL MODIFICÓ REQUERIMIENTO"; solo un evento al re-cotizar tras
  regreso a Comercial (ticket con proforma previa).

## 6.1 Comercial: costo de mano de obra (13/10)

- En `GenerarCotizacionPage.dart`, cabecera "Propuesta Comercial Requerida":
  chip **"Costo M.O.: $X"** = Total HH × **$25** (constante
  `_tarifaHoraHombre`), se recalcula al editar las horas. **Solo se muestra,
  no se guarda en Firestore** ni sale en la proforma/PDF (pendiente si el
  usuario lo pide).

## 7. Notificaciones (Cloud Functions, `functions/src/index.ts`) — SIN DESPLEGAR

- `notificarRepuestosDisponiblesBodega`: texto "📦 Repuestos disponibles
  para hacer picking"; solo cuenta ítems con `fechaValidadoCompras` (Bodega
  nunca la pone) y se ignora si se agregó un picking.
- Nueva `notificarPickingListoParaRetiro`: al confirmar cada picking avisa al
  supervisor del equipo "🛠️ Repuestos listos para retiro".
- Desplegar: `firebase deploy --only functions:notificarRepuestosDisponiblesBodega,functions:notificarPickingListoParaRetiro`

---

## 8. Pendientes

1. **Excel Baja ERP del menú "Excels"** (ventana de picking) trae todos los
   repuestos con saldo: el generador rellena con `cantidadFaltante` si no
   recibe ítems. Plan: elegir picking en ese menú, quitar el relleno, nombre
   de archivo con código real. Esperando confirmación del usuario.
2. Desplegar Cloud Functions y reglas de Storage; revisar rol IAM de Storage.
3. Retiro del PICK-01 del ticket de prueba quedó "pendiente" porque la
   confirmación externa falló (error de Storage): reconfirmar o anular.
   Con la regla secuencial, hasta resolverlo no se puede enviar el siguiente.
4. Proyecto Firebase de pruebas (`aquaspot-postventa-pruebas`) planteado,
   sin decidir (opción A recomendada; desactivar correos en pruebas).
5. Indicadores: decidir inconsistencias de la sección 3.
6. Comercial puede re-cotizar Contador/Cosechadora sin actualizar la lista
   de Compras (solo Caracol reconstruye); reserva de Caracol no se ajusta si
   se finaliza sin "Guardar cambios".
7. Pendientes de la sesión anterior: commits por tema, Venta de Repuesto
   fases 4–5, contraseña SMTP a Secret Manager, código muerto, inventario por
   bodega, regla "datos de garantía cruzados".

## 9. Respaldos de esta sesión (`Claude outputs/respaldos/`)

`2026-10-08_antes_revision_codigos_plan_maestro`, `…_borrador_evaluacion_tecnica`,
`…_indicadores_postventa`, `…_pasteles_indicadores`, `…_indicadores_por_equipo`,
`…_indicador3_cascada`, `…_indicador_adicional`,
`2026-10-12_estado_completo_antes_picking` (zip completo),
`2026-10-12_antes_picking_y_retiro`, `…_textos_picking_y_notificacion`,
`…_texto_notificacion_picking`, `…_retiro_por_picking_y_cambios_materiales`,
`2026-10-13_antes_transaccion_ordenes_retiro` (cambio luego deshecho por el usuario),
`2026-10-13_antes_taller_secuencial_guardado_parcial`,
`2026-10-13_antes_taller_prefijo_y_mayusculas`, `2026-10-13_antes_costo_mano_obra`,
`CLAUDE.md.antes_2026-10-13.respaldo`.
(`2026-10-08_antes_ronda_revision_fallas` no es de esta sesión.)
Restaurar una carpeta vuelve al estado previo a ESE cambio; los cambios
posteriores sobre los mismos archivos se pierden.
