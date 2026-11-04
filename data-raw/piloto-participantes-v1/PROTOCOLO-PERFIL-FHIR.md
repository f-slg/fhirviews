# Protocolo del piloto fhirviews

## Perfil FHIR — interoperabilidad o informática sanitaria

Versión del protocolo: 1.0. Fecha de preparación: 4 de noviembre de 2026.

Objetivo: evaluar la semántica FHIR y ViewDefinition, el contrato estricto y la recuperación transaccional. El alcance usa el kit completo con DBI y duckdb. Bulk Data se revisa documentalmente; no se ensaya contra un servidor propio en esta primera sesión.

## Cómo marcar la sesión

Este protocolo es para evaluación con **datos ficticios incluidos**. Se registra
lo que ocurrió; ninguna casilla está aprobada de antemano. La aprobación del kit
no completa automáticamente la evaluación humana.

- **Pendiente:** todavía no se intentó.
- **Completada sin ayuda:** la persona realizó y explicó la tarea sin intervención del observador. Leer la documentación sí está permitido.
- **Completada con ayuda:** se obtuvo el resultado, pero hubo una intervención; registrar cuál.
- **Bloqueada:** el entorno o un problema impide continuar.
- **Falló:** se ejecutó y no se obtuvo lo esperado.
- **No evaluada:** quedó fuera del alcance o no se pudo comprobar; registrar por qué. No cuenta como aprobada.

Marcar casillas solo después de observar el resultado. Registrar tiempo real,
intervenciones y evidencia por tarea. Las duraciones que acuerden al organizar
la sesión son orientativas, no umbrales de aprobación. No inventar tiempos ni
resultados. No cambiar el candidato a mitad de una sesión: usar un intento nuevo.

**Importante:** el perfil de persona **R** y el perfil de persona **FHIR** son
diferentes de los perfiles técnicos del kit **basico** y **completo**. El primero
orienta las tareas; el segundo determina qué controles automáticos se ejecutan.

## Ficha de identificación

- Sesión / intento: ____________________
- Participante (identificador o seudónimo): ____________________
- Observador / mantenedor: ____________________
- Fecha y modalidad: ____________________
- Experiencia previa en R y en FHIR: ____________________
- Sistema operativo y arquitectura: ____________________
- Versión de R y de fhirviews: ____________________
- Archivo, commit y checksum del candidato: ____________________
- Dependencias ya presentes / instaladas durante la sesión: ____________________
- Hora de inicio / fin y pausas: ____________________
- Alcance y tareas opcionales acordadas: ____________________

## Preparación y conducta del observador

- [ ] El participante acepta realizar esta prueba voluntaria y sabe qué se va a registrar.
- [ ] Se usa el mismo candidato acordado; su manifiesto se entregó con el archivo.
- [ ] Se dispone de una carpeta nueva y de R; no hay datos reales de pacientes.
- [ ] Se explicó que no se envían resultados automáticamente.
- [ ] El observador permite el primer intento y toma notas antes de dar pistas.
- [ ] Cualquier grabación, si se propone, se acuerda por separado; no es obligatoria.
- [ ] Se acordaron canal de contacto y quién revisará los resultados.

Si aparece un problema de instalación, conservar el registro y marcar la tarea
bloqueada. No indicar que fue autónoma si el mantenedor instaló o resolvió el
problema. Se puede continuar una fase asistida, registrándola como tal.

## Orden de trabajo

Completar las tareas por orden. Si una tarea depende de otra bloqueada, marcarla
pendiente o no evaluada y describir la dependencia. No usar un error esperado del
control estricto como evidencia de un fallo inesperado del paquete.

### F01 · Preparar el entorno y verificar el alcance

**Carácter:** obligatoria.

**Objetivo:** Identificar con precisión candidato, capacidades y dependencias.

1. Registrar candidato, commit, checksum, R y sistema operativo.
2. Instalar el archivo acordado, reiniciar R y localizar ayuda y viñetas.
3. Verificar DBI y duckdb para el perfil completo; si faltan, registrar el bloqueo.
4. Explicar que esta sesión usa recursos ficticios R4 y no valida un servidor propio ni perfiles clínicos.

**Comprobaciones para marcar:**

- [ ] Se identificó el candidato exacto y su instalación.
- [ ] La ayuda local está disponible.
- [ ] DBI y duckdb están disponibles o se registró la dependencia bloqueante.
- [ ] Se documentó el alcance FHIR R4, datos ficticios y motor SQL experimental.

**Resultado esperado:** Entorno preparado para completo. No presentar una evaluación básica como recuperación aprobada.

