# Validar un recurso en el servidor (\$validate)

Envía un recurso a la operación `$validate` del servidor
(`POST [base]/[tipo]/$validate`) y devuelve los problemas encontrados.

## Usage

``` r
fhir_validar(con, recurso, perfil = NULL)
```

## Arguments

- con:

  Conexión creada con
  [`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md).

- recurso:

  El recurso como lista de R, texto JSON o ruta a un archivo.

- perfil:

  URL canónica opcional de un perfil (`StructureDefinition`) contra el
  que validar.

## Value

Un `data.frame` de clase `fhir_validacion` con una fila por problema
(`severidad`, `codigo`, `mensaje`, `ubicacion`) y el atributo `valido`
(`TRUE` si no hay errores). Al imprimirlo, resume el resultado.

## Examples

``` r
con <- fhir_conectar("https://hapi.fhir.org/baseR4")
fhir_validar(con, list(resourceType = "Patient", gender = "mujer"))
#> No válido: 1 error y 0 advertencias.
#>   severidad codigo     ubicacion
#> 1 error     processing <NA>     
#>   mensaje                                                                                                                                                                      
#> 1 HAPI-0450: Failed to parse request body as JSON resource. Error was: HAPI-1821: [element="gender"] Invalid attribute value "mujer": Unknown AdministrativeGender code 'mujer'
```
