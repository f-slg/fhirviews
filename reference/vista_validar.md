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
`fhirviews_error_vista` con la lista de problemas encontrados. Los
avisos del modelo R4 son de clase `fhirviews_aviso_vista`.

## Details

- tiene `resource` y al menos un `select`;

- cada `select` usa solo los elementos permitidos y como mucho uno de
  `forEach`, `forEachOrNull` y `repeat`;

- cada columna tiene `name` y `path`; los nombres son válidos en SQL
  (empiezan con una letra y solo usan letras, números y `_`) y no se
  repiten;

- los `select` de un `unionAll` producen las mismas columnas, en el
  mismo orden;

- `column`, `select` y `unionAll`, si aparecen, tienen al menos un
  elemento;

- cada constante tiene nombre y un solo valor (`valueString`,
  `valueInteger`, etc.), y su nombre no es una variable reservada de
  FHIRPath o del motor (`resource`, `rootResource`, `context`,
  `rowIndex`, `ucum`, `sct`, `loinc`...);

- todas las expresiones FHIRPath se pueden compilar.

Además, con el modelo de FHIR R4 avisa (sin error) si `resource` no es
un tipo de recurso de R4 o si una ruta usa un elemento que no existe
(por ejemplo `name.familia` en lugar de `name.family`): FHIRPath no da
error en esos casos y la vista devolvería una tabla vacía o columnas sin
valores. Solo se revisan los pasos de navegación simples; los elementos
de elección (`value`), las extensiones y las expresiones con operadores
no generan avisos. Se pueden silenciar con
`suppressWarnings(..., classes = "fhirviews_aviso_vista")`.

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