**Evidencia:** versiones, find.package(), dependencias y alcance acordado.

```r
library(fhirviews)
packageVersion("fhirviews")
find.package("fhirviews")
install.packages(c("DBI", "duckdb"))
help("vista_validar", package = "fhirviews")
help("vista_ejecutar_lotes", package = "fhirviews")
```

Estado: ______  Minutos: ______  Intervenciones: ______

Ayuda recibida / obstáculo: _________________________________________

Archivo o evidencia: ______________________________________________

Incidencias asociadas: _____________________________________________

### F02 · Ejecutar el perfil completo e interpretar los controles

**Carácter:** obligatoria.

**Objetivo:** Verificar el kit y distinguir la aprobación técnica de la evaluación humana.

1. Ejecutar completo en una carpeta nueva.
2. Revisar los cuatro controles y los códigos de advertencias o fallos si aparecen.
3. Comprobar que validacion_usuario_externo permanece pendiente.

**Comprobaciones para marcar:**

- [ ] Se generaron informes JSON y CSV.
- [ ] Los cuatro controles técnicos están aprobados sin advertencias.
- [ ] Se comprende el significado de pendiente, no_evaluado y requiere_revision.

**Resultado esperado:** API, vigilancia, contrato estricto y recuperación aprobados. Cualquier advertencia exige investigación y repetición.

**Evidencia:** aceptacion.json, aceptacion.csv y códigos revisados.

```r
Sys.setenv(FHIRVIEWS_PILOTO_SALIDA = "piloto-F01-intento01",
           FHIRVIEWS_PILOTO_PERFIL = "completo")
source(system.file("examples", "piloto.R", package = "fhirviews"))
```

Estado: ______  Minutos: ______  Intervenciones: ______

Ayuda recibida / obstáculo: _________________________________________

Archivo o evidencia: ______________________________________________

Incidencias asociadas: _____________________________________________

### F03 · Auditar el vínculo Condition–Patient y el indicador

**Carácter:** obligatoria.

**Objetivo:** Revisar la semántica de la transformación y sus claves.

1. Inspeccionar den-c0001, den-p0001 y el evento excluido den-c0002 en los recursos originales.
2. Revisar subject.reference, onsetDateTime, verificationStatus y codificación CIE-10.
3. Contrastar el enlace a paciente y el DPA de residencia con la fila tabular.
4. Explicar por qué la residencia no demuestra el lugar de infección y por qué se cuentan eventos.

**Comprobaciones para marcar:**

- [ ] Se contrastó Condition.subject con la clave del Patient.
- [ ] Se verificaron inicio 2025-02-27 y DPA 0701 para den-c0001.
- [ ] Se revisó la razón de exclusión de den-c0002 en el recurso original.
- [ ] Se contrastaron los totales 755, 661, 94 y 65 y la unidad contada.

**Resultado esperado:** La selección coincide con eventos confirmados A90/A91; fecha de inicio del evento y territorio de residencia. No inferir tasas ni pacientes únicos.

**Evidencia:** Campos FHIR revisados, vistas JSON de vigilancia y explicación semántica.

```r
entrada <- system.file("extdata", "dengue_2025.ndjson.gz", package = "fhirviews")
recursos <- fhir_recursos(entrada)
r <- Filter(function(x) x$id %in% c("den-c0001", "den-p0001", "den-c0002"), recursos)
cat(jsonlite::toJSON(r, auto_unbox = TRUE, pretty = TRUE))
```

Estado: ______  Minutos: ______  Intervenciones: ______

Ayuda recibida / obstáculo: _________________________________________

Archivo o evidencia: ______________________________________________

Incidencias asociadas: _____________________________________________

### F04 · Revisar la semántica de ViewDefinition y FHIRPath

**Carácter:** obligatoria.

**Objetivo:** Comprobar cardinalidad, tipos y contexto en una vista modificada.

1. Crear una vista Patient con clave y gender y añadir birthDate mediante la documentación.
2. Crear o adaptar una vista que recorra name con forEach y conserve given como colección.
3. Contrastar el número de filas con el JSON de un Patient; explicar first() frente a forEach.
4. Guardar las definiciones y anotar los efectos de listas vacías, ausentes y tipos explícitos.

**Comprobaciones para marcar:**

- [ ] La vista modificada conserva claves y columnas correctas.
- [ ] Se contrastó al menos una expansión de name con el recurso original.
- [ ] Se distingue columna escalar de collection:true.
- [ ] Se explica el contexto de %rowIndex y la multiplicación potencial de filas.

