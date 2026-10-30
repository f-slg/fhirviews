# Validar códigos contra un ValueSet (\$validate-code)

Pregunta al servidor de terminología si cada código pertenece a un
`ValueSet`, con la operación `ValueSet/$validate-code`. Sirve, por
ejemplo, para revisar los diagnósticos de una base de datos antes de
calcular un indicador.

## Usage

``` r
tx_validar_codigo(con, valueset, sistema, codigo, display = NULL, lote = TRUE)
```

## Arguments

- con:

  Conexión al servidor de terminología creada con
  [`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md).

- valueset:

  El `ValueSet`: su URL canónica (con versión opcional,
  `"http://.../ValueSet/x|2.0"`), o el recurso completo como lista de R,
  texto JSON o ruta a un archivo JSON (útil para un `ValueSet` propio
  que no está publicado en el servidor; por ejemplo, uno con
  `compose.include` y un filtro `is-a` de SNOMED CT).

- sistema:

  URL del sistema de codificación de los códigos; se recicla si es uno
  solo.

- codigo:

  Vector de códigos.

- display:

  Vector opcional de nombres (*display*) que el servidor también
  comprueba.

- lote:

  Si es `TRUE` (por defecto), hay varios códigos y `valueset` es una URL
  canónica, se envían en Bundles `batch` de hasta 100 códigos, con una
  petición por Bundle. Si el servidor no admite `batch`, o si `valueset`
  es un recurso, se valida un código por petición, como con
  `lote = FALSE`.

## Value

Un `data.frame` con una fila por código y las columnas `sistema`,
`codigo`, `valido` (lógico), `display` (el nombre que da el servidor) y
`mensaje` (la explicación del servidor, sobre todo cuando no es válido).

## Details

La función se llama `tx_validar_codigo()`, en infinitivo como
[`fhir_validar()`](https://f-slg.github.io/fhirviews/reference/fhir_validar.md),
[`tx_expandir()`](https://f-slg.github.io/fhirviews/reference/tx_expandir.md)
y
[`tx_buscar_codigo()`](https://f-slg.github.io/fhirviews/reference/tx_buscar_codigo.md).

## See also

[`tx_expandir()`](https://f-slg.github.io/fhirviews/reference/tx_expandir.md),
[`tx_buscar_codigo()`](https://f-slg.github.io/fhirviews/reference/tx_buscar_codigo.md).

## Examples

``` r
tx <- fhir_conectar("https://tx.fhir.org/r4", panel = FALSE)
tx_validar_codigo(tx, "http://hl7.org/fhir/ValueSet/administrative-gender",
                  "http://hl7.org/fhir/administrative-gender",
                  c("female", "mujer"))
#>                                     sistema codigo valido display
#> 1 http://hl7.org/fhir/administrative-gender female   TRUE  Female
#> 2 http://hl7.org/fhir/administrative-gender  mujer  FALSE    <NA>
#>                                                                                                                                                                                                                                                             mensaje
#> 1                                                                                                                                                                                                                                                              <NA>
#> 2 The provided code 'http://hl7.org/fhir/administrative-gender#mujer' was not found in the value set 'http://hl7.org/fhir/ValueSet/administrative-gender|4.0.1'; Unknown code 'mujer' in the CodeSystem 'http://hl7.org/fhir/administrative-gender' version '4.0.1'
```
