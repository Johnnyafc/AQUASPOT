# Contexto de la sesión con Claude Code (05 al 07 de octubre de 2026)

Proyecto: **Aquaspot Postventa** (Flutter/Firebase), rama `aquaspot_optimizado`.
Último commit: `0f1c1f0` (trazabilidad gráfica). **Nada de esta sesión está commiteado.**

Este documento resume TODO lo hecho, decidido y pendiente en la sesión, para
que no se pierda y otra sesión pueda continuar.

---

## 0. Forma de trabajo acordada con el usuario

- **Plantear antes de hacer.** El usuario revisa el plan y responde con
  "actúa", "procede", "implementa" o con correcciones. Si dice "no hagas
  nada" / "plantea", solo se plantea.
- **"Solo eso" significa solo eso**: no agregar cambios extra no pedidos.
- **Respaldo antes de cada cambio**: copia de cada archivo a tocar en
  `Claude outputs/respaldos/<fecha>_antes_<tema>/…/<archivo>.respaldo` más un
  `RESTAURAR.ps1`. La extensión `.respaldo` evita que Dart los compile.
- **Nunca commitear** sin autorización explícita en ese turno (regla de
  `CLAUDE.md`). Al hacer `git add`, listar archivos exactos (ruido CRLF).
- Verificar siempre con `flutter analyze` (0 errores; hay ~149 avisos
  previos) y `flutter test` (56 tests pasando al cierre).
- En esta máquina **sí hay Flutter** (`C:\src\flutter`) y Node para
  `functions/` (`npm run build`).
- Las ediciones se hicieron con scripts Python que respetan CRLF/LF de cada
  archivo (algunos archivos son CRLF, otros LF).
- Cuenta administradora maestra: **adminmaster@aquaspot.ec**
  (`correoAdministradorMaestro` en `lib/core/utils/constants.dart`).

---

## 1. Venta de Repuesto (fases 1 a 3 hechas; 4 y 5 pendientes; módulo en desarrollo)

Formulario `VentaRepuestoFormWidget` (hermano de `TicketForm`).

- **Asistencia técnica**: si se activa, se oculta "Datos del Repuesto" y se
  borran las líneas ya agregadas; la sección de asistencia va antes.
- **Fase 1 (creación)**: botón "REGISTRAR REQUERIMIENTO"; campo obligatorio
  "Este repuesto es de:" (Contador/Caracol/Cosechadora → se guarda en
  `equipo` = segmento). `CrearVentaRepuestoEvent` usa el mismo contador
  `metadata/contadores` (REQ-000NN), sin acta PDF. Sube fotos/videos y
  audios (`audios_asistencia`). Ruteo:
  - con asistencia → `recepcionFisica` (Evaluación técnica);
  - sin asistencia y todas las líneas con stock neto suficiente → `comercial`;
  - al menos una línea sin stock → `cotizandoRepuesto` (estado NUEVO).
  - Stock neto = disponible − reservado; se guarda en cada línea
    (`stockDisponibleAlEvaluar`).
  - Campos nuevos en el ticket: `medioContacto`, `lineasRepuestoVenta`,
    `necesitaAsistenciaTecnica`, `urlsAudiosAsistencia`, `urlsCotizacionCompras`.
- **Fase 2 (Cloud Functions, `functions/src/index.ts`)**: venta en
  `recepcionFisica` → push "Evaluación de Venta de Repuesto" al supervisor
  del segmento y NO se envía correo al cliente; `cotizandoRepuesto` → push a
  Compras. (Desplegar con `firebase deploy --only functions`.)
- **Fase 3 (Compras)**: bandeja de Compras muestra `cotizandoRepuesto`;
  pantalla `CotizacionVentaRepuestoPage` (líneas en rojo las sin stock,
  adjuntar cotización) → `AdjuntarCotizacionVentaRepuestoEvent` → `comercial`.
  Auditoría: `COMPRAS: GESTIÓN DE REPUESTO SIN STOCK COMPLETADA (VENTA DE REPUESTO)`.
- **Pendiente**: Fase 4 (Proforma reducida en `GenerarCotizacionPage`: solo
  repuestos + cotización de Compras), Fase 5 (pantalla propia de Evaluación
  de venta con audios + agregar repuestos + re-ruteo por stock), excluir
  ventas de la Bandeja de Recepción, definir su paso por Bodega, y separar su
  tiempo de cotización en una barra propia del dashboard.

## 2. Bodega

