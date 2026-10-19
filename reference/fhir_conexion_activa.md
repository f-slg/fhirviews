# Conexión activa y panel Connections de RStudio

[`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md)
guarda la última conexión como *conexión activa*, que usan los addins de
RStudio y
[`fhir_ejecutar_texto()`](https://f-slg.github.io/fhirviews/reference/fhir_ejecutar_texto.md).
En RStudio, además, la registra en el panel *Connections*: allí se ven
los tipos de recurso del servidor, sus columnas y una vista previa de
los datos (con
[`fhir_tabla()`](https://f-slg.github.io/fhirviews/reference/fhir_tabla.md)),
y hay acciones para ver las capacidades del servidor.

## Usage

``` r
fhir_conexion_activa()

fhir_desconectar(con)
```

## Arguments

- con:

  Conexión creada con
  [`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md).

## Value

`fhir_conexion_activa()` devuelve un objeto `fhir_conexion`.
`fhir_desconectar()` devuelve `TRUE` de forma invisible.

## Details

- `fhir_conexion_activa()` devuelve la conexión activa.

- `fhir_desconectar()` la quita del panel y deja de usarla como activa.

## Examples

``` r
con <- fhir_conectar("https://hapi.fhir.org/baseR4", panel = FALSE)
identical(fhir_conexion_activa()$url, con$url)
#> [1] TRUE
fhir_desconectar(con)
```
