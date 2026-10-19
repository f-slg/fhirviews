# Guardar vistas en DuckDB

Ejecuta uno o varios `ViewDefinition` con
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md)
y guarda cada resultado como una tabla en una base
[DuckDB](https://duckdb.org/), para consultarlas y unirlas con SQL. Es
la idea original de SQL on FHIR: vistas tabulares de los recursos FHIR
listas para cualquier motor SQL.

## Usage

``` r
vista_duckdb(recursos, vistas, con_db = NULL, sobrescribir = TRUE)
```

## Arguments

- recursos:

  Recursos FHIR en cualquier forma que acepte
  [`fhir_recursos()`](https://f-slg.github.io/fhirviews/reference/fhir_recursos.md).

- vistas:

  Un `ViewDefinition` (en cualquier forma que acepte
  [`vista_leer()`](https://f-slg.github.io/fhirviews/reference/vista_leer.md))
  o una lista de ellos. Las tablas se llaman como el nombre de cada
  elemento de la lista o, si no lo tiene, como el elemento `name` de la
  vista.

- con_db:

  Conexión DBI donde guardar las tablas. Si es `NULL` (por defecto), se
  crea una base DuckDB en memoria.

- sobrescribir:

  Si es `TRUE` (por defecto), reemplaza las tablas que ya existan; si es
  `FALSE`, agrega las filas al final.

## Value

La conexión DBI, de forma invisible, para seguir consultándola con
[`DBI::dbGetQuery()`](https://dbi.r-dbi.org/reference/dbGetQuery.html).
Cierra con `DBI::dbDisconnect(con_db)` al terminar.

## Details

Las columnas con `collection: true` se guardan como listas de DuckDB
(por ejemplo `VARCHAR[]`), que se pueden consultar con `unnest()` o
`len()`. Los elementos complejos (objetos FHIR) se guardan como texto
JSON. Las fechas quedan como texto ISO 8601; para convertirlas usa
`CAST(columna AS DATE)` en la consulta cuando sean fechas completas.

Requiere los paquetes DBI y duckdb. Funciona también con otra conexión
DBI (SQLite, PostgreSQL...) siempre que admita los tipos de las
columnas.

## Examples

``` r
pacientes <- list(
  list(resourceType = "Patient", id = "p1", gender = "female",
       birthDate = "1985-03-12",
       name = list(list(family = "Paredes Cevallos",
                        given = list("Ana", "Luc\u00eda")))),
  list(resourceType = "Patient", id = "p2", gender = "male",
       birthDate = "2001-11-30",
       name = list(list(family = "Salazar Moreno", given = list("Jorge"))))
)
observaciones <- list(
  list(resourceType = "Observation", id = "o1", status = "final",
       code = list(text = "Glucosa"), subject = list(reference = "Patient/p1"),
       valueQuantity = list(value = 98, unit = "mg/dL")),
  list(resourceType = "Observation", id = "o2", status = "final",
       code = list(text = "Glucosa"), subject = list(reference = "Patient/p2"),
       valueQuantity = list(value = 131, unit = "mg/dL"))
)

db <- vista_duckdb(
  c(fhir_recursos(pacientes), observaciones),
  list(
    paciente = vista_crear("Patient", c(sexo = "gender",
                                         nombres = "name.given.join(' ')")),
    glucosa = vista_crear("Observation", c(
      paciente = "subject.getReferenceKey(Patient)",
      valor = "value.ofType(Quantity).value"))
  )
)
DBI::dbGetQuery(db, "
  SELECT p.nombres, p.sexo, g.valor
  FROM glucosa g JOIN paciente p ON g.paciente = p.id
  ORDER BY g.valor DESC")
#>     nombres   sexo valor
#> 1     Jorge   male   131
#> 2 Ana Lucía female    98
DBI::dbDisconnect(db)
```
