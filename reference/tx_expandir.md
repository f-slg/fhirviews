# Expandir un ValueSet en un servidor de terminología (\$expand)

Pide a un servidor de terminología FHIR (por ejemplo
`https://tx.fhir.org/r4`, un Snowstorm o un HAPI con terminologías
cargadas) la lista de códigos de un `ValueSet` con la operación
`ValueSet/$expand`. Las expansiones grandes se descargan por páginas
(parámetros `offset` y `count`), así que sirve para conjuntos de miles
de códigos, como todos los diagnósticos de diabetes de la CIE-10 o de
SNOMED CT.

## Usage

``` r
tx_expandir(
  con,
  valueset,
  filtro = NULL,
  max = Inf,
  tamano_pagina = 1000L,
  parametros = list()
)
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

- filtro:

  Texto opcional para filtrar los códigos por su nombre (parámetro
  `filter`; cada servidor decide cómo lo aplica).

- max:

  Número máximo de códigos que se descargan.

- tamano_pagina:

  Códigos que se piden en cada petición.

- parametros:

  Lista con nombre de otros parámetros de `$expand`, por ejemplo
  `list(displayLanguage = "es", activeOnly = TRUE)`.

## Value

Un `data.frame` con una fila por código y las columnas `system`, `code`,
`display` y, si el servidor la informa, `version`. Las jerarquías
(`contains` anidados) se aplanan y se omiten los códigos abstractos
(`abstract = true`), que no se usan para codificar. Los atributos
`valueset` (URL), `total` (total que informa el servidor) y `expansion`
(datos de la expansión sin los códigos) documentan de dónde salió la
lista. Se puede pasar a
[`vista_con_valueset()`](https://f-slg.github.io/fhirviews/reference/vista_con_valueset.md).

## Details

Las funciones de terminología llevan el prefijo `tx_` (abreviatura de
*terminology* que usa la comunidad FHIR, como en `tx.fhir.org`) para
distinguirlas de las que trabajan con recursos clínicos (`fhir_*`) y con
vistas (`vista_*`). Usan la misma conexión de
[`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md),
con su token o su autenticación SMART on FHIR, y los mismos errores con
el `OperationOutcome` del servidor.

## See also

[`tx_buscar_codigo()`](https://f-slg.github.io/fhirviews/reference/tx_buscar_codigo.md),
[`tx_validar_codigo()`](https://f-slg.github.io/fhirviews/reference/tx_validar_codigo.md),
[`vista_con_valueset()`](https://f-slg.github.io/fhirviews/reference/vista_con_valueset.md).

## Examples

``` r
if (FALSE) { # fhir_disponible("https://tx.fhir.org/r4")
tx <- fhir_conectar("https://tx.fhir.org/r4", panel = FALSE)

# Un ValueSet publicado, por su URL canónica
sexo <- tx_expandir(tx, "http://hl7.org/fhir/ValueSet/administrative-gender")
sexo

# Un ValueSet propio: los descendientes de "diabetes mellitus" en SNOMED CT
diabetes <- tx_expandir(tx, list(
  resourceType = "ValueSet",
  compose = list(include = list(list(
    system = "http://snomed.info/sct",
    filter = list(list(property = "concept", op = "is-a",
                       value = "73211009"))
  )))
), max = 200)
head(diabetes)
}
```
