# Banco oficial de pruebas de SQL on FHIR

Ejecuta las pruebas oficiales de conformidad de SQL on FHIR
([FHIR/sql-on-fhir.js](https://github.com/FHIR/sql-on-fhir.js), carpeta
`tests/`) con
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md)
e informa cuántas pasan.

## Usage

``` r
vista_conformidad(
  archivos = NULL,
  descargar = FALSE,
  ref = "main",
  directorio = NULL,
  informe = NULL
)
```

## Arguments

- archivos:

  Nombres de los archivos de pruebas que se ejecutan (por ejemplo
  `"basic.json"`). Por defecto, todos.

- descargar:

  Si es `TRUE`, descarga el banco de GitHub en lugar de usar la copia
  incluida. Necesita conexión a internet.

- ref:

  Rama, etiqueta o commit de `FHIR/sql-on-fhir.js` que se descarga
  cuando `descargar = TRUE`.

- directorio:

  Carpeta con los archivos JSON del banco, si se tiene una copia propia.
  Tiene prioridad sobre `descargar`.

- informe:

  Ruta opcional de un archivo JSON donde se guarda el resultado en el
  formato oficial de informes de SQL on FHIR (el que usa la página de
  implementaciones).

## Value

Un `data.frame` de clase `fhir_conformidad` con una fila por prueba:
`archivo`, `prueba`, `perfil`, `aprobada` (lógico) y `detalle` (motivo
de la falla). Al imprimirlo muestra el resumen por perfil y las pruebas
que fallan.

## Details

Cada prueba aplica un `ViewDefinition` a unos recursos y compara el
resultado con las filas esperadas (sin importar su orden, como el
ejecutor oficial), con los nombres de columnas esperados o con un error
esperado. Las pruebas tienen un perfil: `shareable` (las que debe
cumplir toda implementación) o `experimental`.

El paquete incluye una copia del banco (ver `FUENTE` en
`system.file("sof-tests", package = "fhirviews")`), de modo que no hace
falta internet. Con `descargar = TRUE` se usa la versión más reciente.

## Examples

``` r
vista_conformidad("basic.json")
#> Banco de pruebas de SQL on FHIR (FHIR/sql-on-fhir.js@6677c20, 2026-07-09) 
#> fhirviews 0.0.0.9000 · fhirpath.js 5.2.1
#> 
#>   shareable       11 de  11 aprobadas
#>   total           11 de  11 aprobadas
# \donttest{
res <- vista_conformidad()
table(res$perfil, res$aprobada)
#>               
#>                FALSE TRUE
#>   experimental     4    7
#>   shareable        0  133
# }
```