- **Validación simple en Despacho**: tickets en estado `bodega` sin ítems de
  despacho, o con despacho 100% + fotos pero sin traspaso, aparecen en
  "Despachar Repuestos" con insignia "VALIDACIÓN SIMPLE";
  `ValidacionSimpleDespachoPage` + `ValidarDespachoSimpleBodegaEvent` (relee
  el ticket en transacción antes de escribir) → `procesoTrabajo`.
  Auditoría: `BODEGA: DESPACHO TOTAL Y TRANSFERENCIA A PROCESO DE TRABAJO (VALIDACIÓN SIMPLE)`.
  No descuenta stock ni libera reservas.
- **Notificaciones a Bodega** (Cloud Functions): por cada validación nueva
  de Compras ("Repuestos disponibles para despacho", función
  `notificarRepuestosDisponiblesBodega`) y "Requerimiento en Bodega" para
  los que llegan a `bodega` sin ítems.
- **Pendiente**: reserva liberada de más en Caracoles antiguos (sin reserva)
  al subir evidencias de despacho; revisar filtro de segmento si algún
  ticket no aparece.

## 3. Trazabilidad por proceso (auditoría etiquetada)

- `lib/core/enum/proceso_auditoria.dart`: `ProcesoAuditoria`, `HitoProceso`,
  `procesoDeEstado()`. Cada evento nuevo guarda `proceso`, `hito`
  (inicio/avance/fin) y `habilita` (procesos a los que deja trabajo). Campos
  opcionales: los eventos antiguos no los tienen y NO se migró Firestore.
- Etiquetadas ~31 acciones activas (ticket_bloc, enlace temporal, Guabo,
  modificación de Comercial). Test `auditoria_etiquetada_test.dart` falla si
  una acción activa nueva no lleva `proceso:`.
- Se corrigió `acceso_temporal_bodega_service.dart`, que reescribía el
  historial con solo 4 campos (borraba etiquetas).
- `TiemposPorProcesoService` (`domain/services/tiempos_por_proceso_service.dart`):
  - Tickets nuevos (con etiquetas): **carriles en paralelo** (cada proceso
    desde que se le habilita hasta su FIN). Costos abre Despacho de forma
    provisional (si Bodega despacha stock antes que Compras valide).
    Cambio forzado ADMIN reinicia los relojes y habilita la etapa destino.
  - Tickets antiguos: secuencial por texto (`procesoPorTexto`) con
    correcciones (GUABO→Recepción, Informe técnico/TALLER:→Proceso de
    Trabajo, ADMIN fuera, ORDEN DE COMPRA VALIDADA EN BODEGA→Validación
    Bodega, cotización/aprobación ya no invertidas, revisión comercial
    final→Revisión de pagos, factura/guía→Entrega).
  - **Se promedia por ticket** (no por tramo). Tramos de **0 minutos sí
    cuentan**. Modificación de proforma: ciclos sumados (opción A).
  - Desplegables en el dashboard: **Recepción** (Registro y acta / En camino
    Guabo) y **Proceso de Trabajo** (Antes de iniciar / Espera de material /
    Trabajo). Las partes muestran su promedio real entre los tickets que las
    tuvieron (no suman el total). Compras **no** se despliega.
- Código muerto detectado (no se borró): pantallas `EstacionBodegaPage`,
  `SupervisorExcepcionComprasPage`; eventos `ProcesarBodegaEvent`,
  `DeclararNoRequiereComprasEvent`, `CompletarFaseComprasEvent`,
  `ConsumirRepuestosBodegaEvent`, `CompletarProcesoTrabajoEvent`,
  `AsignarTecnicosTrabajoEvent`, `SubirEvidenciaEvent`,
  `NotificarYGenerarActaEvent`, `ObtenerTicketsEvent`.

## 4. Opciones de administrador (solo adminmaster@aquaspot.ec)

- Menú principal → **"Modificar Ticket"** (`ModificarTicketPage`): buscar
  ticket, nuevo estado + motivo obligatorio + reiniciar Costos/Compras.
  Usa `ForzarCambioEstadoAdminEvent` → auditoría
  `ADMIN: CAMBIO FORZADO A "…" -- Motivo: …` (fuera de los promedios).
  ⚠️ Las Cloud Functions reaccionan al cambio de estado (correos al cliente
  si se mueve a `recepcionFisica` con acta o a `finalizado`).
- Menú principal → **"Inconsistencias de Trazabilidad"**
  (`InconsistenciasTrazabilidadPage`, reglas en
  `InconsistenciasTrazabilidadService`): orden de flujo no habitual, falta
  paso esperado, pasos de distintas etapas en el mismo minuto, creado cuando
  el equipo ya llegó (Guabo), fecha fuera de rango, tiempo atípico (>3× la
  mediana y ≥8 h). Excluye ventas y anulados. Botón "Revisado" guarda la
  clave en `ticket.inconsistenciasRevisadas` (solo arrayUnion; el `toJson`
  del ticket NO escribe ese campo a propósito).
