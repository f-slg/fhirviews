# Tabla rápida de recursos FHIR

Convierte recursos en una tabla con una fila por recurso y una columna
por cada elemento de primer nivel, sin escribir un `ViewDefinition`.
Sirve para echar un vistazo a los datos (es la vista previa del panel
*Connections* de RStudio); para tablas definitivas y reproducibles usa
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md).

## Usage

``` r
fhir_tabla(recursos, tipo = NULL, max_caracteres = 200L)
```

## Arguments

- recursos:

  Recursos FHIR en cualquier forma que acepte
  [`fhir_recursos()`](https://f-slg.github.io/fhirviews/reference/fhir_recursos.md).

- tipo:

  Tipo de recurso opcional para quedarse solo con ese tipo.

- max_caracteres:

  Largo máximo del texto de cada celda compleja; se recorta con `...`.

## Value

Un `data.frame` con las columnas `resourceType`, `id` y una por cada
elemento de primer nivel (salvo `text`, la narrativa HTML).

## Details

Los valores simples se copian tal cual; las listas de valores simples se
unen con `"; "`; los elementos complejos (por ejemplo `name` o `code`)
se muestran como JSON compacto.

## Examples

``` r
fhir_tabla(list(
  list(resourceType = "Patient", id = "p1", gender = "female",
       name = list(list(family = "Paredes Cevallos", given = list("Ana")))),
  list(resourceType = "Patient", id = "p2", birthDate = "2001-11-30")
))
#>   resourceType id gender                                            name
#> 1      Patient p1 female [{"family":"Paredes Cevallos","given":["Ana"]}]
#> 2      Patient p2   <NA>                                            <NA>
#>    birthDate
#> 1       <NA>
#> 2 2001-11-30
```
