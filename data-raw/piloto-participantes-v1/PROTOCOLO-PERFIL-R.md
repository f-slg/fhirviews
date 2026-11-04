# Protocolo del piloto fhirviews

## Perfil R — analista, investigador o epidemiólogo

Versión del protocolo: 1.0. Fecha de preparación: 4 de noviembre de 2026.

Objetivo: evaluar instalación, documentación, interpretación y modificación de una vista desde R. El alcance inicial usa el kit basico; la recuperación con DuckDB es opcional y se registra por separado.

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

### R01 · Preparar la sesión e instalar el candidato

**Carácter:** obligatoria.

**Objetivo:** Comprobar que la persona puede instalar la copia acordada y encontrar su ayuda.

1. Registrar identificador de participante y sesión, sistema operativo, versión de R, candidato y dependencias que ya estaban instaladas.
2. Instalar las dependencias y el archivo local entregado por el mantenedor; reiniciar R.
3. Abrir la ayuda del paquete y localizar vista_ejecutar_lotes().

**Comprobaciones para marcar:**

- [ ] Se anotaron versión, commit y checksum del candidato.
- [ ] El paquete se carga desde la instalación acordada.
- [ ] La ayuda local abre y se registró la ayuda necesaria.

**Resultado esperado:** fhirviews 0.5.0 cargado. La ayuda y las viñetas locales están disponibles.

**Evidencia:** Salida de packageVersion(), find.package(), versión de R y ayuda consultada.

```r
install.packages(c("cli", "httr2", "jsonlite", "rlang", "V8"))
install.packages("fhirviews_0.5.0.tar.gz", repos = NULL, type = "source")
# Reiniciar R antes de continuar
library(fhirviews)
packageVersion("fhirviews")
find.package("fhirviews")
help(package = "fhirviews")
help("vista_ejecutar_lotes", package = "fhirviews")
browseVignettes("fhirviews")
```

Estado: ______  Minutos: ______  Intervenciones: ______

Ayuda recibida / obstáculo: _________________________________________

Archivo o evidencia: ______________________________________________

Incidencias asociadas: _____________________________________________

### R02 · Ejecutar el piloto básico y leer el informe

**Carácter:** obligatoria.

**Objetivo:** Ejecutar el flujo guiado y distinguir resultados técnicos, omisiones y evaluación humana.

1. Elegir una carpeta nueva por participante e intento.
2. Ejecutar el perfil basico y abrir aceptacion.csv y aceptacion.json en esa carpeta.
3. Identificar el estado de cada control y explicar por qué recuperacion figura como no_evaluado.

**Comprobaciones para marcar:**

- [ ] La carpeta era nueva y el comando terminó.
- [ ] Se encontraron los informes y los tres controles básicos están aprobados.
- [ ] Recuperación no evaluada no se interpretó como aprobada.
- [ ] Se identificó que validacion_usuario_externo sigue pendiente.

**Resultado esperado:** resultado_tecnico = aprobado; recuperación = no_evaluado. Cualquier fallo o advertencia se registra y se investiga.

**Evidencia:** Ruta relativa de aceptacion.csv y aceptacion.json, estado y código si hay incidencias.

```r
Sys.setenv(FHIRVIEWS_PILOTO_SALIDA = "piloto-R01-intento01",
           FHIRVIEWS_PILOTO_PERFIL = "basico")
source(system.file("examples", "piloto.R", package = "fhirviews"))
read.csv("piloto-R01-intento01/aceptacion.csv")
```

Estado: ______  Minutos: ______  Intervenciones: ______

Ayuda recibida / obstáculo: _________________________________________

Archivo o evidencia: ______________________________________________

Incidencias asociadas: _____________________________________________

### R03 · Reconciliar la vigilancia y explicar el indicador

**Carácter:** obligatoria.

**Objetivo:** Interpretar correctamente las salidas, no limitarse a ejecutar el script.

1. Leer controles.csv, casos_confirmados.csv, resumen_canton.csv y resumen_mensual.csv dentro de vigilancia/.
2. Explicar el paso de 755 eventos a 661 confirmados y 94 excluidos.
3. Comparar la suma de ambos resúmenes con el número de eventos confirmados.
4. Explicar si el resultado cuenta eventos, pacientes únicos o tasas; indicar qué faltaría para una tasa.