**Resultado esperado:** La cardinalidad observada se justifica con las colecciones del recurso. Una salida escalar multivaluada no se acepta silenciosamente.

**Evidencia:** Vistas JSON antes y después, recurso ficticio y conteo explicado.

Estado: ______  Minutos: ______  Intervenciones: ______

Ayuda recibida / obstáculo: _________________________________________

Archivo o evidencia: ______________________________________________

Incidencias asociadas: _____________________________________________

### F05 · Probar un rechazo estricto antes de entregar el bloque

**Carácter:** obligatoria.

**Objetivo:** Verificar el contrato previo al consumidor y los errores estructurados.

1. Ejecutar el ejercicio de entrada incompatible del protocolo, con un recurso por bloque.
2. Capturar el error y revisar fase, bloque, columna y número de llamadas al consumidor.
3. Explicar que el ejemplo prueba tipo de salida, no formatos ni perfiles FHIR completos.

**Comprobaciones para marcar:**

- [ ] El primer bloque compatible se entregó una vez.
- [ ] El segundo bloque fue rechazado con fase esquema y columna valor.
- [ ] El consumidor no recibió el bloque incompatible.
- [ ] No se usó completados como prueba de persistencia ni como checkpoint.

**Resultado esperado:** fhirviews_error_esquema, bloque 2, columna valor y una entrega al consumidor.

**Evidencia:** Clase y campos estructurados del error y contador de entregas.

Estado: ______  Minutos: ______  Intervenciones: ______

Ayuda recibida / obstáculo: _________________________________________

Archivo o evidencia: ______________________________________________

Incidencias asociadas: _____________________________________________

### Ejercicio reproducible de F05 — rechazo esperado

Ejecutar en una carpeta de trabajo del piloto. El código crea un archivo temporal
con dos observaciones ficticias; no escribe en ninguna base ni contacta servidores.

```r
entrada <- tempfile(fileext = ".ndjson")
writeLines(c(
  '{"resourceType":"Observation","id":"piloto-1","valueQuantity":{"value":1.5}}',
  '{"resourceType":"Observation","id":"piloto-2","valueQuantity":{"value":"incompatible"}}'
), entrada)
vista <- vista_leer(list(resource = "Observation", select = list(list(column = list(
  list(name = "id", path = "getResourceKey()", type = "id"),
  list(name = "valor", path = "value.ofType(Quantity).value", type = "decimal")
)))))
entregas <- 0L
error <- tryCatch(
  vista_ejecutar_lotes(entrada, vista, function(tabla, bloque) {
    entregas <<- entregas + 1L
  }, tamano_lote = 1, estricto = TRUE),
  error = identity
)
list(clase = class(error), bloque = error$bloque, fase = error$fase,
     columna = error$columna, entregas = entregas)
unlink(entrada)
```

Esperado: clase que incluye `fhirviews_error_esquema`, bloque 2, fase `esquema`,
columna `valor` y entregas = 1. Revisar la explicación del participante, además
de copiar los campos.

### F06 · Comprobar rollback y reintento transaccional

**Carácter:** obligatoria.

**Objetivo:** Verificar que una carga fallida conserva el resultado anterior y que repetir no duplica filas.

1. Abrir y leer el ejemplo instalado lotes-transaccion.R.
2. Localizar BEGIN/ROLLBACK/COMMIT implícitos en DBI::dbWithTransaction y la escritura del consumidor.
3. Ejecutar el ejemplo y explicar qué sucede cuando falla después de escribir.
4. Distinguir reemplazo completo en transacción de reanudar bloques con append.

**Comprobaciones para marcar:**

- [ ] El ejemplo verificó que el resultado anterior se conserva tras el fallo.
- [ ] Dos cargas completas dejaron cinco filas sin acumular copias.
- [ ] La persona distingue rollback del destino de validación de tipos.
- [ ] Se explica que el paquete de bloques no garantiza atomicidad por sí solo.

**Resultado esperado:** Mensaje de rollback verificado y cinco filas al repetir. El ejemplo usa una base temporal en memoria y datos ficticios.

**Evidencia:** Salida del ejemplo y explicación del alcance de la transacción.

```r
ruta <- system.file("examples", "lotes-transaccion.R", package = "fhirviews")
cat(readLines(ruta), sep = "\n")
source(ruta)
```

Estado: ______  Minutos: ______  Intervenciones: ______

Ayuda recibida / obstáculo: _________________________________________

Archivo o evidencia: ______________________________________________

Incidencias asociadas: _____________________________________________

