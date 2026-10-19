# ViewDefinition en detalle

Un `ViewDefinition` describe, de forma portable, cómo pasar de recursos
FHIR (árboles JSON) a una tabla. Es el núcleo de la especificación [SQL
on FHIR](https://sql-on-fhir.org/): la misma vista funciona en
fhirviews, en Pathling, en Aidbox o en cualquier otra implementación.
Esta viñeta repasa todos sus elementos con el caso clínico del taller
[aprende-fhir](https://github.com/f-slg/aprende-fhir).

``` r

library(fhirviews)
caso <- fhir_recursos(system.file("extdata", "caso_clinico.ndjson",
                                  package = "fhirviews"))
```

En R conviene escribir el JSON entre `r"-(` y `)-"` (cadenas crudas):
así las comillas dobles del JSON y las simples de FHIRPath no necesitan
escapes.

## Estructura

``` json
{
  "resourceType": "ViewDefinition",
  "name": "...",          // nombre de la tabla
  "resource": "Patient",  // tipo de recurso
  "constant": [...],      // constantes (%nombre)
  "select": [...],        // columnas y anidamientos
  "where": [...]          // filtros
}
```

Cada elemento de `select` puede tener:

| Elemento | Qué hace |
|----|----|
| `column` | columnas: `name`, `path` (FHIRPath), `type`, `collection` |
| `select` | selecciones anidadas, cuyas filas se combinan con las del padre |
| `forEach` | una fila por cada elemento de la expresión |
| `forEachOrNull` | igual, pero con una fila de `NA` si no hay elementos |
| `repeat` | recorre una estructura recursiva a cualquier profundidad |
| `unionAll` | une las filas de varias selecciones con las mismas columnas |

## Columnas, tipos y colecciones

`type` fija el tipo de la columna en R. Si una expresión puede devolver
varios valores, hay que elegir uno (`first()`) o declarar
`"collection": true`, que da una columna de listas:

``` r

vista_ejecutar(caso, r"-({
  "resource": "Patient",
  "select": [{"column": [
    {"name": "id", "path": "getResourceKey()"},
    {"name": "nombres", "path": "name.where(use = 'official').given", "collection": true},
    {"name": "activo", "path": "active", "type": "boolean"},
    {"name": "nacimiento", "path": "birthDate", "type": "date"}
  ]}]
})-")
#>        id       nombres activo nacimiento
#> 1 patient Luis, Alberto   TRUE 1979-03-12
```

Sin `collection`, una expresión con varios valores da un error que
explica qué hacer:

``` r

vista_ejecutar(caso, vista_crear("Patient", c(nombres = "name.given")))
#> Error:
#> ! La columna nombres devolvió varios valores para una fila.
#> ✖ `name.given` dio `["Luis","Alberto"]`.
#> ℹ Usa `"collection": true` para guardar todos los valores, o una expresión que
#>   devuelva uno solo (por ejemplo con `first()`).
```

## forEach, forEachOrNull y `%rowIndex`

`forEach` genera una fila por elemento; `%rowIndex` da su posición
(desde 0). Los encuentros del caso y quién participó en cada uno:

``` r

vista_ejecutar(caso, r"-({
  "resource": "Encounter",
  "select": [
    {"column": [
      {"name": "encuentro", "path": "getResourceKey()"},
      {"name": "tipo", "path": "serviceType.text"},
      {"name": "inicio", "path": "period.start"}
    ]},
    {"forEachOrNull": "participant", "column": [
      {"name": "orden", "path": "%rowIndex"},
      {"name": "profesional", "path": "individual.display"}
    ]}
  ]
})-")
#>               encuentro             tipo                    inicio orden
#> 1             encounter Medicina general 2025-03-20T07:15:00-05:00     0
#> 2 vaccination-encounter             <NA> 2025-04-03T10:00:00-05:00     0
#> 3      nodule-encounter Medicina general 2025-04-22T08:00:00-05:00     0
#>                         profesional
#> 1  Dra. Andrea Lucía Salazar Moreno
#> 2 Lcda. Rosa Elena Quishpe Tenesaca
#> 3   Dra. Salazar · Medicina general
```

Con `forEach` en lugar de `forEachOrNull`, los encuentros sin
participantes no aparecerían.

## repeat: estructuras anidadas

Los cuestionarios (`QuestionnaireResponse`) anidan preguntas dentro de
preguntas. `repeat` las recorre todas, en profundidad, sin saber de
antemano cuántos niveles hay:

``` r

vista_ejecutar(caso, r"-({
  "resource": "QuestionnaireResponse",
  "select": [
    {"column": [
      {"name": "respuesta", "path": "getResourceKey()"},
      {"name": "fecha", "path": "authored"}
    ]},
    {"repeat": ["item"], "column": [
      {"name": "pregunta", "path": "linkId"},
      {"name": "valor", "path": "answer.value.first().toString()"}
    ]}
  ]
})-")
#>                            respuesta                     fecha    pregunta
#> 1  16b-questionnaireresponse-octubre 2025-10-28T09:30:00-05:00       dolor
#> 2  16b-questionnaireresponse-octubre 2025-10-28T09:30:00-05:00        ecog
#> 3  16b-questionnaireresponse-octubre 2025-10-28T09:30:00-05:00     sofocos
#> 4  16b-questionnaireresponse-octubre 2025-10-28T09:30:00-05:00   articular
#> 5  16b-questionnaireresponse-octubre 2025-10-28T09:30:00-05:00 comentarios
#> 6                   response-january 2026-01-27T09:30:00-05:00       dolor
#> 7                   response-january 2026-01-27T09:30:00-05:00        ecog
#> 8                   response-january 2026-01-27T09:30:00-05:00     sofocos
#> 9                   response-january 2026-01-27T09:30:00-05:00   articular
#> 10                  response-january 2026-01-27T09:30:00-05:00 comentarios
#>                                                                     valor
#> 1                                                                       2
#> 2                                0 · Hago mi vida normal sin limitaciones
#> 3                                                                   false
#> 4                                                                   false
#> 5                                    Me siento bien, ya volví al trabajo.
#> 6                                                                       6
#> 7                          1 · Tengo síntomas, pero hago trabajos ligeros
#> 8                                                                    true
#> 9                                                                    true
#> 10 Los bochornos no me dejan dormir y me duelen las rodillas y las manos.
```

## unionAll: varias formas en una sola columna

El valor de una observación puede ser un número, un texto, un código, un
lógico o una razón. Con `unionAll` y `forEach` sobre cada tipo se
obtiene una sola columna de texto:

``` r

valores <- vista_leer(r"-({
  "name": "valores",
  "resource": "Observation",
  "select": [
    {"column": [
      {"name": "id", "path": "getResourceKey()"},
      {"name": "encuentro", "path": "encounter.getReferenceKey(Encounter)"},
      {"name": "medida", "path": "code.text"}
    ]},
    {"unionAll": [
      {"forEach": "value.ofType(Quantity)", "column": [
        {"name": "tipo", "path": "'Quantity'"},
        {"name": "valor", "path": "value.toString() + ' ' + unit"}]},
      {"forEach": "value.ofType(string)", "column": [
        {"name": "tipo", "path": "'string'"},
        {"name": "valor", "path": "$this"}]},
      {"forEach": "value.ofType(CodeableConcept)", "column": [
        {"name": "tipo", "path": "'CodeableConcept'"},
        {"name": "valor", "path": "text"}]},
      {"forEach": "value.ofType(boolean)", "column": [
        {"name": "tipo", "path": "'boolean'"},
        {"name": "valor", "path": "iif($this, 'sí', 'no')"}]},
      {"forEach": "value.ofType(Ratio)", "column": [
        {"name": "tipo", "path": "'Ratio'"},
        {"name": "valor", "path": "numerator.value.toString() + ':' + denominator.value.toString()"}]}
    ]}
  ]
})-")
vista_ejecutar(caso, valores)[, c("medida", "tipo", "valor")]
#>                                               medida            tipo
#> 1                               Temperatura corporal        Quantity
#> 2                            Frecuencia respiratoria        Quantity
#> 3                                Frecuencia cardíaca        Quantity
#> 4                                             Fiebre         boolean
#> 5                                 Motivo de consulta          string
#> 6                             Sangre oculta en heces CodeableConcept
#> 7  Salmonella typhi O, anticuerpos (título) en suero           Ratio
#> 8                                   Tamaño del tumor        Quantity
#> 9                              Receptor de estrógeno CodeableConcept
#> 10                               Superficie corporal        Quantity
#>                                                                    valor
#> 1                                                                38.4 °C
#> 2                                                   20 respiraciones/min
#> 3                                                        102 latidos/min
#> 4                                                                     sí
#> 5  Dolor abdominal tipo cólico desde hace 3 días, con náuseas y diarrea.
#> 6                                                               Positivo
#> 7                                                                  1:160
#> 8                                                                 3.5 cm
#> 9                                                               Positivo
#> 10                                                               1.77 m2
```

Las ramas de un `unionAll` deben tener las mismas columnas en el mismo
orden; si no, la vista no es válida. Las columnas aparecen en este
orden: las del `column` de la selección, las de sus `select` anidados y
al final las del `unionAll`.

## Constantes y filtros

`constant` define valores que las expresiones usan como `%nombre`;
`where` deja solo los recursos que cumplen todas las condiciones. Las
fechas se comparan como fechas:

``` r

vista_ejecutar(caso, r"-({
  "resource": "MedicationRequest",
  "constant": [
    {"name": "desde", "valueDate": "2025-08-01"},
    {"name": "snomed", "valueUri": "http://snomed.info/sct"}
  ],
  "where": [{"path": "authoredOn >= %desde"}],
  "select": [{"column": [
    {"name": "medicamento", "path": "medication.ofType(CodeableConcept).text"},
    {"name": "snomed", "path": "medication.ofType(CodeableConcept).coding.where(system = %snomed).code.first()"},
    {"name": "estado", "path": "status"},
    {"name": "fecha", "path": "authoredOn", "type": "date"}
  ]}]
})-")
#>   medicamento    snomed  estado      fecha
#> 1  Tamoxifeno 373345002 stopped 2025-10-15
```

## Referencias entre recursos

`getResourceKey()` da la clave de cada recurso y `getReferenceKey(Tipo)`
la del recurso al que apunta una referencia (vacía si apunta a otro
tipo). Con ellas las vistas se unen como tablas, por ejemplo con
[`merge()`](https://rdrr.io/r/base/merge.html):

``` r

diagnosticos <- vista_ejecutar(caso, vista_crear("Condition", c(
  paciente = "subject.getReferenceKey(Patient)",
  diagnostico = "code.text",
  cie10 = "code.coding.where(system = 'http://hl7.org/fhir/sid/icd-10').code.first()",
  inicio = "onset.ofType(dateTime)"
)))
pacientes <- vista_ejecutar(caso, vista_crear("Patient", c(
  nombre = "name.where(use = 'official').text", sexo = "gender"
)))
merge(pacientes, diagnosticos, by.x = "id", by.y = "paciente",
      suffixes = c("_paciente", "_diagnostico"))
#>        id                        nombre sexo   id_diagnostico
#> 1 patient Luis Alberto Paredes Cevallos male  condition-intox
#> 2 patient Luis Alberto Paredes Cevallos male condition-cancer
#>                                            diagnostico cie10     inicio
#> 1 Intoxicación alimentaria bacteriana, no especificada A05.9 2025-03-17
#> 2       Carcinoma ductal infiltrante de mama izquierda C50.9 2025-05-13
```

## Validación

[`vista_leer()`](https://f-slg.github.io/fhirviews/reference/vista_leer.md)
y
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md)
validan la vista: estructura, nombres de columnas (letras, números y
`_`), columnas repetidas, ramas de `unionAll`, constantes y que cada
expresión FHIRPath se pueda compilar. Se informan todos los problemas a
la vez:

``` r

vista_validar(list(
  resource = "Patient",
  select = list(list(column = list(
    list(name = "1id", path = "id"),
    list(name = "sexo", path = "gender.("),
    list(name = "sexo", path = "gender")
  )))
))
#> Error:
#> ! El ViewDefinition no es válido.
#> ✖ El nombre de columna "1id" (select[1].column[1]) no es válido: debe empezar
#>   con una letra y usar solo letras, números y _.
#> ✖ Hay columnas con el mismo nombre: sexo.
#> ✖ La expresión de select[1].column[2].path no es válida: `gender.(`.
```

## SQL con DuckDB

[`vista_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_duckdb.md)
ejecuta varias vistas y guarda cada una como tabla en una base
[DuckDB](https://duckdb.org/) (en memoria, salvo que se indique otra
conexión), lista para consultarla con SQL:

``` r

db <- vista_duckdb(caso, list(
  paciente = vista_crear("Patient", c(nombre = "name.where(use = 'official').text")),
  encuentro = vista_crear("Encounter", c(
    paciente = "subject.getReferenceKey(Patient)",
    tipo = "serviceType.text", inicio = "period.start")),
  valores = valores
))
DBI::dbGetQuery(db, "
  SELECT p.nombre, e.tipo AS consulta, left(e.inicio, 10) AS fecha,
         v.medida, v.valor
  FROM valores v
  JOIN encuentro e ON v.encuentro = e.id
  JOIN paciente p ON e.paciente = p.id
  ORDER BY v.medida")
#>                          nombre         consulta      fecha
#> 1 Luis Alberto Paredes Cevallos Medicina general 2025-03-20
#> 2 Luis Alberto Paredes Cevallos Medicina general 2025-03-20
#> 3 Luis Alberto Paredes Cevallos Medicina general 2025-03-20
#> 4 Luis Alberto Paredes Cevallos Medicina general 2025-03-20
#> 5 Luis Alberto Paredes Cevallos Medicina general 2025-03-20
#> 6 Luis Alberto Paredes Cevallos Medicina general 2025-03-20
#> 7 Luis Alberto Paredes Cevallos Medicina general 2025-03-20
#>                                              medida
#> 1                                            Fiebre
#> 2                               Frecuencia cardíaca
#> 3                           Frecuencia respiratoria
#> 4                                Motivo de consulta
#> 5 Salmonella typhi O, anticuerpos (título) en suero
#> 6                            Sangre oculta en heces
#> 7                              Temperatura corporal
#>                                                                   valor
#> 1                                                                    sí
#> 2                                                       102 latidos/min
#> 3                                                  20 respiraciones/min
#> 4 Dolor abdominal tipo cólico desde hace 3 días, con náuseas y diarrea.
#> 5                                                                 1:160
#> 6                                                              Positivo
#> 7                                                               38.4 °C
DBI::dbDisconnect(db)
```

## Conformidad con la especificación

fhirviews incluye el banco oficial de pruebas de SQL on FHIR y pasa
todas las del perfil *shareable*, el que debe cumplir toda
implementación.
[`vista_conformidad()`](https://f-slg.github.io/fhirviews/reference/vista_conformidad.md)
las ejecuta y resume el resultado; con `informe = "archivo.json"` genera
el informe en el formato oficial.

``` r

vista_conformidad(c("basic.json", "foreach.json", "union.json"))
#> Banco de pruebas de SQL on FHIR (FHIR/sql-on-fhir.js@6677c20, 2026-07-09) 
#> fhirviews 0.1.0.9000 · fhirpath.js 5.2.1
#> 
#>   shareable       34 de  34 aprobadas
#>   total           34 de  34 aprobadas
```
