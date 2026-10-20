# Buscar un código en un sistema de codificación (\$lookup)

Consulta un código en un servidor de terminología con la operación
`CodeSystem/$lookup` y devuelve su nombre (*display*), sus designaciones
(por ejemplo, en otros idiomas) y sus propiedades (padres, estado,
sinónimos, etc., según el sistema).

## Usage

``` r
tx_buscar_codigo(con, sistema, codigo, version = NULL, propiedades = NULL)
```

## Arguments

- con:

  Conexión al servidor de terminología creada con
  [`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md).

- sistema:

  URL del sistema de codificación, por ejemplo
  `"http://snomed.info/sct"`, `"http://loinc.org"` o
  `"http://hl7.org/fhir/sid/icd-10"`.

- codigo:

  El código.

- version:

  Versión opcional del sistema.

- propiedades:

  Vector de caracteres opcional con las propiedades que se piden
  (parámetro `property`); por defecto, las que el servidor devuelva.

## Value

Una lista con `sistema`, `codigo`, `nombre` (nombre del sistema),
`version`, `display`, `designaciones` (`data.frame` con `idioma`, `uso`
y `valor`) y `propiedades` (`data.frame` con `propiedad`, `valor` y
`descripcion`). La respuesta completa (`Parameters`) queda en el
atributo `respuesta`.

## See also

[`tx_expandir()`](https://f-slg.github.io/fhirviews/reference/tx_expandir.md),
[`tx_validar_codigo()`](https://f-slg.github.io/fhirviews/reference/tx_validar_codigo.md).

## Examples

``` r
tx <- fhir_conectar("https://tx.fhir.org/r4", panel = FALSE)
glucosa <- tx_buscar_codigo(tx, "http://loinc.org", "2345-7")
glucosa$display
#> [1] "Glucose [Mass/volume] in Serum or Plasma"
head(glucosa$propiedades)
#>    propiedad     valor descripcion
#> 1   inactive     FALSE        <NA>
#> 2      CLASS  LP7786-9        <NA>
#> 3  COMPONENT LP14635-4        <NA>
#> 4   PROPERTY  LP6827-2        <NA>
#> 5 TIME_ASPCT  LP6960-1        <NA>
#> 6     SYSTEM  LP7576-4        <NA>
```