### F07 · Revisar la recuperación de Bulk Data y sus límites

**Carácter:** obligatoria.

**Objetivo:** Evaluar comprensión mediante revisión técnica, sin iniciar escrituras ni exportaciones en servidores ajenos.

1. Leer la ayuda de fhir_exportar y el flujo de recuperación del README.
2. Describir el inicio asíncrono, Content-Location, Retry-After y manifiesto.
3. Explicar validación de JSON/tipo/conteo frente a checksum y qué pasa con un archivo parcial.
4. Revisar la evidencia HAPI publicada y registrar que esta sesión no contactó un servidor propio.

**Comprobaciones para marcar:**

- [ ] Se distingue validación del contenido de comprobación de checksum.
- [ ] Se comprende que un archivo parcial se reinicia desde el principio.
- [ ] Se explica la dependencia de la vigencia del trabajo y sus URL.
- [ ] La prueba de servidor propio del participante quedó no_evaluada.

**Resultado esperado:** Revisión documental completada, no prueba operativa de Bulk Data. Cualquier ensayo en infraestructura propia requiere un plan posterior acordado.

**Evidencia:** Notas de revisión y enlace a la evidencia HAPI; alcance operativo no evaluado.

```r
help("fhir_exportar", package = "fhirviews")
```

Estado: ______  Minutos: ______  Intervenciones: ______

Ayuda recibida / obstáculo: _________________________________________

Archivo o evidencia: ______________________________________________

Incidencias asociadas: _____________________________________________

### F08 · Repetir y evaluar portabilidad declarada

**Carácter:** obligatoria.

**Objetivo:** Verificar repetibilidad y documentar qué se puede trasladar a otra implementación.

1. Repetir el perfil completo en una carpeta nueva.
2. Comparar los hallazgos y conservar versiones de las vistas y del paquete.
3. Explicar qué aporta ViewDefinition como artefacto estándar y qué exige contrastar otro motor.
4. Dejar explícitamente no_evaluada la interoperabilidad con otro motor si no se ejecutó.

**Comprobaciones para marcar:**

- [ ] La repetición conserva resultados y el primer informe.
- [ ] Se guardaron las vistas y las versiones.
- [ ] Se distingue conformidad del banco incluido de una garantía universal.
- [ ] No se afirmó una comparación con Pathling u otra herramienta sin ejecutarla.

**Resultado esperado:** Mismos hallazgos del piloto; no se evalúan tiempos iguales ni se presume equivalencia universal de motores.

**Evidencia:** Informes de dos intentos, vistas versionadas y límites documentados.

```r
Sys.setenv(FHIRVIEWS_PILOTO_SALIDA = "piloto-F01-intento02")
source(system.file("examples", "piloto.R", package = "fhirviews"))
a <- jsonlite::read_json("piloto-F01-intento01/aceptacion.json")
b <- jsonlite::read_json("piloto-F01-intento02/aceptacion.json")
identical(a$hallazgos, b$hallazgos)
```

Estado: ______  Minutos: ______  Intervenciones: ______

Ayuda recibida / obstáculo: _________________________________________

Archivo o evidencia: ______________________________________________

Incidencias asociadas: _____________________________________________

### F09 · Notificar hallazgos y acordar el cierre técnico de la sesión

**Carácter:** obligatoria.

**Objetivo:** Entregar una evaluación técnica reproducible y acciones de mejora.

1. Clasificar incidencias por impacto y reproducibilidad.
2. Adjuntar solo evidencia ficticia y revisar que no haya tokens ni datos ajenos al piloto.
3. Preparar el aviso al mantenedor y registrar manualmente canal y referencia si se envía.
4. Acordar incidencias que requieren corrección y repetición antes de aceptar el alcance.

**Comprobaciones para marcar:**

- [ ] Las incidencias tienen pasos, esperado, observado e impacto.
- [ ] Se identificaron pruebas no evaluadas.
- [ ] Se revisaron los archivos que se van a compartir.
- [ ] Se registró una decisión humana explícita o pendiente y los responsables del seguimiento.

**Resultado esperado:** Informe técnico revisable con tareas, evidencias y decisión separada de los resultados automáticos.

**Evidencia:** Formulario exportado, experiencia-usuario.txt y registro de notificaciones.

Estado: ______  Minutos: ______  Intervenciones: ______

Ayuda recibida / obstáculo: _________________________________________

Archivo o evidencia: ______________________________________________

Incidencias asociadas: _____________________________________________

## Registro de incidencias — copiar una ficha por problema

