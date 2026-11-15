# Perfil FHIR: semantica e interoperabilidad R4

Candidato 0.5.0.9002; datos ficticios. Abre el formulario y registra lo observado.
El perfil de persona y el perfil tecnico basico/completo son decisiones distintas.
Acuerda el alcance antes de empezar; consulta LEEME.md para preparar R.

## F01. Identificar e instalar el candidato

Instalar la copia comprobada y abrir su ayuda sin usar otra instalacion.

1. Acordar perfil basico o completo, identificador, sistema y registro de la sesion.
2. Contrastar CANDIDATO.json y el archivo incluido. Anotar dependencias y ayuda recibida.
3. Ejecutar el lanzador desde la carpeta del kit; el ejemplo usa el perfil sugerido y se adapta al acordado.
4. Abrir la sesion aislada para las tareas manuales; si habia otra copia cargada, reiniciar R.

**Contraste:** fhirviews 0.5.0.9002; el instalador verifica SHA-256 antes de instalar. Esto no completa la evaluacion humana.

**Evidencia:** SESION.json, candidato.txt, ruta de la biblioteca y ayuda consultada.

```r
source("INICIAR.R")
iniciar_piloto("completo", "sesion-P02-intento01")
abrir_sesion("sesion-P02-intento01")
packageVersion("fhirviews")
find.package("fhirviews")
help("fhir_mapa", package = "fhirviews")
browseVignettes("fhirviews")
```

## F02. Leer los cinco controles y su alcance

Interpretar el resultado tecnico, las omisiones y la evaluacion humana pendiente.

1. Abrir piloto/aceptacion.json y aceptacion.csv dentro de la sesion.
2. Contrastar version 0.5.0.9002, MD5 y esquema_informe = 2.
3. Explicar api_instalada, vigilancia, contrato_estricto, recuperacion y r4_cinco_recursos.
4. Registrar advertencias o fallos sin convertirlos en aprobaciones.

**Contraste:** Basico: cuatro aprobados y recuperacion no_evaluado. Completo: cinco aprobados. Una advertencia requiere revision.

**Evidencia:** Informe tecnico y explicacion del participante.

```r
informe <- jsonlite::read_json("sesion-P02-intento01/piloto/aceptacion.json")
informe[c("version_fhirviews", "candidato_md5", "esquema_informe", "resultado_tecnico")]
read.csv("sesion-P02-intento01/piloto/aceptacion.csv")
```

## F03. Contrastar cinco tipos R4 y sus referencias

Relacionar las seis lineas NDJSON con los recursos y tablas originales.

1. Abrir piloto/r4/recursos-r4.ndjson y localizar los seis recursos.
2. Seguir las referencias al Patient/p1 y los enlaces de Condition/c1 e Immunization/i1 a Encounter/e1.
3. Identificar active=false y los objetos opcionales ausentes en la segunda inmunizacion.

**Contraste:** Patient, Encounter, Condition, Observation y dos Immunization; una fila de entrada por recurso construido.

**Evidencia:** Lineas y campos contrastados; explicacion antes de recibir la referencia.

```r
recursos <- fhir_recursos("sesion-P02-intento01/piloto/r4/recursos-r4.ndjson")
print(recursos)
```

## F04. Explicar escala y elecciones de fecha y dosis

Distinguir texto JSON conservado, valores numericos y variantes FHIR ausentes.

1. Localizar 72.00 y 0.50 en los archivos, sin confiar solo en la impresion numerica de R.
2. Contrastar los limites inferiores y las dos variantes de occurrence[x] y doseNumber[x].
3. Explicar por que la segunda inmunizacion conserva texto y no recibe una fecha inventada.

**Contraste:** La escala del JSON original importa; ver 72 o 0.5 en R no acredita su precision original.

**Evidencia:** Literales revisados, tabla contrastada y explicacion del participante.

## F05. Crear y modificar una vista de inmunizaciones

Resolver una tarea nueva usando la documentacion y registrar la ayuda.