- Las devoluciones hechas directamente en Firebase siguen saliendo como
  "orden de flujo no habitual" (usar "Modificar Ticket" para que quede
  auditado).

## 5. Dashboard (`dashboard_tickets_page.dart` + `dashboard_bloc.dart`)

- Filtros: Marca, Equipo, **Requerimiento** (nuevo), Sede, **Garantía**
  (solo Máquina nueva / Servicio), **Estado** (los 15 estados), fechas.
- KPIs: Tickets, **Finalizados**, En proceso, Anulados, **Reclamos de
  garantía**, **Garantías aprobadas** (con descripción al pasar el mouse),
  **Días promedio** (solo finalizados, creación → finalización).
- Tiempo total del ticket = creación → último registro (ya no usa
  `leadTimeTotalHoras`, que se cortaba al terminar el taller).
- Nombres unificados: "Finalizado(s)" y "Revisión de pagos" (son dos
  estados distintos).
- "Tickets creados" por **día** cuando hay filtro de fechas (≤ 92 días).
- Donas interactivas (hover con detalle) en marca, requerimiento (solo
  reclamos + reparaciones), lugar, categorías de falla, razones, dictamen.
- **Diagnóstico de fallas**: categorías (clic = filtra), razones (causa raíz,
  marcas), fallas más frecuentes por equipo (paneles; top 5 / top 10).
- **Garantías**: nota + dona "Dictamen de garantía": Aprobada
  (`esGarantia`), Rechazada (etiqueta de auditoría
  `GARANTÍA RECHAZADA - PASA A FACTURACIÓN CLIENTE`), Sin dictamen.
- **Reclamo de garantía** = `tipoRequerimiento == reclamoGarantia` **o**
  dictamen de garantía en la auditoría (`TicketEntity.esReclamoDeGarantia`),
  porque hay tickets cambiados a mano a "reparación" que no se pueden
  corregir en Firestore.
- Notas "Incluye anulados" / "No incluye anulados" en cada tarjeta.
- Eliminado código sin uso (tiempos netos vs espera, ranking de repuestos,
  gráfico agrupado, segmento operativo, departamentos).
- Tabla: columnas "Tipo de garantía" y "Foto horómetro" (antes ambas
  "Garantía"); Estado muestra el estado real.
- Historial (`historial_tickets_page.dart`): recuadros del Resumen General
  filtrables (Reclamos de garantía, Garantías aprobadas, Caracol,
  Cosechadora, Contador) con descripción al pasar el mouse.

---

## 6. Pendientes generales

1. Probar todo en la app real y, cuando el usuario autorice, commits
   separados por tema (sin `git add -A`).
2. Desplegar Cloud Functions (`firebase deploy --only functions`).
3. Venta de Repuesto fases 4 y 5 (ver sección 1).
4. Regla de inconsistencia "datos de garantía cruzados" (propuesta, no
   aprobada aún).
5. Limpieza del código muerto (sección 3) como tarea aparte.
6. Inventario por bodega (el código del repuesto es la llave única).
7. Contraseña SMTP de Zoho escrita en `functions/src/index.ts` → mover a
   Secret Manager y rotarla.
8. Hora de los eventos la pone el dispositivo (`DateTime.now()`); opción
   futura: hora del servidor.
9. Evaluar evitar correos al cliente en cambios forzados por admin.

## 7. Respaldos (para volver atrás)

Carpeta `Claude outputs/respaldos/`. Cada subcarpeta tiene `RESTAURAR.ps1`:

```
powershell -ExecutionPolicy Bypass -File "Claude outputs/respaldos/<carpeta>/RESTAURAR.ps1"
```

En orden cronológico: validacion_simple_bodega, trazabilidad_por_proceso,
dashboard_diagnostico_fallas, dashboard_fallas_interactivo,
dashboard_fallas_por_equipo, filtro_tipo_requerimiento,
pasteles_interactivos, tendencia_por_dia, desglose_procesos,
partes_promedio_real, etiquetas_barras, inconsistencias, modificar_ticket,
inconsistencias_en_menu, resumen_general_filtro, garantias_diferenciadas,
quitar_desplegable_compras, limpieza_dashboard, dictamen_facturacion,
reclamo_por_auditoria. (Restaurar una carpeta vuelve al estado previo a ESE
cambio; los cambios posteriores sobre los mismos archivos se pierden.)