**Comprobaciones para marcar:**

- [ ] Se identificaron 755 eventos, 661 confirmados y 94 excluidos.
- [ ] Se identificaron 65 cantones con eventos.
- [ ] Ambos resúmenes suman 661.
- [ ] Se conservaron los ceros iniciales del código DPA.
- [ ] La persona explica que son eventos ficticios y que no hay denominador poblacional para una tasa.

**Resultado esperado:** 661 + 94 = 755. Los resúmenes suman 661; el conjunto tiene 65 cantones. La unidad es el evento Condition.

**Evidencia:** Cálculos de reconciliación y explicación del participante, anotada antes de recibir pistas.

```r
base <- "piloto-R01-intento01/vigilancia"
casos <- read.csv(file.path(base, "casos_confirmados.csv"), colClasses = "character")
cantones <- read.csv(file.path(base, "resumen_canton.csv"), colClasses = "character")
meses <- read.csv(file.path(base, "resumen_mensual.csv"), colClasses = "character")
read.csv(file.path(base, "controles.csv"))
c(eventos = nrow(casos), cantones = nrow(cantones),
  suma_cantones = sum(as.integer(cantones$casos)),
  suma_meses = sum(as.integer(meses$casos)))
```

Estado: ______  Minutos: ______  Intervenciones: ______

Ayuda recibida / obstáculo: _________________________________________

Archivo o evidencia: ______________________________________________

Incidencias asociadas: _____________________________________________

### R04 · Contrastar un evento con el recurso original

**Carácter:** obligatoria.

**Objetivo:** Trazar una fila hasta su evento y paciente originales.

1. Localizar den-c0001 entre los eventos confirmados y revisar paciente, inicio y codigo_dpa.
2. Abrir los recursos originales den-c0001 y den-p0001 incluidos en el NDJSON.
3. Explicar de qué recurso viene la fecha y de cuál viene la residencia.

**Comprobaciones para marcar:**

- [ ] den-c0001 enlaza con den-p0001.
- [ ] La fecha de inicio es 2025-02-27.
- [ ] La residencia del paciente tiene DPA 0701.
- [ ] Se contrastó el JSON y se distingue el recurso del evento del recurso del paciente.

**Resultado esperado:** La relación coincide con Condition.subject.reference = Patient/den-p0001; la residencia se toma del Patient.

**Evidencia:** Fila seleccionada y campos del JSON contrastados, usando exclusivamente los datos ficticios.

```r
casos[casos$id == "den-c0001", c("id", "paciente", "inicio", "codigo_dpa")]
entrada <- system.file("extdata", "dengue_2025.ndjson.gz", package = "fhirviews")
recursos <- fhir_recursos(entrada)
originales <- Filter(function(x) x$id %in% c("den-c0001", "den-p0001"), recursos)
cat(jsonlite::toJSON(originales, auto_unbox = TRUE, pretty = TRUE))
```

Estado: ______  Minutos: ______  Intervenciones: ______

Ayuda recibida / obstáculo: _________________________________________

Archivo o evidencia: ______________________________________________

Incidencias asociadas: _____________________________________________

### R05 · Crear y modificar una vista de pacientes

**Carácter:** obligatoria.

**Objetivo:** Medir si la documentación permite construir una extracción propia sencilla.

1. Con la documentación, crear una vista Patient que devuelva la clave y gender.
2. Guardar su definición JSON y ejecutarla sobre caso_clinico.ndjson.
3. Modificarla para añadir birthDate y guardar una segunda definición.
4. Comparar una fila con el Patient original y explicar el tipo de fecha devuelto.

**Comprobaciones para marcar:**

- [ ] Se creó y guardó la primera vista.
- [ ] Se añadió birthDate sin perder la clave.
- [ ] Se guardó la vista modificada y se contrastó una fila con el JSON.
- [ ] Se registraron las consultas a la documentación y las intervenciones del observador.

**Resultado esperado:** La clave se conserva, gender coincide y birthDate se representa como texto. El observador registra la ayuda en lugar de entregar la solución inicialmente.

**Evidencia:** vista-pacientes-v1.json, vista-pacientes-v2.json y fila contrastada.

Estado: ______  Minutos: ______  Intervenciones: ______

Ayuda recibida / obstáculo: _________________________________________

