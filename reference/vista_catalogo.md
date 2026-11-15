# Catálogo de vistas listas para usar

Lista los `ViewDefinition` que trae el paquete para las tablas más
comunes en vigilancia y salud pública: pacientes con su dirección de
residencia, signos vitales, diagnósticos, enfermedades de notificación
obligatoria, inmunizaciones, encuentros y prescripciones de
medicamentos, alergias e intolerancias. Todas usan `getResourceKey()`
para la columna `id` y `getReferenceKey()` para las claves de otros
recursos (por ejemplo `paciente`), de modo que las tablas se pueden unir
entre sí.

## Usage

``` r
vista_catalogo()
```

## Value

Un `data.frame` con una fila por vista y las columnas `nombre` (para
[`vista_plantilla()`](https://f-slg.github.io/fhirviews/reference/vista_plantilla.md)),
`recurso` (tipo de recurso FHIR), `titulo` y `descripcion`.

## Details

Las vistas son JSON estándar de SQL on FHIR, guardados en la carpeta
`vistas` del paquete (`system.file("vistas", package = "fhirviews")`), y
dan los mismos resultados con
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md)
y con
[`vista_ejecutar_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_duckdb.md).
La vista `alergias` produce una fila por manifestacion de cada reaccion,
conservando una fila cuando no hay reacciones. Para contar alergias,
cuenta los valores distintos de `id`; `categoria` es una columna de
listas.

## See also

[`vista_plantilla()`](https://f-slg.github.io/fhirviews/reference/vista_plantilla.md)
para obtener una vista del catálogo.

## Examples

``` r
vista_catalogo()[, c("nombre", "recurso", "titulo")]
#>                     nombre            recurso
#> 1                 alergias AllergyIntolerance
#> 2             diagnosticos          Condition
#> 3               encuentros          Encounter
#> 4           inmunizaciones       Immunization
#> 5             medicamentos  MedicationRequest
#> 6 notificacion_obligatoria          Condition
#> 7                pacientes            Patient
#> 8           signos_vitales        Observation
#>                                       titulo
#> 1 Alergias e intolerancias por manifestación
#> 2                               Diagnósticos
#> 3                                 Encuentros
#> 4                             Inmunizaciones
#> 5             Prescripciones de medicamentos
#> 6   Enfermedades de notificación obligatoria
#> 7                                  Pacientes
#> 8                             Signos vitales
```
