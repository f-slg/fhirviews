# Validar un ViewDefinition

Comprueba que un `ViewDefinition` cumpla la estructura de SQL on FHIR
antes de ejecutarlo:

## Usage

``` r
vista_validar(vista)
```

## Arguments

- vista:

  Un `ViewDefinition` en cualquier forma que acepte
  [`vista_leer()`](https://f-slg.github.io/fhirviews/reference/vista_leer.md).

## Value

La vista, de forma invisible, si es válida. Si no, un error de clase
`fhirviews_error_vista` con la lista de problemas encontrados.

## Details

- tiene `resource` y al menos un `select`;

- cada `select` usa solo los elementos permitidos y como mucho uno de
  `forEach`, `forEachOrNull` y `repeat`;

- cada columna tiene `name` y `path`; los nombres son válidos en SQL
  (empiezan con una letra y solo usan letras, números y `_`) y no se
  repiten;

- los `select` de un `unionAll` producen las mismas columnas, en el
  mismo orden;

- cada constante tiene nombre y un solo valor (`valueString`,
  `valueInteger`, etc.);

- todas las expresiones FHIRPath se pueden compilar.

## Examples

``` r
vista_validar(vista_crear("Patient", c(sexo = "gender")))

mala <- list(resource = "Patient",
             select = list(list(column = list(
               list(name = "1id", path = "id"),
               list(name = "sexo", path = "gender.(")))))
try(vista_validar(mala))
#> Error : El ViewDefinition no es válido.
#> ✖ El nombre de columna "1id" (select[1].column[1]) no es válido: debe empezar
#>   con una letra y usar solo letras, números y _.
#> ✖ La expresión de select[1].column[2].path no es válida: `gender.(`.
```
