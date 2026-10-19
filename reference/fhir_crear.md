# Crear, actualizar y borrar recursos

- `fhir_crear()` envía un recurso nuevo (`POST [base]/[tipo]`); el
  servidor le asigna el id.

- `fhir_actualizar()` reemplaza un recurso existente
  (`PUT [base]/[tipo]/[id]`), o lo crea con ese id si el servidor lo
  permite.

- `fhir_borrar()` lo elimina (`DELETE [base]/[tipo]/[id]`).

## Usage

``` r
fhir_crear(con, recurso)

fhir_actualizar(con, recurso)

fhir_borrar(con, recurso, id = NULL)
```

## Arguments

- con:

  Conexión creada con
  [`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md).

- recurso:

  Para crear o actualizar: el recurso como lista de R, texto JSON o ruta
  a un archivo JSON. Para borrar: el tipo de recurso (`"Patient"`), una
  referencia (`"Patient/123"`) o el recurso mismo.

- id:

  Para borrar, el id del recurso, si `recurso` es solo el tipo.

## Value

`fhir_crear()` y `fhir_actualizar()` devuelven el recurso tal como lo
guardó el servidor (con su id y `meta.versionId`). `fhir_borrar()`
devuelve `TRUE` de forma invisible.

## Examples

``` r
if (FALSE) { # interactive() && fhir_disponible("http://localhost:8080/fhir")
# Con un servidor HAPI local (por ejemplo, el del taller aprende-fhir)
con <- fhir_conectar("http://localhost:8080/fhir")
paciente <- fhir_crear(con, list(
  resourceType = "Patient",
  name = list(list(family = "Paredes Cevallos", given = list("Ana"))),
  gender = "female", birthDate = "1985-03-12"
))
paciente$id

paciente$telecom <- list(list(system = "phone", value = "0991234567"))
paciente <- fhir_actualizar(con, paciente)
paciente$meta$versionId

fhir_borrar(con, paciente)
}
```