Archivo o evidencia: ______________________________________________

Incidencias asociadas: _____________________________________________

### R06 · Repetir el análisis y reconocer un bloque rechazado

**Carácter:** obligatoria.

**Objetivo:** Comprobar reproducibilidad e interpretación de un fallo controlado.

1. Repetir el perfil básico en una carpeta nueva de intento02.
2. Comparar los hallazgos del informe, no los tiempos ni rutas de ambos intentos.
3. Localizar contrato_estricto en el informe y explicar qué pasó con el bloque 2.

**Comprobaciones para marcar:**

- [ ] La repetición usa otra carpeta y conserva el primer informe.
- [ ] Los hallazgos de ambos intentos coinciden.
- [ ] Se identifica el bloque 2 rechazado y una sola entrega al consumidor.
- [ ] Se entiende que un bloque rechazado esperado puede hacer aprobar el control de contrato.

**Resultado esperado:** Mismos controles y referencias. El bloque incompatible no se entrega; el primer bloque sí. Esto no prueba persistencia de escrituras.

**Evidencia:** Informes de los dos intentos y explicación de bloque_rechazado / bloques_entregados.

```r
Sys.setenv(FHIRVIEWS_PILOTO_SALIDA = "piloto-R01-intento02")
source(system.file("examples", "piloto.R", package = "fhirviews"))
a <- jsonlite::read_json("piloto-R01-intento01/aceptacion.json")
b <- jsonlite::read_json("piloto-R01-intento02/aceptacion.json")
identical(a$hallazgos, b$hallazgos)
```

Estado: ______  Minutos: ______  Intervenciones: ______

Ayuda recibida / obstáculo: _________________________________________

Archivo o evidencia: ______________________________________________

Incidencias asociadas: _____________________________________________

### R07 · Evaluar recuperación con DuckDB, si se acordó

**Carácter:** opcional, según alcance acordado.

**Objetivo:** Ampliar la sesión al perfil completo sin confundir el alcance básico.

1. Solo si se acordó y se dispone de DBI y duckdb compatibles, ejecutar completo en una carpeta nueva.
2. Leer el resultado de recuperacion y explicar qué significa rollback.
3. Si no se ejecuta, marcar no_evaluado y anotar la razón.

**Comprobaciones para marcar:**

- [ ] Se registró si el entorno y el alcance permiten el perfil completo.
- [ ] Si se ejecutó, se revisó la recuperación; si no, se dejó constancia de su exclusión.

**Resultado esperado:** Alcance básico: recuperación no evaluada. Alcance ampliado: los cuatro controles deben aprobar.

**Evidencia:** Informe del perfil completo o justificación de no evaluación.

```r
# Opcional: instalar solo si se acordó esta ampliación
install.packages(c("DBI", "duckdb"))
Sys.setenv(FHIRVIEWS_PILOTO_SALIDA = "piloto-R01-completo01",
           FHIRVIEWS_PILOTO_PERFIL = "completo")
source(system.file("examples", "piloto.R", package = "fhirviews"))
```

Estado: ______  Minutos: ______  Intervenciones: ______

Ayuda recibida / obstáculo: _________________________________________

Archivo o evidencia: ______________________________________________

Incidencias asociadas: _____________________________________________

### R08 · Registrar la experiencia y preparar la notificación

**Carácter:** obligatoria.

**Objetivo:** Entregar evidencia revisable y propuestas de mejora.

1. Completar experiencia-usuario.txt y la ficha de tareas.
2. Registrar cada incidencia con pasos de reproducción y evidencia ficticia.
3. Preparar el aviso al mantenedor; revisar archivos y enviar solo por el canal acordado.
4. Registrar la referencia del envío y acordar qué debe repetirse.

**Comprobaciones para marcar:**

- [ ] La ficha contiene tiempos, ayuda y evidencia.
- [ ] Se registraron incidencias o se indicó que no se observaron.
- [ ] Se preparó el resumen para el mantenedor y se anotó el canal.
- [ ] La evaluación humana conserva una decisión explícita o queda pendiente; no se deduce de CI.

**Resultado esperado:** Informe de sesión completo. El envío es manual y el mantenedor revisa el cierre.

**Evidencia:** Ficha exportada, experiencia-usuario.txt, incidencias y referencia del aviso.

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
