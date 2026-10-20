# Catálogo de vistas listas para usar

Lista los `ViewDefinition` que trae el paquete para las tablas más
comunes en vigilancia y salud pública: pacientes con su dirección de
residencia, signos vitales, diagnósticos, enfermedades de notificación
obligatoria, inmunizaciones, encuentros y prescripciones de
medicamentos. Todas usan `getResourceKey()` para la columna `id` y
`getReferenceKey()` para las claves de otros recursos (por ejemplo
`paciente`), de modo que las tablas se pueden unir entre sí.

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

## See also

[`vista_plantilla()`](https://f-slg.github.io/fhirviews/reference/vista_plantilla.md)
para obtener una vista del catálogo.

## Examples

``` r
vista_catalogo()[, c("nombre", "recurso", "titulo")]
#>                     nombre           recurso
#> 1             diagnosticos         Condition
#> 2               encuentros         Encounter
#> 3           inmunizaciones      Immunization
#> 4             medicamentos MedicationRequest
#> 5 notificacion_obligatoria         Condition
#> 6                pacientes           Patient
#> 7           signos_vitales       Observation
#>                                     titulo
#> 1                             Diagnósticos
#> 2                               Encuentros
#> 3                           Inmunizaciones
#> 4           Prescripciones de medicamentos
#> 5 Enfermedades de notificación obligatoria
#> 6                                Pacientes
#> 7                           Signos vitales
```
