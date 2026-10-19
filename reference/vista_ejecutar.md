# Ejecutar un ViewDefinition

Aplica un `ViewDefinition` de [SQL on FHIR](https://sql-on-fhir.org/) a
un conjunto de recursos y devuelve la tabla resultante.

## Usage

``` r
vista_ejecutar(recursos, vista, validar = TRUE)
```

## Arguments

- recursos:

  Recursos FHIR en cualquier forma que acepte
  [`fhir_recursos()`](https://f-slg.github.io/fhirviews/reference/fhir_recursos.md).
  Solo se usan los del tipo indicado en `resource`.

- vista:

  Un `ViewDefinition` en cualquier forma que acepte
  [`vista_leer()`](https://f-slg.github.io/fhirviews/reference/vista_leer.md).

- validar:

  Si es `TRUE` (por defecto), valida la vista antes de ejecutarla con
  [`vista_validar()`](https://f-slg.github.io/fhirviews/reference/vista_validar.md).

## Value

Un `data.frame` con una columna por cada `column` de la vista, en el
orden que define la especificación. Los tipos de R siguen el `type` de
cada columna cuando se indica (`boolean` a lógico; `integer`,
`positiveInt` y `unsignedInt` a entero; `decimal` a numérico; el resto a
texto); si algún valor no es compatible (por ejemplo 1.7 en una columna
`integer`) se avisa y se conserva sin convertir. Sin `type`, el tipo
sale de los valores; si la columna no tiene ninguno, se deduce del
modelo de FHIR R4 (por ejemplo `birthDate` es texto y `active`, lógico),
para que la misma vista dé siempre los mismos tipos. Las fechas quedan
como texto ISO 8601 porque FHIR admite fechas parciales (`"2024"`,
`"2024-05"`). Las columnas con `collection: true` son listas.

## Details

Se admiten todos los elementos de la especificación: `select` anidados,
`column` (con `collection` y `type`), `forEach`, `forEachOrNull`,
`repeat`, `unionAll`, `where`, `constant` y la variable `%rowIndex`,
además de las funciones `getResourceKey()` y `getReferenceKey()`.

El motor evalúa cada expresión sobre todos los recursos a la vez (una
llamada a FHIRPath por expresión y nivel), así que el tiempo crece poco
con el número de recursos.

## See also

[`vista_crear()`](https://f-slg.github.io/fhirviews/reference/vista_crear.md)
y
[`vista_leer()`](https://f-slg.github.io/fhirviews/reference/vista_leer.md)
para definir la vista y
[`vista_fhirpath()`](https://f-slg.github.io/fhirviews/reference/vista_fhirpath.md)
para probar expresiones.

## Examples

``` r
pacientes <- list(
  list(resourceType = "Patient", id = "p1", gender = "female",
       birthDate = "1985-03-12",
       name = list(list(use = "official", family = "Paredes Cevallos",
                        given = list("Ana", "Luc\u00eda"))),
       address = list(list(city = "Loja", district = "Loja"))),
  list(resourceType = "Patient", id = "p2", gender = "male",
       birthDate = "2001-11-30",
       name = list(list(family = "Salazar Moreno", given = list("Jorge"))))
)

vista <- vista_crear(
  "Patient",
  c(sexo = "gender", nacimiento = "birthDate",
    apellido = "name.first().family", ciudad = "address.first().city")
)
vista_ejecutar(pacientes, vista)
#>   id   sexo nacimiento         apellido ciudad
#> 1 p1 female 1985-03-12 Paredes Cevallos   Loja
#> 2 p2   male 2001-11-30   Salazar Moreno   <NA>

# Una fila por cada nombre, desde JSON
vista_ejecutar(pacientes, '{
  "resource": "Patient",
  "select": [
    {"column": [{"name": "id", "path": "getResourceKey()"}]},
    {"forEach": "name", "column": [
      {"name": "orden", "path": "%rowIndex"},
      {"name": "apellido", "path": "family"},
      {"name": "nombres", "path": "given", "collection": true}
    ]}
  ]
}')
#>   id orden         apellido    nombres
#> 1 p1     0 Paredes Cevallos Ana, Lucía
#> 2 p2     0   Salazar Moreno      Jorge
```
