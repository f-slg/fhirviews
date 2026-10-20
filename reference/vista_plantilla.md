# Obtener una vista del catálogo

Devuelve uno de los `ViewDefinition` de
[`vista_catalogo()`](https://f-slg.github.io/fhirviews/reference/vista_catalogo.md)
listo para
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md),
[`vista_ejecutar_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_duckdb.md),
[`vista_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_duckdb.md)
o
[`vista_sql()`](https://f-slg.github.io/fhirviews/reference/vista_sql.md).
Sirve también como punto de partida para una vista propia:
[`vista_json()`](https://f-slg.github.io/fhirviews/reference/vista_json.md)
muestra su JSON para copiarlo y modificarlo.

## Usage

``` r
vista_plantilla(nombre, constantes = NULL)
```

## Arguments

- nombre:

  Nombre de la vista, uno de los de la columna `nombre` de
  [`vista_catalogo()`](https://f-slg.github.io/fhirviews/reference/vista_catalogo.md).

- constantes:

  Lista con nombre opcional para cambiar el valor de constantes de la
  vista, por ejemplo `list(codigos = "A90,A91,A92")`. Solo se pueden
  cambiar constantes que la vista ya tiene.

## Value

Una lista de clase `fhir_vista` (ver
[`vista_leer()`](https://f-slg.github.io/fhirviews/reference/vista_leer.md)).

## Details

Algunas vistas tienen constantes que se pueden cambiar con `constantes`.
Por ejemplo, `notificacion_obligatoria` filtra los diagnósticos con la
constante `codigos`, una lista de categorías CIE-10 (tres caracteres)
separadas por comas, y `diagnosticos` usa las constantes `sistema_cie10`
y `sistema_snomed` con el URI de cada sistema de codificación.

## See also

[`vista_catalogo()`](https://f-slg.github.io/fhirviews/reference/vista_catalogo.md)
para la lista de vistas.

## Examples

``` r
caso <- system.file("extdata", "caso_clinico.ndjson", package = "fhirviews")
vista_ejecutar(caso, vista_plantilla("signos_vitales"))
#>         id paciente encuentro estado                     fecha codigo
#> 1   obs-pa  patient encounter  final 2025-03-20T07:30:00-05:00 8480-6
#> 2   obs-pa  patient encounter  final 2025-03-20T07:30:00-05:00 8462-4
#> 3 obs-temp  patient encounter  final 2025-03-20T07:30:00-05:00 8310-5
#> 4   obs-fr  patient encounter  final 2025-03-20T07:30:00-05:00 9279-1
#> 5   obs-fc  patient encounter  final 2025-03-20T07:30:00-05:00 8867-4
#> 6  obs-bsa  patient      <NA>  final                2025-07-01 8277-6
#>               descripcion  valor            unidad unidad_ucum
#> 1       Presión sistólica 128.00              mmHg      mm[Hg]
#> 2      Presión diastólica  84.00              mmHg      mm[Hg]
#> 3    Temperatura corporal  38.40                °C         Cel
#> 4 Frecuencia respiratoria  20.00 respiraciones/min        /min
#> 5     Frecuencia cardíaca 102.00       latidos/min        /min
#> 6     Superficie corporal   1.77                m2          m2

# Solo los casos de dengue hemorrágico (A91)
dengue <- system.file("extdata", "dengue_2025.ndjson.gz",
                      package = "fhirviews")
notificacion <- vista_plantilla("notificacion_obligatoria",
                                constantes = list(codigos = "A91"))
head(vista_ejecutar(dengue, notificacion))
#>          id  paciente cie10 categoria  descripcion     inicio   registro
#> 1 den-c0010 den-p0010   A91       A91 Dengue grave 2025-04-05 2025-04-08
#> 2 den-c0019 den-p0019   A91       A91 Dengue grave 2025-03-17 2025-03-19
#> 3 den-c0023 den-p0023   A91       A91 Dengue grave 2025-07-23 2025-07-25
#> 4 den-c0038 den-p0038   A91       A91 Dengue grave 2025-07-29 2025-08-01
#> 5 den-c0039 den-p0039   A91       A91 Dengue grave 2025-02-23 2025-02-25
#> 6 den-c0060 den-p0060   A91       A91 Dengue grave 2025-02-16 2025-02-19
#>   verificacion
#> 1    confirmed
#> 2    confirmed
#> 3    confirmed
#> 4    confirmed
#> 5    confirmed
#> 6    confirmed
```