- ID: INC-______   Tarea: ______   Participante: ______   Intento: ______
- Fecha de detección: ______   Responsable de revisar: ______
- Tipo: [ ] instalación [ ] funcional [ ] documentación [ ] usabilidad [ ] entorno
- Impacto: [ ] crítico [ ] alto [ ] medio [ ] bajo
- Estado: [ ] abierta [ ] en revisión [ ] corregida [ ] pendiente de repetir [ ] cerrada
- Reproducibilidad: [ ] sí [ ] no [ ] pendiente de comprobar
- Resumen del problema: ______________________________________________
- Pasos mínimos para reproducir, con datos ficticios: __________________
- Resultado esperado: ________________________________________________
- Resultado observado: _______________________________________________
- Entorno y versión implicados: ______________________________________
- Evidencia / archivo revisado antes de compartir: ____________________
- Solución provisional, si existe: ___________________________________
- Cambio acordado / responsable / fecha objetivo: _____________________
- Repetición realizada / resultado / quién verificó: __________________

**Impacto:** crítico = resultado incorrecto aceptado o pérdida de integridad;
alto = bloquea una tarea esencial sin alternativa viable; medio = permite
continuar con ayuda o alternativa; bajo = mejora de claridad o presentación.
Es una clasificación del piloto, no un diagnóstico automático del sistema.

Ante un problema crítico, detener la aprobación de esa sesión, conservar la
evidencia y avisar al mantenedor por el canal acordado. No hace falta detener
la exploración de tareas independientes si se deja claro que la sesión no está
aceptada. No compartir archivos de pacientes ni credenciales.

## Notificación manual al mantenedor

El formulario HTML prepara un aviso descargable; **no lo envía**. El participante
o el observador revisa el contenido y lo comparte por correo, un issue o el canal
acordado. No existe un plazo de respuesta automático: acordar una fecha objetivo.

```text
Asunto: [fhirviews piloto] <sesión> / <perfil de persona> / <tipo de aviso>

Participante (ID):
Fecha y candidato (versión / commit / checksum):
Alcance: básico o completo; datos ficticios incluidos.
Tareas completadas sin ayuda / con ayuda / bloqueadas / fallidas / no evaluadas:
Resultado técnico del kit:
Incidencias y su impacto:
Pasos de reproducción y resultado esperado/observado:
Evidencia revisada que adjunto:
Ayuda que necesité:
Acción solicitada al mantenedor:
Responsable y fecha de seguimiento acordados:
Evaluación humana de esta sesión: pendiente / repetir / aceptada para el alcance.
```

### Control de la comunicación

- [ ] Aviso preparado.
- [ ] Contenido y adjuntos revisados.
- [ ] Enviado manualmente por el canal acordado.
- [ ] Se recibió acuse de recibo.
- [ ] Se acordó responsable y siguiente acción.
- [ ] Se repitió la tarea si hacía falta.
- [ ] Se revisó y cerró la incidencia, o se dejó explícitamente pendiente.

Canal: ______  Fecha de envío: ______  Referencia del correo/issue: ______
Acuse: ______  Responsable: ______  Próxima revisión: ______

## Cierre de la sesión

| Comprobación | Marcar |
|---|---|
| Se identificó el candidato y el entorno | [ ] |
| Cada tarea tiene estado, tiempo, ayuda y evidencia, o justificación de no evaluación | [ ] |
| Se revisaron los resultados y la interpretación de las tablas | [ ] |
| Se guardaron las vistas modificadas y los informes de los intentos | [ ] |
| Las incidencias tienen responsable y seguimiento | [ ] |
| Se completó experiencia-usuario.txt | [ ] |
| El participante y el mantenedor revisaron la decisión | [ ] |

**Decisión humana (una):** [ ] pendiente [ ] repetir tras correcciones
[ ] aceptada para el alcance acordado [ ] aceptada con pendientes explícitos.

Una tarea obligatoria pendiente, bloqueada, fallida o no evaluada impide aceptar
el alcance completo de esta sesión. Una incidencia crítica o alta sin resolver
o un resultado técnico no aprobado exige revisión y repetición antes de aceptar.
Una tarea con ayuda no demuestra autonomía; para afirmarla hace falta una
repetición sin intervención. Las mejoras medias o bajas pueden quedar acordadas
con responsable y fecha. Una sesión aceptada no certifica uso clínico ni producción.

- Conclusión del participante: _______________________________________
- Conclusión del mantenedor: ________________________________________
- Cambios prioritarios (máximo tres): ________________________________
- Responsables y fechas acordadas: __________________________________
- Firma o identificación de ambos y fecha: ___________________________
