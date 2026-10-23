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

## Estado del repositorio (actualizado 2026-10-13)

Commit más reciente: `0f1c1f0`. **Todo lo trabajado del 05 al 13/10/2026
está SIN commitear** (pendiente de prueba y autorización del usuario).
Verificación al cierre: `flutter analyze` 0 errores (151 avisos previos),
`flutter test` 111 tests pasando, `functions/` compila (`npm run build`).

**Leer antes de continuar, en este orden:**
1. `Claude outputs/CONTEXTO_SESION_2026-10-05_al_07.md` — Venta de Repuesto
   (fases 1–3), Validación simple de Bodega, trazabilidad por proceso,
   opciones de admin, Dashboard.
2. `Claude outputs/CONTEXTO_SESION_2026-10-08_al_13.md` — lo más reciente:
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

Pendiente inmediato: Excel "Baja ERP" del menú "Excels" de la ventana de
picking trae todos los repuestos (plan hecho, falta confirmación); reglas de
Storage para el enlace externo (`Claude outputs/storage_rules_con_retiro_externo.txt`)
y rol IAM "Firebase Rules Firestore Service Agent".

Pendientes generales: commits por tema, desplegar functions, Venta fases 4–5,
regla "datos de garantía cruzados", limpieza de código muerto, inventario
por bodega, contraseña SMTP en `functions/src/index.ts` (mover a Secret
Manager), proyecto Firebase de pruebas (planteado, sin decidir).
