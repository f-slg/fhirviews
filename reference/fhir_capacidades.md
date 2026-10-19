# Capacidades del servidor

Lee el `CapabilityStatement` (`GET [base]/metadata`) y resume qué
recursos admite el servidor y qué se puede hacer con cada uno.

## Usage

``` r
fhir_capacidades(con)
```

## Arguments

- con:

  Conexión creada con
  [`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md).

## Value

Un `data.frame` con una fila por tipo de recurso: `recurso`,
`interacciones` (`read`, `search-type`, `create`...) y
`parametros_busqueda`. El `CapabilityStatement` completo queda en el
atributo `capability`.

## Examples

``` r
if (FALSE) { # fhir_disponible("https://hapi.fhir.org/baseR4")
con <- fhir_conectar("https://hapi.fhir.org/baseR4")
cap <- fhir_capacidades(con)
head(cap)
}
```
