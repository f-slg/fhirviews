# Crear un ViewDefinition sencillo

Arma un `ViewDefinition` con una columna por expresión FHIRPath, sin
escribir JSON. Para vistas con varios niveles (`select` anidados,
`unionAll`, `repeat`) escribe el JSON o la lista completa y léela con
[`vista_leer()`](https://f-slg.github.io/fhirviews/reference/vista_leer.md).

## Usage

``` r
vista_crear(
  recurso,
  columnas,
  por_cada = NULL,
  incluir_vacios = FALSE,
  columnas_recurso = c(id = "getResourceKey()"),
  where = NULL,
  constantes = NULL,
  nombre = NULL
)
```

## Arguments

- recurso:

  Tipo de recurso FHIR, por ejemplo `"Patient"`.

- columnas:

  Vector de caracteres con nombre: el nombre es el de la columna y el
  valor, la expresión FHIRPath.

- por_cada:

  Expresión FHIRPath opcional (`forEach`): se genera una fila por cada
  elemento que devuelve, y las columnas se evalúan sobre él.

- incluir_vacios:

  Con `por_cada`, si es `TRUE` usa `forEachOrNull`: los recursos sin
  elementos dan una fila con `NA` en vez de no aparecer.

- columnas_recurso:

  Vector de caracteres con nombre, como `columnas`, con columnas que se
  evalúan sobre el recurso (no sobre cada elemento de `por_cada`). Por
  defecto, la clave del recurso en la columna `id`.

- where:

  Vector de caracteres con condiciones FHIRPath; solo se incluyen los
  recursos que las cumplen todas.

- constantes:

  Lista con nombre de constantes, que las expresiones usan como
  `%nombre`.

- nombre:

  Nombre de la vista (opcional).

## Value

Una lista de clase `fhir_vista`.

## Examples

``` r
vista_crear("Patient", c(sexo = "gender", nacimiento = "birthDate"))
#> <ViewDefinition> 
#>   Recurso: Patient
#>   Columnas (3): id, sexo, nacimiento

# Una fila por cada nombre del paciente
vista_crear("Patient", c(apellido = "family", nombres = "given.join(' ')"),
            por_cada = "name")
#> <ViewDefinition> 
#>   Recurso: Patient
#>   Columnas (3): id, apellido, nombres

# Observaciones de presi\u00f3n arterial de un paciente
vista_crear(
  "Observation",
  c(paciente = "subject.getReferenceKey(Patient)",
    valor = "value.ofType(Quantity).value"),
  where = "code.coding.where(code = %loinc).exists()",
  constantes = list(loinc = "85354-9")
)
#> <ViewDefinition> 
#>   Recurso: Observation
#>   Columnas (3): id, paciente, valor
#>   Condiciones: code.coding.where(code = %loinc).exists()
```