1. Crear un ViewDefinition para Immunization con id, estado, paciente y fecha.
2. Guardar el JSON; anadir las dos variantes de occurrence y guardar otra version.
3. Contrastar las dos inmunizaciones y explicar los NA. Pedir la referencia solo despues del primer intento.

**Contraste:** El participante conserva el JSON y contrasta la tabla con el recurso original; usar la solucion cuenta como ayuda.

**Evidencia:** Dos archivos ViewDefinition, tabla y registro del observador.

## F06. Leer alergias sin confundir registros y filas

Explicar la relacion entre alergia, reaccion, manifestacion y categorias.

1. Abrir el ejemplo de alergias instalado y ejecutar la vista del catalogo.
2. Explicar por que tres registros producen cinco filas y como contar ids distintos.
3. Contrastar categorias como listas, gravedad por reaccion, criticidad y valores ausentes.
4. Revisar que los estados se seleccionan por sistema y no se mezclan dos Coding.

**Contraste:** a1 aporta tres filas; a2 y a3 una cada uno. AllergyIntolerance se extrae mediante una vista; no es un constructor SQL → FHIR.

**Evidencia:** Conteo de ids, filas y campos contrastados con los recursos ficticios.

```r
archivo <- system.file("extdata", "alergias_r4.ndjson", package = "fhirviews")
alergias <- vista_ejecutar(archivo, vista_plantilla("alergias"))
alergias[, c("id", "estado_clinico", "gravedad_reaccion", "reaccion_codigo")]
length(unique(alergias$id))
```

## F07. Repetir el ensayo conservando ambos intentos

Comprobar repetibilidad sin sobrescribir evidencia ni exigir tiempos iguales.

1. Ejecutar el perfil acordado en una carpeta nueva de intento02.
2. Comparar hallazgos y estados, no rutas, sesiones ni duraciones.
3. Registrar cualquier ayuda y conservar ambas salidas; reiniciar R antes de abrir otra biblioteca si hace falta.

**Contraste:** Los hallazgos de datos ficticios coinciden; cada intento conserva su propio entorno y tiempos.

**Evidencia:** Dos informes, comparacion de hallazgos y registro de ayuda.

```r
iniciar_piloto("completo", "sesion-P02-intento02")
a <- jsonlite::read_json("sesion-P02-intento01/piloto/aceptacion.json")
b <- jsonlite::read_json("sesion-P02-intento02/piloto/aceptacion.json")
identical(a$hallazgos, b$hallazgos)
```

## F08. Revisar hallazgos y registrar la decision humana

Entregar evidencia revisable y un cierre acordado, separado del resultado tecnico.

1. Completar experiencia-usuario.txt y registrar incidencias, pasos, esperado y observado.
2. Revisar con el mantenedor los datos ficticios y archivos que se compartiran.
3. Registrar conclusion, responsables y pruebas no evaluadas; exportar las fichas JSON.
4. Preparar el aviso si se acordo. El envio se realiza fuera del formulario.

**Contraste:** Una decision humana explicita; tareas obligatorias incompletas o incidencias altas/criticas abiertas requieren revision.

**Evidencia:** Ficha exportada, experiencia-usuario.txt y acuerdos de seguimiento.

## F09. Construir Specimen y DiagnosticReport desde SQL (opcional)

Ampliar el recorrido del perfil completo con los constructores del candidato.

1. Revisar y ejecutar `examples/laboratorio-r4.R` desde la instalacion aislada; usar solo datos ficticios.
2. Identificar Patient, Specimen, dos Observation y DiagnosticReport; seguir `result[].reference` y `specimen[].reference`.
3. Comparar las tablas de resultados y muestras entre V8 y DuckDB; registrar ayuda y cualquier diferencia.
4. Si no se evalua, marcar no_evaluada y justificar la exclusion; requiere DBI y DuckDB.

**Contraste:** El ejemplo genera una muestra, dos observaciones y un informe que conserva referencias variables. Esta tarea opcional no altera los cinco controles de aceptacion.

**Evidencia:** Salida del ejemplo, tablas comparadas y explicacion, o razon documentada de exclusion.
